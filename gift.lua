#!/usr/bin/env luajit

bit = require("bit")
ffi = require("ffi")
io = require("io")
string = require("string")

local file = io.open("test/Advent.ulx", "r")
local size = file:seek("end")
file:seek("set", 0)
print("Size is:", size)

assert(bit.band(size, 3) == 0, "Size must be a multiple of 4!")
size = size / 4

memory = ffi.new("uint32_t[?]", size)
for i = 0,size-1 do
  bytes = file:read(4)
  memory[i] = bit.bor(
    bit.lshift(bytes:byte(1), 24),
    bit.lshift(bytes:byte(2), 16),
    bit.lshift(bytes:byte(3), 8),
    bytes:byte(4))
end
file.close()

for i = 0,20 do
  print(memory[i])
end
