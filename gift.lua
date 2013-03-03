#!/usr/bin/env luajit

bit = require("bit")
ffi = require("ffi")
io = require("io")
string = require("string")

functions = require("functions")
memory = require("memory")
oo = require("oo")

local file = io.open("test/Advent.ulx", "r")
local size = file:seek("end")
file:seek("set", 0)
assert(bit.band(size, 3) == 0, "Size must be a multiple of 4!")
size = size / 4

ffi.cdef[[
typedef struct {
  uint32_t memory[?];
} GlulxState;
]]
GlulxState = ffi.typeof("GlulxState")
g = ffi.new(GlulxState, size)

for i = 0,size-1 do
  bytes = file:read(4)
  g.memory[i] = bit.bor(
    bit.lshift(bytes:byte(1), 24),
    bit.lshift(bytes:byte(2), 16),
    bit.lshift(bytes:byte(3), 8),
    bytes:byte(4))
end
file.close()

local r = memory.Reader(g, 0)
local magic = r:read32()
local version = r:read32()
local ramStart = r:read32()
local extStart = r:read32()
local endMem = r:read32()
local stackSize = r:read32()
local startFunc = r:read32()
local stringTable = r:read32()
local checksum = r:read32()

assert(magic == 0x476c756c)

print(functions.parseFunction(g, startFunc):toCode())
print(functions.parseFunction(g, 72):toCode())
print(functions.parseFunction(g, 66736):toCode())
print(functions.parseFunction(g, 69746):toCode())
