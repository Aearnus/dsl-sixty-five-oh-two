{-# LANGUAGE TemplateHaskell #-}

module SixtyFiveOhTwo.Instruction where
    
import Control.Monad.State
import qualified Data.ByteString as B
import qualified Data.Map.Strict as M
import Control.Lens
import Data.Word

data InstructionState = InstructionState {
    -- The functionTable relates functions to their byte offsets in the compiled code
    _functionTable :: M.Map String Int,
    _bytestring :: B.ByteString
} deriving Show
makeLenses ''InstructionState
emptyState :: InstructionState
emptyState = InstructionState { _functionTable = M.empty, _bytestring = B.empty }

type Instruction = State InstructionState InstructionState

-- Remember, it's little endian
data AddressingMode = 
    Implied | 
    Accumulator | 
    Immediate Word8 | 
    Relative Word8 | -- Signed
    Absolute Word16 | 
    AbsoluteX Word16 | 
    AbsoluteY Word16 | 
    ZeroPage Word8 | 
    ZeroPageX Word8 | 
    ZeroPageY Word8 | 
    ZeroPageIndirect Word8 | 
    Indirect Word16 | 
    IndirectX Word8 | 
    IndirectY Word8

appendBytes :: [Word8] -> InstructionState -> InstructionState
appendBytes bytes insState = over bytestring (\bs -> B.append bs (B.pack bytes)) insState

define :: String -> Instruction -> Instruction
define name definition = do
    insState <- get
    let insState' = over functionTable (\fT -> M.insert name (B.length $ insState ^. bytestring) fT) insState
    -- TODO: COMBINE THE FUNCTION DEFINITIONS HERE TOO NOT JUST BYTESTRINGS
    return $ execState definition insState'

adc :: AddressingMode -> Instruction
adc (Immediate b) = do
    insState <- get
    return $ appendBytes [0x69, b] insState
adc (ZeroPage b) = do
    insState <- get
    return $ appendBytes [0x65, b] insState
adc (ZeroPageX b) = do
    insState <- get
    return $ appendBytes [0x75, b] insState