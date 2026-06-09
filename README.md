# magic

It is a binding to the C [libmagic](https://www.darwinsys.com/file/) library. It allows you to determine the type of a file not by looking at its name or extension, but rather by examining the contents itself.

libmagic can provide either a textual description or a MIME content type (and, occasionally, also a character set). The Haskell binding can examine files, open file descriptors, and in-memory data (as a `String` or, for binary content, a strict `ByteString`).

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

You can simply add `magic` to your `build-depends` to enable this library.

```haskell
import Magic

main :: IO ()
main = do
  magic <- magicOpen [MagicMimeType]
  magicLoadDefault magic
  mime <- magicFile magic "some-file.png"
  putStrLn mime          -- e.g. "image/png"
```

## Author & history

magic-haskell was written by John Goerzen <jgoerzen@complete.org>, who created it in 2005 and maintained it for nearly two decades. It is now maintained by Philippe, with development at <https://github.com/philippedev101/magic-haskell>.

## License

3-clause BSD. See the `COPYING` file included with the package.
