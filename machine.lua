local machine = {}

local bit = require("bit")
local ffi = require("ffi")

local oo = require("oo")
local strings = require("strings")

local uint32_array_t = ffi.typeof("uint32_t[?]")

local Machine = oo.Class("Machine")

function Machine:init(data)
  self.memory = data

  self.magic = data[0]
  self.version = data[1]
  self.ramStart = data[2]
  self.extStart = data[3]
  self.endMem = data[4]
  self.stackSize = data[5]
  self.startFunc = data[6]
  self.stringTable = data[7]
  self.checksum = data[8]

  assert(self.magic == 0x476c756c)

  self.stackBase = ffi.new(uint32_array_t, self.stackSize)
  self.stackPtr = self.stackBase
  self.framePtr = self.stackBase
end

function Machine:reader(addr)
  return memory.Reader(self.memory, addr)
end

function Machine:read32(addr)
  return memory.read32(self.memory, addr)
end

function Machine:write32(addr, value)
  return memory.write32(self.memory, addr, value)
end

function Machine:push(value)
  self.stackPtr[0] = value
  self.stackPtr = self.stackPtr + 1
end

function Machine:pop()
  self.stackPtr = self.stackPtr - 1
  local result = self.stackPtr[0]
  self.stackPtr[0] = 0xdeadbeef -- To help catch out-of-bounds accesses
  return result
end

function Machine:getLocal(offset)
  local index = bit.rshift(12 + offset, 2)
  return self.framePtr[index]
end

function Machine:setLocal(offset, value)
  local index = bit.rshift(12 + offset, 2)
  self.framePtr[index] = value
end

function Machine:getMemSize()
  return self.endMem
end

function Machine:streamStr(addr)
  strings.putString(self, addr)
end

function Machine:streamChar(c)
  strings.putChar(c)
end

function Machine:streamNum(n)
  strings.putNum(n)
end

function Machine:call(addr, ...)
  print(string.format("* Indirect call: %08x", addr))
  return self:functionPtr(addr)(self, ...)
end

function Machine:labelName(addr)
  return string.format("label_%08x", addr)
end

function Machine:baseName(addr)
  return string.format("glulx_%08x", addr)
end

local sandbox = {}

local STUB = [[
sandbox, compile = ...
function %s(vm, ...)
  return compile(%d)(vm, ...)
end
]]

function Machine:functionName(addr)
  -- Put generated code into the "sandbox" namespace.
  -- TODO: Could probably use a better sandbox!
  local baseName = self:baseName(addr)
  local name = "sandbox." .. baseName
  if sandbox[baseName] == nil then
    -- Function hasn't been called yet. Generate a compile stub for it.
    -- TODO: Could maybe pass vm as a parameter to loadstring.
    print(string.format("* Stubbing: %08x", addr))
    local compile = function(addr)
      return self:compile(addr)
    end
    local stub = string.format(STUB, name, addr)
    loadstring(stub)(sandbox, compile)
  end
  return name
end

function Machine:functionPtr(addr)
  self:functionName(addr) -- Force stub generation. Tacky! TODO: fix this
  return sandbox[self:baseName(addr)]
end

function Machine:compile(addr)
  local name = self:functionName(addr)
  print(string.format("* Compiling: %08x", addr))
  local func = functions.parseFunction(self:reader(addr))
  local s = utils.Joiner("\n"):pushPrefix("\t")
  s:add("sandbox = ...")
  local code = func:toCode(self, s)
  -- print(s)
  loadstring(tostring(s))(sandbox)
  return sandbox[self:baseName(addr)]
end

function machine.fromFile(file, size)
  local data = ffi.new(uint32_array_t, size)
  for i = 0,size-1 do
    bytes = file:read(4)
    data[i] = bit.bor(
      bit.lshift(bytes:byte(1), 24),
      bit.lshift(bytes:byte(2), 16),
      bit.lshift(bytes:byte(3), 8),
      bytes:byte(4))
  end
  return Machine(data)
end

return machine
