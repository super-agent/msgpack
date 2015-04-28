exports.name = "creationix/msgpack"
exports.version = "1.0.1"
exports.description = "A pure lua implementation of the msgpack format."
exports.homepage = "https://github.com/creationix/msgpack-lua"
exports.keywords = {"codec", "msgpack"}
exports.license = "MIT"

local floor = math.floor
local ceil = math.ceil
local char = string.char
local byte = string.byte
local sub = string.sub
local bit = require('bit')
local rshift = bit.rshift
local lshift = bit.lshift
local band = bit.band
local bor = bit.bor
local concat = table.concat

local function write16(num)
  return char(rshift(num, 8))
    .. char(band(num, 0xff))
end

local function write32(num)
  return char(rshift(num, 24))
    .. char(band(rshift(num, 16), 0xff))
    .. char(band(rshift(num, 8), 0xff))
    .. char(band(num, 0xff))
end

local function read16(data, offset)
  return bor(
    lshift(byte(data, offset), 8),
    byte(data, offset + 1))
end

local function read32(data, offset)
  return bor(
    lshift(byte(data, offset), 24),
    lshift(byte(data, offset + 1), 16),
    lshift(byte(data, offset + 2), 8),
    byte(data, offset + 3))
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
          return "\xcd" .. write16(value)
        elseif value < 0x100000000 then
          return "\xce" .. write32(value)
        else
          return "\xcf"
            .. write32(floor(value / 0x100000000))
            .. write32(value % 0x100000000)
        end
      else
        if value >= -0x20 then
          return char(0x100 + value)
        elseif value >= -0x80 then
          return "\xd0" .. char(0x100 + value)
        elseif value >= -0x8000 then
          return "\xd1" .. write16(0x10000 + value)
        elseif value >= -0x80000000 then
          return "\xd2" .. write32(0x100000000 + value)
        elseif value >= -0x100000000 then
          return "\xd3\xff\xff\xff\xff"
            .. write32(0x100000000 + value)
        else
          local high = ceil(value / 0x100000000)
          local low = value - high * 0x100000000
          if low == 0 then
            high = 0x100000000 + high
          else
            high = 0xffffffff + high
            low = 0x100000000 + low
          end
          return "\xd3" .. write32(high) .. write32(low)
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
      return "\xda" .. write16(l) .. value
    elseif l < 0x100000000 then
      return "\xdb" .. write32(l) .. value
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
        return "\xde" .. write16(count) .. value
      elseif count < 0x100000000 then
        return "\xdf" .. write32(count) .. value
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
        return "\xdc" .. write16(l) .. value
      elseif l < 0x100000000 then
        return "\xdd" .. write32(l) .. value
      else
        error("Array too long: " .. l .. "items")
      end
    end
  else
    error("Unknown type: " .. t)
  end
end
exports.encode = encode

local readmap, readarray

local function decode(data, offset)
  local c = byte(data, offset + 1)
  if c < 0x80 then
    return c, 1
  elseif c >= 0xe0 then
    return c - 0x100, 1
  elseif c < 0x90 then
    return readmap(band(c, 0xf), data, offset, offset + 1)
  elseif c < 0xa0 then
    return readarray(band(c, 0xf), data, offset, offset + 1)
  elseif c < 0xc0 then
    local len = 1 + band(c, 0x1f)
    return sub(data, offset + 2, offset + len), len
  elseif c == 0xc0 then
    return nil, 1
  elseif c == 0xc2 then
    return false, 1
  elseif c == 0xc3 then
    return true, 1
  elseif c == 0xcc then
    return byte(data, offset + 2), 2
  elseif c == 0xcd then
    return read16(data, offset + 2), 3
  elseif c == 0xce then
    return read32(data, offset + 2) % 0x100000000, 5
  elseif c == 0xcf then
    return (read32(data, offset + 2) % 0x100000000) * 0x100000000
      + (read32(data, offset + 6) % 0x100000000), 9
  elseif c == 0xd0 then
    local num = byte(data, offset + 2)
    return (num >= 0x80 and (num - 0x100) or num), 2
  elseif c == 0xd1 then
    local num = read16(data, offset + 2)
    return (num >= 0x8000 and (num - 0x10000) or num), 3
  elseif c == 0xd2 then
    return read32(data, offset + 2), 5
  elseif c == 0xd3 then
    local high = read32(data, offset + 2)
    local low = read32(data, offset + 6)
    if low < 0 then
      high = high + 1
    end
    return high * 0x100000000 + low, 9
  elseif c == 0xd9 then
    local len = 2 + byte(data, offset + 2)
    return sub(data, offset + 3, offset + len), len
  elseif c == 0xda then
    local len = 3 + read16(data, offset + 2)
    return sub(data, offset + 4, offset + len), len
  elseif c == 0xdb then
    local len = 5 + read32(data, offset + 2) % 0x100000000
    return sub(data, offset + 6, offset + len), len
  elseif c == 0xdc then
    return readarray(read16(data, offset + 2), data, offset, offset + 3)
  elseif c == 0xdd then
    return readarray(read32(data, offset + 2) % 0x100000000, data, offset, offset + 5)
  elseif c == 0xde then
    return readmap(read16(data, offset + 2), data, offset, offset + 3)
  elseif c == 0xdf then
    return readmap(read32(data, offset + 2) % 0x100000000, data, offset, offset + 5)
  else
    error("TODO: more types: " .. string.format("%02x", c))
  end
end
exports.decode = decode

function readarray(count, data, offset, start)
  local items = {}
  for i = 1, count do
    local len
    items[i], len = decode(data, start)
    start = start + len
  end
  return items, start - offset
end

function readmap(count, data, offset, start)
  local map = {}
  for _ = 1, count do
    local len, key
    key, len = decode(data, start)
    start = start + len
    map[key], len = decode(data, start)
    start = start + len
  end
  return map, start - offset
end
