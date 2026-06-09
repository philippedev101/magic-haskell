{-  -*- Mode: haskell; -*-
Haskell magic Interface
Copyright (C) 2005 John Goerzen <jgoerzen@complete.org>

This code is under a 3-clause BSD license; see COPYING for details.
-}

{-# LANGUAGE DeriveGeneric #-}

{- |
   Module     : Magic.Types
   Copyright  : Copyright (C) 2005 John Goerzen
   License    : BSD-3-Clause

   Maintainer : Philippe <philippedev101\@gmail.com>
   Stability  : provisional
   Portability: portable

The core types of the binding: the opaque t'Magic' handle, the t'MagicException'
error type (both defined in "Magic.Internal"), and the 'MagicParam' tunables.
The flag bit-mask lives in "Magic.Data".
-}

module Magic.Types(Magic,
                   MagicException(..),
                   MagicParam(..))
where
import Control.DeepSeq (NFData(rnf))
import GHC.Generics (Generic)
import Magic.Internal (Magic, MagicException(..))

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
  deriving (Show, Eq, Ord, Enum, Bounded, Generic)

instance NFData MagicParam where rnf x = x `seq` ()

