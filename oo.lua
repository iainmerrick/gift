local oo = {}

-- Basic instantiable classes, no inheritance.

local alloc = {}
function alloc:__call(...)
  obj = {}
  self.init(obj, ...)
  setmetatable(obj, self)
  return obj
end

function defaultInit(self, args)
  assert(args == nil, "Non-empty default args, probably bad")
end

function oo.Class()
  local class = {}
  class.__index = class
  class.init = defaultInit
  setmetatable(class, alloc)
  return class
end

-- Prototype objects. Calling a prototype creates a child instance.

local function copy(parent, child)
  child.__index = child
  child.__call = copy
  return setmetatable(child, parent)
end

local copier = {}
copier.__call = copy

function oo.Prototype(base)
  local proto = base or {}
  proto.__index = proto
  proto.__call = copy
  return setmetatable(proto, copier)
end

-- Unit test

local Foo = oo.Class()
function Foo:hello()
  return "hello"
end
function Foo:add1(n)
  return n + 1
end

local foo = Foo()
assert(foo:hello() == "hello")
assert(foo:add1(2) == 3)

local Bar = oo.Class()
function Bar:init(n)
  self.value = n or 0
end
function Bar:inc()
  self.value = self.value + 1
  return self.value
end

local bar1 = Bar()
local bar2 = Bar(10)
assert(bar1:inc() == 1)
assert(bar1:inc() == 2)
assert(bar2:inc() == 11)
assert(bar2:inc() == 12)

local Hat = oo.Prototype {
  name = "hat",
  desc = function(self)
    return self.colour .. " " .. self.name
  end
}
local RedHat = Hat { colour = "red" }
local BlueHat = Hat { colour = "blue" }
local RedBowler = RedHat { name = "bowler" }

assert(RedHat:desc() == "red hat")
assert(BlueHat:desc() == "blue hat")
assert(RedBowler:desc() == "red bowler")

return oo