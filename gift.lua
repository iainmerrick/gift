#!/usr/bin/env luajit

bit = require("bit")
ffi = require("ffi")
io = require("io")
string = require("string")

functions = require("functions")
machine = require("machine")
memory = require("memory")
oo = require("oo")
utils = require("utils")

local file = io.open("test/Advent.ulx", "r")
local size = file:seek("end")
file:seek("set", 0)
assert(bit.band(size, 3) == 0, "Size must be a multiple of 4!")
size = size / 4
local vm = machine.fromFile(file, size)
file:close()

local s = utils.Joiner("\n")
functions.parseFunction(vm:reader(vm.startFunc)):toCode(s)
functions.parseFunction(vm:reader(72)):toCode(s)
print(s)
