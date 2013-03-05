local functions = {}

local bit = require("bit")
local string = require("string")
local table = require("table")

bor = bit.bor
lshift = bit.lshift

local instructions = require("instructions")
local memory = require("memory")
local oo = require("oo")
local utils = require("utils")

local STACK_ARGS = 0xc0
local LOCAL_ARGS = 0xc1

local Function = oo.Class("Function")

function Function:init(addr, kind, numLocals, code)
  self.addr = addr            -- Start address of this function
  self.kind = kind            -- STACK_ARGS or LOCAL_ARGS
  self.numLocals = numLocals  -- Number of local variables
  self.code = code            -- Sequence of Instruction objects
  self.localArgs = {}            -- Sequence of argument names
  if kind == LOCAL_ARGS then
    for i = 1,numLocals do
      self.localArgs[i] = "arg" .. i
    end
  end
end

function Function:tostring()
  return utils.Joiner("\n")
    :addFormat("%08x", self.addr)
    :pushPrefix("  ")
      :addIfElse(self.kind == STACK_ARGS, "Type: stack", "Type: locals")
      :add("Locals: " .. self.numLocals)
      :addEach(self.code)
    :popPrefix()
    :add("")
end

function Function:toCode(cc, s)
  local functionName = cc:functionName(self.addr)
  -- Function header
  if self.kind == LOCAL_ARGS then
    s:addFormat("function %s(%s)",
        functionName,
        utils.Joiner(", "):add("vm"):addEach(self.localArgs))
  else
    s:addFormat("function %s(vm, ...)", functionName)
    s:add("  local stackArgs = {...}")
  end
  s:pushPrefix("  ")
  -- Push a new frame onto the stack.
  do
    assert(self.numLocals <= 255)
    local frameLen = 4 * (3 + self.numLocals)
    local localsPos = 12
    local localsFormat = bor(lshift(4, 24), lshift(self.numLocals, 16))
    s:addFormat("vm:push(%s)", frameLen)
    s:addFormat("vm:push(%s)", localsPos)
    s:addFormat("vm:push(0x%x)", localsFormat)
    if self.kind == LOCAL_ARGS then
      -- Push function arguments into the frame
      for i = 1,self.numLocals do
        s:addFormat("vm:push(%s or 0)", self.localArgs[i])
      end
    else
      -- Fill the frame with zeroes, then push args onto the stack.
      s:addFormat("for i = 1,%s do", self.numLocals)
      s:addFormat("  vm:push(0)")
      s:add("end")
      s:add("for i = 1,#stackArgs do")
      s:add("  vm:push(stackArgs[i] or 0)")
      s:add("end")
      s:add("vm:push(#stackArgs)")
    end
  end
  -- Function body
  for i = 1,#self.code do
    self.code[i]:toCode(cc, s)
  end
  -- Function footer
  s:popPrefix():add("end", "")
end

function functions.parseFunction(reader)
  local addr = reader:addr()
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

  return Function(addr, kind, numLocals, code)
end

return functions
