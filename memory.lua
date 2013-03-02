local memory = {}

bit = require("bit")

band = bit.band
bor = bit.bor
lshift = bit.lshift
rshift = bit.rshift

function memory.read32(g, addr)
  local word = g.memory[rshift(addr, 2)]
  local byte = band(addr, 3)
  if byte == 0 then
    return word
  end
  return bor(
    lshift(memory.read16(g, addr), 16),
    memory.read16(g, addr + 2))
end

function memory.read16(g, addr)
  local word = g.memory[rshift(addr, 2)]
  local byte = band(addr, 3)
  if byte == 0 then
    return rshift(word, 16)
  elseif byte == 2 then
    return band(word, 0xffff)
  end
  return bor(
    lshift(memory.read8(g, addr), 8),
    memory.read8(g, addr + 1))
end

function memory.read8(g, addr)
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

-- Unit test

mock = {
  memory = {
    [0] = 0x00112233;
    [1] = 0x44556677;
  }
}

assert(memory.read32(mock, 0) == 0x00112233)
assert(memory.read32(mock, 1) == 0x11223344)
assert(memory.read32(mock, 2) == 0x22334455)
assert(memory.read32(mock, 3) == 0x33445566)
assert(memory.read32(mock, 4) == 0x44556677)

assert(memory.read16(mock, 0) == 0x0011)
assert(memory.read16(mock, 1) == 0x1122)
assert(memory.read16(mock, 2) == 0x2233)
assert(memory.read16(mock, 3) == 0x3344)
assert(memory.read16(mock, 4) == 0x4455)
assert(memory.read16(mock, 5) == 0x5566)
assert(memory.read16(mock, 6) == 0x6677)

assert(memory.read8(mock, 0) == 0x00)
assert(memory.read8(mock, 1) == 0x11)
assert(memory.read8(mock, 2) == 0x22)
assert(memory.read8(mock, 3) == 0x33)
assert(memory.read8(mock, 4) == 0x44)
assert(memory.read8(mock, 5) == 0x55)
assert(memory.read8(mock, 6) == 0x66)
assert(memory.read8(mock, 7) == 0x77)

return memory
