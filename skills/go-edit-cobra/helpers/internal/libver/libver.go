// Package libver pins the module-wide, release-controlled version string.
//
// The file lives at the fixed path internal/libver/libver.go so the release
// helper (internal/cmd/release) always knows where to rewrite it; the
// package declares Version and nothing else.
package libver

// Version is the human-readable version string for the whole module. The
// release helper rewrites this declaration when cutting a release, then
// bumps it to the next "-devel" version after tagging.
//
// Edit by hand only when the release helper is unavailable (e.g. cherry-pick
// of a release commit).
const Version = "v0.0.0-devel"
