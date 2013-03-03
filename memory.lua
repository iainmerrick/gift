local memory = {}

local bit = require("bit")

local oo = require("oo")

local band = bit.band
local bor = bit.bor
local bnot = bit.bnot
local lshift = bit.lshift
local rshift = bit.rshift
local tobit = bit.tobit

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
    return band(val, 0xffff)
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
    return band(rshift(val, 16), 0xff)
  elseif byte == 2 then
    return band(rshift(val, 8), 0xff)
  else
    return band(val, 0xff)
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
  memory.write16(g, addr + 2, band(val, 0xffff))
end

function memory.write16(g, addr, val)
  val = band(val, 0xffff)
  local word = rshift(addr, 2)
  local byte = band(addr, 3)
  if byte == 0 then
    g.memory[word] = bor(
      lshift(val, 16),
      band(g.memory[word], 0xffff))
    return
  elseif byte == 2 then
    g.memory[word] = bor(
      band(g.memory[word], 0xffff0000),
      band(val, 0xffff))
    return
  end
  memory.write8(g, addr, rshift(val, 8))
  memory.write8(g, addr + 1, band(val, 0xff))
end

function memory.write8(g, addr, val)
  val = band(val, 0xff)
  local word = rshift(addr, 2)
  local byte = band(addr, 3)
  if byte == 0 then
    g.memory[word] = bor(
      lshift(val, 24),
      band(g.memory[word], bnot(0xff000000)))
  elseif byte == 1 then
    g.memory[word] = bor(
      lshift(val, 16),
      band(g.memory[word], bnot(0x00ff0000)))
  elseif byte == 2 then
    g.memory[word] = bor(
      lshift(val, 8),
      band(g.memory[word], bnot(0x0000ff00)))
  else
    g.memory[word] = bor(
      val,
      band(g.memory[word], bnot(0xff)))
  end
end

memory.Reader = oo.Class()

function memory.Reader:init(g, addr)
  self._g = g
  self._addr = addr
end

function memory.Reader:addr()
  return self._addr
end

function memory.Reader:peek8()
  return memory.read8(self._g, self._addr)
end

function memory.Reader:peek16()
  return memory.read16(self._g, self._addr)
end

function memory.Reader:peek32()
  return memory.read32(self._g, self._addr)
end

function memory.Reader:read8()
  self._addr = self._addr + 1
  return memory.read8(self._g, self._addr - 1)
end

function memory.Reader:read16()
  self._addr = self._addr + 2
  return memory.read16(self._g, self._addr - 2)
end

function memory.Reader:read32()
  self._addr = self._addr + 4
  return memory.read32(self._g, self._addr - 4)
end

-- Unit test

local mock = {
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

local r = memory.Reader(mock, 0)
assert(r:addr() == 0)
assert(r:read8() == tobit(0x00))
assert(r:addr() == 1)
assert(r:peek8() == tobit(0x11))
assert(r:peek16() == tobit(0x1122))
assert(r:peek32() == tobit(0x11223344))
assert(r:read16() == tobit(0x1122))
assert(r:read32() == tobit(0x33445566))
assert(r:read8() == tobit(0x77))
assert(r:addr() == 8)

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
