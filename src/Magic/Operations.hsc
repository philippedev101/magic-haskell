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
                        magicCString, magicByteString,
                        -- * Flags
                        magicSetFlags, magicGetFlags,
                        -- * Tunable parameters
                        magicGetParam, magicSetParam,
                        -- * Magic databases
                        magicCompile, magicCheck, magicLoadBuffers,
                        magicGetPath,
                        -- * Library information
                        magicVersion, magicErrno)
where

import Control.Concurrent.MVar (modifyMVar_)
import Control.Exception (throwIO)
import qualified Data.Text as T
import Foreign.ForeignPtr (withForeignPtr)
import Foreign.Ptr
import Foreign.C.String
import Foreign.C.Types
import Foreign.Marshal.Alloc (alloca)
import Foreign.Marshal.Array (withArray)
import Foreign.Marshal.Utils (with)
import Foreign.Storable (peek)
import Data.Word
import Data.ByteString (ByteString)
import qualified Data.ByteString.Unsafe as BSU
import Data.Text (Text)
import System.OsPath (OsPath)
import System.Posix.Types (Fd)
import Magic.Types (MagicParam(..))
import Magic.Data (MagicFlags(..))
import Magic.Internal (Magic(..), CMagic, MagicException(..), withMagicPtr, throwErrorIfNull, checkIntError, peekCStringText, withOsPathCString, withSearchPathCString, peekSearchPath)

#include <magic.h>

{- | Identify the file at the given path. The result is in the form selected by
the handle's flags (a textual description, a MIME type, an encoding, and so on;
see t'MagicFlags'). Raises a @MagicException@ if the file cannot be
examined. -}
magicFile :: Magic -> OsPath -> IO Text
magicFile magic fp =
    withMagicPtr magic (\cmagic ->
    withOsPathCString fp (\cfp ->
     do res <- throwErrorIfNull "magicFile" magic (magic_file cmagic cfp)
        peekCStringText res
                    )
                       )

{- | Identify the data available on standard input, as 'magicFile' does for a
named file. Raises a @MagicException@ if the data cannot be
examined. -}
magicStdin :: Magic -> IO Text
magicStdin magic =
    withMagicPtr magic (\cmagic ->
     do res <- throwErrorIfNull "magicStdin" magic (magic_file cmagic nullPtr)
        peekCStringText res
                       )

{- | Identify the contents of a C string buffer (a pointer and a length). The
lowest-level in-memory primitive; for ordinary use prefer 'magicByteString'.
Raises a @MagicException@ if the data cannot be examined. -}
magicCString :: Magic -> CStringLen -> IO Text
magicCString magic (cstr, len) =
    withMagicPtr magic (\cmagic ->
     do res <- throwErrorIfNull "magicCString" magic (magic_buffer cmagic cstr (fromIntegral len))
        peekCStringText res
                    )

{- | Change the flags (see t'MagicFlags') on an existing handle, for example to
switch between textual descriptions and MIME types. Raises a @MagicException@ on
failure. -}
magicSetFlags :: Magic -> MagicFlags -> IO ()
magicSetFlags m (MagicFlags flags) = withMagicPtr m (\cmagic ->
     checkIntError "magicSetFlags" m $ magic_setflags cmagic flags)

{- | Compile the given magic database file(s) into the binary @.mgc@ form. Each
compiled file is named after its source with @.mgc@ appended. Pass the empty
list to compile the default database. Raises a @MagicException@ on failure.

(libmagic joins the list with the platform search-path separator, so a path
that itself contains that separator cannot be represented.)
-}
magicCompile :: Magic -> [OsPath] -> IO ()
magicCompile m ps = withMagicPtr m (\cm ->
     case ps of
       [] -> worker cm nullPtr
       _  -> withSearchPathCString ps (worker cm))
    where worker cm cs = checkIntError "magicCompile" m $ magic_compile cm cs

{- | Identify the data behind an open file descriptor, as 'magicFile' does for a
named file. Useful for sockets, pipes, or files you have already opened. Raises
a @MagicException@ if the descriptor cannot be examined.

@since 1.1.2
-}
magicDescriptor :: Magic -> Fd -> IO Text
magicDescriptor magic fd =
    withMagicPtr magic (\cmagic ->
     do res <- throwErrorIfNull "magicDescriptor" magic
                 (magic_descriptor cmagic (fromIntegral fd))
        peekCStringText res)

{- | Identify the contents of a strict 'ByteString'. Does no encoding
conversion, so it is the right way to examine in-memory data. Raises a
@MagicException@ if the data cannot be examined.

@since 1.1.2
-}
magicByteString :: Magic -> ByteString -> IO Text
magicByteString magic bs =
    withMagicPtr magic (\cmagic ->
     BSU.unsafeUseAsCStringLen bs (\(cstr, len) ->
      do res <- throwErrorIfNull "magicByteString" magic
                  (magic_buffer cmagic cstr (fromIntegral len))
         peekCStringText res))

{- | Read the flags currently set on the handle (see 'magicSetFlags'). Test the
result with @hasFlag@. Raises a @MagicException@ if the running @libmagic@ does not
support querying flags.

@since 1.1.2
-}
magicGetFlags :: Magic -> IO MagicFlags
magicGetFlags m =
    withMagicPtr m (\cmagic ->
     do fl <- magic_getflags cmagic
        if fl < 0
           then throwIO (MagicException (T.pack "magicGetFlags")
                  (T.pack "magic_getflags is unsupported by this libmagic"))
           else return (MagicFlags fl))

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
of bytes scanned in untrusted input. Raises a @MagicException@ on failure.

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
them, as @file -c@ does. Pass the empty list for the default database. Returns
'True' if the database is valid. (libmagic joins the list with the platform
search-path separator, so a path that itself contains that separator cannot be
represented.)

@since 1.1.2
-}
magicCheck :: Magic -> [OsPath] -> IO Bool
magicCheck m ps =
    withMagicPtr m (\cmagic ->
     case ps of
       [] -> fmap (== 0) (magic_check cmagic nullPtr)
       _  -> withSearchPathCString ps (fmap (== 0) . magic_check cmagic))

{- | Load magic from one or more in-memory compiled databases (the @.mgc@ binary
form produced by 'magicCompile'), rather than from files. This lets a program
embed its magic database.

@libmagic@ keeps (does not copy) the supplied buffers for the lifetime of the
handle, so the handle retains references to the given 'ByteString's to keep
their memory alive until it is closed. Raises a @MagicException@ on failure.

@since 2.0.0
-}
magicLoadBuffers :: Magic -> [ByteString] -> IO ()
magicLoadBuffers (Magic fp mv) bufs =
    modifyMVar_ mv $ \retained ->
     do withForeignPtr fp $ \cmagic ->
          withBuffers bufs $ \pls ->
            withArray (map fst pls) $ \pptr ->
            withArray (map snd pls) $ \sptr ->
              checkIntError "magicLoadBuffers" (Magic fp mv)
                (magic_load_buffers cmagic pptr sptr (fromIntegral (length bufs)))
        -- Keep the buffers reachable (and so, being pinned, validly addressable)
        -- for as long as the handle lives.
        return (bufs ++ retained)
  where
    withBuffers :: [ByteString] -> ([(Ptr Word8, CSize)] -> IO a) -> IO a
    withBuffers []     k = k []
    withBuffers (b:bs) k =
        BSU.unsafeUseAsCStringLen b (\(p, l) ->
          withBuffers bs (\rest -> k ((castPtr p, fromIntegral l) : rest)))

{- | The default magic database search path, honouring the @MAGIC@ environment
variable, as a list of paths.

@since 1.1.2
-}
magicGetPath :: IO [OsPath]
magicGetPath =
    do res <- magic_getpath nullPtr 0
       if res == nullPtr then return [] else peekSearchPath res

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

-- Parses (potentially large) in-memory databases -> safe
foreign import ccall safe "magic.h magic_load_buffers"
  magic_load_buffers :: Ptr CMagic -> Ptr (Ptr Word8) -> Ptr CSize -> CSize -> IO CInt

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
