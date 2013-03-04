local machine = {}

local ffi = require("ffi")

local oo = require("oo")

uint32_array_t = ffi.typeof("uint32_t[?]")

Machine = oo.Class("Machine")

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
