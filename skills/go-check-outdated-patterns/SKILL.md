---
name: go-check-outdated-patterns
description: "Use this to review your change if you have edited Go code."
---

# Go Outdated Pattern Checklist

Use this checklist to find old Go writing and replace it with idioms and APIs available in the module's declared Go version.

## How to use this skill

- 1. Identify the active module's Go version.
  - Use `go mod edit -json | jq -r ".Go"`
  - You may face a mono-repo and therefore you may not be below a module root. In that case you would change cwd for the command.
- 2. Apply the checklist for that version and all earlier versions below, unless a later version supersedes a rule.
- 3. Treat **DON'T** items as patterns to flag or replace.
- 4. Treat **DO** items as preferred replacements when they fit the code's behavior.
  - If following **DO** items changes behavior of code, ask the user how to change.
- 5. Do not upgrade `go.mod`

## Checklist

#### Go 1.26

##### Language

- **DO** use `new(<expr>)` to create pointers from expressions (e.g. `new("foo")`, `new(true)`, `new(yearsSince(born))`).
  - **DON'T** define a helper like `func ptr[T any](v T) *T`.
- **DO** use self-referential generic type constraints when needed: `type Adder[A Adder[A]] interface { Add(A) A }`.

##### Crypto / TLS

- **DO** use new `crypto/hpke` (RFC 9180 HPKE).
- **DO** use `testing/cryptotest.SetGlobalRandom()` for deterministic crypto tests.
- **DO** use `crypto/rsa.EncryptOAEPWithOptions()` when MGF1 hash differs from OAEP hash.
- **DO** use `crypto/x509.ExtKeyUsage.String()`, `.OID()`, and `OIDFromASN1OID()`.
- **DON'T** rely on custom `rand.Reader` inputs for affected crypto APIs; Go 1.26 ignores them and always uses secure randomness. Use `testing/cryptotest.SetGlobalRandom()` for deterministic crypto tests.
- **DON'T** use `EncryptPKCS1v15` / `DecryptPKCS1v15` (deprecated).
- **DON'T** use `big.Int` fields on `crypto/ecdsa.PublicKey` / `PrivateKey` (deprecated).
- **DO** implement `crypto.MessageSigner` on `Certificate.PrivateKey` for TLS 1.2+.

##### Standard Library

- **DO** use `errors.AsType[T]` (generic, allocation-free `errors.As`).
- **DO** use `bytes.Buffer.Peek()` for non-destructive reads.
- **DO** use iterator methods on `reflect.Type` / `reflect.Value`: `Fields()`, `Methods()`, `Ins()`, `Outs()`.
- **DO** use `net.Dialer.DialIP/DialTCP/DialUDP/DialUnix` (context-aware).
- **DO** use `testing.T/B/F.ArtifactDir()` with the `-artifacts` flag.
- **DO** use `slog.NewMultiHandler()` to fan out slog records.
- **DO** use `os.Process.WithHandle()` for pidfd / Windows process handles.
- **DON'T** use `ReverseProxy.Director` — use `ReverseProxy.Rewrite` (header-stripping safe).
- **DO** prefer `HTTP2Config.StrictMaxConcurrentRequests` for connection-pool control.

#### Go 1.25

##### Language / Compiler

- **DO** check errors **before** using results — the compiler no longer delays nil checks past use sites.
  ```go
  f, err := os.Open(p)
  if err != nil { return err }
  _ = f.Name() // safe
  ```
- **DON'T** dereference results before the error check.

##### Standard Library

- **DO** use `testing/synctest` (graduated, no longer experimental).
  ```go
  synctest.Test(t, func(ctx context.Context) { /* virtual time */ })
  ```
- **DO** use `sync.WaitGroup.Go(fn)` instead of `Add(1)`/`go`/`defer Done()`.
- **DO** use `crypto.MessageSigner` / `crypto.SignMessage()` for hash-internal signers.
- **DO** use `crypto/ecdsa.ParseRawPrivateKey` / `ParseUncompressedPublicKey` and `.Bytes()` instead of low-level `crypto/elliptic`.
- **DO** use `crypto/tls.ConnectionState.CurveID` to inspect the key exchange.
- **DO** use `tls.Config.GetEncryptedClientHelloKeys` callback for ECH.
- **DO** use `net/http.CrossOriginProtection` for token-less CSRF protection.
- **DO** use `os.Root.Chmod/Chown/Symlink/...` for sandboxed FS ops; `os.CopyFS` now honors symlinks via `io/fs.ReadLinkFS`.
- **DO** use `reflect.TypeAssert[T](v)` for zero-allocation type assertions.
- **DO** use `T/B/F.Attr()` and `T.Output()` in tests.
- **DON'T** call `testing.AllocsPerRun` from a parallel test (now panics).
- **DON'T** use SHA-1 signatures in TLS 1.2 (RFC 9155).
- **DON'T** use `go/parser.ParseDir` or `go/ast.FilterPackage`/`PackageExports`/`MergePackageFiles` (deprecated).

#### Go 1.24

##### Language

- **DO** use generic type aliases: `type MyAlias[T any] = SomeType[T]` (fully supported).

##### Testing

- **DO** write benchmarks with `for b.Loop() { ... }` instead of `for i := 0; i < b.N; i++`.
- **DO** use `T.Context()` / `B.Context()` and `T.Chdir()` / `B.Chdir()`.
- **DO** address `tests` analyzer findings (malformed test/example signatures).

##### Crypto

- **DO** use stdlib equivalents instead of `golang.org/x/crypto`: `crypto/hkdf`, `crypto/pbkdf2`, `crypto/sha3`, `crypto/mlkem`.
- **DO** use `crypto/cipher.NewGCMWithRandomNonce()` for auto nonce generation.
- **DO** use `crypto/ecdsa.PrivateKey.Sign()` with `nil` random source for RFC 6979 deterministic signatures.
- **DO** use `crypto/rand.Text()` for random text.
- **DO** use post-quantum `tls.X25519MLKEM768` (default).
- **DO** use `crypto/x509.Certificate.Policies` instead of `PolicyIdentifiers`.
- **DO** prefer `runtime.AddCleanup` over `runtime.SetFinalizer`.
- **DON'T** generate RSA keys < 1024 bits — `GenerateKey` errors out.
- **DON'T** use `cipher.NewOFB`, `NewCFBEncrypter`, `NewCFBDecrypter` (deprecated; use AEAD or CTR).
- **DON'T** call `aes.NewCipher` helpers (`NewCTR`, `NewGCM`, etc.) — pass `Block` to `crypto/cipher` directly.
- **DON'T** rely on `crypto/rand.Read` returning errors — it now crashes.
- **DON'T** use `X25519Kyber768Draft00` (use `X25519MLKEM768`).

##### Filesystem

- **DO** use `os.OpenRoot` / `os.Root` for path-traversal-safe FS access.

##### Iterators / Hashing / Weak Refs

- **DO** use `bytes.Lines/SplitSeq/SplitAfterSeq/FieldsSeq/FieldsFuncSeq` and the same in `strings`.
- **DO** use iterator methods in `go/types` (e.g. `Methods()`).
- **DO** use `maphash.Comparable` / `WriteComparable`.
- You can use `weak` package for weak pointers in caches, if really needed.

##### Encoding Interfaces

- **DO** implement `encoding.TextAppender` / `BinaryAppender` to avoid allocations.

##### JSON

- **DO** prefer the `omitzero` struct tag over `omitempty`: use only `omitzero`.

##### Networking

- **DO** rely on default MPTCP via `ListenConfig` on Linux.
- **DO** configure HTTP via `Server.Protocols` / `Transport.Protocols`; use `UnencryptedHTTP2` when intentional.

##### Misc

- **DO** use `go:wasmexport` for WASM exports.
- **DON'T** use `math/rand.Seed` (use `math/rand/v2`).

#### Go 1.23

##### Language

- **DO** use range-over-func iterators:
  ```go
  for x := range seq { ... }              // func(yield func(T) bool)
  for k, v := range seq2 { ... }          // func(yield func(K, V) bool)
  for range counter { ... }               // func(yield func() bool)
  ```

##### Standard Library — New Packages

- You can use `unique.Make[T]` for value canonicalization (interning) returning `unique.Handle[T]`.
- If your library returns sequence of data, **DO** return `iter.Seq[K]` or `iter.Seq2[K, V]` instead of converting internal data structure into `[]T`.
- **DO** mark host-API structs with `structs.HostLayout`.

##### Timer / Ticker (only when `go 1.23+` in go.mod)

- **DO** rely on GC of unreferenced timers/tickers — no `Stop()` needed.
- **DO** use non-blocking `select`/`case` for timer reads.
- **DON'T** use `len(t.C)` / `cap(t.C)` (now 0).
- **DON'T** expect stale values to remain after `Reset()` / `Stop()`.

##### slices / maps Iterators

- **DO** use `slices.{All,Values,Backward,Collect,AppendSeq,Sorted,SortedFunc,SortedStableFunc,Chunk,Repeat}`.
- **DO** use `maps.{All,Keys,Values,Insert,Collect}`.

##### net / net/http

- **DO** use `net.TCPConn.SetKeepAliveConfig` and `net.KeepAliveConfig`.
- **DO** use `Request.CookiesNamed`, `http.ParseCookie`, `http.ParseSetCookie`, `Cookie.Quoted`, `Cookie.Partitioned`.
- **DO** use `Request.Pattern` to read the matched `ServeMux` pattern.
- **DON'T** wrap `ResponseWriter` with on-the-fly `Content-Encoding` middleware around `ServeContent`/`ServeFile`/`ServeFileFS` — those now strip such headers on errors. Use `Transfer-Encoding` instead.

##### Crypto / TLS

- **DO** populate `tls.Certificate.Leaf` automatically via `X509KeyPair`/`LoadX509KeyPair`.
- **DO** support ECH via `tls.Config.EncryptedClientHelloConfigList`.
- **DON'T** verify SHA-1 certificate signatures.

##### reflect

- **DO** use `Type.OverflowComplex/Float/Int/Uint`, `reflect.SliceAt`, `Value.Seq`/`Value.Seq2`, `Type.CanSeq`/`CanSeq2`.
- **DO** use `Value.Pointer`/`UnsafePointer` on string kinds.

##### Other Stdlib Additions

- **DO** use `encoding/binary.Encode/Decode/Append`, `sync.Map.Clear`, `sync/atomic.And/Or`, `unicode/utf16.RuneLen`, `runtime/debug.SetCrashOutput`.

#### Go 1.22

##### Language

- **DO** rely on per-iteration loop variable scoping — each iteration gets fresh variables. Existing loop-capture bugs are fixed.
- **DO** use `for i := range 10` for integer ranges.

##### Standard Library

- **DO** use `math/rand/v2`. Names: `IntN`, `Int32`, `Int32N`, `Int64`, `Int64N`, `Uint32`, `Uint32N`, `Uint64`, `Uint64N`, `UintN`, generic `N[T]`.
  - **DON'T** use legacy names like `Intn`, `Int31`, `Int63n`.
- **DO** use `math/rand/v2.N(5*time.Minute)` for typed durations.
- **DO** use enhanced `http.ServeMux` patterns:
  - method prefix: `"POST /items/create"`
  - wildcards: `/items/{id}` → `r.PathValue("id")`
  - greedy (terminal only): `/files/{path...}`
  - exact match: `/exact/{$}`
- **DO** use `database/sql.Null[T]` for nullable columns.
- **DO** use `cmp.Or` for first non-zero.
- **DO** use `slices.Concat`.
- **DO** use `reflect.TypeFor[T]()` instead of `reflect.TypeOf((*T)(nil)).Elem()`.
- **DO** use `AppendEncode` / `AppendDecode` in encoding packages to reuse buffers.
- **DO** use `ServeFileFS`, `FileServerFS`, `NewFileTransportFS` for `fs.FS` integration.
- **DO** use `go/version` to validate/compare Go versions.
- **DON'T** use `reflect.PtrTo` — use `reflect.PointerTo`.
- **DON'T** use `go/ast` resolution helpers (`Ident.Obj`, `Object`, `Scope`, `File.Scope`, `File.Unresolved`, `Importer`, `Package`, `NewPackage`) — use `go/types` (`Info.Uses`, `Info.Defs`).

#### Go 1.21

##### Language — New Builtins

- **DO** use the `min` / `max` builtins instead of helper functions or `if`/`else` comparisons.
- **DO** use the `clear` builtin to empty a map (`clear(m)`) or zero a slice (`clear(s)`).
  - **DON'T** loop `for k := range m { delete(m, k) }` just to empty a map.
- **DON'T** call `panic(nil)` — in `go 1.21+` modules it raises `*runtime.PanicNilError` and `recover()` returns non-nil.

##### Standard Library — New Packages (`slices` / `maps` / `cmp`)

- **DON'T** use `sort.Strings`, `sort.Ints`, `sort.Float64s` — **DO** use `slices.Sort`.
- **DON'T** use `sort.Slice` / `sort.SliceStable` — **DO** use `slices.SortFunc` / `slices.SortStableFunc` with a `func(a, b E) int` comparator (build it with `cmp.Compare`).
  ```go
  slices.SortFunc(users, func(a, b User) int {
      return cmp.Compare(a.Name, b.Name)
  })
  ```
  - `sort.Sort` over a genuine custom `sort.Interface` (non-slice) is still fine.
- **DON'T** use `sort.SearchInts` / `sort.SearchStrings` / a hand-rolled `sort.Search` over a sorted slice — **DO** use `slices.BinarySearch` / `slices.BinarySearchFunc`.
- **MIND the comparator direction.** `slices.SortFunc` / `SortStableFunc` / `BinarySearchFunc` / `CompareFunc` take a three-way `func(a, b) int` that must return a **negative** number when `a` sorts **before** `b` (same direction as `cmp.Compare(a, b)`). This is **not** the boolean `less func(i, j) bool` of `sort.Slice` (or the old `golang.org/x/exp/slices.SortFunc`); reusing boolean logic or flipping the sign silently reverses the order and breaks the search. **DO** build it from `cmp.Compare` rather than a hand-rolled `if` ladder.
  - `sort` has no `BinarySearch`: `sort.Search` takes a bool predicate (`data[i] >= x`), so porting it means rewriting the predicate as a three-way comparator (or just use `slices.BinarySearch` for `cmp.Ordered` elements).
- **DON'T** use `sort.IntsAreSorted` / `sort.StringsAreSorted` — **DO** use `slices.IsSorted` / `slices.IsSortedFunc`.
- **DON'T** hand-write membership or index loops — **DO** use `slices.Contains` / `slices.ContainsFunc` / `slices.Index` / `slices.IndexFunc`.
- **DON'T** hand-write min/max-over-slice loops — **DO** use `slices.Max` / `slices.Min` / `slices.MaxFunc` / `slices.MinFunc`.
- **DO** use `slices.{Clone,Equal,EqualFunc,Compare,CompareFunc,Compact,CompactFunc,Delete,DeleteFunc,Insert,Replace,Reverse,Grow,Clip}` instead of manual slice surgery.
- **DON'T** depend on `golang.org/x/exp/slices` / `golang.org/x/exp/maps` — **DO** use the stdlib `slices` / `maps`.
- **DO** use `maps.{Clone,Copy,Equal,EqualFunc,DeleteFunc}` instead of manual map loops. (Iterator-based `maps.Keys`/`Values` are Go 1.23.)
- **DO** use `cmp.Compare` / `cmp.Less` and the `cmp.Ordered` constraint for generic ordering.

##### Structured Logging

- **DO** use `log/slog` for structured logging in new code.
- **DO** validate custom `slog.Handler` implementations with `testing/slogtest`.

##### sync / context / errors

- **DO** use `sync.OnceFunc` / `sync.OnceValue` / `sync.OnceValues` instead of a hand-written `sync.Once` plus captured variables.
- **DO** use `context.WithoutCancel`, `context.WithDeadlineCause`, `context.WithTimeoutCause`, and `context.AfterFunc`.
- **DO** wrap/return `errors.ErrUnsupported` to signal an unsupported operation; detect it with `errors.Is(err, errors.ErrUnsupported)`.

##### reflect

- **DON'T** use `reflect.SliceHeader` / `reflect.StringHeader` (deprecated) — **DO** use `unsafe.Slice`, `unsafe.SliceData`, `unsafe.String`, `unsafe.StringData`.
- **DO** use `reflect.Value.Clear()` to empty a map or zero a slice via reflection.

##### Crypto

- **DON'T** use `crypto/elliptic` `Curve` methods or `GenerateKey`/`Marshal`/`Unmarshal` (deprecated) — **DO** use `crypto/ecdh`.
- **DON'T** use `crypto/x509.RevocationList.RevokedCertificates` (deprecated) — **DO** use `RevokedCertificateEntries` with `RevocationListEntry`.

##### Other Stdlib Additions

- **DO** use `binary.NativeEndian` for machine-native byte order.
- **DO** use `bytes.Buffer.Available()` / `AvailableBuffer()` for allocation-free appends.
- **DO** use `flag.BoolFunc` for boolean flags that take no argument.
