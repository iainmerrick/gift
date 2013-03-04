local utils = {}

local oo = require("oo")

utils.Joiner = oo.Class("Joiner")

function utils.Joiner:init(sep)
  self._sep = sep
  self._data = {}
  self._prefixes = {""}
end

function utils.Joiner:prefix()
  return self._prefixes[#self._prefixes]
end

function utils.Joiner:pushPrefix(prefix)
  self._prefixes[#self._prefixes + 1] = self:prefix() .. prefix
  return self
end

function utils.Joiner:popPrefix()
  assert(#self._prefixes > 1)
  table.remove(self._prefixes)
  return self
end

function utils.Joiner:addFormat(fmt, ...)
  self:_add(string.format(fmt, ...))
  return self
end

function utils.Joiner:addIf(cond, s)
  if cond then
    self:_add(s)
  end
  return self
end

function utils.Joiner:addIfElse(cond, s1, s2)
  if cond then
    self:_add(s1)
  else
    self:_add(s2)
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
  if value then
    self._data[#self._data + 1] = self:prefix() .. tostring(value)
  end
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

local j2 = utils.Joiner("\n")
j2:add("1")
j2:pushPrefix("* ")
j2:add("1.1")
j2:pushPrefix("- ")
j2:add("1.1.1")
j2:popPrefix()
j2:add("1.2")
j2:popPrefix()
j2:add("2")
assert(tostring(j2) == [[1
* 1.1
* - 1.1.1
* 1.2
2]])

return utils
