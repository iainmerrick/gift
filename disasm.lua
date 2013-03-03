local disasm = {}

local bit = require("bit")
local string = require("string")
local table = require("table")

local instructions = require("instructions")
local memory = require("memory")
local oo = require("oo")

function hex(s)
  return string.format("0x%x", s)
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
  repeat
    local instr = instructions.parseInstruction(reader)
    instr:emit(buffer)
    buffer:emit("\n")
  until instr:alwaysExits();
end

return disasm
