{- Test runner
Copyright (C) 2005 John Goerzen <jgoerzen@complete.org>

This code is under a 3-clause BSD license; see COPYING for details.
-}

module Main (main) where

import Control.Monad (when)
import System.Exit (exitFailure)
import Test.HUnit

import Tests

main :: IO ()
main = do
    cs <- runTestTT tests
    when (errors cs > 0 || failures cs > 0) exitFailure
