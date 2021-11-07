{-|
Description : Mptcpanalyzer
Maintainer  : matt

 accepts as input(s) capture file(s) (\*.pcap) and depending on from there can :

* list the MPTCP connections in the pcap
* display some statistics on a specific MPTCP connection (list of subflows etc...);
* convert packet capture files (\*.pcap) to \*.csv files
* plot data sequence numbers for all subflows
* `XDG compliance <http://standards.freedesktop.org/basedir-spec/basedir-spec-latest.html>`_, i.e., 
  |prog| looks for files in certain directories. will try to load your configuration from `$XDG_CONFIG_HOME/mptcpanalyzer/config`
* caching mechanism: mptcpanalyzer compares your pcap creation time and will
  regenerate the cache if it exists in `$XDG_CACHE_HOME/mptcpanalyzer/<path_to_the_file>`
* support 3rd party plugins (plots or commands)

Most commands are self documented and/or with autocompletion.

Then you have an interpreter with autocompletion that can generate & display plots such as the following:

![Data Sequence Number (DSN) per subflow plot](examples/dsn.png)


How to associate an MP_JOIN to its MPTCP connection ?

See https://tools.ietf.org/html/draft-ietf-mptcp-rfc6824bis-02#page-40 for mor details:


   The token is used to identify the MPTCP connection and is a
   cryptographic hash of the receiver's key, as exchanged in the initial
   MP_CAPABLE handshake (Section 3.1).  In this specification, the


   tokens presented in this option are generated by the SHA-1 ([4],
   [17]) algorithm, truncated to the most significant 32 bits.  The
   token included in the MP_JOIN option is the token that the receiver
   of the packet uses to identify this connection; i.e., Host A will
   send Token-B (which is generated from Key-B).  Note that the hash
   generation algorithm can be overridden by the choice of cryptographic
   handshake algorithm, as defined in Section 3.1.

              Host A                                  Host B
     ------------------------                       ----------
     Address A1    Address A2                       Address B1
     ----------    ----------                       ----------
         |             |                                |
         |            SYN + MP_CAPABLE(Key-A)           |
         |--------------------------------------------->|
         |<---------------------------------------------|
         |          SYN/ACK + MP_CAPABLE(Key-B)         |
         |             |                                |
         |        ACK + MP_CAPABLE(Key-A, Key-B)        |
         |--------------------------------------------->|
         |             |                                |
         |             |   SYN + MP_JOIN(Token-B, R-A)  |
         |             |------------------------------->|
         |             |<-------------------------------|
         |             | SYN/ACK + MP_JOIN(HMAC-B, R-B) |
         |             |                                |
         |             |     ACK + MP_JOIN(HMAC-A)      |
         |             |------------------------------->|
         |             |<-------------------------------|
         |             |             ACK                |

   HMAC-A = HMAC(Key=(Key-A+Key-B), Msg=(R-A+R-B))
   HMAC-B = HMAC(Key=(Key-B+Key-A), Msg=(R-B+R-A))
    


      Host A                                  Host B
      ------                                  ------
      MP_JOIN               ->
      [B's token, A's nonce,
       A's Address ID, flags]
                            <-                MP_JOIN
                                              [B's HMAC, B's nonce,
                                               B's Address ID, flags]
      ACK + MP_JOIN         ->
      [A's HMAC]

                            <-                ACK


Introduction

* list the MPTCP connections in the pcap
* display some statistics on a specific MPTCP connection (list of subflows etc...);
* convert packet capture files (\*.pcap) to \*.csv files
* plot data sequence numbers for all subflows
* `XDG compliance <http://standards.freedesktop.org/basedir-spec/basedir-spec-latest.html>`_, i.e., 
  |prog| looks for files in certain directories. will try to load your configuration from `$XDG_CONFIG_HOME/mptcpanalyzer/config`
* caching mechanism: mptcpanalyzer compares your pcap creation time and will
  regenerate the cache if it exists in `$XDG_CACHE_HOME/mptcpanalyzer/<path_to_the_file>`
* support 3rd party plugins (plots or commands)

Most commands are self documented and/or with autocompletion.

Then you have an interpreter with autocompletion that can generate & display plots such as the following:

![Data Sequence Number (DSN) per subflow plot](examples/dsn.png)

* How to use

This package installs 2 programs:
- *mptcpanalyzer* to get details on a loaded pcap.
  
  
mptcpanalyzer can run into 3 modes:
  1. :ref:`interactive-mode` (default): an interpreter with some basic completion will accept your commands. 
  2. :ref:`batch-mode` if a filename is passed as argument, it will load commands from this file.
  3. :ref:`oneshot`, it will consider the unknow arguments as one command, the same that could be used interactively

For example, we can load an mptcp pcap (I made one available on `wireshark wiki 
<https://wiki.wireshark.org/SampleCaptures#MPTCP>`_ or in this repository, in the _examples_ folder).

It expects a trace to work with. If the trace has the form *XXX.pcap* extension, the script will look for its csv counterpart *XXX.pcap.csv*. The program will tell you what arguments are needed. Then you can open the generated graphs.



-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE UndecidableInstances       #-}
{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE KindSignatures             #-}
{-# LANGUAGE LambdaCase             #-}

module Main where

import MptcpAnalyzer.Cache
import MptcpAnalyzer.Types
import MptcpAnalyzer.Stream
import MptcpAnalyzer.ArtificialFields
import MptcpAnalyzer.Commands
import MptcpAnalyzer.Commands.Definitions as CMD
import MptcpAnalyzer.Commands.List as CLI
import MptcpAnalyzer.Commands.ListMptcp as CLI
import MptcpAnalyzer.Commands.Export as CLI
import MptcpAnalyzer.Commands.Map as CLI
import MptcpAnalyzer.Commands.Reinjections as CLI
import MptcpAnalyzer.Merge
import qualified MptcpAnalyzer.Commands.Plot as Plots
import qualified MptcpAnalyzer.Commands.PlotOWD as Plots
import MptcpAnalyzer.Plots.Types
-- import qualified MptcpAnalyzer.Plots.Owd as Plots
import qualified MptcpAnalyzer.Commands.Load as CL
-- import Control.Monad (void)
import Tshark.Interfaces
import Tshark.Live
import MptcpAnalyzer.Pcap (defaultParserOptions)
import MptcpAnalyzer.Utils.Completion
import Tshark.Main (generateCsvCommand, defaultTsharkPrefs, defaultTsharkOptions, tsharkReadFilter, genReadFilterFromTcpConnection)


import Polysemy (Sem, Members, runFinal, Final)
import qualified Polysemy as P
import qualified Polysemy.IO as P
import qualified Polysemy.State as P
import qualified Polysemy.Embed as P
import qualified Polysemy.Internal as P
import qualified Polysemy.Trace as P
import Polysemy.Log (Log)
import qualified Polysemy.Log as Log
import Polysemy.Log.Colog (interpretLogStdout)
import Polysemy.Trace (trace)
import System.FilePath
import System.Directory
import Prelude hiding (concat, init, log)
import Options.Applicative
import Options.Applicative.Common
import Options.Applicative.Help (parserHelp)
-- import Colog.Actions
import Graphics.Rendering.Chart.Backend.Cairo (toFile,
    renderableToFile, FileOptions(..), FileFormat(..))
import Graphics.Rendering.Chart.Renderable    (toRenderable)
-- import           Graphics.Rendering.Chart.Easy          hiding (argument)
import Graphics.Rendering.Chart.Layout (layout_title)
import qualified Data.Map                       as Map


-- for noCompletion
        -- <> Options.Applicative.value "/tmp"
-- import System.Posix.Signals -- installHandler
import Control.Monad.State.Lazy        (State, StateT, execStateT, get, put)
import System.Console.Haskeline
import System.Console.ANSI
import Control.Lens ((^.), view)
import System.Exit
import Pipes hiding (Proxy)
import System.Process hiding (runCommand)
import Distribution.Simple.Utils (withTempFileEx)
import Distribution.Compat.Internal.TempFile (openTempFile)
import MptcpAnalyzer.Loader
import Data.Maybe (fromMaybe, catMaybes)
import Data.Either (fromLeft)
import Data.Foldable (forM_)
import Frames.InCore (toFrame)
import Frames.CSV (writeDSV)
import Frames (recMaybe, Frame, Record)
import Frames as F
-- withOpenFile
-- withOpenFile
import System.IO (openFile, stderr, stdout)
import Tshark.Fields (baseFields, TsharkFieldDesc (tfieldFullname))
import GHC.IO.Handle
import GHC.Conc (forkIO)
import Data.List (isPrefixOf)
import Options.Applicative.Types
import Options.Applicative.Builder (allPositional)
import Debug.Trace (traceShowId)

data CLIArguments = CLIArguments {
  _input :: Maybe FilePath
  , version    :: Bool  -- ^ to show version
  , cacheDir    :: Maybe FilePath -- ^ Folder where to log files
  , logLevel :: Log.Severity   -- ^ what level to use to parse
  , extraCommands :: [String]  -- ^ commands to run on start
  }


defaultImageOptions :: FileOptions
defaultImageOptions = FileOptions (800,600) PNG

loggerName :: String
loggerName = "main"

deriving instance Read Log.Severity

    -- <*> commandGroup "Loader commands"
    -- <> command "load-csv" CL.piLoadCsv

startupParser :: Parser CLIArguments
startupParser = CLIArguments
      <$> optional ( strOption
          ( long "load"
          <> short 'l'
         <> help "Either a pcap or a csv file (in good format).\
                 \When a pcap is passed, mptcpanalyzer will look for a its cached csv.\
                 \If it can't find one (or with the flag --regen), it will generate a \
                 \csv from the pcap with the external tshark program."
         <> metavar "INPUT_FILE" ))
      <*> switch (
          long "version"
          <> help "Show version"
          )
      <*> optional ( strOption
          ( long "cachedir"
         <> help "mptcpanalyzer creates a cache of files in the folder \
            \$XDG_CACHE_HOME/mptcpanalyzer"
         -- <> showDefault
         -- <> Options.Applicative.value "/tmp"
         <> metavar "CACHEDIR" ))
      <*> option auto
          ( long "log-level"
         <> help "Log level"
         <> showDefault
         <> Options.Applicative.value Log.Info
         <> metavar "LOG_LEVEL" )
      -- optional arguments
      <*> many ( argument str (
            metavar "COMMANDS..."
        ))


opts :: ParserInfo CLIArguments
opts = info (startupParser <**> helper)
  ( fullDesc
  <> progDesc "Tool to provide insight in MPTCP (Multipath Transmission Control Protocol)\
              \performance via the generation of stats & plots"
  <> header "Type 'help' or '?' to list the available commands"
  -- <> footer "You can report issues/contribute at https://github.com/teto/mptcpanalyzer"
  )


-- https://github.com/sdiehl/repline/issues/32

-- just for testing, to remove afterwards
defaultPcap :: FilePath
defaultPcap = "examples/client_2_filtered.pcapng"

        -- P.modify (\s -> s { _prompt = pcapFilename ++ "> ",
        --       _loadedFile = Just frame
        --     })
finalizePrompt :: String -> String
finalizePrompt newPrompt = setSGRCode [SetColor Foreground Vivid Red] ++ newPrompt ++ "> " ++ setSGRCode [Reset]

-- alternatively could modify defaultPrefs
-- subparserInline + multiSuffix helpShowGlobals
defaultParserPrefs :: ParserPrefs
defaultParserPrefs = (prefs $ showHelpOnEmpty <> showHelpOnError)
              {
                prefBacktrack = NoBacktrack
                }


-- default if complete = completeFilename,
-- (String, String) -> m (String, [Completion])
customCompleteFunc :: CompletionFunc IO
customCompleteFunc = completeFilename
-- customCompleteFunc _i = return ("toto", [ Completion "toInsert" "choice 1" False ])

-- debugParser :: ArgumentReachability -> Option x -> String
-- debugParser reachability opt = case optMain opt of
--       OptReader ns _ _ -> "optreader"
--       FlagReader ns _ -> "flagReader"
--       ArgReader rdr -> "argreader"
--          -- >>= \x -> return $ Completion x "argreader help" True
--       CmdReader _ ns p -> "cmdreader"


{-

Dont display anything before the call to execParser otherwise it gets printed in
the different shell completion scripts
-}
main :: IO ()
main = do

  cacheFolderXdg <- getXdgDirectory XdgCache "mptcpanalyzer2"
  -- Create cache if doesn't exist
  doesDirectoryExist cacheFolderXdg >>= \case
      -- TODO log it instead
      -- putStrLn ("cache folder already exists" ++ show cacheFolderXdg)
      True -> return ()
      False -> createDirectory cacheFolderXdg

  let myState = MyState {
    _stateCacheFolder = cacheFolderXdg,
    _loadedFile = Nothing,
    _prompt = finalizePrompt ">"
  }

  options <- execParser opts

  putStrLn "Commands:"
  print $ extraCommands options

  -- let out = mapParser debugParser mainParser
  -- putStrLn $ "out=" ++ show  out

  let haskelineSettings = (Settings {
      -- complete = customCompleteFunc
      -- TODO test with loadPcapArgs instead
      -- complete = customHaskelineParser defaultParserPrefs mainParserInfo
      complete = generateHaskelineCompleterFromParserInfo defaultParserPrefs mainParserInfo
      -- piLoadCsv
        -- piLoadPcapOpts
      , historyFile = Just $ cacheFolderXdg </> "history"
      , autoAddHistory = True
      })
  let
    cacheConfig :: CacheConfig
    cacheConfig = CacheConfig {
      cacheFolder = cacheFolderXdg
      , cacheEnabled = True
    }

  _ <- runInputT haskelineSettings $
          runFinal @(InputT IO)
          $ P.embedToFinal . P.runEmbedded lift
          $ P.traceToStdout
          $ P.runState myState
          $ runCache cacheConfig
          $ interpretLogStdout
            (inputLoop (extraCommands options))

      -- -- Set the level of logging we want (for more control see 'filterLogs')
      -- & setLogLevel Debug
  return ()


-- TODO move


piListInterfaces :: ParserInfo CommandArgs
piListInterfaces = info (pure ArgsListInterfaces)
  ( fullDesc
  <> progDesc "List interfaces as seen by tshark"
  <> footer "Example: load-pcap examples/client_2_filtered.pcapng"
  <> forwardOptions
  )

-- |Global parser: contains every available command
-- TODO for some commands we could factorize the preprocessing eg check a file
-- was pre-loaded
-- aka check the if loadedFile was loaded
-- one can create groups with <|> subparser
mainParser :: Parser CommandArgs
mainParser = subparser (
    commandGroup "Generic"
    -- <> command "help" helpParser
    <> command "quit" quit
    -- <> commandGroup "Loader commands"
    <> command "load-csv" CL.piLoadCsv
    <> command "load-pcap" CL.piLoadPcapOpts
    <> commandGroup "TCP commands"
    <> command "tcp-summary" CLI.piTcpSummaryOpts
    <> command "mptcp-summary" CLI.piMptcpSummaryOpts
    <> command "list-tcp" CLI.piListTcpOpts
    <> command "map-tcp" CLI.mapTcpOpts
    <> command "map-mptcp" CLI.mapMptcpOpts
    <> commandGroup "MPTCP commands"
    <> command "list-reinjections" CLI.piListReinjections
    <> command "list-mptcp" CLI.piListMpTcpOpts
    <> command "list-interfaces" piListInterfaces
    <> command "export" CLI.piExportOpts
    <> command "analyze" CLI.piQualifyReinjections
    <> commandGroup "TCP plots"
    -- TODO here we should pass a subparser
    -- <> subparser (
    -- Main.piParserGeneric
    <> command "plot-tcp" ( info Plots.parserPlotTcpMain (progDesc "Plot One-Way-Delays (also called One-Time-Trips)"))
    <> command "plot-mptcp" ( info Plots.parserPlotMptcpMain (progDesc "Multipath-tcp plots"))
    <> command "plot-tcp-live" ( info Plots.parserPlotTcpLive (progDesc "Live plots"))
    )
    where
      helpParser = info (pure ArgsHelp) (progDesc "Display help")
      quit = info (pure ArgsQuit) (progDesc "Quit mptcpanalyzer")


-- |Main parser
mainParserInfo :: ParserInfo CommandArgs
-- mainParserInfo = info (mainParser <**> helper)
mainParserInfo = info mainParser
  ( fullDesc
  <> allPositional
  <> progDesc "Tool to provide insight in MPTCP (Multipath Transmission Control Protocol)\
              \performance via the generation of stats & plots"
  <> header "hello - a test for optparse-applicative"
  <> footer "You can report issues/contribute at https://github.com/teto/mptcpanalyzer"
  -- <> noIntersperse
  -- <> forwardOptions
  )


cmdListInterfaces :: (Members '[
  Log, Cache,
  P.Trace, P.State MyState,
  P.Embed IO
  ] r) => Sem r CMD.RetCode
cmdListInterfaces = do
  (exitCode, ifs) <- P.embed listInterfaces

  trace "Listing interfaces:"
  trace $ "ifs" ++ concatMap (\x -> x ++ "\n") ifs
  return CMD.Continue


runCommand :: (Members '[Log, Cache, P.Trace, P.State MyState, P.Embed IO] r)
  => CommandArgs -> Sem r CMD.RetCode
runCommand (ArgsLoadPcap fileToLoad) = loadPcap fileToLoad
  -- ret <- CL.loadPcap fileToLoad
  -- TODO modify only on success
  -- P.modify (\s -> s { _prompt = pcapFilename ++ "> ",
  --       _loadedFile = Just frame
  --     })
  -- return ret
runCommand (ArgsLoadCsv csvFile _) = CL.cmdLoadCsv csvFile
runCommand (ArgsParserSummary detailed streamId) = CLI.cmdTcpSummary streamId detailed
runCommand (ArgsMptcpSummary detailed streamId) = CLI.cmdMptcpSummary streamId detailed
runCommand (ArgsListSubflows detailed) = CLI.cmdListSubflows detailed
runCommand (ArgsListReinjections streamId)  = CLI.cmdListReinjections streamId
runCommand (ArgsListTcpConnections detailed) = CLI.cmdListTcpConnections detailed
runCommand (ArgsListMpTcpConnections detailed) = CLI.cmdListMptcpConnections detailed
runCommand ArgsListInterfaces = cmdListInterfaces
runCommand (ArgsExport out) = CLI.cmdExport out
runCommand (ArgsPlotGeneric plotSettings plotArgs) = runPlotCommand plotSettings plotArgs
runCommand (ArgsMapTcpConnections cmd False) = CLI.cmdMapTcpConnection cmd
runCommand (ArgsMapTcpConnections args True) = CLI.cmdMapMptcpConnection args
runCommand (ArgsQualifyReinjections mapping verbose) = CLI.cmdQualifyReinjections mapping [RoleServer] verbose
runCommand ArgsQuit = cmdQuit
runCommand ArgsHelp = cmdHelp

-- TODO move commands to their own module
-- TODO it should update the loadedFile in State !
-- handleParseResult
-- loadPcap :: CMD.CommandCb
-- loadPcap :: Members [Log, P.State MyState, Cache, Embed IO] m => [String] -> Sem m RetCode
loadPcap :: (Members '[Log, P.State MyState, Cache, P.Embed IO] r)
  => FilePath -- ^ File to load
  -> Sem r RetCode
loadPcap pcapFilename = do
    Log.info $ "loading pcap " <> tshow pcapFilename
    mFrame <- loadPcapIntoFrame defaultTsharkPrefs pcapFilename
    -- fmap onSuccess mFrame
    case mFrame of
      Left _ -> return CMD.Continue
      Right frame -> do
        P.modify (\s -> s {
            _prompt = finalizePrompt pcapFilename,
            _loadedFile = Just frame
          })
        Log.info "Frame loaded" >> return CMD.Continue

-- | Quits the program
cmdQuit :: Members '[P.Trace] r => Sem r CMD.RetCode
cmdQuit = trace "Thanks for flying with mptcpanalyzer" >> return CMD.Exit

-- | Prints the help when requested
cmdHelp :: Members '[P.Trace, P.State MyState] r => Sem r CMD.RetCode
cmdHelp = do
  -- TODO display help / use trace instead
  trace $ show $ parserHelp defaultParserPrefs mainParser
  return CMD.Continue

-- |Command specific to plots
-- TODO these should return a plot instead of a generated file so that one can overwrite the title
runPlotCommand :: (Members '[Log, Cache, P.Trace, P.State MyState, P.Embed IO] r)
  => PlotSettings -> ArgsPlots
  -> Sem r CMD.RetCode
runPlotCommand (PlotSettings mbOut _mbTitle displayPlot mptcpPlot) specificArgs = do
    (tempPath, handle) <- P.embed $ openTempFile "/tmp" "plot.png"
    _ <- case specificArgs of
      (ArgsPlotTcpAttr pcapFilename streamId attr mbDest) -> do
        let destinations = getDests mbDest
        Log.debug $ "MPTCP plot" <> tshow mptcpPlot

        res <- if mptcpPlot then do
              eFrame <- buildAFrameFromStreamIdMptcp defaultTsharkPrefs pcapFilename (StreamId streamId)
              case eFrame of
                Left err -> return $ CMD.Error err
                Right frame -> Plots.cmdPlotMptcpAttribute attr tempPath destinations frame

            else do
              eFrame <- buildAFrameFromStreamIdTcp defaultTsharkPrefs pcapFilename (StreamId streamId)
              case eFrame of
                Left err -> return $ CMD.Error err
                Right frame -> do
                  l <- Plots.cmdPlotTcpAttribute attr destinations frame
                  -- toRenderable
                  P.embed $ toFile defaultImageOptions tempPath l
                  -- embed $ void $ renderableToFile defaultImageOptions tempPath (toRenderable l)
                      -- layout_title .= "TCP " ++ attr
                      -- l
                  return CMD.Continue
        return res

      -- Destinations
      (ArgsPlotOwdTcp mapping dest) ->
        -- Log.info $ "plotting owd for tcp.stream " <> tshow streamId1 <> " and " <> tshow streamId2
        -- eframe1 <- buildAFrameFromStreamIdTcp defaultTsharkPrefs pcap1 streamId1
        -- eframe2 <- buildAFrameFromStreamIdTcp defaultTsharkPrefs pcap2 streamId2

        -- res <- case (eframe1, eframe2 ) of
        --   (Right (FrameTcp con frame1), Right aframe2) -> do
        --       -- TODO addTcpDest -> convert then
        --       let
        --         dest = genTcpDestFrame frame1 con

        --         convertCols' :: Record '[TcpDest] -> Record '[SenderDest]
        --         convertCols' = F.withNames . F.stripNames
        --         sendFrame = fmap convertCols' dest

        --       mergedRes <- mergeTcpConnectionsFromKnownStreams (FrameTcp con (F.zipFrames sendFrame frame1)) aframe2
        --       -- let mbRecs = map recMaybe mergedRes
        --       -- let justRecs = catMaybes mbRecs
        --       Plots.cmdPlotTcpOwd tempPath handle (getDests dest) (ffCon aframe1) mergedRes
        --   (Left err, _) -> return $ CMD.Error err
        --   (_, Left err) -> return $ CMD.Error err
        Plots.cmdPlotTcpOwd tempPath handle (getDests dest) mapping

      (ArgsPlotOwdMptcp (PcapMapping pcap1 streamId1 pcap2 streamId2) dest) -> do
        Log.info "plotting mptcp owd"
        eframe1 <- buildAFrameFromStreamIdMptcp defaultTsharkPrefs pcap1 streamId1
        eframe2 <- buildAFrameFromStreamIdMptcp defaultTsharkPrefs pcap2 streamId2

        case (eframe1, eframe2 ) of
          (Right aframe1, Right aframe2) -> do
              mergedRes <- mergeMptcpConnectionsFromKnownStreams aframe1 aframe2
              -- let mbRecs = map recMaybe mergedRes
              -- let justRecs = catMaybes mbRecs
              -- Plots.cmdPlotMptcpOwd tempPath handle (getDests dest) (ffCon aframe1) mergedRes
              error "not implemented"
          (Left err, _) -> return $ CMD.Error err
          (_, Left err) -> return $ CMD.Error err

      -- Starts livestatistics on a connection
      (ArgsPlotLiveTcp connectionFilter mbFake connectionRole ifname) -> do
        -- (exitCode, ifs) <- P.embed listInterfaces
        -- Here we would start a process and keep updating some metrics until we get a cancel signal ?
        -- case exitCode of
        --   ExitSuccess -> return $ CMD.Error "failed listing interfaces"
        --   _  -> return $ CMD.Error "failed listing interfaces"

        let
          fields = Map.elems $ Map.map tfieldFullname baseFields

          -- stats/packetCount/Frame
          -- keeping it light for now
          -- initialLiveStats = LiveStats mempty 0 (FrameTcp connectionFilter mempty)
          initialLiveStats = LiveStats mempty 0 mempty
          toLoad = case mbFake of
            Just filename -> Right filename
            Nothing -> Left ifname

          --capture-comment
          tsharkPrefs = defaultTsharkPrefs { 
            tsharkReadFilter = Just $ genReadFilterFromTcpConnection connectionFilter Nothing
            }
          (RawCommand bin genArgs) = generateCsvCommand fields toLoad tsharkPrefs
          -- args = genArgs ++ ["--capture-comment='Generated by mptcpanalyzer'"]
          args = genArgs ++ [ "-l"]
          createProc :: CreateProcess
          createProc = (proc bin args) {
                std_err = CreatePipe
                -- Inherit,
                , std_out = CreatePipe
                -- lets the child handle Ctrl-c
                , delegate_ctlc = True
              }

        
        trace $ "Command run: " ++ show (RawCommand bin args)
        trace $ "Command run: " ++ showCommandForUser bin args
        -- Log.info $ "Starting " <> tshow bin <> tshow args
        _ <- P.embed $ startLivePlot initialLiveStats createProc

        return CMD.Continue

    P.embed $ forM_ mbOut (renameFile tempPath)
    -- _ <- P.embed $ case mbOut of
    --         -- user specified a file move the file
    --         Just outFilename -> renameFile tempPath outFilename
    --         Nothing -> return ()
    if displayPlot then do
        let
          createProc :: CreateProcess
          -- for some reason it recognizes the image as application/octet-stream
          -- and I can't manage to make it use my image/png application
          -- createProc = proc "xdg-open" [ tempPath ]
          createProc = (proc "sxiv" [ tempPath ]) {
              delegate_ctlc = True 
              }

        Log.info $ "Launching " <> tshow createProc
        (_, _, mbHerr, ph) <- P.embed $ createProcess createProc
        exitCode <- P.embed $ waitForProcess ph
        return Continue

    else
      return Continue
    where
      getDests mbDest = maybe [RoleClient, RoleServer] (: []) mbDest


startLivePlot :: LiveStats -> CreateProcess -> IO ()
-- startLivePlot createProc = do
--   -- hSetBuffering tmpFileHandle LineBuffering
--   -- hSeek tmpFileHandle AbsoluteSeek 0 >> T.hPutStrLn tmpFileHandle fieldHeader
--   -- mb_stdin_hdl, mb_stdout_hdl, mb_stderr_hdl, ph
--   (_, Just hout, Just herr, ph) <-  createProcess_ "error" createProc
--   -- threadId <- forkIO $
--   readTsharkOutputAndPlotIt hout herr
--   exitCode <- waitForProcess ph
--   case exitCode of
--     ExitSuccess -> putStrLn "Success"
--     _  -> do 
--       hGetContents herr >>= putStrLn
--   pure ()
startLivePlot initialLiveStats createProc = do
  -- withCreateProcess
  (_, Just hout, Just herr, ph) <-  createProcess_ "error when creating process" createProc
  -- Just hout
  -- let stdout = System.IO.stdout
  hSetBuffering stdout NoBuffering
  putStrLn $ " hout " ++ show hout
  putStrLn $ " stdout " ++ show stdout
  -- hSetBuffering hout NoBuffering
  -- non blocking
  exitCode <- getProcessExitCode ph
  case exitCode of
    Just code -> putStrLn "Finished"
    _ -> do
      -- LineBuffering
      hSetBuffering hout NoBuffering
      hSetBuffering herr NoBuffering
      putStrLn $ "Live stats (before): " ++ show (lsPackets initialLiveStats)
      liveStats <- execStateT (runEffect (tsharkLoop hout)) initialLiveStats 
      -- liveStats <- runEffect (tsharkLoop hout)
      -- putStrLn $ "Live stats (after): " ++ show (lsPackets liveStats)
      -- blocking
      exitCode2 <- waitForProcess ph
      case exitCode2 of
        ExitSuccess -> putStrLn "Success"
        _  -> do
          putStrLn "hGetContents"
          hGetContents herr >>= putStrLn
  putStrLn $ "final exitCode"

  -- pure ()

-- TODO use genericRunCommand
runIteration :: (Members '[Log, Cache, P.Trace, P.State MyState, P.Embed IO] r)
  => Maybe String
  -> Sem r CMD.RetCode
runIteration fullCmd = do
    cmdCode <- case fmap Prelude.words fullCmd of
        Nothing -> do
          trace "please enter a valid command, see help"
          return CMD.Continue
        Just args -> do
          -- TODO parse
          Log.info $ "Running " <> tshow args
          let parserResult = execParserPure defaultParserPrefs mainParserInfo args
          case parserResult of
            -- Failure (ParserFailure ParserHelp)
            (Failure failure) -> do
                -- last arg is progname
                let (h, exit) = renderFailure failure ""
                -- Log.debug h
                P.trace h
                Log.debug $ "Exit code " <> tshow exit
                Log.debug $ "Passed args " <> tshow args
                return $ case exit of
                    ExitSuccess -> CMD.Continue
                    ExitFailure _exitCode -> CMD.Error $ "could not parse: " ++ show failure
            (CompletionInvoked _compl) -> return CMD.Continue
            (Success parsedArgs) -> runCommand parsedArgs

    case cmdCode of
        CMD.Exit -> P.trace "Exiting" >> return CMD.Exit
        CMD.Error msg -> do
          P.trace $ "CmdCode: Last command failed with message:\n" ++ show msg
          return $ CMD.Error msg
        behavior -> return behavior

-- | Main loop of the program, will run commands in turn
inputLoop :: (Members '[Log , Cache, P.Trace, P.State MyState, P.Embed IO, P.Final (InputT IO)] r)
    => [String] -> Sem r ()
inputLoop = go
  where
    go :: (Members '[Log, Cache, P.Trace, P.State MyState, P.Embed IO, P.Final (InputT IO)] r)
      => [String] -> Sem r ()
    go (xs:rest) = runIteration (Just xs) >>= \case
        CMD.Exit -> trace "Exiting"
        _ -> do
          inputLoop rest
    go [] = do
      s <- P.get
      minput <- P.embedFinal $ getInputLine (view prompt s)
      runIteration minput >>= \case
        CMD.Exit -> trace "Exiting"
        -- _ -> pure ()
        _ -> inputLoop []

