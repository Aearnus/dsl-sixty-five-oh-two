{-# LANGUAGE TemplateHaskell #-}

module DSL.SixtyFiveOhTwo where

import Control.Monad.State
import qualified Data.ByteString as B
import qualified Data.Map.Strict as M
import Control.Lens
import Data.Word
import Data.Int
import Data.Bits

data InstructionState = InstructionState {
    -- The functionTable relates functions to their byte offsets in the compiled code
    _functionTable :: M.Map String Int,
    _bytestring :: B.ByteString
} deriving Show
makeLenses ''InstructionState

emptyState :: InstructionState
emptyState = InstructionState { _functionTable = M.empty, _bytestring = B.empty }

type Instruction = State InstructionState ()

-- This function converts the instructions into a usable bytestring. It's the meat and bones of this DSL.
runInstructions :: Instruction -> B.ByteString
runInstructions ins = (execState ins emptyState) ^. bytestring

-- Remember, it's little endian
data AddressingMode =
    Implied |
    Accumulator |
    Immediate Word8 |
    Relative Int8 | -- Signed
    ZeroPageRelative Int8 | -- Signed
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

splitW16 :: Word16 -> (Word8, Word8)
splitW16 w = (lo, hi) -- Little endian
    where
        hi = fromIntegral $ w `shiftR` 8
        lo = fromIntegral w

appendBytes :: [Word8] -> InstructionState -> InstructionState
appendBytes bytes insState = over bytestring (\bs -> B.append bs (B.pack bytes)) insState

appendBytesThenWord :: [Word8] -> Word16 -> InstructionState -> InstructionState
appendBytesThenWord bytes word insState = over bytestring (\bs -> B.append bs (B.pack totalBytes)) insState
    where
        (lowByte, highByte) = splitW16 word
        totalBytes = concat [bytes, [lowByte], [highByte]]

-- This function allows you to define an instruction opcode that takes no argument
genericNoByteOp :: Word8 -> Instruction
genericNoByteOp op = modify $ appendBytes [op]

-- This function allows you to define an instruction opcode that takes a one byte argument
-- This is polymorphic to support Int8 OR Word8
genericOp :: (FiniteBits a, Integral a) => Word8 -> a -> Instruction
-- fromIntegral from an IntN to a WordN does _not_ preserve value, only structure
-- Thus, this is valid code.
genericOp op arg = modify $ appendBytes [op, fromIntegral arg]

--  This function allows you to define an instruction opcode that takes a two byte argument
genericTwoByteOp :: Word8 -> Word16 -> Instruction
genericTwoByteOp op arg = modify $ appendBytesThenWord [op] arg

-- This allows you to define subroutines which can be called later using `call`.
-- NOTE: your function must end with an `rts`. This is not added implicitly to
-- be able to use this function to create branching case statements or the like.
define :: String -> Instruction -> Instruction
define name definition = do
    insState <- get
    let functionOffset = B.length $ insState ^. bytestring
    let modifyFunctionTable = \table ->
            M.insert name functionOffset table
    -- insState' is the modified state before definition compilation
    let insState' = over functionTable modifyFunctionTable insState
    -- insState'' is the modified state after definition compilation
    let insState'' = execState definition insState'
    -- The final state uses these following things:
    --   The compiled bytestring from insState''
    --   The function table from insState', WITH the additions from insState'' modified properly
    let newlyDefinedFunctions = M.difference (insState'' ^. functionTable) (insState' ^. functionTable)
    -- NOTE: because of the order of the next line, function shadowing in the DSL is impossible. the first
    -- definition is always the one that's used.
    -- The fmap is done to shift any definitions made inside this definition to their correct positions
    -- in the global scope.
    let finalFunctionTable = M.union (insState' ^. functionTable) (fmap (+ functionOffset) (insState'' ^. functionTable))
    let finalInsState = set functionTable finalFunctionTable insState''
    put finalInsState

-- This can be used to call subroutines which were previously `define`d.
call :: String -> Instruction
call name = do
    insState <- get
    let pointer = case (M.lookup name (insState ^. functionTable)) of
                    Just ptr -> ptr
                    Nothing -> error ("Couldn't find function " ++ name ++ ". Perhaps it wasn't `define`d?")
    put $ execState (jsr (Absolute $ fromIntegral pointer)) insState

-- THE FOLLOWING WAS GENERATED BY
-- https://github.com/aearnus/assemblicom
-- for the 65C02 instruction set
adc :: AddressingMode -> Instruction
adc (Immediate b) = genericOp 105 b
adc (ZeroPage b) = genericOp 101 b
adc (ZeroPageX b) = genericOp 117 b
adc (Absolute b) = genericTwoByteOp 109 b
adc (AbsoluteX b) = genericTwoByteOp 125 b
adc (AbsoluteY b) = genericTwoByteOp 121 b
adc (ZeroPageIndirect b) = genericOp 114 b
adc (IndirectX b) = genericOp 97 b
adc (IndirectY b) = genericOp 113 b

and :: AddressingMode -> Instruction
and (Immediate b) = genericOp 41 b
and (ZeroPage b) = genericOp 37 b
and (ZeroPageX b) = genericOp 53 b
and (Absolute b) = genericTwoByteOp 45 b
and (AbsoluteX b) = genericTwoByteOp 61 b
and (AbsoluteY b) = genericTwoByteOp 57 b
and (ZeroPageIndirect b) = genericOp 50 b
and (IndirectX b) = genericOp 33 b
and (IndirectY b) = genericOp 49 b

asl :: AddressingMode -> Instruction
asl (Accumulator) = genericNoByteOp 10
asl (ZeroPage b) = genericOp 6 b
asl (ZeroPageX b) = genericOp 22 b
asl (Absolute b) = genericTwoByteOp 14 b
asl (AbsoluteX b) = genericTwoByteOp 30 b

bbr0 :: AddressingMode -> Instruction
bbr0 (ZeroPageRelative b) = genericOp 15 b

bbr1 :: AddressingMode -> Instruction
bbr1 (ZeroPageRelative b) = genericOp 31 b

bbr2 :: AddressingMode -> Instruction
bbr2 (ZeroPageRelative b) = genericOp 47 b

bbr3 :: AddressingMode -> Instruction
bbr3 (ZeroPageRelative b) = genericOp 63 b

bbr4 :: AddressingMode -> Instruction
bbr4 (ZeroPageRelative b) = genericOp 79 b

bbr5 :: AddressingMode -> Instruction
bbr5 (ZeroPageRelative b) = genericOp 95 b

bbr6 :: AddressingMode -> Instruction
bbr6 (ZeroPageRelative b) = genericOp 111 b

bbr7 :: AddressingMode -> Instruction
bbr7 (ZeroPageRelative b) = genericOp 127 b

bbs0 :: AddressingMode -> Instruction
bbs0 (ZeroPageRelative b) = genericOp 143 b

bbs1 :: AddressingMode -> Instruction
bbs1 (ZeroPageRelative b) = genericOp 159 b

bbs2 :: AddressingMode -> Instruction
bbs2 (ZeroPageRelative b) = genericOp 175 b

bbs3 :: AddressingMode -> Instruction
bbs3 (ZeroPageRelative b) = genericOp 191 b

bbs4 :: AddressingMode -> Instruction
bbs4 (ZeroPageRelative b) = genericOp 207 b

bbs5 :: AddressingMode -> Instruction
bbs5 (ZeroPageRelative b) = genericOp 223 b

bbs6 :: AddressingMode -> Instruction
bbs6 (ZeroPageRelative b) = genericOp 239 b

bbs7 :: AddressingMode -> Instruction
bbs7 (ZeroPageRelative b) = genericOp 255 b

bcc :: AddressingMode -> Instruction
bcc (Relative b) = genericOp 144 b

bcs :: AddressingMode -> Instruction
bcs (Relative b) = genericOp 176 b

beq :: AddressingMode -> Instruction
beq (Relative b) = genericOp 240 b

bit :: AddressingMode -> Instruction
bit (Immediate b) = genericOp 137 b
bit (ZeroPage b) = genericOp 36 b
bit (ZeroPageX b) = genericOp 52 b
bit (Absolute b) = genericTwoByteOp 44 b
bit (AbsoluteX b) = genericTwoByteOp 60 b

bmi :: AddressingMode -> Instruction
bmi (Relative b) = genericOp 48 b

bne :: AddressingMode -> Instruction
bne (Relative b) = genericOp 208 b

bpl :: AddressingMode -> Instruction
bpl (Relative b) = genericOp 16 b

bra :: AddressingMode -> Instruction
bra (Relative b) = genericOp 128 b

brk :: AddressingMode -> Instruction
brk (Implied) = genericNoByteOp 0

bvc :: AddressingMode -> Instruction
bvc (Relative b) = genericOp 80 b

bvs :: AddressingMode -> Instruction
bvs (Relative b) = genericOp 112 b

clc :: AddressingMode -> Instruction
clc (Implied) = genericNoByteOp 24

cld :: AddressingMode -> Instruction
cld (Implied) = genericNoByteOp 216

cli :: AddressingMode -> Instruction
cli (Implied) = genericNoByteOp 88

clv :: AddressingMode -> Instruction
clv (Implied) = genericNoByteOp 184

cmp :: AddressingMode -> Instruction
cmp (Immediate b) = genericOp 201 b
cmp (ZeroPage b) = genericOp 197 b
cmp (ZeroPageX b) = genericOp 213 b
cmp (Absolute b) = genericTwoByteOp 205 b
cmp (AbsoluteX b) = genericTwoByteOp 221 b
cmp (AbsoluteY b) = genericTwoByteOp 217 b
cmp (ZeroPageIndirect b) = genericOp 210 b
cmp (IndirectX b) = genericOp 193 b
cmp (IndirectY b) = genericOp 209 b

cpx :: AddressingMode -> Instruction
cpx (Immediate b) = genericOp 224 b
cpx (ZeroPage b) = genericOp 228 b
cpx (Absolute b) = genericTwoByteOp 236 b

cpy :: AddressingMode -> Instruction
cpy (Immediate b) = genericOp 192 b
cpy (ZeroPage b) = genericOp 196 b
cpy (Absolute b) = genericTwoByteOp 204 b

dec :: AddressingMode -> Instruction
dec (Accumulator) = genericNoByteOp 58
dec (ZeroPage b) = genericOp 198 b
dec (ZeroPageX b) = genericOp 214 b
dec (Absolute b) = genericTwoByteOp 206 b
dec (AbsoluteX b) = genericTwoByteOp 222 b

dex :: AddressingMode -> Instruction
dex (Implied) = genericNoByteOp 202

dey :: AddressingMode -> Instruction
dey (Implied) = genericNoByteOp 136

eor :: AddressingMode -> Instruction
eor (Immediate b) = genericOp 73 b
eor (ZeroPage b) = genericOp 69 b
eor (ZeroPageX b) = genericOp 85 b
eor (Absolute b) = genericTwoByteOp 77 b
eor (AbsoluteX b) = genericTwoByteOp 93 b
eor (AbsoluteY b) = genericTwoByteOp 89 b
eor (ZeroPageIndirect b) = genericOp 82 b
eor (IndirectX b) = genericOp 65 b
eor (IndirectY b) = genericOp 81 b

inc :: AddressingMode -> Instruction
inc (Accumulator) = genericNoByteOp 26
inc (ZeroPage b) = genericOp 230 b
inc (ZeroPageX b) = genericOp 246 b
inc (Absolute b) = genericTwoByteOp 238 b
inc (AbsoluteX b) = genericTwoByteOp 254 b

inx :: AddressingMode -> Instruction
inx (Implied) = genericNoByteOp 232

iny :: AddressingMode -> Instruction
iny (Implied) = genericNoByteOp 200

jmp :: AddressingMode -> Instruction
jmp (Absolute b) = genericTwoByteOp 76 b
jmp (Indirect b) = genericTwoByteOp 108 b
jmp (AbsoluteX b) = genericTwoByteOp 124 b

jsr :: AddressingMode -> Instruction
jsr (Absolute b) = genericTwoByteOp 32 b

lda :: AddressingMode -> Instruction
lda (Immediate b) = genericOp 169 b
lda (ZeroPage b) = genericOp 165 b
lda (ZeroPageX b) = genericOp 181 b
lda (Absolute b) = genericTwoByteOp 173 b
lda (AbsoluteX b) = genericTwoByteOp 189 b
lda (AbsoluteY b) = genericTwoByteOp 185 b
lda (ZeroPageIndirect b) = genericOp 178 b
lda (IndirectX b) = genericOp 161 b
lda (IndirectY b) = genericOp 177 b

ldx :: AddressingMode -> Instruction
ldx (Immediate b) = genericOp 162 b
ldx (ZeroPage b) = genericOp 166 b
ldx (ZeroPageY b) = genericOp 182 b
ldx (Absolute b) = genericTwoByteOp 174 b
ldx (AbsoluteY b) = genericTwoByteOp 190 b

ldy :: AddressingMode -> Instruction
ldy (Immediate b) = genericOp 160 b
ldy (ZeroPage b) = genericOp 164 b
ldy (ZeroPageX b) = genericOp 180 b
ldy (Absolute b) = genericTwoByteOp 172 b
ldy (AbsoluteX b) = genericTwoByteOp 188 b

lsr :: AddressingMode -> Instruction
lsr (Accumulator) = genericNoByteOp 74
lsr (ZeroPage b) = genericOp 70 b
lsr (ZeroPageX b) = genericOp 86 b
lsr (Absolute b) = genericTwoByteOp 78 b
lsr (AbsoluteX b) = genericTwoByteOp 94 b

nop :: AddressingMode -> Instruction
nop (Implied) = genericNoByteOp 234

ora :: AddressingMode -> Instruction
ora (Immediate b) = genericOp 9 b
ora (ZeroPage b) = genericOp 5 b
ora (ZeroPageX b) = genericOp 21 b
ora (Absolute b) = genericTwoByteOp 13 b
ora (AbsoluteX b) = genericTwoByteOp 29 b
ora (AbsoluteY b) = genericTwoByteOp 25 b
ora (ZeroPageIndirect b) = genericOp 18 b
ora (IndirectX b) = genericOp 1 b
ora (IndirectY b) = genericOp 17 b

pha :: AddressingMode -> Instruction
pha (Implied) = genericNoByteOp 72

php :: AddressingMode -> Instruction
php (Implied) = genericNoByteOp 8

phx :: AddressingMode -> Instruction
phx (Implied) = genericNoByteOp 218

phy :: AddressingMode -> Instruction
phy (Implied) = genericNoByteOp 90

pla :: AddressingMode -> Instruction
pla (Implied) = genericNoByteOp 104

plp :: AddressingMode -> Instruction
plp (Implied) = genericNoByteOp 40

plx :: AddressingMode -> Instruction
plx (Implied) = genericNoByteOp 250

ply :: AddressingMode -> Instruction
ply (Implied) = genericNoByteOp 122

rmb0 :: AddressingMode -> Instruction
rmb0 (ZeroPage b) = genericOp 7 b

rmb1 :: AddressingMode -> Instruction
rmb1 (ZeroPage b) = genericOp 23 b

rmb2 :: AddressingMode -> Instruction
rmb2 (ZeroPage b) = genericOp 39 b

rmb3 :: AddressingMode -> Instruction
rmb3 (ZeroPage b) = genericOp 55 b

rmb4 :: AddressingMode -> Instruction
rmb4 (ZeroPage b) = genericOp 71 b

rmb5 :: AddressingMode -> Instruction
rmb5 (ZeroPage b) = genericOp 87 b

rmb6 :: AddressingMode -> Instruction
rmb6 (ZeroPage b) = genericOp 103 b

rmb7 :: AddressingMode -> Instruction
rmb7 (ZeroPage b) = genericOp 119 b

rol :: AddressingMode -> Instruction
rol (Accumulator) = genericNoByteOp 42
rol (ZeroPage b) = genericOp 38 b
rol (ZeroPageX b) = genericOp 54 b
rol (Absolute b) = genericTwoByteOp 46 b
rol (AbsoluteX b) = genericTwoByteOp 62 b

ror :: AddressingMode -> Instruction
ror (Accumulator) = genericNoByteOp 106
ror (ZeroPage b) = genericOp 102 b
ror (ZeroPageX b) = genericOp 118 b
ror (Absolute b) = genericTwoByteOp 110 b
ror (AbsoluteX b) = genericTwoByteOp 126 b

rti :: AddressingMode -> Instruction
rti (Implied) = genericNoByteOp 64

rts :: AddressingMode -> Instruction
rts (Implied) = genericNoByteOp 96

sbc :: AddressingMode -> Instruction
sbc (Immediate b) = genericOp 233 b
sbc (ZeroPage b) = genericOp 229 b
sbc (ZeroPageX b) = genericOp 245 b
sbc (Absolute b) = genericTwoByteOp 237 b
sbc (AbsoluteX b) = genericTwoByteOp 253 b
sbc (AbsoluteY b) = genericTwoByteOp 249 b
sbc (ZeroPageIndirect b) = genericOp 242 b
sbc (IndirectX b) = genericOp 225 b
sbc (IndirectY b) = genericOp 241 b

sec :: AddressingMode -> Instruction
sec (Implied) = genericNoByteOp 56

sed :: AddressingMode -> Instruction
sed (Implied) = genericNoByteOp 248

sei :: AddressingMode -> Instruction
sei (Implied) = genericNoByteOp 120

smb0 :: AddressingMode -> Instruction
smb0 (ZeroPage b) = genericOp 135 b

smb1 :: AddressingMode -> Instruction
smb1 (ZeroPage b) = genericOp 151 b

smb2 :: AddressingMode -> Instruction
smb2 (ZeroPage b) = genericOp 167 b

smb3 :: AddressingMode -> Instruction
smb3 (ZeroPage b) = genericOp 183 b

smb4 :: AddressingMode -> Instruction
smb4 (ZeroPage b) = genericOp 199 b

smb5 :: AddressingMode -> Instruction
smb5 (ZeroPage b) = genericOp 215 b

smb6 :: AddressingMode -> Instruction
smb6 (ZeroPage b) = genericOp 231 b

smb7 :: AddressingMode -> Instruction
smb7 (ZeroPage b) = genericOp 247 b

sta :: AddressingMode -> Instruction
sta (ZeroPage b) = genericOp 133 b
sta (ZeroPageX b) = genericOp 149 b
sta (Absolute b) = genericTwoByteOp 141 b
sta (AbsoluteX b) = genericTwoByteOp 157 b
sta (AbsoluteY b) = genericTwoByteOp 153 b
sta (ZeroPageIndirect b) = genericOp 146 b
sta (IndirectX b) = genericOp 129 b
sta (IndirectY b) = genericOp 145 b

stp :: AddressingMode -> Instruction
stp (Implied) = genericNoByteOp 219

stx :: AddressingMode -> Instruction
stx (ZeroPage b) = genericOp 134 b
stx (ZeroPageY b) = genericOp 150 b
stx (Absolute b) = genericTwoByteOp 142 b

sty :: AddressingMode -> Instruction
sty (ZeroPage b) = genericOp 132 b
sty (ZeroPageX b) = genericOp 148 b
sty (Absolute b) = genericTwoByteOp 140 b

stz :: AddressingMode -> Instruction
stz (ZeroPage b) = genericOp 100 b
stz (ZeroPageX b) = genericOp 116 b
stz (Absolute b) = genericTwoByteOp 156 b
stz (AbsoluteX b) = genericTwoByteOp 158 b

tax :: AddressingMode -> Instruction
tax (Implied) = genericNoByteOp 170

tay :: AddressingMode -> Instruction
tay (Implied) = genericNoByteOp 168

trb :: AddressingMode -> Instruction
trb (ZeroPage b) = genericOp 20 b
trb (Absolute b) = genericTwoByteOp 28 b

tsb :: AddressingMode -> Instruction
tsb (ZeroPage b) = genericOp 4 b
tsb (Absolute b) = genericTwoByteOp 12 b

tsx :: AddressingMode -> Instruction
tsx (Implied) = genericNoByteOp 186

txa :: AddressingMode -> Instruction
txa (Implied) = genericNoByteOp 138

txs :: AddressingMode -> Instruction
txs (Implied) = genericNoByteOp 154

tya :: AddressingMode -> Instruction
tya (Implied) = genericNoByteOp 152

wai :: AddressingMode -> Instruction
wai (Implied) = genericNoByteOp 203