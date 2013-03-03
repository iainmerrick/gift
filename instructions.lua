local instructions = {}

local oo = require("oo")
local operands = require("operands")
local utils = require("utils")

instructions.Instruction = oo.Class("Instruction")

function instructions.Instruction:init(addr, opcode, loads, stores)
  self.addr = addr      -- Start address of this instruction
  self.opcode = opcode  -- An Opcode object
  self.loads = loads    -- List of Operands, one per input
  self.stores = stores  -- List of Operands, one per output
end

function instructions.Instruction:tostring()
  return utils.Joiner(" ")
      :addFormat("%08x %s", self.addr, self.opcode.name)
      :addEach(self.loads)
      :addIf(#self.stores > 0, "->")
      :addEach(self.stores)
end

function instructions.Instruction:alwaysExits()
  return self.opcode.alwaysExits
end

local function Opcode(name, numLoads, numStores)
  return oo.Prototype {
    name = name;
    alwaysExits = false;
    parse = function(self, reader)
      local addr = reader:addr()
      local modes = {}
      local numModeBytes = bit.rshift(numLoads + numStores + 1, 1);
      for i = 1,numModeBytes do
        local byte = reader:read8()
        modes[2*i - 1] = bit.band(byte, 0xf)
        if (numLoads + numStores) >= 2*i then
          modes[2*i] = bit.rshift(byte, 4)
        end
      end
      local loads = {}
      for i = 1,numLoads do
        loads[i] = operands.parseOperand(modes[i], reader)
      end
      local stores = {}
      for i = 1,numStores do
        stores[i] = operands.parseOperand(modes[numLoads + i], reader)
      end
      return instructions.Instruction(addr, self, loads, stores)
    end;
  }
end

local function OpcodeL(name) return Opcode(name, 1, 0) end
local function OpcodeLL(name) return Opcode(name, 2, 0) end
local function OpcodeLLL(name) return Opcode(name, 3, 0) end

local function OpcodeS(name) return Opcode(name, 0, 1) end
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
  [0x20] = OpcodeL("jump") { alwaysExits = true },
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
  [0x31] = OpcodeL("return") { alwaysExits = true },
  -- [0x32] = catch
  -- [0x33] = throw
  -- [0x34] = tailcall
  [0x40] = OpcodeLS("copy"),
  -- [0x41] = copys
  -- [0x42] = copyb
  -- [0x44] = sexs
  -- [0x45] = sexb
  [0x48] = OpcodeLLS("aload"),
  [0x49] = OpcodeLLS("aloads"),
  [0x4A] = OpcodeLLS("aloadb"),
  [0x4B] = OpcodeLLS("aloadbit"),
  [0x4C] = OpcodeLLL("astore"),
  [0x4D] = OpcodeLLL("astores"),
  [0x4E] = OpcodeLLL("astoreb"),
  [0x4F] = OpcodeLLL("astorebit"),
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
  [0x102] = OpcodeS("getmemsize"),
  [0x103] = OpcodeLS("setmemsize"),
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

local function UnknownOpcode(code)
  return Opcode(string.format("(unknown: 0x%x)", code), 0, 0) {
    alwaysExits = true;
  }
end

function instructions.parseInstruction(reader)
  local code
  local size = bit.rshift(reader:peek8(), 6)
  if size == 0 or size == 1 then
    code = reader:read8()
  elseif size == 2 then
    code = reader:read16() - 0x8000
  else
    code = reader:read32() - 0xc0000000
  end
  local opcode = OPCODES[code] or UnknownOpcode(code)
  return opcode:parse(reader)
end

return instructions
