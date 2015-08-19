{-
 - A Set of types to describe Events that can be displayed within edenTv
 -}
{-# LANGUAGE TemplateHaskell #-}

module Bachelor.Types where

import Control.Lens
import qualified Data.HashMap.Strict as M
import Data.Word
import GHC.RTS.Events (ThreadId, MachineId, ProcessId, Timestamp)
-- The GUIEvent type describes events that can be displayed within the
-- edentv GUI. All of these have a specified starting time and duration
-- | describes the current state of the RTS at the current moment in time

type Time = Word64

type ProcessState = (RunState, Timestamp, [ThreadId])
type MachineState = (RunState, Timestamp, [ProcessId])
type ThreadState  = (RunState, Timestamp)

type ThreadMap    = M.HashMap ThreadId ThreadState
type ProcessMap   = M.HashMap ProcessId ProcessState
type MachineMap   = M.HashMap MachineId MachineState

data RunState = Idle | Running | Blocked | Runnable
    deriving (Show, Eq)


data RTSState = RTSState {
    machineMap :: MachineMap,
    processMap :: ProcessMap,
    threadMap  :: ThreadMap
    }

data MtpType = Machine MachineId | Process ProcessId | Thread ThreadId deriving Show

startingState :: RTSState
startingState = RTSState M.empty M.empty M.empty

{- auxiliary functions for manipulation RTSState -}

--returns a list of blocked Processes
--a Process is blocked when all its threads are blocked
processesBlocked :: RTSState -> [ProcessId]
processesBlocked rts =
    map fst $ M.toList $ M.filter
        (\(_,_,threads) -> threadsInState rts Blocked threads) (processMap rts)

--given a list of threads, returns wether they are in RunState state.
threadsInState :: RTSState -> RunState -> [ThreadId] -> Bool
threadsInState rts state threads =
    all (threadInState rts state) threads

--given a list of threads, returns wether at least one of them is in RunState
--state.
oneThreadInState :: RTSState -> RunState -> [ThreadId] -> Bool
oneThreadInState rts state threads =
    any (threadInState rts state) threads

threadInState :: RTSState -> RunState -> ThreadId -> Bool
threadInState rts state tid = case (threadMap rts) M.! tid of
            (state,_) -> True
            _ -> False

-- okay, now we can make the adjustments, that a single change can make to
-- the RTSState.
-- when the state of a thread has been changed, check the processes need to
-- be changed.

-- The Timestamp is the stamp of the most current event.
adjustProcessState :: RTSState -> Timestamp ->  RTSState
adjustProcessState rts ts =
    rts {
        processMap = M.map (adjustSingleProcess rts) (processMap rts)
        }

adjustSingleProcess :: RTSState -> ProcessState -> ProcessState
adjustSingleProcess rts pstate@(state,ts,threads)
    -- if at least one thread is running, this process is running.
    | oneThreadInState rts Running  threads = (Running,ts,threads)
    -- if at least one process is runnable, this thread is runnable.
    | oneThreadInState rts Runnable threads = (Runnable,ts,threads)
    -- if all threads are Blocked, the process is Blocked.
    | threadsInState   rts Blocked  threads = (Blocked,ts,threads)
    -- otherwise, keep the state
    | otherwise                             = pstate

{- Types for events that can be written to the database. -}
data GUIEvent = GUIEvent{
    mtpType   :: MtpType,
    startTime :: Word64,
    duration  :: Word64,
    state     :: RunState
    } | AssignTtoP ThreadId ProcessId | AssignPtoM ProcessId MachineId

--  | The Interface for reading/writing the data from disk.
class IOEventData a where
    readEvent  :: IOEventData a => a
        -> Integer -- ^ start time (in ns)
        -> Integer -- ^ end time (in ns)
        -> Integer -- ^ resolution (in ns). States smaller than this will not
                   -- be retreived from disk.
        -> IO [GUIEvent]
    -- | writes a single Event to Disk
    writeEvent :: IOEventData a => a -> GUIEvent -> IO()

{- auxiliary functions for detecting wether the state has changed, and
 - which events need to be written out to the database -}

generateGUIEvents :: RTSState -> RTSState -> [GUIEvent]
generateGUIEvents oldRts newRts = undefined

