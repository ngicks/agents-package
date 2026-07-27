package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestIsDevel(t *testing.T) {
	cases := []struct {
		v    string
		want bool
	}{
		{"v0.1.0-devel", true},
		{"v0.1.0-devel.20240101", true},
		{"v0.1.0", false},
		{"v0.1.0-rc1", false},
		{"v0.1.0-alpha-devel", true},
	}
	for _, c := range cases {
		if got := isDevel(c.v); got != c.want {
			t.Errorf("isDevel(%q) = %v, want %v", c.v, got, c.want)
		}
	}
}

func TestDefaultNextDev(t *testing.T) {
	cases := []struct {
		release string
		want    string
		wantErr bool
	}{
		{"v0.1.0", "v0.1.1-devel", false},
		{"v1.2.99", "v1.2.100-devel", false},
		{"v0.1.0-rc1", "v0.1.1-devel", false},
		{"subpkg/v0.1.0", "subpkg/v0.1.1-devel", false},
		{"nested/dir/v1.2.0", "nested/dir/v1.2.1-devel", false},
		{"subpkg/v0.1.0-rc1", "subpkg/v0.1.1-devel", false},
		{"v0.1", "", true},
		{"subpkg/v0.1", "", true},
	}
	for _, c := range cases {
		got, err := defaultNextDev(c.release)
		if (err != nil) != c.wantErr {
			t.Errorf("defaultNextDev(%q) err = %v, wantErr = %v", c.release, err, c.wantErr)
		}
		if !c.wantErr && got != c.want {
			t.Errorf("defaultNextDev(%q) = %q, want %q", c.release, got, c.want)
		}
	}
}

func TestSplitTag(t *testing.T) {
	cases := []struct {
		tag        string
		wantPrefix string
		wantVer    string
	}{
		{"v0.1.0", "", "v0.1.0"},
		{"v0.1.0-devel", "", "v0.1.0-devel"},
		{"subpkg/v0.1.0", "subpkg", "v0.1.0"},
		{"nested/sub/v0.1.0", "nested/sub", "v0.1.0"},
		{"a/b/c/v0.1.0-rc1", "a/b/c", "v0.1.0-rc1"},
	}
	for _, c := range cases {
		gotPrefix, gotVer := splitTag(c.tag)
		if gotPrefix != c.wantPrefix || gotVer != c.wantVer {
			t.Errorf("splitTag(%q) = (%q, %q), want (%q, %q)",
				c.tag, gotPrefix, gotVer, c.wantPrefix, c.wantVer)
		}
	}
}

func TestVersionRE(t *testing.T) {
	cases := []struct {
		tag   string
		match bool
	}{
		{"v0.1.0", true},
		{"v0.1.0-rc1", true},
		{"v0.1.0-devel", true},
		{"v0.1.0-devel.20240101", true},
		{"subpkg/v0.1.0", true},
		{"nested/dir/v0.1.0-devel", true},
		{"go.mod-helper/v1.0.0", true},
		{"foo", false},
		{"v0.1", false},
		{"v0.1.0.4", false},
		{"/v0.1.0", false},        // empty leading component
		{"subpkg//v0.1.0", false}, // empty middle component
		{"subpkg/", false},
	}
	for _, c := range cases {
		got := versionRE.MatchString(c.tag)
		if got != c.match {
			t.Errorf("versionRE.MatchString(%q) = %v, want %v", c.tag, got, c.match)
		}
	}
}

func TestFindVersionFile(t *testing.T) {
	write := func(t *testing.T, root string, rel string) {
		t.Helper()
		path := filepath.Join(root, filepath.FromSlash(rel))
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte("package x\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	t.Run("top-level layout", func(t *testing.T) {
		dir := t.TempDir()
		write(t, dir, "mytool/version.go")
		write(t, dir, "internal/versioninfo/version.go") // not top-level; ignored anyway
		write(t, dir, "cmd/version.go")                  // skipped dir
		t.Chdir(dir)
		got, err := findVersionFile("")
		if err != nil {
			t.Fatalf("findVersionFile: %v", err)
		}
		if want := filepath.Join("mytool", "version.go"); got != want {
			t.Errorf("findVersionFile = %q, want %q", got, want)
		}
	})

	t.Run("legacy pkg fallback", func(t *testing.T) {
		dir := t.TempDir()
		write(t, dir, "pkg/mytool/version.go")
		t.Chdir(dir)
		got, err := findVersionFile("")
		if err != nil {
			t.Fatalf("findVersionFile: %v", err)
		}
		if want := filepath.Join("pkg", "mytool", "version.go"); got != want {
			t.Errorf("findVersionFile = %q, want %q", got, want)
		}
	})

	t.Run("top-level wins over legacy", func(t *testing.T) {
		dir := t.TempDir()
		write(t, dir, "mytool/version.go")
		write(t, dir, "pkg/other/version.go")
		t.Chdir(dir)
		got, err := findVersionFile("")
		if err != nil {
			t.Fatalf("findVersionFile: %v", err)
		}
		if want := filepath.Join("mytool", "version.go"); got != want {
			t.Errorf("findVersionFile = %q, want %q", got, want)
		}
	})

	t.Run("ambiguous", func(t *testing.T) {
		dir := t.TempDir()
		write(t, dir, "mytool/version.go")
		write(t, dir, "othertool/version.go")
		t.Chdir(dir)
		if _, err := findVersionFile(""); err == nil {
			t.Fatal("expected error on two candidate version files")
		}
	})

	t.Run("submodule prefix", func(t *testing.T) {
		dir := t.TempDir()
		write(t, dir, "subpkg/mytool/version.go")
		t.Chdir(dir)
		got, err := findVersionFile("subpkg")
		if err != nil {
			t.Fatalf("findVersionFile: %v", err)
		}
		if want := filepath.Join("subpkg", "mytool", "version.go"); got != want {
			t.Errorf("findVersionFile = %q, want %q", got, want)
		}
	})
}

func TestRewriteVersion(t *testing.T) {
	dir := t.TempDir()
	file := filepath.Join(dir, "version.go")
	original := `package mytool

// Version is the version string.
const Version = "v0.0.0-devel"
`
	if err := os.WriteFile(file, []byte(original), 0o644); err != nil {
		t.Fatal(err)
	}

	if err := rewriteVersion(file, "v1.2.3"); err != nil {
		t.Fatalf("rewriteVersion: %v", err)
	}
	got, err := os.ReadFile(file)
	if err != nil {
		t.Fatal(err)
	}
	want := `package mytool

// Version is the version string.
const Version = "v1.2.3"
`
	if string(got) != want {
		t.Errorf("rewriteVersion produced:\n%s\nwant:\n%s", got, want)
	}
}

func TestRewriteVersion_noMatch(t *testing.T) {
	dir := t.TempDir()
	file := filepath.Join(dir, "version.go")
	if err := os.WriteFile(file, []byte("package mytool\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := rewriteVersion(file, "v1.2.3"); err == nil {
		t.Fatal("expected error when version line is missing")
	}
}

func TestRewriteVersion_multipleMatches(t *testing.T) {
	dir := t.TempDir()
	file := filepath.Join(dir, "version.go")
	content := `package mytool

const Version = "v0.0.0-devel"
const Version = "v0.0.0-devel"
`
	if err := os.WriteFile(file, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := rewriteVersion(file, "v1.2.3"); err == nil {
		t.Fatal("expected error when multiple version lines are present")
	}
}
