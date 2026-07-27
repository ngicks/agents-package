// Command release cuts a release of this binary.
//
// Usage:
//
//	go run ./internal/cmd/release [-file <path>] <release-version> [<next-dev-version>]
//
// Workflow:
//  1. Validate the inputs and ensure the working tree is clean.
//  2. Rewrite internal/libver/libver.go to the release version, commit
//     ("🔖: release <tag>"), tag.
//  3. Rewrite the same file to the next development version (suffix
//     "-devel"), commit ("👷: start <tag> development cycle").
//  4. Push the branch and the new tag to origin.
//
// The version file lives at the fixed path internal/libver/libver.go.
// Legacy layouts — a top-level <name-without-separator>/version.go, or
// pkg/<name-without-separator>/version.go before that — are auto-detected
// as fallbacks (the glob must then match exactly one file). Pass
// -file <path> to override.
//
// Cross-platform by virtue of being a Go program: the same source
// compiles and runs on Linux, macOS, and Windows.
package main

import (
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

var (
	versionFile = flag.String(
		"file",
		"",
		"path to the version file (defaults to internal/libver/libver.go; legacy */version.go layouts auto-detected)",
	)
)

func init() {
	flag.Usage = func() {
		fmt.Fprint(
			flag.CommandLine.Output(),
			`usage: go run ./internal/cmd/release [-file <path>] <release-version> [<next-dev-version>]

  release-version    e.g. v0.2.0; must NOT end in -devel.
                     For a Go submodule, prefix the tag with the submodule
                     directory: subpkg/v0.2.0, nested/dir/v0.2.0. The version
                     file is then located under the same prefix
                     (<prefix>/internal/libver/libver.go; legacy layouts
                     auto-detected) and the bare version string (without the
                     prefix) is written into it.
  next-dev-version   defaults to bumping the patch and appending -devel
                     (v0.2.0 -> v0.2.1-devel; subpkg/v0.2.0 -> subpkg/v0.2.1-devel).
                     Must end in -devel.

flags:
`,
		)
		flag.PrintDefaults()
	}
}

const versionLineFormat = `const Version = %q`

var (
	// versionRE matches a release tag, optionally prefixed by a submodule
	// path. Each path component is [A-Za-z0-9_.-]+; components are joined
	// by "/"; the prefix (if any) ends with "/". The version part is the
	// usual vMAJOR.MINOR.PATCH[-suffix].
	versionRE = regexp.MustCompile(
		`^(?:[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*/)?v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$`,
	)
	versionLineRE = regexp.MustCompile(`(?m)^const\s+Version\s*=\s*"[^"]*"`)
)

func main() {
	flag.Parse()

	if n := flag.NArg(); n < 1 || n > 2 {
		panic(fmt.Errorf("missing or too many args"))
	}

	if err := run(flag.Arg(0), flag.Arg(1), *versionFile); err != nil {
		fmt.Fprintln(os.Stderr, "release:", err)
		os.Exit(1)
	}
}

func run(release, nextDev, versionFile string) error {
	if !versionRE.MatchString(release) {
		return fmt.Errorf("release-version must be vMAJOR.MINOR.PATCH[-suffix]; got %q", release)
	}
	if isDevel(release) {
		return fmt.Errorf("release-version must not end in -devel; got %q", release)
	}

	if nextDev == "" {
		var err error
		nextDev, err = defaultNextDev(release)
		if err != nil {
			return err
		}
	}
	if !versionRE.MatchString(nextDev) {
		return fmt.Errorf("next-dev-version must be vMAJOR.MINOR.PATCH[-suffix]; got %q", nextDev)
	}
	if !isDevel(nextDev) {
		return fmt.Errorf("next-dev-version must end in -devel; got %q", nextDev)
	}

	prefix, releaseVer := splitTag(release)
	_, nextDevVer := splitTag(nextDev)

	if versionFile == "" {
		var err error
		versionFile, err = findVersionFile(prefix)
		if err != nil {
			return err
		}
	}
	if _, err := os.Stat(versionFile); err != nil {
		return fmt.Errorf("version file: %w", err)
	}

	if err := requireCleanWorkTree(); err != nil {
		return err
	}
	if err := requireTagAbsent(release); err != nil {
		return err
	}

	if err := rewriteVersion(versionFile, releaseVer); err != nil {
		return err
	}
	if err := git("add", "--", versionFile); err != nil {
		return err
	}
	if err := git("commit", "-m", "🔖: release "+release); err != nil {
		return err
	}
	if err := git("tag", "-a", release, "-m", release); err != nil {
		return err
	}

	if err := rewriteVersion(versionFile, nextDevVer); err != nil {
		return err
	}
	if err := git("add", "--", versionFile); err != nil {
		return err
	}
	if err := git("commit", "-m", "👷: start "+nextDev+" development cycle"); err != nil {
		return err
	}

	if err := git("push"); err != nil {
		return err
	}
	if err := git("push", "origin", release); err != nil {
		return err
	}

	fmt.Printf(
		"released %s; bumped to %s; pushed branch and tag %s to origin.\n",
		release,
		nextDev,
		release,
	)
	return nil
}

// isDevel reports whether v carries a -devel suffix (with or without an
// extra dotted qualifier such as -devel.20240101).
func isDevel(v string) bool {
	return strings.HasSuffix(v, "-devel") || strings.Contains(v, "-devel.")
}

// splitTag separates an optional submodule path prefix from the version part
// of a release tag. The prefix is everything up to (and not including) the
// last "/"; the version part is everything after.
//
//	splitTag("v0.1.0")              -> "", "v0.1.0"
//	splitTag("subpkg/v0.1.0")       -> "subpkg", "v0.1.0"
//	splitTag("nested/sub/v0.1.0")   -> "nested/sub", "v0.1.0"
func splitTag(tag string) (prefix, version string) {
	if i := strings.LastIndex(tag, "/"); i >= 0 {
		return tag[:i], tag[i+1:]
	}
	return "", tag
}

// defaultNextDev returns the patch-bumped, -devel-suffixed counterpart of
// release. The submodule prefix (if any) is preserved.
//
//	v0.2.0           -> v0.2.1-devel
//	v0.2.0-rc1       -> v0.2.1-devel
//	subpkg/v0.2.0    -> subpkg/v0.2.1-devel
func defaultNextDev(release string) (string, error) {
	prefix, ver := splitTag(release)
	base := strings.TrimPrefix(ver, "v")
	if i := strings.IndexByte(base, '-'); i >= 0 {
		base = base[:i]
	}
	parts := strings.Split(base, ".")
	if len(parts) != 3 {
		return "", fmt.Errorf("could not parse release %q", release)
	}
	patch, err := strconv.Atoi(parts[2])
	if err != nil {
		return "", fmt.Errorf("could not parse patch component of %q: %w", release, err)
	}
	next := fmt.Sprintf("v%s.%s.%d-devel", parts[0], parts[1], patch+1)
	if prefix == "" {
		return next, nil
	}
	return prefix + "/" + next, nil
}

// findVersionFile locates the version file under submoduleDir ("" for the
// root module). The canonical location is the fixed internal/libver/libver.go.
// Legacy layouts kept a top-level <name-without-separator>/version.go
// (cmd/, internal/, api/, and pkg/ never held it and are skipped), or
// pkg/<name-without-separator>/version.go before that; those are detected
// as fallbacks and must then match exactly one file.
func findVersionFile(submoduleDir string) (string, error) {
	canonical := filepath.Join(submoduleDir, "internal", "libver", "libver.go")
	if _, err := os.Stat(canonical); err == nil {
		return canonical, nil
	}

	pattern := filepath.Join(submoduleDir, "*", "version.go")
	matches, err := filepath.Glob(pattern)
	if err != nil {
		return "", err
	}
	var filtered []string
	for _, m := range matches {
		switch filepath.Base(filepath.Dir(m)) {
		case "cmd", "internal", "api", "pkg":
			continue
		}
		filtered = append(filtered, m)
	}
	if len(filtered) == 0 {
		pattern = filepath.Join(submoduleDir, "pkg", "*", "version.go")
		filtered, err = filepath.Glob(pattern)
		if err != nil {
			return "", err
		}
	}
	if len(filtered) != 1 {
		return "", fmt.Errorf(
			"expected %s, or exactly one legacy %s; found %d legacy matches (pass -file <path> to override)",
			canonical,
			pattern,
			len(filtered),
		)
	}
	return filtered[0], nil
}

func requireCleanWorkTree() error {
	out, err := exec.Command("git", "status", "--porcelain").Output()
	if err != nil {
		return fmt.Errorf("git status: %w", err)
	}
	if len(out) > 0 {
		return errors.New("working tree is dirty; commit or stash first")
	}
	return nil
}

func requireTagAbsent(tag string) error {
	cmd := exec.Command("git", "rev-parse", "--verify", "refs/tags/"+tag)
	cmd.Stderr = nil // suppress "fatal: Needed a single revision"
	if err := cmd.Run(); err == nil {
		return fmt.Errorf("tag already exists: %s", tag)
	}
	return nil
}

func git(args ...string) error {
	cmd := exec.Command("git", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("git %s: %w", strings.Join(args, " "), err)
	}
	return nil
}

func rewriteVersion(file, version string) error {
	content, err := os.ReadFile(file)
	if err != nil {
		return fmt.Errorf("read %s: %w", file, err)
	}
	matches := versionLineRE.FindAll(content, -1)
	if len(matches) != 1 {
		return fmt.Errorf("expected exactly one %q line in %s; found %d",
			"const Version = \"...\"", file, len(matches))
	}
	replacement := fmt.Appendf(nil, versionLineFormat, version)
	newContent := versionLineRE.ReplaceAll(content, replacement)
	if err := os.WriteFile(file, newContent, 0o644); err != nil {
		return fmt.Errorf("write %s: %w", file, err)
	}
	return nil
}
