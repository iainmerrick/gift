local strings = {}

local bit = require("bit")
local io = require("io")

local oo = require("oo")

local rshift = bit.rshift
local lshift = bit.lshift

local Bits = oo.Class("bit")

function Bits:init(reader)
  self._reader = reader
  self._bits = 0
  self._size = 0
end

function Bits:read1()
  if self._size == 0 then
    self._bits = self._reader:read32()
    self._size = 32
  end
  local b = rshift(self._bits, 31)
  self._bits = lshift(self._bits, 1)
  self._size = self._size - 1
  return b
end

function strings.putNum(n)
  io.write(n)
end

function strings.putChar(c)
  -- print("putChar", c)
  if c > 127 then
    io.write(string.format("0x%x", c))
  else
    io.write(string.char(c))
  end
end

local function putCString(r)
  -- print("putCString", r:addr())
  local c = r:read8()
  while c ~= 0 do
    strings.putChar(c)
    c = r:read8()
  end
end

local function putUnicodeString(r)
  r:setAddr(r:addr() + 3)
  local c = r:read32()
  while c ~= 0 do
    strings.putChar(c)
    c = r:read32()
  end
end

local BRANCH_NODE = 0
local END_NODE = 1
local CHAR_NODE = 2
local STRING_NODE = 3
local UNICHAR_NODE = 4
local UNISTRING_MODE = 5
local REF_NODE = 8
local DOUBLE_REF_NODE =9
local REF_ARGS_NODE = 10
local DOUBLE_REF_ARGS_NODE = 11

local function putCompressedString(vm, r)
  local bits = Bits(r)
  local table = vm:reader(vm.stringTable)
  local length = table:read32() -- Number of entries in the table
  local count = table:read32() -- Size of the table in bytes
  local root = table:read32() -- Address of the root node
  while true do
    -- print(string.format("At the root, addr is now: 0x%x", root))
    local node = vm:reader(root)
    local kind = node:read8()
    while kind == BRANCH_NODE do
      local addr = node:read32()
      if bits:read1() == 1 then
        addr = node:read32()
        -- print(string.format("read a 1, addr is now: 0x%x", addr))
      else
        -- print(string.format("read a 0, addr is now: 0x%x", addr))
      end
      node:setAddr(addr)
      kind = node:read8()
    end
    if kind == END_NODE then
      return
    elseif kind == CHAR_NODE then
      strings.putChar(node:read8())
    elseif kind == STRING_NODE then
      putCString(node)
    elseif kind == UNICHAR_NODE then
      strings.putChar(node:read32())
    elseif kind == UNISTRING_NODE then
      putUnicodeString(node)
    else
      assert(false, "Unknown string table node: " .. kind)
    end
  end
end

local C_STRING = 0xE0
local COMPRESSED_STRING = 0xE1
local UNICODE_STRING = 0xE2

function strings.putString(vm, addr)
  local r = vm:reader(addr)
  local kind = r:read8()
  if kind == C_STRING then
    putCString(r)
  elseif kind == UNICODE_STRING then
    putUnicodeString(r)
  elseif kind == COMPRESSED_STRING then
    putCompressedString(vm, r)
  else
    assert(false, "Unknown string tag: " .. kind)
  end
end

return strings
