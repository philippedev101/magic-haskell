# Changelog for `magic`

All notable changes to this project are documented here.

## 1.1.2 (2026-06-09)

Backwards-compatible additions: existing code continues to work unchanged. This release rounds out the binding to cover (almost) all of `libmagic`'s public API.

- Added the remaining `MagicFlag` constructors from `<magic.h>`: `MagicApple`, `MagicExtension`, `MagicCompressTransp`, `MagicNoCompressFork`, `MagicNodesc`, and the whole no-check family (`MagicNoCheckCompress`, `…Tar`, `…Soft`, `…Apptype`, `…Elf`, `…Text`, `…Cdf`, `…Csv`, `…Tokens`, `…Encoding`, `…Json`, `…Simh`) plus `MagicNoCheckBuiltin`.
- Added new operations in `Magic.Operations`: `magicDescriptor` (identify an open file descriptor), `magicByteString` (binary-safe identification of a strict `ByteString`), `magicGetFlags`, `magicGetParam`/`magicSetParam` with the new `MagicParam` type, `magicCheck`, `magicGetPath`, `magicVersion`, and `magicErrno`.
- `magicGetParam`/`magicSetParam` require `libmagic` >= 5.21; `magicGetFlags` requires >= 5.05. All current systems are well past this.
- New dependency: `bytestring` (a GHC boot library) for the `ByteString` entry points.
- Moved the `CMagic` phantom type (the tag behind the `Magic` handle) into `Magic.Types` and removed the internal `Magic.TypesLL` module. `CMagic` is now documented and linkable from the exposed `Magic.Types`. Documentation polish throughout: full Haddock coverage with no warnings, `@since` annotations on the new API, and default values listed for each `MagicParam`.
- `magic_load` is now imported as a `safe` foreign call (it was `unsafe`). It reads and parses the magic database from disk (blocking I/O), so under the threaded runtime loading a database no longer stalls other Haskell threads or blocks garbage collection. No API change.
- Documented the thread-safety contract of the `Magic` handle: a single handle is not safe for concurrent use (serialise access or use one per thread); distinct handles are independent.

## 1.1.1 (2026-06-09)

No API changes: this release is a drop-in replacement for 1.1.

- New maintainer: Philippe (<philippedev101@gmail.com>); package handed over from John Goerzen.
- Modernised the Cabal package description (`cabal-version: 2.4`, proper `library`/`test-suite` stanzas, `source-repository`, `tested-with`).
- Added an automatic `pkgconfig` flag: libmagic is now located via pkg-config when available, falling back transparently to plain `extra-libraries` linking otherwise.
- Moved library sources under `src/` and tests under `test/` (no code or module-name changes).
- Revived the original HUnit test suite in place: completed the unfinished `Inittest` module with real tests exercising the bindings against the system magic database, and fixed the runner to exit non-zero on failure.
- Added a GitHub Actions CI workflow building and testing across GHC 9.6 / 9.8 / 9.10 / 9.12.
- Removed dead imports so the library builds `-Wall`-clean.
- Ships the `unsafe`-FFI fix (use safe FFI calls for blocking I/O) that was merged upstream after the 1.1 Hackage release but never published.

## 1.1 (2014-10) and earlier

Releases by John Goerzen. See the git history for details.
