{- -*- Mode: haskell; -*-
Haskell Magic Interface
Copyright (C) 2005 John Goerzen <jgoerzen@complete.org>

This code is under a 3-clause BSD license; see COPYING for details.
-}

{-
This generator produces src/Magic/Data.hsc: the MagicFlag type plus its
Enum/Ord/Eq instances and Haddock documentation, derived from libmagic's
MAGIC_* constants in <magic.h>.

To regenerate after adding (or removing) a flag:

    runghc utils/genconsts.hs > src/Magic/Data.hsc

Keep both lists below in sync with <magic.h>: `magicFlags` (the constants to
emit, in order) and `flagDocs` (the Haddock description for each). A constant
missing from `flagDocs` still generates, with a placeholder description.
-}

import Data.Char
import Data.List

const2HS (x:xs) =
    x : c2hs xs
    where c2hs [] = []
          c2hs ('_':x:xs) = x : c2hs xs
          c2hs (x:xs) = toLower x : c2hs xs

getC const = "#{const " ++ const ++ "}"

-- | Haddock description for each MAGIC_* constant.
flagDocs :: [(String, String)]
flagDocs =
  [ ("MAGIC_NONE",           "No special handling; return a textual description (the default).")
  , ("MAGIC_DEBUG",          "Print debugging messages to stderr.")
  , ("MAGIC_SYMLINK",        "Follow symbolic links.")
  , ("MAGIC_COMPRESS",       "Look inside compressed files.")
  , ("MAGIC_DEVICES",        "Look at the contents of block or character special devices.")
  , ("MAGIC_MIME_TYPE",      "Return a MIME type string instead of a textual description.")
  , ("MAGIC_MIME_ENCODING",  "Return the MIME encoding (character set) instead of a textual description.")
  , ("MAGIC_MIME",           "Return both the MIME type and the encoding.")
  , ("MAGIC_CONTINUE",       "Return all matches, not just the first.")
  , ("MAGIC_CHECK",          "Check the magic database for consistency and report problems.")
  , ("MAGIC_PRESERVE_ATIME", "Preserve the access time of examined files.")
  , ("MAGIC_RAW",            "Do not translate unprintable characters to octal escapes.")
  , ("MAGIC_ERROR",          "Treat errors while examining a file as real errors instead of embedding them in the result.")
  , ("MAGIC_APPLE",          "Return the Apple creator and type.")
  , ("MAGIC_EXTENSION",      "Return a slash-separated list of valid file extensions for the detected type.")
  , ("MAGIC_COMPRESS_TRANSP","Report on the compressed contents only, without mentioning the compression itself (transparent decompression).")
  , ("MAGIC_NO_COMPRESS_FORK","Do not allow decompression that requires forking a helper process.")
  , ("MAGIC_NODESC",         "Composite of 'MagicExtension', 'MagicMime' and 'MagicApple': return identifiers rather than a textual description.")
  , ("MAGIC_NO_CHECK_COMPRESS","Do not look inside compressed files.")
  , ("MAGIC_NO_CHECK_TAR",   "Do not examine tar archives.")
  , ("MAGIC_NO_CHECK_SOFT",  "Do not consult the magic database entries (soft magic).")
  , ("MAGIC_NO_CHECK_APPTYPE","Do not check for an application type (e.g. EMX).")
  , ("MAGIC_NO_CHECK_ELF",   "Do not examine ELF details.")
  , ("MAGIC_NO_CHECK_TEXT",  "Do not examine text files.")
  , ("MAGIC_NO_CHECK_CDF",   "Do not examine CDF (Microsoft Compound Document) files.")
  , ("MAGIC_NO_CHECK_CSV",   "Do not examine CSV files.")
  , ("MAGIC_NO_CHECK_TOKENS","Do not look for known text tokens.")
  , ("MAGIC_NO_CHECK_ENCODING","Do not check text encodings.")
  , ("MAGIC_NO_CHECK_JSON",  "Do not examine JSON files.")
  , ("MAGIC_NO_CHECK_SIMH",  "Do not examine SIMH tape files.")
  , ("MAGIC_NO_CHECK_BUILTIN","Disable all built-in tests; consult only the magic database.")
  ]

docFor :: String -> String
docFor c = maybe ("The " ++ c ++ " flag.") id (lookup c flagDocs)

-- A Haddock-documented data declaration: one '-- |' comment per constructor.
dataDecl name consts =
    "-- | Flags that control how @libmagic@ examines a file and what it\n" ++
    "-- reports. Combine them in the list passed to @magicOpen@ or\n" ++
    "-- @magicSetFlags@.\n" ++
    "data " ++ name ++ "\n" ++
    "    = " ++ intercalate "\n    | " (map documented consts ++ [unknownCon]) ++ "\n" ++
    "  deriving (Show)\n"
    where
    documented c = "-- | " ++ docFor c ++ "\n      " ++ const2HS c
    unknownCon =
      "-- | A flag value returned by libmagic that these bindings do not\n" ++
      "      --   recognise, carrying its raw integer value.\n" ++
      "      Unknown" ++ name ++ " Int"

errorClause name consts =
    dataDecl name consts ++
    "\ninstance Enum " ++ name ++ " where\n" ++
    concat (intersperse "\n" (map toenums consts)) ++
    "\n toEnum x = Unknown" ++ name ++ " x\n" ++
    "\n" ++ concat (intersperse "\n" (map fromenums consts)) ++
    "\n fromEnum (Unknown" ++ name ++ " x) = x\n" ++
    "\ninstance Ord " ++ name ++ " where\n" ++
    " compare x y = compare (fromEnum x) (fromEnum y)\n\n" ++
    "instance Eq " ++ name ++ " where\n" ++
    " x == y = (fromEnum x) == (fromEnum y)\n\n"
    where
    toenums i =
        " toEnum (" ++ getC i ++ ") = " ++ (const2HS i)
    fromenums i =
        " fromEnum " ++ (const2HS i) ++ " = (" ++ getC i ++ ")"

modHeader =
 "-- AUTO-GENERATED FILE, DO NOT EDIT.  GENERATED BY utils/genconsts.hs\n" ++
 "{- |\n" ++
 "   Module     : Magic.Data\n" ++
 "   Copyright  : Copyright (C) 2005 John Goerzen\n" ++
 "   License    : BSD-3-Clause\n" ++
 "\n" ++
 "   Maintainer : Philippe <philippedev101\\@gmail.com>\n" ++
 "   Stability  : provisional\n" ++
 "   Portability: portable\n" ++
 "\n" ++
 "The 'MagicFlag' enumeration, mapping the C @libmagic@ @MAGIC_*@ constants\n" ++
 "to Haskell.\n" ++
 "-}\n\n" ++
 "module Magic.Data (MagicFlag(..)) where\n" ++
 "\n#include \"magic.h\"\n\n"

main =
    do putStrLn modHeader
       putStrLn (errorClause "MagicFlag" magicFlags)

-- NOTE: keep these in sync with <magic.h>. Aliases / zero-valued constants are
-- intentionally omitted because the Enum instance maps each constructor to a
-- distinct integer: MAGIC_NO_CHECK_ASCII is a synonym for MAGIC_NO_CHECK_TEXT,
-- and MAGIC_NO_CHECK_FORTRAN / MAGIC_NO_CHECK_TROFF are deprecated no-ops equal
-- to 0 (i.e. MAGIC_NONE). Composite flags (MAGIC_MIME, MAGIC_NODESC,
-- MAGIC_NO_CHECK_BUILTIN) are kept: each has a distinct value.
magicFlags = ["MAGIC_NONE", "MAGIC_DEBUG", "MAGIC_SYMLINK",
              "MAGIC_COMPRESS", "MAGIC_DEVICES",
              "MAGIC_MIME_TYPE", "MAGIC_MIME_ENCODING", "MAGIC_MIME",
              "MAGIC_CONTINUE", "MAGIC_CHECK",
              "MAGIC_PRESERVE_ATIME", "MAGIC_RAW", "MAGIC_ERROR",
              "MAGIC_APPLE", "MAGIC_EXTENSION",
              "MAGIC_COMPRESS_TRANSP", "MAGIC_NO_COMPRESS_FORK",
              "MAGIC_NODESC",
              "MAGIC_NO_CHECK_COMPRESS", "MAGIC_NO_CHECK_TAR",
              "MAGIC_NO_CHECK_SOFT", "MAGIC_NO_CHECK_APPTYPE",
              "MAGIC_NO_CHECK_ELF", "MAGIC_NO_CHECK_TEXT",
              "MAGIC_NO_CHECK_CDF", "MAGIC_NO_CHECK_CSV",
              "MAGIC_NO_CHECK_TOKENS", "MAGIC_NO_CHECK_ENCODING",
              "MAGIC_NO_CHECK_JSON", "MAGIC_NO_CHECK_SIMH",
              "MAGIC_NO_CHECK_BUILTIN"]
