{- -*- Mode: haskell; -*-
Haskell magic Interface
Copyright (C) 2005 John Goerzen <jgoerzen@complete.org>

This code is under a 3-clause BSD license; see COPYING for details.
-}

{- |
   Module     : Magic.Init
   Copyright  : Copyright (C) 2005 John Goerzen
   License    : BSD-3-Clause

   Maintainer : Philippe <philippedev101\@gmail.com>
   Stability  : provisional
   Portability: portable

Creating a magic handle and loading magic databases into it. A handle returned
by 'magicOpen' must be given a database with 'magicLoadDefault' or 'magicLoad'
before it can be queried with the functions in "Magic.Operations".

Written by John Goerzen.
-}

module Magic.Init(magicOpen, magicLoad, magicLoadDefault)
where

import Foreign.Ptr
import Foreign.C.String
import Magic.Types
import Foreign.C.Types
import Magic.Utils
import Magic.TypesLL

{- | Create a new magic handle configured with the given flags (see
'MagicFlag'). Before querying anything you must load a database with
'magicLoadDefault' or 'magicLoad'.

The handle is freed automatically when it is garbage-collected. Raises an
'IOError' if the handle cannot be created.
-}
magicOpen :: [MagicFlag] -> IO Magic
magicOpen mfl =
    fromMagicPtr "magicOpen" (magic_open flags)
    where flags = flaglist2int mfl

{- | Load the system's default magic database into the handle. Raises an
'IOError' if the database cannot be loaded. -}
magicLoadDefault :: Magic -> IO ()
magicLoadDefault m = withMagicPtr m (\cmagic ->
    checkIntError "magicLoadDefault" m $ magic_load cmagic nullPtr)

{- | Load the given magic database(s) into the handle. The argument may be a
single path or several colon-separated paths. Raises an 'IOError' if a database
cannot be loaded. -}
magicLoad :: Magic -> String -> IO ()
magicLoad m s = withMagicPtr m (\cmagic ->
    withCString s (\cs ->
     checkIntError "magicLoad" m $ magic_load cmagic cs))
    
foreign import ccall unsafe "magic.h magic_open"
  magic_open :: CInt -> IO (Ptr CMagic)

foreign import ccall unsafe "magic.h magic_load"
  magic_load :: Ptr CMagic -> CString -> IO CInt