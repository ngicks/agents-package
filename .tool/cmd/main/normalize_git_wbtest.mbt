///|
/// Whitebox tests for `normalize_git` (package-private). The central concern is
/// the port-vs-scp-separator disambiguation: a pre-path colon is a port when the
/// URL carries an explicit `<scheme>://`, and the scp host/owner separator only
/// when it does not.
test "normalize_git: https without a port" {
  assert_eq(normalize_git("https://github.com/o/r"), "github.com/o/r")
}

///|
test "normalize_git: https strips a trailing .git" {
  assert_eq(normalize_git("https://github.com/o/r.git"), "github.com/o/r")
}

///|
test "normalize_git: https keeps an explicit port" {
  assert_eq(
    normalize_git("https://github.com:8443/o/r.git"),
    "github.com:8443/o/r",
  )
}

///|
test "normalize_git: ssh:// with user and port keeps the port" {
  assert_eq(
    normalize_git("ssh://git@github.com:7999/o/r.git"),
    "github.com:7999/o/r",
  )
}

///|
test "normalize_git: ssh:// with user, no port" {
  assert_eq(normalize_git("ssh://git@github.com/o/r.git"), "github.com/o/r")
}

///|
test "normalize_git: scp form rewrites the host/owner colon" {
  assert_eq(normalize_git("git@github.com:o/r.git"), "github.com/o/r")
}

///|
test "normalize_git: bare shorthand is unchanged" {
  assert_eq(normalize_git("github.com/o/r"), "github.com/o/r")
}

///|
test "normalize_git: surrounding whitespace and newline are trimmed" {
  assert_eq(normalize_git("  https://github.com/o/r\n"), "github.com/o/r")
}
