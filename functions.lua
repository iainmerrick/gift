local functions = {}

local bit = require("bit")
local string = require("string")
local table = require("table")

local instructions = require("instructions")
local memory = require("memory")
local oo = require("oo")
local utils = require("utils")

local STACK_ARGS = 0xc0
local LOCAL_ARGS = 0xc1

functions.Function = oo.Class("Function")

function functions.Function:init(addr, kind, numLocals, code)
  self.addr = addr            -- Start address of this function
  self.kind = kind            -- STACK_ARGS or LOCAL_ARGS
  self.numLocals = numLocals  -- Number of local variables
  self.code = code            -- Sequence of Instruction objects
end

function functions.Function:tostring()
  local s = utils.Joiner("\n")
  s:addFormat("%08x", self.addr)
  s:addIfElse(self.kind == STACK_ARGS,
    "  Type: stack",
    "  Type: locals")
  s:add("  Locals: " .. self.numLocals)
  for i, c in ipairs(self.code) do
    s:add("  " .. tostring(c))
  end
  s:add("")
  return s
end

function functions.parseFunction(g, addr)
  local reader = memory.Reader(g, addr)
  local kind = reader:read8()
  assert(kind == STACK_ARGS or kind == LOCAL_ARGS)

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

  local code = {}
  repeat
    code[#code + 1] = instructions.parseInstruction(reader)
  until code[#code]:alwaysExits();

  return functions.Function(addr, kind, numLocals, code)
end

return functions
