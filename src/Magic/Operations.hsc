{- -*- Mode: haskell; -*-
Haskell magic Interface
Copyright (C) 2005 John Goerzen <jgoerzen@complete.org>

This code is under a 3-clause BSD license; see COPYING for details.
-}

{- |
   Module     : Magic.Operations
   Copyright  : Copyright (C) 2005 John Goerzen
   License    : BSD-3-Clause

   Maintainer : Philippe <philippedev101\@gmail.com>
   Stability  : provisional
   Portability: portable

Querying the type of files and in-memory data, and other operations on a magic
handle. The handle must first be created with @magicOpen@ and populated with
@magicLoadDefault@ or @magicLoad@ (see "Magic.Init").

Written by John Goerzen.
-}

module Magic.Operations(-- * Guessing the type
                        magicFile, magicStdin,
                        magicString, magicCString,
                        -- * Other operations
                        magicSetFlags, magicCompile)
where

import Foreign.Ptr
import Foreign.C.String
import Magic.Types
import Foreign.C.Types
import Data.Word
import Magic.Utils
import Magic.TypesLL

{- | Identify the file at the given path. The result is in the form selected by
the handle's flags (a textual description, a MIME type, an encoding, and so on;
see 'MagicFlag'). Raises an 'IOError' if the file cannot be examined. -}
magicFile :: Magic -> FilePath -> IO String
magicFile magic fp =
    withMagicPtr magic (\cmagic ->
    withCString fp (\cfp ->
     do res <- throwErrorIfNull "magicFile" magic (magic_file cmagic cfp)
        peekCString res
                    )
                       )

{- | Identify the data available on standard input, as 'magicFile' does for a
named file. Raises an 'IOError' if the data cannot be examined. -}
magicStdin :: Magic -> IO String
magicStdin magic =
    withMagicPtr magic (\cmagic ->
     do res <- throwErrorIfNull "magicStdin" magic (magic_file cmagic nullPtr)
        peekCString res
                       )

{- | Identify the contents of the given 'String'. Note that the string is
processed strictly, not lazily.

This is convenient for textual data. For binary data prefer 'magicCString' (or
write it to a file and use 'magicFile'): marshalling through 'String' goes via
the current locale encoding, which can corrupt non-textual bytes. Raises an
'IOError' if the data cannot be examined. -}
magicString :: Magic -> String -> IO String
magicString m s = withCStringLen s (magicCString m)

{- | Identify the contents of a C string buffer (a pointer and a length). This
is the lower-level primitive behind 'magicString', and the right choice for raw
binary data since it does no encoding conversion. Raises an 'IOError' if the
data cannot be examined. -}
magicCString :: Magic -> CStringLen -> IO String
magicCString magic (cstr, len) =
    withMagicPtr magic (\cmagic ->
     do res <- throwErrorIfNull "magicCString" magic (magic_buffer cmagic cstr (fromIntegral len))
        peekCString res
                    )

{- | Change the flags (see 'MagicFlag') on an existing handle, for example to
switch between textual descriptions and MIME types. Raises an 'IOError' on
failure. -}
magicSetFlags :: Magic -> [MagicFlag] -> IO ()
magicSetFlags m mfl = withMagicPtr m (\cmagic ->
     checkIntError "magicSetFlags" m $ magic_setflags cmagic flags)
    where flags = flaglist2int mfl

{- | Compile the given colon-separated magic database file(s) into the binary
@.mgc@ form. Each compiled file is named after its source with @.mgc@ appended.
Pass 'Nothing' to compile the default database. Raises an 'IOError' on failure.
-}
magicCompile :: Magic           -- ^ Object to use
             -> Maybe String    -- ^ Colon separated list of databases, or Nothing for default
             -> IO ()
magicCompile m mstr = withMagicPtr m (\cm ->
     case mstr of
               Nothing -> worker cm nullPtr
               Just x -> withCString x (worker cm)
                                     )
    where worker cm cs = checkIntError "magicCompile" m $ magic_compile cm cs

-- Does file I/O -> safe
foreign import ccall safe "magic.h magic_file"
  magic_file :: Ptr CMagic -> CString -> IO CString

-- Does not do I/O -> unsafe
foreign import ccall unsafe "magic.h magic_buffer"
  magic_buffer :: Ptr CMagic -> CString -> #{type size_t} -> IO CString

-- Does not do I/O -> unsafe
foreign import ccall unsafe "magic.h magic_setflags"
  magic_setflags :: Ptr CMagic -> CInt -> IO CInt

-- Does file I/O -> safe
foreign import ccall safe "magic.h magic_compile"
  magic_compile :: Ptr CMagic -> CString -> IO CInt
