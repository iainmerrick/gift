local disasm = {}

local bit = require("bit")
local string = require("string")
local table = require("table")

local memory = require("memory")
local oo = require("oo")

-- A note on terminology:
--  * Mode: a glulx addressing mode, in the range 0-15
--  * Argument: a Mode plus its associated value, e.g. "constant 123"
--  * Opcode: a glulx instruction code, e.g. "add" or "call"
--  * Operation: an Opcode plus its associated Arguments
-- Parsed code is a map of address -> Operation.

disasm.Operation = oo.Class()

function disasm.Operation:init(opcode, loads, stores)
  self.opcode = opcode
  self.loads = loads
  self.stores = stores
end

function disasm.Operation:emit(buffer)
  buffer:emit(self.opcode.name)
  for i = 1,#self.loads do
    buffer:emit(self.loads[i].mode.name, self.loads[i].value)
  end
  if #self.stores > 0 then
    buffer:emit("->")
  end
  for i = 1,#self.stores do
    buffer:emit(self.stores[i].mode.name, self.stores[i].value)
  end
end

disasm.Argument = oo.Class()

function disasm.Argument:init(mode, value)
  self.mode = mode
  self.value = value
end

local function Mode(name, size)
  assert(type(name) == "string")
  assert(type(size) == "number")
  return oo.Prototype() {
    name = name;
    parse = function(self, reader)
      if size == 0 then
        return disasm.Argument(self, 0)
      elseif size == 1 then
        return disasm.Argument(self, reader:read8())
      elseif size == 2 then
        return disasm.Argument(self, reader:read16())
      else
        return disasm.Argument(self, reader:read32())
      end
    end;
  }
end

local function ConstMode(size)
  return Mode("const", size)
end

local function AddrMode(size)
  return Mode("addr", size)
end

local function StackMode(size)
  return Mode("stack", size)
end

local function LocalMode(size)
  return Mode("local", size)
end

local function RamMode(size)
  return Mode("ram", size)
end

local MODES = {
  [0x0] = ConstMode(0),
  [0x1] = ConstMode(1),
  [0x2] = ConstMode(2),
  [0x3] = ConstMode(4),
  [0x4] = nil,
  [0x5] = AddrMode(1),
  [0x6] = AddrMode(2),
  [0x7] = AddrMode(4),
  [0x8] = StackMode(0),
  [0x9] = LocalMode(1),
  [0xa] = LocalMode(2),
  [0xb] = LocalMode(4),
  [0xc] = nil,
  [0xd] = RamMode(1),
  [0xe] = RamMode(2),
  [0xf] = RamMode(4),
}

local function Opcode(name, numLoads, numStores)
  return oo.Prototype() {
    name = name;
    parse = function(self, reader)
      local modes = {}
      local numOperands = numLoads + numStores
      local numModeBytes = bit.rshift(numOperands + 1, 1);
      for i = 1,numModeBytes do
        local byte = reader:read8()
        modes[2*i - 1] = MODES[bit.band(byte, 0xf)]
        if numOperands >= 2*i then
          modes[2*i] = MODES[bit.rshift(byte, 4)]
        end
      end
      local loads = {}
      for i = 1,numLoads do
        loads[i] = modes[i]:parse(reader)
      end
      local stores = {}
      for i = 1,numStores do
        stores[i] = modes[numLoads + i]:parse(reader)
      end
      return disasm.Operation(self, loads, stores)
    end;
  }
end

local function OpcodeL(name) return Opcode(name, 1, 0) end
local function OpcodeLL(name) return Opcode(name, 2, 0) end
local function OpcodeLLL(name) return Opcode(name, 3, 0) end

local function OpcodeLS(name) return Opcode(name, 1, 1) end
local function OpcodeLLS(name) return Opcode(name, 2, 1) end

local OPCODES = {

  [0x00] = Opcode("nop", 0, 0),
  [0x10] = OpcodeLLS("add"),
  [0x11] = OpcodeLLS("sub"),
  -- [0x12] = mul
  -- [0x13] = div
  -- [0x14] = mod
  -- [0x15] = neg
  -- [0x18] = bitand
  -- [0x19] = bitor
  -- [0x1A] = bitxor
  -- [0x1B] = bitnot
  -- [0x1C] = shiftl
  -- [0x1D] = sshiftr
  -- [0x1E] = ushiftr
  [0x20] = OpcodeL("jump"),
  [0x22] = OpcodeLL("jz"),
  [0x23] = OpcodeLL("jnz"),
  [0x24] = OpcodeLLL("jeq"),
  [0x25] = OpcodeLLL("jne"),
  [0x26] = OpcodeLLL("jlt"),
  [0x27] = OpcodeLLL("jge"),
  [0x28] = OpcodeLLL("jgt"),
  [0x29] = OpcodeLLL("jle"),
  [0x2A] = OpcodeLLL("jltu"),
  [0x2B] = OpcodeLLL("jgeu"),
  [0x2C] = OpcodeLLL("jgtu"),
  [0x2D] = OpcodeLLL("jleu"),
  [0x30] = OpcodeLLS("call"),
  [0x31] = OpcodeL("return"),
  -- [0x32] = catch
  -- [0x33] = throw
  -- [0x34] = tailcall
  [0x40] = OpcodeLS("copy"),
  -- [0x41] = copys
  -- [0x42] = copyb
  -- [0x44] = sexs
  -- [0x45] = sexb
  -- [0x48] = aload
  -- [0x49] = aloads
  -- [0x4A] = aloadb
  -- [0x4B] = aloadbit
  -- [0x4C] = astore
  -- [0x4D] = astores
  -- [0x4E] = astoreb
  -- [0x4F] = astorebit
  -- [0x50] = stkcount
  -- [0x51] = stkpeek
  -- [0x52] = stkswap
  -- [0x53] = stkroll
  -- [0x54] = stkcopy
  [0x70] = OpcodeL("streamchar"),
  [0x71] = OpcodeL("streamnum"),
  [0x72] = OpcodeL("streamstr"),
  [0x73] = OpcodeL("streamunichar"),
  -- [0x100] = gestalt
  -- [0x101] = debugtrap
  -- [0x102] = getmemsize
  -- [0x103] = setmemsize
  -- [0x104] = jumpabs
  -- [0x110] = random
  -- [0x111] = setrandom
  -- [0x120] = quit
  -- [0x121] = verify
  -- [0x122] = restart
  -- [0x123] = save
  -- [0x124] = restore
  -- [0x125] = saveundo
  -- [0x126] = restoreundo
  -- [0x127] = protect
  [0x130] = OpcodeLLS("glk"),
  -- [0x140] = getstringtbl
  -- [0x141] = setstringtbl
  -- [0x148] = getiosys
  -- [0x149] = setiosys
  -- [0x150] = linearsearch
  -- [0x151] = binarysearch
  -- [0x152] = linkedsearch
  -- [0x160] = callf
  -- [0x161] = callfi
  -- [0x162] = callfii
  -- [0x163] = callfiii
  -- [0x170] = mzero
  -- [0x171] = mcopy
  -- [0x178] = malloc
  -- [0x179] = mfree
  -- [0x180] = accelfunc
  -- [0x181] = accelparam
  -- [0x190] = numtof
  -- [0x191] = ftonumz
  -- [0x192] = ftonumn
  -- [0x198] = ceil
  -- [0x199] = floor
  -- [0x1A0] = fadd
  -- [0x1A1] = fsub
  -- [0x1A2] = fmul
  -- [0x1A3] = fdiv
  -- [0x1A4] = fmod
  -- [0x1A8] = sqrt
  -- [0x1A9] = exp
  -- [0x1AA] = log
  -- [0x1AB] = pow
  -- [0x1B0] = sin
  -- [0x1B1] = cos
  -- [0x1B2] = tan
  -- [0x1B3] = asin
  -- [0x1B4] = acos
  -- [0x1B5] = atan
  -- [0x1B6] = atan2
  -- [0x1C0] = jfeq
  -- [0x1C1] = jfne
  -- [0x1C2] = jflt
  -- [0x1C3] = jfle
  -- [0x1C4] = jfgt
  -- [0x1C5] = jfge
  -- [0x1C8] = jisnan
  -- [0x1C9] = jisinf  
}

function hex(s)
  return string.format("0x%s", s)
end

function disasm.parseFunction(g, addr, buffer)
  local reader = memory.Reader(g, addr)
  local type = reader:read8()

  local numLocals = 0
  while true do
    local width, count = reader:read8(), reader:read8()
    if count == 0 then
      break
    else
      assert(width == 4)
      numLocals = numLocals + count
    end
  end

  buffer:emit(
    "\naddr:", addr,
    "\ntype:", hex(type),
    "\nlocals:", numLocals,
    "\n")

  local ops = {}
  while true do
    local code
    local size = bit.rshift(reader:peek8(), 6)
    if size == 0 or size == 1 then
      code = reader:read8()
    elseif size == 2 then
      code = reader:read16() - 0x8000
    else
      code = reader:read32() - 0xc0000000
    end
    local opcode = OPCODES[code]    
    if opcode == nil then
      buffer:emit("Unknown opcode:", hex(code))
      break
    end
    local op = opcode:parse(reader)
    op:emit(buffer)
    buffer:emit("\n")
  end
  buffer:emit("\n")
end

return disasm
