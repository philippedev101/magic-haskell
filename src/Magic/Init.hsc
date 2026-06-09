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
import Magic.Internal (Magic, CMagic, fromMagicPtr, withMagicPtr, checkIntError, withSearchPathCString)
import Magic.Data (MagicFlags(..))
import Foreign.C.Types
import System.OsPath (OsPath)

{- | Create a new magic handle configured with the given flags. Combine flags
with @('<>')@ (see t'MagicFlags'), or pass 'mempty' for the defaults. Before
querying anything you must load a database with 'magicLoadDefault' or
'magicLoad'.

The handle is freed automatically when it is garbage-collected. Raises an
'IOError' if the handle cannot be created.
-}
magicOpen :: MagicFlags -> IO Magic
magicOpen (MagicFlags flags) =
    fromMagicPtr "magicOpen" (magic_open flags)

{- | Load the system's default magic database into the handle. Raises a
@MagicException@ if the database cannot be loaded. -}
magicLoadDefault :: Magic -> IO ()
magicLoadDefault m = withMagicPtr m (\cmagic ->
    checkIntError "magicLoadDefault" m $ magic_load cmagic nullPtr)

{- | Load the given magic database(s) into the handle. Pass the empty list to
load the system default (equivalent to 'magicLoadDefault'). Raises a
@MagicException@ if a database cannot be loaded.

(libmagic joins the list with the platform search-path separator, so a path
that itself contains that separator cannot be represented.) -}
magicLoad :: Magic -> [OsPath] -> IO ()
magicLoad m ps = withMagicPtr m (\cmagic ->
    case ps of
      [] -> checkIntError "magicLoad" m $ magic_load cmagic nullPtr
      _  -> withSearchPathCString ps (\cs ->
             checkIntError "magicLoad" m $ magic_load cmagic cs))
    
-- Allocates the cookie, no file I/O -> unsafe
foreign import ccall unsafe "magic.h magic_open"
  magic_open :: CInt -> IO (Ptr CMagic)

-- Reads and parses the (potentially multi-megabyte) magic database from disk:
-- blocking I/O, so this must be a safe call. A safe call lets other Haskell
-- threads run during the load and does not stall garbage collection, whereas
-- an unsafe call would block the capability for the whole load.
foreign import ccall safe "magic.h magic_load"
  magic_load :: Ptr CMagic -> CString -> IO CInt