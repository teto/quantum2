{-# LANGUAGE ForeignFunctionInterface #-}
{-|
Module      : Net.Mptcp.Constants
Description : A module to bridge the haskell code to underlying C code

I consider this module internal.
The documentation may be a bit sparse.
Inspired by:
https://stackoverflow.com/questions/6689969/how-does-one-interface-with-a-c-enum-using-haskell-and-ffi

TODO might be best to just use the netlink script and adapt it
https://github.com/Ongy/netlink-hs/issues/7
-}
module Net.Mptcp.Constants_v1 (
  MptcpAttr(..)
  , MptcpGenlEvent(..)

  , mptcpGenlVer
  , mptcpGenlName
  , mptcpGenlCmdGrpName
  , mptcpGenlEvGrpName
)
where

import Data.Word (Word8)
-- import System.Linux.Netlink.Constants (MessageType)
import Data.Bits ()

-- from include/uapi/linux/mptcp.h
#include <linux/mptcp_v1.h>

-- {underscoreToCase}
-- add prefix = "e"
{#enum MPTCP_PM_ATTR_UNSPEC as MptcpAttr {} omit (__MPTCP_PM_ATTR_MAX) deriving (Eq, Show, Ord)#}

-- {underscoreToCase}
-- v1 merged events and commands while v1 distinguishes between the two !
{#enum MPTCP_PM_CMD_UNSPEC as MptcpGenlEvent {} omit (	__MPTCP_PM_CMD_AFTER_LAST) deriving (Eq, Show)#}

-- #define MPTCP_PM_NAME		"mptcp_pm"
-- #define MPTCP_PM_CMD_GRP_NAME	"mptcp_pm_cmds"
-- #define MPTCP_PM_EV_GRP_NAME	"mptcp_pm_events"
-- #define MPTCP_PM_VER		0x1

-- |Generic netlink MPTCP version
mptcpGenlVer :: Word8
mptcpGenlVer = {#const MPTCP_PM_VER #}

mptcpGenlName :: String
mptcpGenlName = {#const MPTCP_PM_NAME #}
mptcpGenlCmdGrpName :: String
mptcpGenlCmdGrpName = {#const MPTCP_PM_CMD_GRP_NAME #}
mptcpGenlEvGrpName :: String
mptcpGenlEvGrpName  = {#const MPTCP_PM_EV_GRP_NAME #}
