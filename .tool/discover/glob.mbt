///|
/// glob_match reports whether `path` matches the glob `pattern`.
///
/// Both are treated as '/'-separated paths. The matcher is hand-rolled and
/// pure (no regex, no external glob). Wildcards:
///
/// - `?`  matches exactly one character that is not `/` (stays within a
///   single path segment).
/// - `*`  matches zero or more characters that are not `/` (stays within a
///   single path segment).
/// - `**` matches zero or more characters including `/` (crosses segments).
///   It matches the empty string, so it can match zero segments: `foo/**`
///   matches `foo/`, and `**` alone matches the empty path.
///
/// `**` semantics (documented edge cases):
///
/// - Trailing `**` matches everything below a prefix: `instructions/**`
///   matches `instructions/x.md`, `instructions/a/b/c`, and `instructions/`.
/// - A `**/` group may collapse to nothing, so `a/**/b` matches `a/b`
///   (zero intermediate segments) as well as `a/x/b` and `a/x/y/b`.
/// - Every other character (including `/`) is matched literally, so
///   `a/**/b` does NOT match `a/x/c` — the trailing literal must still line up.
///
/// The implementation memoises the `(pattern index, path index)` subproblem, so
/// matching is polynomial (no exponential backtracking on adversarial patterns
/// such as `*a*a*a...*b`) and its recursion depth is bounded by the pattern
/// length, not the path length.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(
///     @discover.glob_match("skills/go-*", "skills/go-edit-cobra"),
///     content="true",
///   )
///   inspect(@discover.glob_match("skills/*", "skills/a/b"), content="false")
///   inspect(
///     @discover.glob_match("instructions/**", "instructions/go/x.md"),
///     content="true",
///   )
/// }
/// ```
pub fn glob_match(pattern : String, path : String) -> Bool {
  let p = pattern.to_array()
  let s = path.to_array()
  let cols = s.length() + 1
  let matcher = GlobMatcher::{
    p,
    s,
    cols,
    // memo[pi * cols + si]: -1 unknown, 0 false, 1 true.
    memo: Array::make((p.length() + 1) * cols, -1),
  }
  matcher.at(0, 0)
}

///|
/// GlobMatcher carries the pattern/path character arrays and the memo table so
/// the recursive matcher can share subproblem results.
priv struct GlobMatcher {
  p : Array[Char]
  s : Array[Char]
  cols : Int
  memo : Array[Int]
}

///|
/// at reports whether `p[pi..]` matches `s[si..]`, memoised on `(pi, si)`.
fn GlobMatcher::at(self : GlobMatcher, pi : Int, si : Int) -> Bool {
  let key = pi * self.cols + si
  let cached = self.memo[key]
  if cached != -1 {
    return cached == 1
  }
  let result = self.compute(pi, si)
  self.memo[key] = if result { 1 } else { 0 }
  result
}

///|
fn GlobMatcher::compute(self : GlobMatcher, pi : Int, si : Int) -> Bool {
  let s = self.s
  match self.p[pi:] {
    [] => si == s.length()
    // `**` — crosses segments. A `**/` group may collapse to zero segments;
    // that is only valid at the position where `**` begins, so the check lives
    // here in `compute` rather than inside the consuming loop.
    ['*', '*', '/', ..] if self.at(pi + 3, si) => true
    ['*', '*', ..] => self.doublestar(pi, si)
    // single `*` — stays within one segment.
    ['*', ..] => self.star(pi, si)
    ['?', ..] => si < s.length() && s[si] != '/' && self.at(pi + 1, si + 1)
    // literal character.
    [c, ..] => si < s.length() && s[si] == c && self.at(pi + 1, si + 1)
  }
}

///|
/// star consumes zero or more non-`/` characters for a single `*`. Iterative so
/// the stack depth stays bounded by the pattern length.
fn GlobMatcher::star(self : GlobMatcher, pi : Int, si : Int) -> Bool {
  for k in si..<=self.s.length() {
    if self.at(pi + 1, k) {
      return true
    }
    if k == self.s.length() || self.s[k] == '/' {
      return false
    }
  }
  false
}

///|
/// doublestar consumes zero or more characters (including `/`) for a `**`.
/// Iterative so the stack depth stays bounded by the pattern length.
fn GlobMatcher::doublestar(self : GlobMatcher, pi : Int, si : Int) -> Bool {
  for k in si..<=self.s.length() {
    if self.at(pi + 2, k) {
      return true
    }
  }
  false
}
