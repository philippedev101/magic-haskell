{-  -*- Mode: haskell; -*-
Haskell magic Interface
Copyright (C) 2005 John Goerzen <jgoerzen@complete.org>

This code is under a 3-clause BSD license; see COPYING for details.
-}

{- |
   Module     : Magic.TypesLL
   Copyright  : Copyright (C) 2005 John Goerzen
   License    : BSD-3-Clause

   Maintainer : Philippe <philippedev101\@gmail.com>
   Stability  : provisional
   Portability: portable

Low-level types for the binding.

Written by John Goerzen.
-}

module Magic.TypesLL(CMagic)
where

-- | Phantom type standing in for the C @magic_t@ cookie. It appears only as the
-- argument of a @ForeignPtr@ (the @Magic@ handle) and has no values of its own.
data CMagic
