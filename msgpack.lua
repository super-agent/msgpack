exports.name = "creationix/msgpack"
exports.version = "1.0.0"
exports.description = "A pure lua implementation of the msgpack format."
exports.homepage = "https://github.com/creationix/msgpack-lua"
exports.keywords = {"codec", "msgpack"}

local floor = math.floor
local ceil = math.ceil
local char = string.char
local byte = string.byte
local bit = require('bit')
local rshift = bit.rshift
local lshift = bit.lshift
local band = bit.band
local bor = bit.bor
local concat = table.concat

local function uint16(num)
  return char(rshift(num, 8))
    .. char(band(num, 0xff))
end

local function uint32(num)
  return char(rshift(num, 24))
    .. char(band(rshift(num, 16), 0xff))
    .. char(band(rshift(num, 8), 0xff))
    .. char(band(num, 0xff))
end

local function uint64(num)
  return uint32(floor(num / 0x100000000))
    .. uint32(num % 0x100000000)
end

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
          return "\xcc" .. char(value)
        elseif value < 0x10000 then
          return "\xcd" .. uint16(value)
        elseif value < 0x100000000 then
          return "\xce" .. uint32(value)
        else
          return "\xcf" .. uint64(value)
        end
      else
        if value >= -0x20 then
          return char(0x100 + value)
        elseif value >= -0x80 then
          return "\xd0" .. char(0x100 + value)
        elseif value >= -0x8000 then
          return "\xd1" .. uint16(0x10000 + value)
        elseif value >= -0x80000000 then
          return "\xd2" .. uint32(0x100000000 + value)
        elseif value >= -0x100000000 then
          return "\xd3\xff\xff\xff\xff"
            .. uint32(0x100000000 + value)
        else
          local high = ceil(value / 0x100000000)
          local low = value - high * 0x100000000
          if low == 0 then
            high = 0x100000000 + high
          else
            high = 0xffffffff + high
            low = 0x100000000 + low
          end
          return "\xd3" .. uint32(high) .. uint32(low)
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
      return "\xda" .. uint16(l) .. value
    elseif l < 0x100000000 then
      return "\xdb" .. uint32(l) .. value
    else
      error("String too long: " .. l .. " bytes")
    end
  elseif t == "table" then
    local isMap = false
    local index = 1
    for key in pairs(value) do
      if type(key) ~= "number" or key ~= index then
        isMap = true
        break
      else
        index = index + 1
      end
    end
    if isMap then
      local count = 0
      local parts = {}
      for key, part in pairs(value) do
        parts[#parts + 1] = encode(key)
        parts[#parts + 1] = encode(part)
        count = count + 1
      end
      value = concat(parts)
      if count < 16 then
        return char(bor(0x80, count)) .. value
      elseif count < 0x10000 then
        return "\xde" .. uint16(count) .. value
      elseif count < 0x100000000 then
        return "\xdf" .. uint32(count) .. value
      else
        error("map too big: " .. count)
      end
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
        return "\xdc" .. uint16(l) .. value
      elseif l < 0x100000000 then
        return "\xdd" .. uint32(l) .. value
      else
        error("Array too long: " .. l .. "items")
      end
    end
  else
    error("Unknown type: " .. t)
  end
end
exports.encode = encode

local function decode(data)
  local c = byte(data, 1)
  if c < 0x80 then
    return c
  elseif c >= 0xe0 then
    return c - 0x100
  elseif c < 0x90 then
    error("TODO: fixmap")
  elseif c < 0xa0 then
    error("TODO: fixarray")
  elseif c < 0xc0 then
    error("TODO: fixstring")
  elseif c == 0xc0 then
    return nil
  elseif c == 0xc1 then
    return nil, "Invalid type 0xc1"
  elseif c == 0xc2 then
    return false
  elseif c == 0xc3 then
    return true
  elseif c == 0xcc then
    return byte(data, 2)
  elseif c == 0xcd then
    return bor(
      lshift(byte(data, 2), 8),
      byte(data, 3))
  elseif c == 0xce then
    return bor(
      lshift(byte(data, 2), 24),
      lshift(byte(data, 3), 16),
      lshift(byte(data, 4), 8),
      byte(data, 5)) % 0x100000000
  elseif c == 0xcf then
    return (bor(
      lshift(byte(data, 2), 24),
      lshift(byte(data, 3), 16),
      lshift(byte(data, 4), 8),
      byte(data, 5)) % 0x100000000) * 0x100000000
      + (bor(
      lshift(byte(data, 6), 24),
      lshift(byte(data, 7), 16),
      lshift(byte(data, 8), 8),
      byte(data, 9)) % 0x100000000)
  elseif c == 0xd0 then
    local num = byte(data, 2)
    return num >= 0x80 and (num - 0x100) or num
  elseif c == 0xd1 then
    local num = bor(
      lshift(byte(data, 2), 8),
      byte(data, 3))
    return num >= 0x8000 and (num - 0x10000) or num
  elseif c == 0xd2 then
    return bor(
      lshift(byte(data, 2), 24),
      lshift(byte(data, 3), 16),
      lshift(byte(data, 4), 8),
      byte(data, 5))
  elseif c == 0xd3 then
    local high = 0x100000000 - (
      byte(data, 2) * 0x1000000 +
      byte(data, 3) * 0x10000 +
      byte(data, 4) * 0x100 +
      byte(data, 5))
    local low = 0x100000000 - (
      byte(data, 6) * 0x1000000 +
      byte(data, 7) * 0x10000 +
      byte(data, 8) * 0x100 +
      byte(data, 9))
    p(high, low)

    -- if low == 0xffffffff then
      return high * 0x100000000 + low
    -- else
      -- return (high - 1) * 0x100000000 + low
    -- end
  else
    error("TODO: more types: " .. string.format("%02x", c))
  end
end
exports.decode = decode
