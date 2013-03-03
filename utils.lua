local utils = {}

local oo = require("oo")

utils.Joiner = oo.Class("Joiner")

function utils.Joiner:init(sep)
  self._sep = sep
  self._data = {}
end

function utils.Joiner:addFormat(fmt, ...)
  self:_add(string.format(fmt, ...))
  return self
end

function utils.Joiner:addIfElse(cond, a, b)
  if cond then
    self:_add(a)
  else
    self:_add(b)
  end
  return self
end

function utils.Joiner:addEach(seq)
  for i = 1,#seq do
    self:_add(seq[i])
  end
  return self
end

function utils.Joiner:add(...)
  local args = {...}
  for i = 1,#args do
    self:_add(args[i])
  end
  return self
end

function utils.Joiner:_add(value)
  self._data[#self._data + 1] = tostring(value)
end

function utils.Joiner:tostring()
  return table.concat(self._data, self._sep)
end

-- Unit test

local j = utils.Joiner(" ")
j:addFormat("%4d-%02d-%02d", 2013, 3, 3)
j:addIfElse(100 > 200, 100, 200)
j:addEach({"a", "b", "c"})
j:add("foo"):add("bar", "xyzzy")
assert(tostring(j) == "2013-03-03 200 a b c foo bar xyzzy")

return utils
