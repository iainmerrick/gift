#!/usr/bin/env luajit

bit = require("bit")
ffi = require("ffi")
io = require("io")
string = require("string")

memory = require("memory")

local file = io.open("test/Advent.ulx", "r")
local size = file:seek("end")
file:seek("set", 0)
print("Size is:", size)

assert(band(size, 3) == 0, "Size must be a multiple of 4!")
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

assert(memory.read32(g, 0) == 0x476c756c)
