{-
Module:  Net.Mptcp.LogStats
Description :
Maintainer  : matt
Portability : Linux

Trying to come up with a userspace abstraction for MPTCP path management

-}

module Net.MpTcp.LogStats (
  logStatistics
)
where

import FilePath
{- Logs to a json file the results of sockDiag
  -}
logStatistics :: FilePath
              -> Natural             -- ^ Current delay
              -> MptcpConnection
              -> [SockDiagMetrics]
              -> IO ()
logStatistics filename delay mptcpConn metrics = do
    let jsonConn = (toJSON mptcpConn)
    let merged = lodashMerge jsonConn (object [
          "delay" .= delay,
          "subflows" .= metrics
          ])

    let jsonBs = encodePretty merged
    let subflowCount = length $ subflows mptcpConn
    infoM "main" $ "Saving to " ++ filename

    -- throws in case of error
    Data.ByteString.Lazy.writeFile filename jsonBs
