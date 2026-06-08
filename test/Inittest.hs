{-
Copyright (C) 2005 John Goerzen <jgoerzen@complete.org>

This code is under a 3-clause BSD license; see COPYING for details.
-}

module Inittest(tests) where

import Control.Exception (bracket)
import qualified Data.ByteString as BS
import Data.List (isInfixOf, isPrefixOf)
import System.Directory (getTemporaryDirectory, removeFile)
import System.FilePath ((</>))
import Test.HUnit

import Magic

-- | Open a handle with the given flags and load the default database.
withDefault :: [MagicFlag] -> (Magic -> IO a) -> IO a
withDefault flags act = do
    m <- magicOpen flags
    magicLoadDefault m
    act m

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
  where
    -- 8-byte PNG signature followed by the start of an IHDR chunk.
    pngBytes = BS.pack
        [0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A
        ,0x00,0x00,0x00,0x0D,0x49,0x48,0x44,0x52]
    withPngFile :: (FilePath -> IO b) -> IO b
    withPngFile act = do
        dir <- getTemporaryDirectory
        let pngPath = dir </> "magic-test-sample.png"
        bracket (BS.writeFile pngPath pngBytes >> return pngPath)
                removeFile
                act

tests :: Test
tests = TestList
    [ TestLabel "text MIME type"   test_textMime
    , TestLabel "text description" test_textDescription
    , TestLabel "PNG MIME type"    test_pngMime
    ]
