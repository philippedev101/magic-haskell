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

The core types of the binding: the opaque 'Magic' handle, the 'MagicFlag'
enumeration (re-exported from "Magic.Data") and the 'MagicParam' tunables.

Written by John Goerzen.
-}

module Magic.Types(Magic,
                   CMagic,
                   MagicFlag(..),
                   MagicParam(..))
where
import Foreign.ForeignPtr
import Magic.Data

#include <magic.h>

-- | Phantom type standing in for the C @magic_t@ cookie. It appears only as the
-- argument of a 'Foreign.ForeignPtr.ForeignPtr' (the 'Magic' handle) and has no
-- values of its own.
data CMagic

{- | The magic handle: an opaque cookie obtained from @magicOpen@ and passed to
the loading and querying functions.

Handles are closed (and their memory freed) automatically when they are
garbage-collected by Haskell. There is no need to close them explicitly.

__Thread safety.__ A single @Magic@ handle is /not/ safe for concurrent use:
the underlying @libmagic@ cookie keeps mutable state, so calling operations on
the same handle from multiple threads at once is a data race. Use one handle
per thread, or serialise access to a shared handle (e.g. behind an @MVar@).
Distinct handles are independent and may be used concurrently. Programs doing
blocking work (loading databases, examining files) should also be built with
the threaded runtime (@-threaded@).
-}
type Magic = ForeignPtr CMagic

{- | Tunable limits that bound how hard @libmagic@ works when examining data,
read and written with @magicGetParam@ and @magicSetParam@ (see
"Magic.Operations"). Lowering these (especially 'MagicParamBytesMax') is a way
to cap the effort spent on untrusted input. Defaults below are those documented
for @libmagic@ 5.45.

@since 1.1.2
-}
data MagicParam
    = -- | Maximum number of levels of recursion when following indirect magic. (Default: 15.)
      MagicParamIndirMax
    | -- | Maximum length of a name used by name\/use magic. (Default: 30.)
      MagicParamNameMax
    | -- | Maximum number of ELF program header sections processed. (Default: 128.)
      MagicParamElfPhnumMax
    | -- | Maximum number of ELF section header sections processed. (Default: 32768.)
      MagicParamElfShnumMax
    | -- | Maximum number of ELF notes processed. (Default: 256.)
      MagicParamElfNotesMax
    | -- | Maximum length of a regex search. (Default: 8192.)
      MagicParamRegexMax
    | -- | Maximum number of bytes read from a file before giving up. (Default: 1048576, i.e. 1 MiB.)
      MagicParamBytesMax
    | -- | Maximum number of bytes scanned when guessing a text encoding.
      MagicParamEncodingMax
    | -- | Maximum size of an ELF section processed.
      MagicParamElfShsizeMax
  deriving (Show, Eq, Ord, Enum, Bounded)

