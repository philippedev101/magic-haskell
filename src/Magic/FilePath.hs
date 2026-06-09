{-  -*- Mode: haskell; -*-
Haskell magic Interface
Copyright (C) 2005 John Goerzen <jgoerzen@complete.org>

This code is under a 3-clause BSD license; see COPYING for details.
-}

{- |
   Module     : Magic.FilePath
   Copyright  : Copyright (C) 2005 John Goerzen
   License    : BSD-3-Clause

   Maintainer : Philippe <philippedev101\@gmail.com>
   Stability  : provisional
   Portability: portable

A convenience facade over "Magic" that takes ordinary 'FilePath's instead of
'System.OsPath.OsPath's. Import this module /instead of/ "Magic" if you prefer
@String@ paths:

> import Magic.FilePath

Everything else (the handle, flags, in-memory and descriptor queries, and so on)
is re-exported unchanged from "Magic".

The 'FilePath' wrappers convert with 'System.OsPath.encodeFS' /
'System.OsPath.decodeFS', which go through the locale's filesystem encoding. For
ordinary ASCII/UTF-8 filenames under a UTF-8 locale this is fine. But a
'FilePath' cannot faithfully represent every path the operating system can:
names whose bytes are not valid in the current locale (raw non-UTF-8 bytes on
Unix, or names created under a different locale) may be corrupted or fail to
round-trip, so a call can fail to open a file that exists, or open the wrong
one. The @OsPath@ functions in "Magic" store the path bytes verbatim and avoid
this entirely; prefer them when correctness on arbitrary filenames matters.

@since 2.0.0
-}

module Magic.FilePath
  ( module Magic
  , magicFile
  , magicLoad
  , magicCompile
  , magicCheck
  , magicGetPath
  ) where

import Magic hiding (magicFile, magicLoad, magicCompile, magicCheck, magicGetPath)
import qualified Magic as O
import Data.Text (Text)
import System.OsPath (decodeFS, encodeFS)

-- | 'Magic.magicFile' taking a 'FilePath'.
magicFile :: Magic -> FilePath -> IO Text
magicFile m p = O.magicFile m =<< encodeFS p

-- | 'Magic.magicLoad' taking 'FilePath's (empty list = the default database).
magicLoad :: Magic -> [FilePath] -> IO ()
magicLoad m ps = O.magicLoad m =<< mapM encodeFS ps

-- | 'Magic.magicCompile' taking 'FilePath's (empty list = the default database).
magicCompile :: Magic -> [FilePath] -> IO ()
magicCompile m ps = O.magicCompile m =<< mapM encodeFS ps

-- | 'Magic.magicCheck' taking 'FilePath's (empty list = the default database).
magicCheck :: Magic -> [FilePath] -> IO Bool
magicCheck m ps = O.magicCheck m =<< mapM encodeFS ps

-- | 'Magic.magicGetPath' returning 'FilePath's.
magicGetPath :: IO [FilePath]
magicGetPath = O.magicGetPath >>= mapM decodeFS
