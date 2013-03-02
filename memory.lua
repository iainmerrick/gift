local memory = {}

local bit = require("bit")

local band = bit.band
local bor = bit.bor
local bnot = bit.bnot
local lshift = bit.lshift
local rshift = bit.rshift
local tobit = bit.tobit

local xxxx = 0xffffffff
local xx__ = 0xffff0000
local __xx = 0x0000ffff
local x___ = 0xff000000
local _x__ = 0x00ff0000
local __x_ = 0x0000ff00
local ___x = 0x000000ff

function memory.read32(g, addr)
  local word = rshift(addr, 2)
  local byte = band(addr, 3)
  local val = g.memory[word]
  if byte == 0 then
    return tobit(val)
  end
  return bor(
    lshift(memory.read16(g, addr), 16),
    memory.read16(g, addr + 2))
end

function memory.read16(g, addr)
  local word = rshift(addr, 2)
  local byte = band(addr, 3)
  local val = g.memory[word]
  if byte == 0 then
    return rshift(val, 16)
  elseif byte == 2 then
    return band(val, __xx)
  end
  return bor(
    lshift(memory.read8(g, addr), 8),
    memory.read8(g, addr + 1))
end

function memory.read8(g, addr)
  local word = rshift(addr, 2)
  local byte = band(addr, 3)
  local val = g.memory[word]
  if byte == 0 then
    return rshift(val, 24)
  elseif byte == 1 then
    return band(rshift(val, 16), ___x)
  elseif byte == 2 then
    return band(rshift(val, 8), ___x)
  else
    return band(val, ___x)
  end
end

function memory.write32(g, addr, val)
  local word = rshift(addr, 2)
  local byte = band(addr, 3)
  if byte == 0 then
    g.memory[word] = val
    return
  end
  memory.write16(g, addr, rshift(val, 16))
  memory.write16(g, addr + 2, band(val, __xx))
end

function memory.write16(g, addr, val)
  val = band(val, __xx)
  local word = rshift(addr, 2)
  local byte = band(addr, 3)
  if byte == 0 then
    g.memory[word] = bor(
      lshift(val, 16),
      band(g.memory[word], __xx))
    return
  elseif byte == 2 then
    g.memory[word] = bor(
      band(g.memory[word], xx__),
      band(val, __xx))
    return
  end
  memory.write8(g, addr, rshift(val, 8))
  memory.write8(g, addr + 1, band(val, ___x))
end

function memory.write8(g, addr, val)
  val = band(val, ___x)
  local word = rshift(addr, 2)
  local byte = band(addr, 3)
  if byte == 0 then
    g.memory[word] = bor(
      lshift(val, 24),
      band(g.memory[word], bnot(x___)))
  elseif byte == 1 then
    g.memory[word] = bor(
      lshift(val, 16),
      band(g.memory[word], bnot(_x__)))
  elseif byte == 2 then
    g.memory[word] = bor(
      lshift(val, 8),
      band(g.memory[word], bnot(__x_)))
  else
    g.memory[word] = bor(
      val,
      band(g.memory[word], bnot(___x)))
  end
end

-- Unit test

mock = {
  memory = {
    [0] = 0x00112233;
    [1] = 0x44556677;
  }
}

assert(memory.read32(mock, 0) == tobit(0x00112233))
assert(memory.read32(mock, 1) == tobit(0x11223344))
assert(memory.read32(mock, 2) == tobit(0x22334455))
assert(memory.read32(mock, 3) == tobit(0x33445566))
assert(memory.read32(mock, 4) == tobit(0x44556677))

assert(memory.read16(mock, 0) == tobit(0x0011))
assert(memory.read16(mock, 1) == tobit(0x1122))
assert(memory.read16(mock, 2) == tobit(0x2233))
assert(memory.read16(mock, 3) == tobit(0x3344))
assert(memory.read16(mock, 4) == tobit(0x4455))
assert(memory.read16(mock, 5) == tobit(0x5566))
assert(memory.read16(mock, 6) == tobit(0x6677))

assert(memory.read8(mock, 0) == tobit(0x00))
assert(memory.read8(mock, 1) == tobit(0x11))
assert(memory.read8(mock, 2) == tobit(0x22))
assert(memory.read8(mock, 3) == tobit(0x33))
assert(memory.read8(mock, 4) == tobit(0x44))
assert(memory.read8(mock, 5) == tobit(0x55))
assert(memory.read8(mock, 6) == tobit(0x66))
assert(memory.read8(mock, 7) == tobit(0x77))

memory.write32(mock, 0, 0xa0a1a2a3)
assert(memory.read32(mock, 0) == tobit(0xa0a1a2a3))
assert(memory.read32(mock, 4) == tobit(0x44556677))
memory.write32(mock, 1, 0xb1b2b3b4)
assert(memory.read32(mock, 0) == tobit(0xa0b1b2b3))
assert(memory.read32(mock, 4) == tobit(0xb4556677))
memory.write32(mock, 2, 0xc2c3c4c5)
assert(memory.read32(mock, 0) == tobit(0xa0b1c2c3))
assert(memory.read32(mock, 4) == tobit(0xc4c56677))
memory.write32(mock, 3, 0xd3d4d5d6)
assert(memory.read32(mock, 0) == tobit(0xa0b1c2d3))
assert(memory.read32(mock, 4) == tobit(0xd4d5d677))
memory.write32(mock, 4, 0xe4e5e6e7)
assert(memory.read32(mock, 0) == tobit(0xa0b1c2d3))
assert(memory.read32(mock, 4) == tobit(0xe4e5e6e7))

return memory
