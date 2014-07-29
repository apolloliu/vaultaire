--
-- Data vault for metrics
--
-- Copyright © 2013-2014 Anchor Systems, Pty Ltd and Others
--
-- The code in this file, and the program it is a part of, is
-- made available to you by its authors as open source software:
-- you can redistribute it and/or modify it under the terms of
-- the 3-clause BSD licence.
--

{-# LANGUAGE RankNTypes      #-}

--
-- | This module encapsulates the various daemons that you might want to start
-- up as part of a Vaultaire cluster, along with their default behaviours.
--
module DaemonRunners
(
   forkThread,
   runBrokerDaemon,
   runWriterDaemon,
   runReaderDaemon,
   runContentsDaemon
)
where

import qualified Control.Concurrent.Async as A
import Control.Concurrent.MVar
import qualified Data.ByteString.Char8 as S
import Data.Word (Word64)
import Pipes
import System.Log.Logger
import System.ZMQ4.Monadic

import Vaultaire.Broker
import Vaultaire.Contents (startContents)
import Vaultaire.Reader (startReader)
import Vaultaire.Writer (startWriter)


forkThread :: IO a -> IO ()
forkThread a = A.link =<< A.async a

forkThreadZMQ :: forall a z. ZMQ z a -> ZMQ z ()
forkThreadZMQ a = (liftIO . A.link) =<< async a

runBrokerDaemon :: MVar () -> IO ()
runBrokerDaemon _ =
    forkThread $ do
        infoM "Daemons.runBrokerDaemon" "Broker daemon started"
        runZMQ $ do
            -- Writer proxy.
            forkThreadZMQ $ startProxy
                (Router,"tcp://*:5560") (Dealer,"tcp://*:5561") "tcp://*:5000"

            -- Reader proxy.
            forkThreadZMQ $ startProxy
                (Router,"tcp://*:5570") (Dealer,"tcp://*:5571") "tcp://*:5001"

            -- Contents proxy.
            forkThreadZMQ $ startProxy
                (Router,"tcp://*:5580") (Dealer,"tcp://*:5581") "tcp://*:5002"

runReaderDaemon :: String -> String -> String -> MVar () -> IO ()
runReaderDaemon pool user broker shutdown =
    forkThread $ do
        infoM "Daemons.runReaderDaemon" "Reader daemon started"
        startReader ("tcp://" ++ broker ++ ":5571")
                (Just $ S.pack user)
                (S.pack pool)
                shutdown

runWriterDaemon :: String -> String -> String -> Word64 -> MVar () -> IO ()
runWriterDaemon pool user broker bucket_size shutdown =
    forkThread $ do
        infoM "Daemons.runWriterDaemon" "Writer daemon started"
        startWriter ("tcp://" ++ broker ++ ":5561")
                (Just $ S.pack user)
                (S.pack pool)
                bucket_size
                shutdown

runContentsDaemon :: String -> String -> String -> MVar () -> IO ()
runContentsDaemon pool user broker shutdown =
    forkThread $ do
        infoM "Daemons.runContentsDaemon" "Contents daemon started"
        startContents ("tcp://" ++ broker ++ ":5581")
                (Just $ S.pack user)
                (S.pack pool)
                shutdown

