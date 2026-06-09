{- -*- Mode: haskell; -*-
Haskell magic Interface
Copyright (C) 2005 John Goerzen <jgoerzen@complete.org>

This code is under a 3-clause BSD license; see COPYING for details.
-}

{- |
   Module     : Magic.Utils
   Copyright  : Copyright (C) 2005 John Goerzen
   License    : BSD-3-Clause

   Maintainer : Philippe <philippedev101\@gmail.com>
   Stability  : provisional
   Portability: portable

Internal marshalling helpers shared by the other modules: converting between
'MagicFlag' lists and the C bit-mask, wrapping the C handle in a 'ForeignPtr',
and turning C error returns into 'IOError's.

Written by John Goerzen.
-}

module Magic.Utils (flaglist2int, int2flaglist, fromMagicPtr, withMagicPtr,
                    checkIntError, throwErrorIfNull)
where

import Foreign
import Foreign.C.Error
import Foreign.C.String
import Magic.Types
import Foreign.C.Types

flaglist2int :: [MagicFlag] -> CInt
flaglist2int mfl =
    foldl (\c f -> c .|. (fromIntegral . fromEnum $ f)) 0 mfl

-- | Decode a C bit-mask into the list of set 'MagicFlag's. Each set bit is
-- mapped to its individual flag, so composite values come back decomposed
-- (e.g. the MIME mask yields @['MagicMimeType', 'MagicMimeEncoding']@).
int2flaglist :: CInt -> [MagicFlag]
int2flaglist flags =
    [ toEnum v
    | i <- [0 .. finiteBitSize flags - 1]
    , testBit flags i
    , let v = bit i :: Int ]

fromMagicPtr :: String -> IO (Ptr CMagic) -> IO Magic
fromMagicPtr caller action =
    do ptr <- throwErrnoIfNull caller action
       newForeignPtr magic_close ptr

throwErrorIfNull :: String -> Magic -> IO (Ptr a) -> IO (Ptr a)
throwErrorIfNull caller m action =
    do res <- action
       if res == nullPtr
          then throwError caller m
          else return res

withMagicPtr :: Magic -> (Ptr CMagic -> IO a) -> IO a
withMagicPtr m = withForeignPtr m

throwError :: String -> Magic -> IO a
throwError caller m = withMagicPtr m (\cmagic ->
               do errormsg <- magic_error cmagic
                  if errormsg /= nullPtr
                     then do em <- peekCString errormsg
                             fail $ caller ++ ": " ++ em
                     else fail $ caller ++ ": got error code but no error message"
                                     )

checkIntError :: String -> Magic -> IO CInt -> IO ()
checkIntError caller m action = 
    do res <- action
       if res == 0
          then return ()
          else throwError caller m


foreign import ccall unsafe "magic.h &magic_close"
  magic_close :: FunPtr (Ptr CMagic -> IO ())

foreign import ccall unsafe "magic.h magic_error"
  magic_error :: Ptr CMagic -> IO CString
