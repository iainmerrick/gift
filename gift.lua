#!/usr/bin/env luajit

bit = require("bit")
band = bit.band
bor = bit.bor
lshift = bit.lshift
rshift = bit.rshift

ffi = require("ffi")
io = require("io")
string = require("string")

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
state = ffi.new(GlulxState, size)

for i = 0,size-1 do
  bytes = file:read(4)
  state.memory[i] = bor(
    lshift(bytes:byte(1), 24),
    lshift(bytes:byte(2), 16),
    lshift(bytes:byte(3), 8),
    bytes:byte(4))
end
file.close()

function read32(g, addr)
  local word = g.memory[rshift(addr, 2)]
  local byte = band(addr, 3)
  if byte == 0 then
    return word
  end
  return bor(
    lshift(read16(g, addr), 16),
    read16(g, addr + 2))
end

function read16(g, addr)
  local word = g.memory[rshift(addr, 2)]
  local byte = band(addr, 3)
  if byte == 0 then
    return rshift(word, 16)
  elseif byte == 2 then
    return band(word, 0xffff)
  end
  return bor(
    lshift(read8(g, addr), 8),
    read8(g, addr + 1))
end

function read8(g, addr)
  local word = g.memory[rshift(addr, 2)]
  local byte = band(addr, 3)
  if byte == 0 then
    return rshift(word, 24)
  elseif byte == 1 then
    return band(rshift(word, 16), 0xff)
  elseif byte == 2 then
    return band(rshift(word, 8), 0xff)
  else
    return band(word, 0xff)
  end
end

for i = 0,10 do
  print(string.format("%08x", state.memory[i]))
end

for i = 0,7 do
  print(string.format("%4d: %08x %04x %02x",
    i,
    read32(state, i),
    read16(state, i),
    read8(state, i)))
end
