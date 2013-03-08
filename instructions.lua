local instructions = {}

local oo = require("oo")
local operands = require("operands")
local utils = require("utils")

local Instruction = oo.Class("Instruction")

function Instruction:init(addr, nextAddr, opcode, loads, stores)
  self._addr = addr         -- Start address of this instruction
  self._nextAddr = nextAddr -- Address of the next instruction
  self._opcode = opcode     -- An Opcode object
  self._loads = loads       -- List of Operands, one per input
  self._stores = stores     -- List of Operands, one per output
end

function Instruction:tostring()
  return utils.Joiner(" ")
      :add(self._opcode.name)
      :addEach(self._loads)
      :addIf(#self._stores > 0, "->")
      :addEach(self._stores)
end

function Instruction:toCode(cc, s)
  s:add("::" .. cc:labelName(self._addr) .. "::")
  s:addFormat("print(\"* %08x %s\")", self._addr, self)
  s:add("do"):pushPrefix("  ")
  do
    for i = 1,#self._loads do
      s:addFormat("local L%d = %s", i, self._loads[i]:toLoadCode())
    end
    for i = 1,#self._stores do
      s:addFormat("local S%d", i)
    end
    s:add(self._opcode:toCode(self, cc, s, unpack(self._loads)))
    for i = 1,#self._stores do
      s:add(self._stores[i]:toStoreCode("S" .. i))
    end
  end
  return s:popPrefix():add("end")
end

function Instruction:addr()
  return self._addr
end

function Instruction:branchAddr()
  return self._opcode:branchAddr(self, unpack(self._loads))
end

function Instruction:nextAddr()
  if self._opcode.alwaysExits then
    return nil
  else
    return self._nextAddr
  end
end

local function Opcode(name, code, numLoads, numStores)
  code = code or string.format("assert(false, \"UNIMPLEMENTED: %s\")", name)
  return oo.Prototype {
    name = name;
    alwaysExits = false;
    toCode = function(self, instr, cc, s)
      s:add(code)
    end;
    branchAddr = function(self, loads)
      return nil
    end;
    parse = function(self, addr, reader)
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
      local nextAddr = reader:addr()
      return Instruction(addr, nextAddr, self, loads, stores)
    end;
  }
end

local function OpcodeL(name, code) return Opcode(name, code, 1, 0) end
local function OpcodeLL(name, code) return Opcode(name, code, 2, 0) end
local function OpcodeLLL(name, code) return Opcode(name, code, 3, 0) end

local function OpcodeS(name, code) return Opcode(name, code, 0, 1) end
local function OpcodeLS(name, code) return Opcode(name, code, 1, 1) end
local function OpcodeLLS(name, code) return Opcode(name, code, 2, 1) end

local function Branch(name, code, numLoads)
  return Opcode(name, code, numLoads, 0) {
    toCode = function(self, instr, cc, s, ...)
      local loads = {...}
      local target = loads[#loads]
      s:add("if " .. code .. " then"):pushPrefix("  ")
      local dest = target:const()
      if dest == nil then
        s:add("assert(false, \"Non-const branch! Not implemented yet\")")
      elseif dest == 0 then
        s:add("return 0")
      elseif dest == 1 then
        s:add("return 1")
      else
        dest = instr._nextAddr + dest - 2
        s:add("goto " .. cc:labelName(dest))
      end
      s:popPrefix():add("end")
    end;
    branchAddr = function(self, instr, ...)
      local loads = {...}
      local target = loads[#loads]
      local dest = target:const()
      if dest == nil or dest == 0 or dest == 1 then
        return nil
      else
        return instr._nextAddr + dest - 2
      end
    end;
  }
end

local function BranchL(name, code) return Branch(name, code, 1) end
local function BranchLL(name, code) return Branch(name, code, 2) end
local function BranchLLL(name, code) return Branch(name, code, 3) end

local OPCODES = {

  [0x00] = Opcode("nop", "-- nop", 0, 0),
  [0x10] = OpcodeLLS("add", "S1 = L1 + L2"),
  [0x11] = OpcodeLLS("sub", "S1 = L1 - L2"),
  [0x12] = OpcodeLLS("mul", "S1 = L1 * L2"),
  [0x13] = OpcodeLLS("div", "S1 = bit.tobit(L1 / L2)"),
  [0x14] = OpcodeLLS("mod", "S1 = L1 % L2"),
  [0x15] = OpcodeLS("neg", "S1 = -L1"),
  [0x18] = OpcodeLLS("bitand", "S1 = bit.band(L1, L2)"),
  [0x19] = OpcodeLLS("bitor", "S1 = bit.bor(L1, L2)"),
  [0x1A] = OpcodeLLS("bitxor", "S1 = bit.bxor(L1, L2)"),
  [0x1B] = OpcodeLLS("bitnot", "S1 = bit.bnot(L1, L2)"),
  [0x1C] = OpcodeLLS("shiftl", "S1 = bit.lshift(L1, L2)"),
  [0x1D] = OpcodeLLS("sshiftr", "S1 = bit.arshift(L1, L2)"),
  [0x1E] = OpcodeLLS("ushiftr", "S1 = bit.rshift(L1, L2)"),
  [0x20] = BranchL("jump", "true") { alwaysExits = true },
  [0x22] = BranchLL("jz", "L2 == 0"),
  [0x23] = BranchLL("jnz", "L2 ~= 0"),
  [0x24] = BranchLLL("jeq", "L2 == L3"),
  [0x25] = BranchLLL("jne", "L2 ~= L3"),
  [0x26] = BranchLLL("jlt", "L2 < L3"),
  [0x27] = BranchLLL("jge", "L2 >= L3"),
  [0x28] = BranchLLL("jgt", "L2 > L3"),
  [0x29] = BranchLLL("jle", "L2 <= L3"),
  [0x2A] = OpcodeLLL("jltu"),
  [0x2B] = OpcodeLLL("jgeu"),
  [0x2C] = OpcodeLLL("jgtu"),
  [0x2D] = OpcodeLLL("jleu"),

  [0x30] = OpcodeLLS("call") {
    toCode = function(self, instr, cc, s, L1, L2)
      s:add("local args = {}")
      s:add("for i = 1,L2 do")
      s:add("  args[#args] = vm:pop()")
      s:add("end")
      if L1:isConst() then
        local func = cc:functionName(L1:const())
        s:add("S1 = " .. func .. "(vm, unpack(args))")
      else
        s:add("S1 = vm:call(L1, unpack(args))")
      end
    end;
  },
  [0x31] = OpcodeL("return", "return L1") { alwaysExits = true },
  -- [0x32] = catch
  -- [0x33] = throw
  -- [0x34] = tailcall
  [0x40] = OpcodeLS("copy", "S1 = L1"),
  -- [0x41] = copys
  -- [0x42] = copyb
  -- [0x44] = sexs
  -- [0x45] = sexb
  [0x48] = OpcodeLLS("aload", "S1 = vm:reader(L1 + 4 * L2):read32()"),
  [0x49] = OpcodeLLS("aloads", "S1 = vm:reader(L1 + 2 * L2):read16()"),
  [0x4A] = OpcodeLLS("aloadb", "S1 = vm:reader(L1 + L2):read8()"),
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
  [0x70] = OpcodeL("streamchar", "vm:streamChar(L1)"),
  [0x71] = OpcodeL("streamnum", "vm:streamNum(L1)"),
  [0x72] = OpcodeL("streamstr", "vm:streamStr(L1)"),
  [0x73] = OpcodeL("streamunichar", "vm:streamChar(L1)"),
  -- [0x100] = gestalt
  -- [0x101] = debugtrap
  [0x102] = OpcodeS("getmemsize", "S1 = vm:getMemSize()"),
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
  return Opcode(
      string.format("(unknown: 0x%x)", code),
      "assert(false, \"Unknown opcode!\")",
      0, 0) {
    alwaysExits = true;
  }
end

function instructions.parseInstruction(reader)
  local addr = reader:addr()
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
  return opcode:parse(addr, reader)
end

return instructions
