# Changelog for `magic`

All notable changes to this project are documented here.

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
