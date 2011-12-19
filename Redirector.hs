--
-- Web redirector
--
-- Copyright © 2011 Operational Dynamics Consulting, Pty Ltd
--
-- The code in this file, and the program it is a part of, is made available
-- to you by its authors as open source software: you can redistribute it
-- and/or modify it under the terms of the GNU General Public License version
-- 2 ("GPL") as published by the Free Software Foundation.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
-- FITNESS FOR A PARTICULAR PURPOSE. See the GPL for more details.
--
-- You should have received a copy of the GPL along with this program. If not,
-- see http://www.gnu.org/licenses/. The authors of this program may be
-- contacted through http://research.operationaldynamics.com/
--

{-# LANGUAGE OverloadedStrings, ScopedTypeVariables #-}

import Snap.Http.Server
import Snap.Core
import Snap.Util.FileServe
import Control.Applicative
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as S
import qualified Data.ByteString.Lazy.Char8 as L
import Data.Maybe (fromMaybe)
import Numeric
import Data.Char
import Database.Redis
import Control.Monad.Trans (liftIO)
import Prelude hiding (catch)
import Control.Exception

--
-- Conversion between decimal and base 62
--

represent :: Int -> Char
represent x | x < 10 = chr (48 + x)
            | x < 36 = chr (65 + x - 10)
            | x < 62 = chr (97 + x - 36)
            | otherwise = '@'

encode :: Int -> String
encode x    = showIntAtBase 62 represent x ""


value :: Char -> Int
value c     | isDigit c = ord c - 48
            | isUpper c = ord c - 65 + 10
            | isLower c = ord c - 97 + 36
            | otherwise = 0

multiply :: Int -> Char -> Int
multiply acc c = acc * 62 + value c

decode :: String -> Int
decode ss   = foldl multiply 0 ss

--
-- Process jump hash
--

fromValue :: RedisValue -> S.ByteString
fromValue v = case v of
        RedisString s   -> s
        RedisInteger i  -> S.pack $ show i
        RedisNil        -> "" -- used to be "(nil)"
        RedisMulti vs   -> S.intercalate "\n" $ map fromValue vs


toKey :: S.ByteString -> L.ByteString
toKey x = L.fromChunks [x]


queryKey :: Server -> S.ByteString -> IO S.ByteString
queryKey r x = catch
        (do
            k <- get r $ toKey x
            return $ fromValue k)
        (\(e :: RedisError) -> do
            putStrLn $ show e
            return "")


lookupHash :: S.ByteString -> Snap S.ByteString
lookupHash x = bracketSnap
    (connect "localhost" 6379)
    (disconnect)
    (\r -> liftSnap $ liftIO $ queryKey r x)


serveJump :: Snap ()
serveJump = do
    h <-  getParam "hash"
    let h' = fromMaybe "" h
    t <- lookupHash h'
    if t == ""
    then
        serveNotFound
    else
        redirect' t 301

--
-- If a key is requested that doesn't exist, we give 404. TODO
-- As this is probably a common case, we should serve a more
-- interesting page.
--

serveNotFound :: Snap ()
serveNotFound = do
    modifyResponse $ setResponseStatus 404 "Not Found"
    writeBS "404 Not Found"

--
-- If they request / then we send them to the corporate home page 
--

serveHome :: Snap ()
serveHome = do
    redirect' "http://www.operationaldynamics.com/" 302

--
-- Top level URL routing logic.
--

site :: Snap ()
site = route
    [("/", serveHome),
     ("/:hash", serveJump)]
    <|> serveNotFound

main :: IO ()
main = quickHttpServe site

