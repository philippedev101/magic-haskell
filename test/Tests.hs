{- Tests main file
Copyright (C) 2005 John Goerzen <jgoerzen@complete.org>

This code is under a 3-clause BSD license; see COPYING for details.
-}

module Tests(tests) where

import Test.HUnit
import qualified Inittest

tests :: Test
tests = TestList [TestLabel "init" Inittest.tests]
