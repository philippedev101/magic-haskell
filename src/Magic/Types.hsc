{-  -*- Mode: haskell; -*-
Haskell magic Interface
Copyright (C) 2005 John Goerzen <jgoerzen@complete.org>

This code is under a 3-clause BSD license; see COPYING for details.
-}

{- |
   Module     : Magic.Types
   Copyright  : Copyright (C) 2005 John Goerzen
   License    : BSD-3-Clause

   Maintainer : Philippe <philippedev101\@gmail.com>
   Stability  : provisional
   Portability: portable

The core types of the binding: the opaque 'Magic' handle and the 'MagicFlag'
enumeration (re-exported from "Magic.Data").

Written by John Goerzen.
-}

module Magic.Types(Magic,
                   MagicFlag(..))
where
import Foreign.ForeignPtr
import Magic.Data
import Magic.TypesLL

#include <magic.h>

{- | The magic handle: an opaque cookie obtained from @magicOpen@ and passed to
the loading and querying functions.

Handles are closed (and their memory freed) automatically when they are
garbage-collected by Haskell. There is no need to close them explicitly.
-}
type Magic = ForeignPtr CMagic

