local operands = {}

local oo = require("oo")

operands.Operand = oo.Class("Operand")

function operands.Operand:init(mode, value)
  self.mode = mode    -- Addressing mode (a Mode object)
  self.value = value  -- 32-bit value
end

function operands.Operand:tostring()
  return string.format("%s %x", self.mode.name, self.value)
end

function operands.Operand:toLoadCode()
  return self.mode:loadCode(self.value)
end

function operands.Operand:toStoreCode(var)
  return self.mode:storeCode(self.value, var)
end

local function Mode(name, size)
  assert(type(name) == "string")
  assert(type(size) == "number")
  return oo.Prototype() {
    name = name;
    parse = function(self, reader)
      local value
      if size == 0 then
        value = 0
      elseif size == 1 then
        value = reader:read8()
      elseif size == 2 then
        value = reader:read16()
      else
        value = reader:read32()
      end
      return operands.Operand(self, value)
    end;
    loadCode = function(self, value)
      assert(false, "Don't know how to load this operand!")
    end;
    storeCode = function(self, value, var)
      return nil
    end;
  }
end

local function ConstMode(size)
  return Mode("const", size) {
    loadCode = function(self, value)
      return value
    end;
  }
end

local function AddrMode(size)
  return Mode("addr", size) {
    loadCode = function(self, value)
      return "vm:read32(" .. value .. ")"
    end;
    storeCode = function(self, value, var)
      return "vm:write32(" .. value .. ", " .. var .. ")"
    end;
  }
end

local function RamMode(size)
  return Mode("ram", size) {
    loadCode = function(self, value)
      -- TODO: ramStart is a compile-time constant
      return "vm:read32(vm.ramStart() + " .. value .. ")"
    end;
    storeCode = function(self, value, var)
      return "vm:write32(vm.ramStart() + " .. value .. ", " .. var .. ")"
    end;
  }
end

local function StackMode(size)
  return Mode("stack", size) {
    loadCode = function(self, value)
      return "vm:pop()"
    end;
    storeCode = function(self, value, var)
      return "vm:push(" .. var .. ")"
    end;
  }
end

local function LocalMode(size)
  return Mode("local", size) {
    loadCode = function(self, value)
      return "vm:getLocal(" .. value .. ")"
    end;
    storeCode = function(self, value, var)
      return "vm:setLocal(" .. value .. ", " .. var .. ")"
    end;
  }
end

local MODES = {
  [0x0] = ConstMode(0),
  [0x1] = ConstMode(1),
  [0x2] = ConstMode(2),
  [0x3] = ConstMode(4),
  [0x4] = nil,
  [0x5] = AddrMode(1),
  [0x6] = AddrMode(2),
  [0x7] = AddrMode(4),
  [0x8] = StackMode(0),
  [0x9] = LocalMode(1),
  [0xa] = LocalMode(2),
  [0xb] = LocalMode(4),
  [0xc] = nil,
  [0xd] = RamMode(1),
  [0xe] = RamMode(2),
  [0xf] = RamMode(4),
}

function operands.parseOperand(mode, reader)
  return MODES[mode]:parse(reader)
end

return operands
