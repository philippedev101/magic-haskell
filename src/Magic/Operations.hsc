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
                        magicFile, magicStdin, magicDescriptor,
                        magicString, magicCString, magicByteString,
                        -- * Flags
                        magicSetFlags, magicGetFlags,
                        -- * Tunable parameters
                        magicGetParam, magicSetParam,
                        -- * Magic databases
                        magicCompile, magicCheck, magicGetPath,
                        -- * Library information
                        magicVersion, magicErrno)
where

import Foreign.Ptr
import Foreign.C.String
import Foreign.C.Types
import Foreign.Marshal.Alloc (alloca)
import Foreign.Marshal.Utils (with)
import Foreign.Storable (peek)
import Data.Word
import Data.ByteString (ByteString)
import qualified Data.ByteString.Unsafe as BSU
import System.Posix.Types (Fd)
import Magic.Types
import Magic.Utils

#include <magic.h>

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

{- | Identify the data behind an open file descriptor, as 'magicFile' does for a
named file. Useful for sockets, pipes, or files you have already opened. Raises
an 'IOError' if the descriptor cannot be examined.

@since 1.1.2
-}
magicDescriptor :: Magic -> Fd -> IO String
magicDescriptor magic fd =
    withMagicPtr magic (\cmagic ->
     do res <- throwErrorIfNull "magicDescriptor" magic
                 (magic_descriptor cmagic (fromIntegral fd))
        peekCString res)

{- | Identify the contents of a strict 'ByteString'. Unlike 'magicString' this
does no encoding conversion, so it is the right choice for binary data. Raises
an 'IOError' if the data cannot be examined.

@since 1.1.2
-}
magicByteString :: Magic -> ByteString -> IO String
magicByteString magic bs =
    withMagicPtr magic (\cmagic ->
     BSU.unsafeUseAsCStringLen bs (\(cstr, len) ->
      do res <- throwErrorIfNull "magicByteString" magic
                  (magic_buffer cmagic cstr (fromIntegral len))
         peekCString res))

{- | Read the flags currently set on the handle (see 'magicSetFlags'). Composite
masks are returned decomposed into their individual flags. Raises an 'IOError'
if the running @libmagic@ does not support querying flags.

@since 1.1.2
-}
magicGetFlags :: Magic -> IO [MagicFlag]
magicGetFlags m =
    withMagicPtr m (\cmagic ->
     do fl <- magic_getflags cmagic
        if fl < 0
           then ioError (userError
                  "magicGetFlags: magic_getflags is unsupported by this libmagic")
           else return (int2flaglist fl))

{- | Read a tunable parameter (see 'MagicParam').

@since 1.1.2
-}
magicGetParam :: Magic -> MagicParam -> IO Int
magicGetParam m p =
    withMagicPtr m (\cmagic ->
     alloca (\ptr ->
      do checkIntError "magicGetParam" m
           (magic_getparam cmagic (paramToCInt p) (castPtr ptr))
         v <- peek ptr
         return (fromIntegral (v :: CSize))))

{- | Set a tunable parameter (see 'MagicParam'), for example to cap the number
of bytes scanned in untrusted input. Raises an 'IOError' on failure.

@since 1.1.2
-}
magicSetParam :: Magic -> MagicParam -> Int -> IO ()
magicSetParam m p val =
    withMagicPtr m (\cmagic ->
     with (fromIntegral val :: CSize) (\ptr ->
      checkIntError "magicSetParam" m
        (magic_setparam cmagic (paramToCInt p) (castPtr ptr))))

paramToCInt :: MagicParam -> CInt
paramToCInt p = case p of
    MagicParamIndirMax     -> #{const MAGIC_PARAM_INDIR_MAX}
    MagicParamNameMax      -> #{const MAGIC_PARAM_NAME_MAX}
    MagicParamElfPhnumMax  -> #{const MAGIC_PARAM_ELF_PHNUM_MAX}
    MagicParamElfShnumMax  -> #{const MAGIC_PARAM_ELF_SHNUM_MAX}
    MagicParamElfNotesMax  -> #{const MAGIC_PARAM_ELF_NOTES_MAX}
    MagicParamRegexMax     -> #{const MAGIC_PARAM_REGEX_MAX}
    MagicParamBytesMax     -> #{const MAGIC_PARAM_BYTES_MAX}
    MagicParamEncodingMax  -> #{const MAGIC_PARAM_ENCODING_MAX}
    MagicParamElfShsizeMax -> #{const MAGIC_PARAM_ELF_SHSIZE_MAX}

{- | Check the validity of the given magic database file(s) without compiling
them, as @file -c@ does. Pass 'Nothing' for the default database. Returns
'True' if the database is valid.

@since 1.1.2
-}
magicCheck :: Magic -> Maybe FilePath -> IO Bool
magicCheck m mpath =
    withMagicPtr m (\cmagic ->
     case mpath of
       Nothing -> fmap (== 0) (magic_check cmagic nullPtr)
       Just p  -> withCString p (fmap (== 0) . magic_check cmagic))

{- | The path of the default magic database, honouring the @MAGIC@ environment
variable.

@since 1.1.2
-}
magicGetPath :: IO FilePath
magicGetPath =
    do res <- magic_getpath nullPtr 0
       if res == nullPtr then return "" else peekCString res

{- | The version of the @libmagic@ library in use, encoded as a single integer
(for example @545@ for version 5.45).

@since 1.1.2
-}
magicVersion :: IO Int
magicVersion = fmap fromIntegral magic_version

{- | The @errno@ recorded by the last failing operation on the handle, or @0@ if
the last failure was not caused by a system error.

@since 1.1.2
-}
magicErrno :: Magic -> IO Int
magicErrno m = withMagicPtr m (fmap fromIntegral . magic_errno)

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

-- Reads the descriptor -> safe
foreign import ccall safe "magic.h magic_descriptor"
  magic_descriptor :: Ptr CMagic -> CInt -> IO CString

-- Validates a database file -> safe
foreign import ccall safe "magic.h magic_check"
  magic_check :: Ptr CMagic -> CString -> IO CInt

-- Does not do I/O -> unsafe
foreign import ccall unsafe "magic.h magic_getflags"
  magic_getflags :: Ptr CMagic -> IO CInt

-- Does not do I/O -> unsafe
foreign import ccall unsafe "magic.h magic_getparam"
  magic_getparam :: Ptr CMagic -> CInt -> Ptr () -> IO CInt

-- Does not do I/O -> unsafe
foreign import ccall unsafe "magic.h magic_setparam"
  magic_setparam :: Ptr CMagic -> CInt -> Ptr () -> IO CInt

-- Reads an environment variable -> unsafe
foreign import ccall unsafe "magic.h magic_getpath"
  magic_getpath :: CString -> CInt -> IO CString

-- Does not do I/O -> unsafe
foreign import ccall unsafe "magic.h magic_version"
  magic_version :: IO CInt

-- Does not do I/O -> unsafe
foreign import ccall unsafe "magic.h magic_errno"
  magic_errno :: Ptr CMagic -> IO CInt
