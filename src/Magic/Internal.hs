{-  -*- Mode: haskell; -*-
Haskell magic Interface
Copyright (C) 2005 John Goerzen <jgoerzen@complete.org>

This code is under a 3-clause BSD license; see COPYING for details.
-}

{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveGeneric #-}

{- |
   Module     : Magic.Internal
   Copyright  : Copyright (C) 2005 John Goerzen
   License    : BSD-3-Clause

   Maintainer : Philippe <philippedev101\@gmail.com>
   Stability  : provisional
   Portability: portable

Internal representation of the t'Magic' handle, the t'MagicException' error type,
and the helpers shared by the other modules. Not part of the public API: it is
exposed only so the rest of the package can build, and may change without a
major-version bump.
-}

module Magic.Internal
  ( CMagic
  , Magic(..)
  , MagicException(..)
  , fromMagicPtr
  , withMagicPtr
  , checkIntError
  , throwErrorIfNull
  , peekCStringText
  , withOsPathCString
  , withSearchPathCString
  , peekSearchPath
  ) where

import Control.Concurrent.MVar (MVar, newMVar, withMVar)
import Control.DeepSeq (NFData(rnf))
import Control.Exception (Exception, displayException, throwIO)
import GHC.Generics (Generic)
import qualified Data.ByteString as BS
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (decodeUtf8With)
import Data.Text.Encoding.Error (lenientDecode)
import Foreign
import Foreign.C.Error (throwErrnoIfNull)
import Foreign.C.String (CString)
import Foreign.C.Types (CInt)
import System.OsPath (OsPath)

#if defined(mingw32_HOST_OS)
import Data.List (intercalate)
import Foreign.C.String (peekCString, withCString)
import System.OsPath (decodeFS, encodeFS)
#else
import qualified Data.ByteString.Short as SBS
import System.OsString.Internal.Types (OsString(OsString, getOsString), PosixString(PosixString, getPosixString))
#endif

-- | Phantom type standing in for the C @magic_t@ cookie. It appears only as the
-- argument of a 'ForeignPtr' inside the t'Magic' handle and has no values of its
-- own.
data CMagic

{- | The magic handle: an opaque cookie obtained from @magicOpen@ and passed to
the loading and querying functions.

Handles are closed (and their memory freed) automatically when they are
garbage-collected; there is no need to close them explicitly.

__Thread safety.__ Operations on a single handle are serialised by an internal
lock, so it is safe to share one handle across threads (concurrent calls simply
take turns). For genuine parallelism, use one handle per thread; distinct
handles are independent. Programs doing blocking work (loading databases,
examining files) should use the threaded runtime (@-threaded@).
-}
data Magic = Magic !(ForeignPtr CMagic) !(MVar [BS.ByteString])
-- The MVar is both the per-handle lock and the store that keeps any buffers
-- passed to magicLoadBuffers alive for the lifetime of the handle (libmagic
-- retains, rather than copies, those buffers).

-- | The handle is opaque; it shows as a fixed placeholder.
instance Show Magic where
  show _ = "<magic handle>"

-- | The exception raised when a @libmagic@ operation fails. Carries the name of
-- the operation that failed and the message reported by @libmagic@.
--
-- @since 2.0.0
data MagicException = MagicException
  { magicErrorContext :: !Text  -- ^ the operation that failed, e.g. @\"magicFile\"@
  , magicErrorMessage :: !Text  -- ^ @libmagic@'s error message
  } deriving (Show, Eq, Generic)

instance NFData MagicException where
  rnf (MagicException c m) = rnf c `seq` rnf m

instance Exception MagicException where
  displayException (MagicException ctx msg) = T.unpack ctx ++ ": " ++ T.unpack msg

-- | Read a NUL-terminated C string into 'Text', decoding UTF-8 leniently
-- (replacing invalid bytes). Avoids the locale round-trip through 'String'.
peekCStringText :: CString -> IO Text
peekCStringText cs = decodeUtf8With lenientDecode <$> BS.packCString cs

-- | Build a handle from a C cookie-returning action, attaching the
-- @magic_close@ finalizer. Raises an 'IOError' (from @errno@) if the action
-- returns @NULL@.
fromMagicPtr :: String -> IO (Ptr CMagic) -> IO Magic
fromMagicPtr caller action =
    do ptr <- throwErrnoIfNull caller action
       fp  <- newForeignPtr magic_close ptr
       mv  <- newMVar []
       return (Magic fp mv)

-- | Run an action on the raw handle pointer, holding the per-handle lock and
-- keeping the handle alive for the whole action.
withMagicPtr :: Magic -> (Ptr CMagic -> IO a) -> IO a
withMagicPtr (Magic fp mv) act = withMVar mv (\_ -> withForeignPtr fp act)

-- Turn libmagic's last error into a 'MagicException'. Accesses the handle
-- lock-free because it is only ever called from inside an operation that
-- already holds the lock (so re-taking it would deadlock).
throwError :: String -> Magic -> IO a
throwError caller (Magic fp _) =
    withForeignPtr fp (\cmagic ->
     do errormsg <- magic_error cmagic
        msg <- if errormsg /= nullPtr
                  then peekCStringText errormsg
                  else return (T.pack "got error code but no error message")
        throwIO (MagicException (T.pack caller) msg))

-- | Raise a t'MagicException' if the C action returns a non-zero (failure) code.
checkIntError :: String -> Magic -> IO CInt -> IO ()
checkIntError caller m action =
    do res <- action
       if res == 0 then return () else throwError caller m

-- | Raise a t'MagicException' if the C action returns a @NULL@ pointer.
throwErrorIfNull :: String -> Magic -> IO (Ptr a) -> IO (Ptr a)
throwErrorIfNull caller m action =
    do res <- action
       if res == nullPtr then throwError caller m else return res

foreign import ccall unsafe "magic.h &magic_close"
  magic_close :: FunPtr (Ptr CMagic -> IO ())

foreign import ccall unsafe "magic.h magic_error"
  magic_error :: Ptr CMagic -> IO CString

-- Marshalling between 'OsPath' and the C @const char*@ that libmagic expects.
-- On POSIX an 'OsPath' is exactly the path bytes the OS uses, which is exactly
-- what libmagic wants, so they pass through untouched (no lossy locale round
-- trip). On Windows we fall back to the locale encoding (a libmagic build for
-- Windows is a rarity).

#if defined(mingw32_HOST_OS)

withOsPathCString :: OsPath -> (CString -> IO a) -> IO a
withOsPathCString p k = decodeFS p >>= \s -> withCString s k

withSearchPathCString :: [OsPath] -> (CString -> IO a) -> IO a
withSearchPathCString ps k =
    do ss <- mapM decodeFS ps
       withCString (intercalate ";" ss) k

peekSearchPath :: CString -> IO [OsPath]
peekSearchPath cs =
    do s <- peekCString cs
       mapM encodeFS (filter (not . null) (splitOn ';' s))
  where
    splitOn :: Char -> String -> [String]
    splitOn c s = case break (== c) s of
        (a, [])     -> [a]
        (a, _:rest) -> a : splitOn c rest

#else

osPathBytes :: OsPath -> BS.ByteString
osPathBytes = SBS.fromShort . getPosixString . getOsString

bytesOsPath :: BS.ByteString -> OsPath
bytesOsPath = OsString . PosixString . SBS.toShort

-- | Run an action with the path marshalled to a NUL-terminated C string.
withOsPathCString :: OsPath -> (CString -> IO a) -> IO a
withOsPathCString = BS.useAsCString . osPathBytes

-- | Marshal a search path: the paths joined by the @:@ separator.
withSearchPathCString :: [OsPath] -> (CString -> IO a) -> IO a
withSearchPathCString ps =
    BS.useAsCString (BS.intercalate (BS.singleton 0x3a) (map osPathBytes ps))

-- | Read a @:@-separated C search-path string back into a list of paths.
peekSearchPath :: CString -> IO [OsPath]
peekSearchPath cs =
    (map bytesOsPath . filter (not . BS.null) . BS.split 0x3a) <$> BS.packCString cs

#endif
