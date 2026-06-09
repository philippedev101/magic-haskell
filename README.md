# magic

It is a binding to the C [libmagic](https://www.darwinsys.com/file/) library. It allows you to determine the type of a file not by looking at its name or extension, but rather by examining the contents itself.

libmagic can provide either a textual description or a MIME content type (and, occasionally, also a character set). The Haskell binding can examine files, open file descriptors, and in-memory data (as a strict `ByteString`). Results come back as `Text`.

## Requirements

You need the C `libmagic` library and its development headers installed before building. It is part of the [`file`](https://www.darwinsys.com/file/) package.

| Platform | Install |
|----------|---------|
| Debian / Ubuntu | `apt-get install libmagic-dev` |
| Fedora | `dnf install file-devel` |
| Arch | `pacman -S file` |
| macOS (Homebrew) | `brew install libmagic` |
| Nix | `file` / `file.dev` |

## Building

With `cabal`:

```sh
cabal build
cabal test
```

With `stack`:

```sh
stack build
stack test
```

libmagic is located automatically via pkg-config. If pkg-config cannot find it (for example, an unusual install location), point Cabal at the library directly:

```sh
cabal build \
  --extra-lib-dirs=/path/to/lib \
  --extra-include-dirs=/path/to/include
```

## Usage

Add `magic` to your `build-depends`. The easiest way in is `Magic.FilePath`, which takes ordinary `String` paths:

```haskell
import Magic.FilePath          -- convenience facade: ordinary String paths
import qualified Data.Text.IO as T

main :: IO ()
main = do
  magic <- magicOpen MagicMimeType
  magicLoadDefault magic
  mime <- magicFile magic "some-file.png"
  T.putStrLn mime        -- e.g. "image/png"
```

### `Magic` vs `Magic.FilePath`

`import Magic` is the primary API. It is the same in every way except that paths are `OsPath` instead of `String`. Prefer it when filename correctness matters.

`Magic.FilePath` is a drop-in facade that converts paths through the locale's filesystem encoding (`encodeFS` / `decodeFS`). For ordinary ASCII/UTF-8 filenames under a UTF-8 locale that is perfectly fine. What you give up: a `String` path cannot faithfully represent every path the operating system can. Filenames containing bytes that are not valid in the current locale (raw non-UTF-8 bytes on Unix, names created under a different `LANG`/`LC_*`, and so on) may be corrupted or fail to round-trip, so you can fail to open a file that exists, or open the wrong one, and the outcome depends on the environment. `OsPath` stores the OS-native path bytes verbatim, so it represents any path losslessly and independently of the locale.

## Author & history

magic-haskell was written by John Goerzen <jgoerzen@complete.org>, who created it in 2005 and maintained it for nearly two decades. It is now maintained by Philippe, with development at <https://github.com/philippedev101/magic-haskell>.

## License

3-clause BSD. See the `COPYING` file included with the package.
