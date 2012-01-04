--
-- Web redirector
--
-- Copyright © 2011-2012 Operational Dynamics Consulting, Pty Ltd
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

{-# LANGUAGE OverloadedStrings #-}

module Lookup (lookupHash, test) where

import qualified Data.ByteString.Char8 as S
import qualified Data.ByteString.Lazy.Char8 as L
import Data.Maybe (fromMaybe)
import Database.Redis
import Control.Monad.Trans (liftIO)
import Control.Monad.CatchIO (MonadCatchIO, bracket)


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
queryKey r x = do
        k <- get r key
        return $ fromValue k
    where
        key = toKey $ S.append "target:" x


lookupHash :: S.ByteString -> IO S.ByteString
lookupHash x = bracket
        (connect "localhost" 6379)
        (disconnect)
        (\r -> queryKey r x)


test :: String -> IO S.ByteString
test x = lookupHash $ S.pack x
