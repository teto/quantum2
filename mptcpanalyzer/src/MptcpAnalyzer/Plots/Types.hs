{-
Module:  MptcpAnalyzer.Plots.Types
Description :
Maintainer  : matt
Portability : Linux

Trying to come up with a userspace abstraction for MPTCP path management

-}
module MptcpAnalyzer.Plots.Types (
  PlotSettings(..)
  , ArgsPlots(..)
  , LivePlotTcpSettings(..)
)
where

import Data.Word (Word32)
import MptcpAnalyzer.ArtificialFields
import MptcpAnalyzer.Stream
import MptcpAnalyzer.Types
import Net.IP
import Net.Tcp
import Net.Stream

-- | Settings shared by all plots
data PlotSettings = PlotSettings {
  -- | Where to save the file
  plsOut :: Maybe String
  -- | To override the default title
  , plsTitle :: Maybe String
  -- | Whether to display the result
  , plsDisplay :: Bool
  -- , ploLabelx :: String
  -- , ploLabely :: String
  , plsMptcp :: Bool -- ^ True if it's an mptcp plot (as opposed to TCP)
  }
      -- parser.add_argument('--display', action="store", default="term", choices=["term", "gui", "no"],

data LivePlotTcpSettings = LivePlotTcpSettings {
    lvsFilter :: TcpConnection   -- ^the connection to filter
  , lvsTestPcap :: (Maybe FilePath) -- ^a pcap file used to test, when set, ignore interface name
  , lvsDestination :: (Maybe ConnectionRole) -- % to filter destination
  , lvsIfName :: String -- ^Interface name
}

-- | The list of possible plots
data ArgsPlots =

    -- actually valid for MPTCP too
    -- | Expects a filename/streamId attr and maybe destination
    ArgsPlotTcpAttr
        FilePath -- ^ The pcap file to load
        Word32
        String   -- ^ The parameter to plot (e.g., "seq", "ack")
        (Maybe ConnectionRole)
    -- |
    -- @pcap1 pcap2 stream1 stream2 destinations whether its tcp or mptcp
    | ArgsPlotOwdTcp (PcapMapping Tcp) (Maybe ConnectionRole)
    | ArgsPlotOwdMptcp (PcapMapping Mptcp) (Maybe ConnectionRole)
    -- Maybe filename
    -- TODO use LivePlotTcpSettings instead ?
    | ArgsPlotLiveTcp LivePlotTcpSettings
    | ArgsPlotLiveMptcp LivePlotTcpSettings
