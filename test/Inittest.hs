{-
Copyright (C) 2005 John Goerzen <jgoerzen@complete.org>

This code is under a 3-clause BSD license; see COPYING for details.
-}

module Inittest(tests) where

import Control.Exception (IOException, bracket, try)
import qualified Data.ByteString as BS
import Data.List (isInfixOf, isPrefixOf)
import System.Directory (getTemporaryDirectory, removeFile)
import System.FilePath ((</>))
import System.Posix.IO (OpenMode(ReadOnly), closeFd, defaultFileFlags, openFd)
import Test.HUnit

import Magic

-- | Open a handle with the given flags and load the default database.
withDefault :: [MagicFlag] -> (Magic -> IO a) -> IO a
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

-- | A small in-memory string is detected as plain text.
test_textMime :: Test
test_textMime = TestCase $ do
    result <- withDefault [MagicMimeType] $ \m ->
        magicString m "Hello, world!\nThis is just some plain ASCII text.\n"
    assertBool ("expected a text/* MIME type, got: " ++ show result)
               ("text/" `isPrefixOf` result)

-- | The textual description of plain text mentions \"text\".
test_textDescription :: Test
test_textDescription = TestCase $ do
    result <- withDefault [MagicNone] $ \m ->
        magicString m "The quick brown fox jumps over the lazy dog.\n"
    assertBool ("expected a description mentioning 'text', got: " ++ show result)
               ("text" `isInfixOf` result)

-- | A file whose contents start with the PNG signature is recognised as a PNG.
--
-- Binary content must be detected via a file (raw bytes); passing binary
-- data through 'magicString' would corrupt the high bytes via the locale
-- encoding.
test_pngMime :: Test
test_pngMime = TestCase $
    withPngFile $ \pngPath -> do
        result <- withDefault [MagicMimeType] $ \m -> magicFile m pngPath
        assertEqual "PNG MIME type" "image/png" result

-- | 'magicByteString' identifies binary data directly, without an intermediate
-- file and without locale-encoding corruption.
test_byteStringMime :: Test
test_byteStringMime = TestCase $ do
    result <- withDefault [MagicMimeType] $ \m -> magicByteString m pngBytes
    assertEqual "PNG MIME via ByteString" "image/png" result

-- | 'magicDescriptor' identifies the data behind an open file descriptor.
test_descriptorMime :: Test
test_descriptorMime = TestCase $
    withPngFile $ \pngPath -> do
        result <- withDefault [MagicMimeType] $ \m ->
            bracket (openFd pngPath ReadOnly defaultFileFlags) closeFd
                    (magicDescriptor m)
        assertEqual "PNG MIME via descriptor" "image/png" result

-- | 'magicVersion' reports a sane (positive) library version.
test_version :: Test
test_version = TestCase $ do
    v <- magicVersion
    assertBool ("expected a positive libmagic version, got " ++ show v) (v > 0)

-- | Flags set with 'magicSetFlags' are read back by 'magicGetFlags'.
test_getFlags :: Test
test_getFlags = TestCase $
    withDefault [MagicNone] $ \m -> do
        magicSetFlags m [MagicMimeType, MagicError]
        fl <- magicGetFlags m
        assertBool ("expected MimeType and Error among " ++ show fl)
                   (MagicMimeType `elem` fl && MagicError `elem` fl)

-- | A parameter set with 'magicSetParam' is read back by 'magicGetParam'.
test_params :: Test
test_params = TestCase $
    withDefault [MagicNone] $ \m -> do
        magicSetParam m MagicParamBytesMax 4096
        v <- magicGetParam m MagicParamBytesMax
        assertEqual "bytes-max round-trip" 4096 v

-- | The system's default magic database validates with 'magicCheck'.
test_check :: Test
test_check = TestCase $ do
    ok <- withDefault [MagicNone] $ \m -> magicCheck m Nothing
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
        result <- withDefault [MagicExtension] $ \m -> magicFile m pngPath
        assertBool ("expected 'png' among extensions, got: " ++ show result)
                   ("png" `isInfixOf` result)

-- | The composite 'MagicMime' mask is read back decomposed into its component
-- flags by 'magicGetFlags'.
test_getFlagsComposite :: Test
test_getFlagsComposite = TestCase $
    withDefault [MagicNone] $ \m -> do
        magicSetFlags m [MagicMime]
        fl <- magicGetFlags m
        assertBool ("expected MimeType and MimeEncoding among " ++ show fl)
                   (MagicMimeType `elem` fl && MagicMimeEncoding `elem` fl)

-- | With 'MagicError' set, examining a missing file raises an 'IOError' rather
-- than embedding the message in the result.
test_errorRaised :: Test
test_errorRaised = TestCase $ do
    r <- withDefault [MagicError] $ \m ->
        try (magicFile m "/no/such/magic/file") :: IO (Either IOException String)
    case r of
        Left _  -> return ()
        Right s -> assertFailure ("expected an IOError, got: " ++ show s)

-- | After a failed operation, 'magicErrno' reports the underlying system error.
test_errno :: Test
test_errno = TestCase $
    withDefault [MagicError] $ \m -> do
        _ <- try (magicFile m "/no/such/magic/file")
                 :: IO (Either IOException String)
        e <- magicErrno m
        assertBool ("expected a non-zero errno after a failed open, got " ++ show e)
                   (e /= 0)

tests :: Test
tests = TestList
    [ TestLabel "text MIME type"        test_textMime
    , TestLabel "text description"      test_textDescription
    , TestLabel "PNG MIME type"         test_pngMime
    , TestLabel "PNG MIME (ByteString)" test_byteStringMime
    , TestLabel "PNG MIME (descriptor)" test_descriptorMime
    , TestLabel "library version"       test_version
    , TestLabel "get/set flags"         test_getFlags
    , TestLabel "composite flags"       test_getFlagsComposite
    , TestLabel "extension flag"        test_extension
    , TestLabel "get/set params"        test_params
    , TestLabel "check database"        test_check
    , TestLabel "default path"          test_getPath
    , TestLabel "error raised"          test_errorRaised
    , TestLabel "errno after failure"   test_errno
    ]
