local disasm = {}

local bit = require("bit")
local string = require("string")
local table = require("table")

local memory = require("memory")

local function Mode(name, size)
  assert(type(name) == "string")
  assert(type(size) == "number")
  return {
    name = name;
    parse = function(reader, buffer)
      buffer.emit(name)
      if size == 0 then
        buffer.emit(0)
      elseif size == 1 then
        buffer.emit(reader.read8())
      elseif size == 2 then
        buffer.emit(reader.read16())
      else
        buffer.emit(reader.read32())
      end
    end;
  }
end

local MODES = {
  [0x0] = Mode("const", 0),
  [0x1] = Mode("const", 1),
  [0x2] = Mode("const", 2),
  [0x3] = Mode("const", 4),
  [0x4] = Mode("(unused)", 0),
  [0x5] = Mode("addr", 1),
  [0x6] = Mode("addr", 2),
  [0x7] = Mode("addr", 4),
  [0x8] = Mode("stack", 0),
  [0x9] = Mode("local", 1),
  [0xa] = Mode("local", 2),
  [0xb] = Mode("local", 4),
  [0xc] = Mode("(unused)", 0),
  [0xd] = Mode("ram", 1),
  [0xe] = Mode("ram", 2),
  [0xf] = Mode("ram", 4),
}

local L = ("L"):byte(1)
local S = ("S"):byte(1)

local function Opcode(name, operands)
  assert(type(name) == "string")
  assert(type(operands) == "string")
  local numModeBytes = bit.rshift(#operands + 1, 1);
  return {
    name = name;
    parse = function(reader, buffer)
      buffer.emit(name)
      local modes = {}
      for i = 1,numModeBytes do
        local byte = reader.read8()
        modes[2*i - 1] = MODES[bit.band(byte, 0xf)]
        if #operands >= 2*i then
          modes[2*i] = MODES[bit.rshift(byte, 4)]
        end
      end
      local stored = false
      for i = 1,#operands do
        if operands:byte(i) == S and not stored then
          buffer.emit("->")
          stored = true
        end
        modes[i].parse(reader, buffer)
      end
      buffer.emit("\n")
    end;
  }
end

local function BinaryOpcode(name) return Opcode(name, "LLS") end
local function JumpOpcode0(name) return Opcode(name, "L") end
local function JumpOpcode1(name) return Opcode(name, "LL") end
local function JumpOpcode2(name) return Opcode(name, "LLL") end

local OPCODES = {

  [0x00] = Opcode("nop", ""),
  [0x10] = BinaryOpcode("add"),
  [0x11] = BinaryOpcode("sub"),
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
  [0x20] = JumpOpcode0("jump"),
  [0x22] = JumpOpcode1("jz"),
  [0x23] = JumpOpcode1("jnz"),
  [0x24] = JumpOpcode2("jeq"),
  [0x25] = JumpOpcode2("jne"),
  [0x26] = JumpOpcode2("jlt"),
  [0x27] = JumpOpcode2("jge"),
  [0x28] = JumpOpcode2("jgt"),
  [0x29] = JumpOpcode2("jle"),
  [0x2A] = JumpOpcode2("jltu"),
  [0x2B] = JumpOpcode2("jgeu"),
  [0x2C] = JumpOpcode2("jgtu"),
  [0x2D] = JumpOpcode2("jleu"),
  [0x30] = Opcode("call", "LLS"),
  [0x31] = Opcode("return", "L"),
  -- [0x32] = catch
  -- [0x33] = throw
  -- [0x34] = tailcall
  [0x40] = Opcode("copy", "LS"),
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
  [0x70] = Opcode("streamchar", "L"),
  [0x71] = Opcode("streamnum", "L"),
  [0x72] = Opcode("streamstr", "L"),
  [0x73] = Opcode("streamunichar", "L"),
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
  [0x130] = Opcode("glk", "LLS"),
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

local function Buffer()
  local size = 0
  local data = {}
  return {
    emit = function(...)
      args = {...}
      for i = 1,#args do
        data[size + i] = args[i]
      end
      size = size + #args
    end;
    build = function()
      return table.concat(data, " ")
    end;
  }
end

local function hex(s)
  return "0x"..string.format("%x", s)
end

function disasm.parseFunction(g, addr)
  local reader = memory.Reader(g, addr)
  local buffer = Buffer()
  buffer.emit("@", addr, "\n")

  local type = reader.read8()
  buffer.emit("type:", hex(type), "\n")

  local numLocals = 0
  while true do
    local width, count = reader.read8(), reader.read8()
    if count == 0 then
      break
    else
      assert(width == 4)
      numLocals = numLocals + count
    end
  end
  buffer.emit("locals:", numLocals, "\n")

  while true do
    local code
    local size = bit.rshift(reader.peek8(), 6)
    if size == 0 or size == 1 then
      code = reader.read8()
    elseif size == 2 then
      code = reader.read16() - 0x8000
    else
      code = reader.read32() - 0xc0000000
    end
    local op = OPCODES[code]    
    if op == nil then
      buffer.emit("Unknown opcode", hex(code))
      break
    end
    op.parse(reader, buffer)
  end
  return buffer.build()
end

return disasm
