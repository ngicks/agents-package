///|
test "glob_match literal" {
  assert_eq(@discover.glob_match("skills/foo", "skills/foo"), true)
  assert_eq(@discover.glob_match("skills/foo", "skills/bar"), false)
  assert_eq(@discover.glob_match("", ""), true)
  assert_eq(@discover.glob_match("", "a"), false)
  assert_eq(@discover.glob_match("abc", "abcd"), false)
}

///|
test "glob_match star stays within a segment" {
  assert_eq(@discover.glob_match("skills/*", "skills/foo"), true)
  // `*` must not cross '/'.
  assert_eq(@discover.glob_match("skills/*", "skills/foo/bar"), false)
  // `*` matches zero characters.
  assert_eq(@discover.glob_match("skills/foo*", "skills/foo"), true)
  // prefix wildcard within one segment.
  assert_eq(@discover.glob_match("skills/go-*", "skills/go-edit-cobra"), true)
  assert_eq(@discover.glob_match("skills/go-*", "skills/go-edit/cobra"), false)
  // `*` matches zero characters after the literal prefix.
  assert_eq(@discover.glob_match("go-*", "go-"), true)
  assert_eq(@discover.glob_match("go*", "go"), true)
  // but the literal prefix itself must be present.
  assert_eq(@discover.glob_match("go-*", "go"), false)
  // different first segment.
  assert_eq(@discover.glob_match("skills/*", "hooks/foo"), false)
}

///|
test "glob_match question mark" {
  assert_eq(@discover.glob_match("a?c", "abc"), true)
  // `?` matches exactly one, never zero.
  assert_eq(@discover.glob_match("a?c", "ac"), false)
  // `?` must not match '/'.
  assert_eq(@discover.glob_match("a?c", "a/c"), false)
}

///|
test "glob_match doublestar crosses segments" {
  assert_eq(@discover.glob_match("instructions/**", "instructions/x.md"), true)
  assert_eq(@discover.glob_match("instructions/**", "instructions/a/b/c"), true)
  assert_eq(
    @discover.glob_match("instructions/**", "instructions/foo.instructions.md"),
    true,
  )
  assert_eq(@discover.glob_match("skills/foo/**", "skills/foo/bar"), true)
}

///|
test "glob_match doublestar matches zero segments" {
  // trailing `**` matches the empty remainder.
  assert_eq(@discover.glob_match("foo/**", "foo/"), true)
  // `**` alone matches the empty path and anything else.
  assert_eq(@discover.glob_match("**", ""), true)
  assert_eq(@discover.glob_match("**", "a/b/c"), true)
  // a `**/` group collapses to zero segments.
  assert_eq(@discover.glob_match("a/**/b", "a/b"), true)
  assert_eq(@discover.glob_match("a/**/b", "a/x/b"), true)
  assert_eq(@discover.glob_match("a/**/b", "a/x/y/b"), true)
  // trailing literal must still line up.
  assert_eq(@discover.glob_match("a/**/b", "a/x/c"), false)
}

///|
test "glob_match pattern longer than path" {
  assert_eq(@discover.glob_match("abc", "ab"), false)
  assert_eq(@discover.glob_match("skills/foo/bar", "skills/foo"), false)
  assert_eq(@discover.glob_match("a?", "a"), false)
}

///|
/// Adversarial patterns that would blow up an unmemoised backtracker must still
/// resolve instantly and stack-safely.
test "glob_match is polynomial on adversarial input" {
  // Classic catastrophic-backtracking shape: many `*` separated by the same
  // literal, matched against a long all-`a` path with no trailing `b`.
  assert_eq(
    @discover.glob_match("*a*a*a*a*a*a*a*a*a*b", String::make(64, 'a')),
    false,
  )
  // A matching variant still resolves.
  assert_eq(@discover.glob_match("*a*a*a*b", "aaaaaaaaaab"), true)
  // Long path, trailing-literal mismatch behind a `**`.
  assert_eq(@discover.glob_match("**z", String::make(200, 'a')), false)
  assert_eq(@discover.glob_match("**z", String::make(200, 'a') + "z"), true)
}
