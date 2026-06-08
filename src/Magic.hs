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

A typical session creates a handle, loads the system magic database, then
queries files or in-memory data. The flags passed to 'magicOpen' (see
'MagicFlag') choose what kind of answer comes back:

> import Magic
>
> main :: IO ()
> main = do
>   magic <- magicOpen [MagicMimeType]   -- ask for MIME types
>   magicLoadDefault magic               -- load the system database
>   mime <- magicFile magic "/etc/passwd"
>   putStrLn mime                        -- e.g. "text/plain"

Handles are closed and their memory freed automatically when they are
garbage-collected (see 'Magic'); there is no explicit close. On failure the
operations in this library raise an 'IOError'.

Originally written by John Goerzen.
-}

module Magic (-- * Basic Types
             module Magic.Types,
             -- * Initialization
             module Magic.Init,
             -- * Operation
             module Magic.Operations
            )
where
import Magic.Types
import Magic.Init
import Magic.Operations
