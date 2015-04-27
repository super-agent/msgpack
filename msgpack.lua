exports.name = "creationix/msgpack"
exports.version = "1.0.0"
exports.description = "A pure lua implementation of the msgpack format."
exports.homepage = "https://github.com/creationix/msgpack-lua"
exports.keywords = {"codec", "msgpack"}

local floor = math.floor
local ceil = math.ceil
local char = string.char
local bit = require('bit')
local rshift = bit.rshift
local band = bit.band
local bor = bit.bor
local concat = table.concat

local function encode(value)
  local t = type(value)
  if t == "nil" then
    return "\xc0"
  elseif t == "boolean" then
    return value and "\xc3" or "\xc2"
  elseif t == "number" then
    if floor(value) == value then
      if value >= 0 then
        if value < 0x80 then
          return char(value)
        elseif value < 0x100 then
          return "\xcc"
            .. char(value)
        elseif value < 0x10000 then
          return "\xcd"
            .. char(rshift(value, 8))
            .. char(band(value, 0xff))
        elseif value < 0x100000000 then
          return "\xce"
            .. char(rshift(value, 24))
            .. char(band(rshift(value, 16), 0xff))
            .. char(band(rshift(value, 8), 0xff))
            .. char(band(value, 0xff))
        else
          local high = floor(value / 0x100000000)
          local low = value % 0x100000000
          return "\xcf"
            .. char(rshift(high, 24))
            .. char(band(rshift(high, 16), 0xff))
            .. char(band(rshift(high, 8), 0xff))
            .. char(band(high, 0xff))
            .. char(rshift(low, 24))
            .. char(band(rshift(low, 16), 0xff))
            .. char(band(rshift(low, 8), 0xff))
            .. char(band(low, 0xff))
        end
      else
        if value >= -0x20 then
          return char(0x100 + value)
        elseif value >= -0x80 then
          return "\xd0" .. char(0x100 + value)
        elseif value >= -0x8000 then
          local num = 0x10000 + value
          return "\xd1"
            .. char(rshift(num, 8))
            .. char(band(num, 0xff))
        elseif value >= -0x80000000 then
          local num = 0x100000000 + value
          return "\xd2"
            .. char(rshift(num, 24))
            .. char(band(rshift(num, 16), 0xff))
            .. char(band(rshift(num, 8), 0xff))
            .. char(band(num, 0xff))
        elseif value >= -0x100000000 then
          local num = 0x100000000 + value
          return "\xd3\xff\xff\xff\xff"
            .. char(rshift(num, 24))
            .. char(band(rshift(num, 16), 0xff))
            .. char(band(rshift(num, 8), 0xff))
            .. char(band(num, 0xff))
        else
          local high = ceil(value / 0x100000000)
          local low = value - high * 0x100000000
          if low == 0 then
            high = 0x100000000 + high
          else
            high = 0xffffffff + high
            low = 0x100000000 + low
          end
          return "\xd3"
            .. char(rshift(high, 24))
            .. char(band(rshift(high, 16), 0xff))
            .. char(band(rshift(high, 8), 0xff))
            .. char(band(high, 0xff))
            .. char(rshift(low, 24))
            .. char(band(rshift(low, 16), 0xff))
            .. char(band(rshift(low, 8), 0xff))
            .. char(band(low, 0xff))
        end
      end
    else
      error("TODO: floating point numbers")
    end
  elseif t == "string" then
    local l = #value
    if l < 0x20 then
      return char(bor(0xa0, l)) .. value
    elseif l < 0x100 then
      return "\xd9" .. char(l) .. value
    elseif l < 0x10000 then
      return "\xda"
        .. char(rshift(l, 8))
        .. char(band(l, 0xff))
        .. value
    elseif l < 0x100000000 then
      return "\xdb"
        .. char(rshift(l, 24))
        .. char(band(rshift(l, 16), 0xff))
        .. char(band(rshift(l, 8), 0xff))
        .. char(band(l, 0xff))
        .. value
    else
      error("String too long: " .. l .. " bytes")
    end
  elseif t == "table" then
    local isMap = false
    local index = 1
    for key, value in pairs(value) do
      if type(key) ~= "number" or key ~= index then
        isMap = true
        break
      else
        index = index + 1
      end
    end
    if isMap then
      error("TODO: map")
    else
      local parts = {}
      local l = #value
      for i = 1, l do
        parts[i] = encode(value[i])
      end
      value = concat(parts)
      if l < 0x10 then
        return char(bor(0x90, l)) .. value
      elseif l < 0x10000 then
        return "\xdc"
          .. char(rshift(l, 8))
          .. char(band(l, 0xff))
          .. value
      elseif l < 0x100000000 then
        return "\xdd"
          .. char(rshift(l, 24))
          .. char(band(rshift(l, 16), 0xff))
          .. char(band(rshift(l, 8), 0xff))
          .. char(band(l, 0xff))
          .. value
      else
        error("Array too long: " .. l .. "items")
      end
    end
  else
    error("Unknown type: " .. t)
  end
end
exports.encode = encode

function exports.decode(data)
end
