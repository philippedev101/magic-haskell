{-
Copyright (C) 2005 John Goerzen <jgoerzen@complete.org>

This code is under a 3-clause BSD license; see COPYING for details.
-}

module Inittest(tests) where

import Control.Concurrent (forkIO)
import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)
import Control.DeepSeq (rnf)
import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (forM, forM_)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import Data.List (isInfixOf, isPrefixOf, isSuffixOf)
import Data.Text (Text)
import qualified Data.Text as T
import System.Directory (doesFileExist, getTemporaryDirectory, removeFile)
import System.FilePath ((</>))
import System.Mem (performMajorGC)
import System.OsPath (encodeFS)
import System.Posix.IO (OpenMode(ReadOnly), closeFd, defaultFileFlags, openFd)
import Test.HUnit

import Magic.FilePath
import qualified Magic as M

-- | Open a handle with the given flags and load the default database.
withDefault :: MagicFlags -> (Magic -> IO a) -> IO a
withDefault flags act = do
    m <- magicOpen flags
    magicLoadDefault m
    act m

-- 8-byte PNG signature followed by the start of an IHDR chunk.
pngBytes :: BS.ByteString
pngBytes = BS.pack
    [0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A
    ,0x00,0x00,0x00,0x0D,0x49,0x48,0x44,0x52]

-- | Run an action with a temporary file holding the PNG bytes.
withPngFile :: (FilePath -> IO b) -> IO b
withPngFile act = do
    dir <- getTemporaryDirectory
    let pngPath = dir </> "magic-test-sample.png"
    bracket (BS.writeFile pngPath pngBytes >> return pngPath)
            removeFile
            act

-- | A small in-memory byte string is detected as plain text.
test_textMime :: Test
test_textMime = TestCase $ do
    result <- withDefault MagicMimeType $ \m ->
        magicByteString m (BS8.pack "Hello, world!\nThis is just some plain ASCII text.\n")
    assertBool ("expected a text/* MIME type, got: " ++ show result)
               ("text/" `isPrefixOf` T.unpack result)

-- | The textual description of plain text mentions \"text\".
test_textDescription :: Test
test_textDescription = TestCase $ do
    result <- withDefault MagicNone $ \m ->
        magicByteString m (BS8.pack "The quick brown fox jumps over the lazy dog.\n")
    assertBool ("expected a description mentioning 'text', got: " ++ show result)
               ("text" `isInfixOf` T.unpack result)

-- | A file whose contents start with the PNG signature is recognised as a PNG.
test_pngMime :: Test
test_pngMime = TestCase $
    withPngFile $ \pngPath -> do
        result <- withDefault MagicMimeType $ \m -> magicFile m pngPath
        assertEqual "PNG MIME type" "image/png" (T.unpack result)

-- | The primary "Magic" API identifies a file given as an 'OsPath'.
test_osPathFile :: Test
test_osPathFile = TestCase $
    withPngFile $ \pngPath -> do
        p <- encodeFS pngPath
        result <- do
            m <- M.magicOpen M.MagicMimeType
            M.magicLoadDefault m
            M.magicFile m p
        assertEqual "PNG MIME via OsPath" "image/png" (T.unpack result)

-- | 'magicByteString' identifies binary data directly, without an intermediate
-- file and without locale-encoding corruption.
test_byteStringMime :: Test
test_byteStringMime = TestCase $ do
    result <- withDefault MagicMimeType $ \m -> magicByteString m pngBytes
    assertEqual "PNG MIME via ByteString" "image/png" (T.unpack result)

-- | 'magicDescriptor' identifies the data behind an open file descriptor.
test_descriptorMime :: Test
test_descriptorMime = TestCase $
    withPngFile $ \pngPath -> do
        result <- withDefault MagicMimeType $ \m ->
            bracket (openFd pngPath ReadOnly defaultFileFlags) closeFd
                    (magicDescriptor m)
        assertEqual "PNG MIME via descriptor" "image/png" (T.unpack result)

-- | 'magicVersion' reports a sane (positive) library version.
test_version :: Test
test_version = TestCase $ do
    v <- magicVersion
    assertBool ("expected a positive libmagic version, got " ++ show v) (v > 0)

-- | Flags set with 'magicSetFlags' are read back by 'magicGetFlags'.
test_getFlags :: Test
test_getFlags = TestCase $
    withDefault MagicNone $ \m -> do
        magicSetFlags m (MagicMimeType <> MagicError)
        fl <- magicGetFlags m
        assertBool ("expected MimeType and Error set in " ++ show fl)
                   (hasFlag fl MagicMimeType && hasFlag fl MagicError)

-- | Pure laws and helpers of the 'MagicFlags' algebra: monoid identity,
-- 'hasFlag' (including its edge cases), 'removeFlags', and the name-printing
-- 'Show' (composites decompose into their atomic flags).
test_flagAlgebra :: Test
test_flagAlgebra = TestCase $ do
    assertEqual "mempty is MagicNone" MagicNone (mempty :: MagicFlags)
    assertEqual "right identity"      MagicMimeType (MagicMimeType <> mempty)
    let both = MagicMimeType <> MagicError
    assertBool  "contains a set flag"  (hasFlag both MagicError)
    assertBool  "lacks an unset flag"  (not (hasFlag MagicMimeType MagicError))
    assertBool  "empty is a subset"    (hasFlag MagicMimeType MagicNone)
    let dropped = removeFlags both MagicError
    assertBool  "removed flag is gone" (not (hasFlag dropped MagicError))
    assertBool  "other flag remains"   (hasFlag dropped MagicMimeType)
    assertEqual "removing an absent flag is a no-op"
                MagicMimeType (removeFlags MagicMimeType MagicError)
    assertEqual "show of the empty set" "MagicNone" (show MagicNone)
    assertEqual "show of one flag"      "MagicMimeType" (show MagicMimeType)
    assertEqual "show decomposes composites"
                "MagicMimeType <> MagicMimeEncoding" (show MagicMime)

-- | The opaque 'Magic' handle shows as a fixed placeholder.
test_showHandle :: Test
test_showHandle = TestCase $ do
    m <- magicOpen MagicNone
    assertEqual "handle shows as placeholder" "<magic handle>" (show m)

-- | The 'NFData' instances force values fully without bottoming.
test_nfdata :: Test
test_nfdata = TestCase $
    rnf (MagicMimeType <> MagicError) `seq`
    rnf MagicParamBytesMax `seq`
    rnf (MagicException (T.pack "ctx") (T.pack "msg")) `seq`
    assertBool "NFData forces flags, params, and exceptions without error" True

-- | A parameter set with 'magicSetParam' is read back by 'magicGetParam'.
test_params :: Test
test_params = TestCase $
    withDefault MagicNone $ \m -> do
        magicSetParam m MagicParamBytesMax 4096
        v <- magicGetParam m MagicParamBytesMax
        assertEqual "bytes-max round-trip" 4096 v

-- | The system's default magic database validates with 'magicCheck'.
test_check :: Test
test_check = TestCase $ do
    ok <- withDefault MagicNone $ \m -> magicCheck m []
    assertBool "default magic database should be valid" ok

-- | 'magicGetPath' returns a non-empty default database path.
test_getPath :: Test
test_getPath = TestCase $ do
    p <- magicGetPath
    assertBool "expected a non-empty default magic path" (not (null p))

-- | A newly added flag ('MagicExtension') maps to the right value end-to-end:
-- it makes libmagic report candidate file extensions.
test_extension :: Test
test_extension = TestCase $
    withPngFile $ \pngPath -> do
        result <- withDefault MagicExtension $ \m -> magicFile m pngPath
        assertBool ("expected 'png' among extensions, got: " ++ show result)
                   ("png" `isInfixOf` T.unpack result)

-- | The composite 'MagicMime' mask is read back decomposed into its component
-- flags by 'magicGetFlags'.
test_getFlagsComposite :: Test
test_getFlagsComposite = TestCase $
    withDefault MagicNone $ \m -> do
        magicSetFlags m MagicMime
        fl <- magicGetFlags m
        assertBool ("expected MimeType and MimeEncoding set in " ++ show fl)
                   (hasFlag fl MagicMimeType && hasFlag fl MagicMimeEncoding)

-- | With 'MagicError' set, examining a missing file raises an 'IOError' rather
-- than embedding the message in the result.
test_errorRaised :: Test
test_errorRaised = TestCase $ do
    r <- withDefault MagicError $ \m ->
        try (magicFile m "/no/such/magic/file") :: IO (Either MagicException Text)
    case r of
        Left e  -> do
            assertEqual "exception carries the operation as its context"
                        "magicFile" (T.unpack (magicErrorContext e))
            assertBool "exception carries a non-empty libmagic message"
                       (not (T.null (magicErrorMessage e)))
            assertBool ("displayException is prefixed with the context, got: "
                          ++ displayException e)
                       ("magicFile: " `isPrefixOf` displayException e)
        Right s -> assertFailure ("expected a MagicException, got: " ++ show s)

-- | After a failed operation, 'magicErrno' reports the underlying system error.
test_errno :: Test
test_errno = TestCase $
    withDefault MagicError $ \m -> do
        _ <- try (magicFile m "/no/such/magic/file")
                 :: IO (Either MagicException Text)
        e <- magicErrno m
        assertBool ("expected a non-zero errno after a failed open, got " ++ show e)
                   (e /= 0)

-- | 'magicLoadBuffers' loads a compiled database from memory, and the handle
-- keeps the buffer alive: after dropping the local reference and forcing a GC,
-- the handle still works. Skipped (passes trivially) when no compiled @.mgc@
-- database can be located, to avoid depending on the host layout.
test_loadBuffers :: Test
test_loadBuffers = TestCase $ do
    mfile <- findCompiledMagic
    case mfile of
        Nothing -> return ()        -- no compiled database available here
        Just f  -> do
            m <- magicOpen MagicMimeType
            -- Load from a buffer that goes out of scope immediately afterwards.
            do buf <- BS.readFile f
               magicLoadBuffers m [buf]
            performMajorGC          -- try to reclaim the now-unreferenced buffer
            result <- magicByteString m pngBytes
            assertEqual "PNG MIME after magicLoadBuffers (buffer survived GC)"
                        "image/png" (T.unpack result)

-- | 'magicLoad' with a non-empty path list (exercises the search-path
-- marshalling, joining the paths for libmagic). Loads a located compiled
-- database explicitly, then identifies data. Skipped when none is found.
test_loadFromPath :: Test
test_loadFromPath = TestCase $ do
    mfile <- findCompiledMagic
    case mfile of
        Nothing -> return ()
        Just f  -> do
            result <- do
                m <- magicOpen MagicMimeType
                magicLoad m [f]         -- non-empty list -> withSearchPathCString
                magicByteString m pngBytes
            assertEqual "PNG MIME after magicLoad from an explicit path"
                        "image/png" (T.unpack result)

-- | Many concurrent calls on a single shared handle all succeed (exercises the
-- per-handle lock; run under the threaded RTS with @-N@).
test_concurrent :: Test
test_concurrent = TestCase $
    withDefault MagicMimeType $ \m -> do
        let n = 32 :: Int
        done <- newEmptyMVar
        forM_ [1 .. n] $ \_ -> forkIO $ do
            r <- try (magicByteString m pngBytes) :: IO (Either SomeException Text)
            putMVar done r
        results <- forM [1 .. n] $ \_ -> takeMVar done
        let ok :: Either SomeException Text -> Bool
            ok (Right s) = T.unpack s == "image/png"
            ok (Left _)  = False
        assertBool "every concurrent call returned image/png" (all ok results)

-- | Locate a compiled magic database from the default search path.
findCompiledMagic :: IO (Maybe FilePath)
findCompiledMagic = do
    paths <- magicGetPath
    firstExisting (filter (".mgc" `isSuffixOf`)
                          (concatMap (\p -> [p, p ++ ".mgc"]) paths))
  where
    firstExisting :: [FilePath] -> IO (Maybe FilePath)
    firstExisting []     = return Nothing
    firstExisting (f:fs) = do
        e <- doesFileExist f
        if e then return (Just f) else firstExisting fs

tests :: Test
tests = TestList
    [ TestLabel "text MIME type"        test_textMime
    , TestLabel "text description"      test_textDescription
    , TestLabel "PNG MIME type"         test_pngMime
    , TestLabel "PNG MIME (OsPath)"     test_osPathFile
    , TestLabel "PNG MIME (ByteString)" test_byteStringMime
    , TestLabel "PNG MIME (descriptor)" test_descriptorMime
    , TestLabel "library version"       test_version
    , TestLabel "get/set flags"         test_getFlags
    , TestLabel "composite flags"       test_getFlagsComposite
    , TestLabel "flag algebra"          test_flagAlgebra
    , TestLabel "show handle"           test_showHandle
    , TestLabel "NFData instances"      test_nfdata
    , TestLabel "extension flag"        test_extension
    , TestLabel "get/set params"        test_params
    , TestLabel "check database"        test_check
    , TestLabel "default path"          test_getPath
    , TestLabel "error raised"          test_errorRaised
    , TestLabel "errno after failure"   test_errno
    , TestLabel "load buffers"          test_loadBuffers
    , TestLabel "load from path"        test_loadFromPath
    , TestLabel "concurrent handle use" test_concurrent
    ]
