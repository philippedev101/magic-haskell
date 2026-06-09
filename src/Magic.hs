{- -*- Mode: haskell; -*-
Haskell Magic Interface
Copyright (C) 2005 John Goerzen <jgoerzen@complete.org>

This code is under a 3-clause BSD license; see COPYING for details.
-}

{- |
   Module     : Magic
   Copyright  : Copyright (C) 2005 John Goerzen
   License    : BSD-3-Clause

   Maintainer : Philippe <philippedev101\@gmail.com>
   Stability  : provisional
   Portability: portable

Haskell bindings to the C @libmagic@ library, which identifies the type of a
file by inspecting its contents rather than its name. It can report a textual
description, a MIME type, or a character-set encoding.

This top-level module re-exports the whole interface: the types in
"Magic.Types", the initialization functions in "Magic.Init", and the querying
functions in "Magic.Operations".

If you just want to pass ordinary @String@ paths, start with "Magic.FilePath",
a drop-in facade over this module. The functions here take
'System.OsPath.OsPath' instead, which represents any filename losslessly and
independently of the locale (see the note below).

A typical session creates a handle, loads the system magic database, then
queries files or in-memory data. The flags passed to 'magicOpen' choose what
kind of answer comes back (see t'MagicFlags'); combine them with @('<>')@ and
use 'mempty' (i.e. 'MagicNone') for the defaults:

> {-# LANGUAGE QuasiQuotes #-}
> import Magic
> import System.OsPath (osp)
> import qualified Data.Text.IO as T
>
> main :: IO ()
> main = do
>   magic <- magicOpen MagicMimeType     -- ask for MIME types
>   magicLoadDefault magic               -- load the system database
>   mime <- magicFile magic [osp|/etc/passwd|]
>   T.putStrLn mime                      -- e.g. "text/plain"

Paths here are 'System.OsPath.OsPath', which stores the OS-native path bytes
verbatim and so represents any path the system can, without a lossy locale
round-trip. The "Magic.FilePath" facade offers the same API with @String@
paths for convenience; it is fine for ordinary filenames, but cannot faithfully
represent names whose bytes are invalid in the current locale.

Handles are closed and their memory freed automatically when they are
garbage-collected (see t'Magic'); there is no explicit close. On failure, most
operations raise a t'MagicException'; 'magicOpen' raises an 'IOError' (from
@errno@) if the handle cannot be allocated.

Originally written by John Goerzen.
-}

module Magic (-- * Basic Types
             module Magic.Types,
             -- * Flags
             module Magic.Data,
             -- * Initialization
             module Magic.Init,
             -- * Operation
             module Magic.Operations
            )
where
import Magic.Types
import Magic.Data
import Magic.Init
import Magic.Operations
