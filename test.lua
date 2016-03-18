local encode = require('./msgpack').encode
local decode = require('./msgpack').decode
local colorize = require('pretty-print').colorize
local dump = require('pretty-print').dump

local function tabrep(num)
  local tab = {}
  for i = 1, num do
    tab[i] = 64
  end
  return tab
end

local function maprep(num)
  local map = {}
  for i = 1, num do
    map[i - 1] = 64
  end
  return map
end

local tests = {
    -- Nil format stores nil
    nil,                "\xc0",

    -- Bool format family stores false or true
    false,              "\xc2",
    true,               "\xc3",

    -- positive fixnum stores 7-bit positive integer
    0x0,                "\x00",
    0x1,                "\x01",
    0x4,                "\x04",
    0x10,               "\x10",
    0x40,               "\x40",
    0x7f,               "\x7f",
    -- uint 8 stores a 8-bit unsigned integer
    0x80,               "\xcc\x80",
    0xff,               "\xcc\xff",
    -- uint 16 stores a 16-bit big-endian unsigned integer
    0x100,              "\xcd\x01\x00",
    0x200,              "\xcd\x02\x00",
    0x400,              "\xcd\x04\x00",
    0x800,              "\xcd\x08\x00",
    0x1000,             "\xcd\x10\x00",
    0x2000,             "\xcd\x20\x00",
    0x4000,             "\xcd\x40\x00",
    0x7fff,             "\xcd\x7f\xff",
    0x8000,             "\xcd\x80\x00",
    0xffff,             "\xcd\xff\xff",
    -- uint 32 stores a 32-bit big-endian unsigned integer
    0x10000,            "\xce\x00\x01\x00\x00",
    0x7fffffff,         "\xce\x7f\xff\xff\xff",
    0x80000000,         "\xce\x80\x00\x00\x00",
    0xffffffff,         "\xce\xff\xff\xff\xff",
    -- uint 64 stores a 64-bit big-endian unsigned integer
    0x100000000,        "\xcf\x00\x00\x00\x01\x00\x00\x00\x00",
    0x100000001,        "\xcf\x00\x00\x00\x01\x00\x00\x00\x01",
    0x1ffffffff,        "\xcf\x00\x00\x00\x01\xff\xff\xff\xff",
    0x1000000000,       "\xcf\x00\x00\x00\x10\x00\x00\x00\x00",
    0x1000000001,       "\xcf\x00\x00\x00\x10\x00\x00\x00\x01",
    0x1fffffffff,       "\xcf\x00\x00\x00\x1f\xff\xff\xff\xff",
    0x10000000000,      "\xcf\x00\x00\x01\x00\x00\x00\x00\x00",
    0x10000000001,      "\xcf\x00\x00\x01\x00\x00\x00\x00\x01",
    0x1ffffffffff,      "\xcf\x00\x00\x01\xff\xff\xff\xff\xff",
    0x100000000000,     "\xcf\x00\x00\x10\x00\x00\x00\x00\x00",
    0x100000000001,     "\xcf\x00\x00\x10\x00\x00\x00\x00\x01",
    0x1fffffffffff,     "\xcf\x00\x00\x1f\xff\xff\xff\xff\xff",
    0x1000000000000,    "\xcf\x00\x01\x00\x00\x00\x00\x00\x00",
    0x1000000000001,    "\xcf\x00\x01\x00\x00\x00\x00\x00\x01",
    0x1ffffffffffff,    "\xcf\x00\x01\xff\xff\xff\xff\xff\xff",
    0x10000000000000,   "\xcf\x00\x10\x00\x00\x00\x00\x00\x00",
    0x10000000000001,   "\xcf\x00\x10\x00\x00\x00\x00\x00\x01",
    0x1fffffffffffff,   "\xcf\x00\x1f\xff\xff\xff\xff\xff\xff",
    0x20000000000000,   "\xcf\x00\x20\x00\x00\x00\x00\x00\x00",
    -- Lua numbers are no longer precise after this point.
    0x40000000000000,   "\xcf\x00\x40\x00\x00\x00\x00\x00\x00",
    0x80000000000000,   "\xcf\x00\x80\x00\x00\x00\x00\x00\x00",
    0x100000000000000,  "\xcf\x01\x00\x00\x00\x00\x00\x00\x00",
    0x200000000000000,  "\xcf\x02\x00\x00\x00\x00\x00\x00\x00",
    0x400000000000000,  "\xcf\x04\x00\x00\x00\x00\x00\x00\x00",
    0x800000000000000,  "\xcf\x08\x00\x00\x00\x00\x00\x00\x00",
    0x1000000000000000, "\xcf\x10\x00\x00\x00\x00\x00\x00\x00",
    0x2000000000000000, "\xcf\x20\x00\x00\x00\x00\x00\x00\x00",
    0x4000000000000000, "\xcf\x40\x00\x00\x00\x00\x00\x00\x00",
    0x8000000000000000, "\xcf\x80\x00\x00\x00\x00\x00\x00\x00",
    0xf000000000000000, "\xcf\xf0\x00\x00\x00\x00\x00\x00\x00",
    0xff00000000000000, "\xcf\xff\x00\x00\x00\x00\x00\x00\x00",
    0xffff000000000000, "\xcf\xff\xff\x00\x00\x00\x00\x00\x00",
    0xffffff0000000000, "\xcf\xff\xff\xff\x00\x00\x00\x00\x00",
    0xffffffff00000000, "\xcf\xff\xff\xff\xff\x00\x00\x00\x00",
    0xffffffffff000000, "\xcf\xff\xff\xff\xff\xff\x00\x00\x00",
    0xffffffffffff0000, "\xcf\xff\xff\xff\xff\xff\xff\x00\x00",
    0xfffffffffffff000, "\xcf\xff\xff\xff\xff\xff\xff\xf0\x00",
    0xfffffffffffff800, "\xcf\xff\xff\xff\xff\xff\xff\xf8\x00",
    -- negative fixnum stores 5-bit negative integer
    -0x1,               "\xff",
    -0x2,               "\xfe",
    -0x1f,              "\xe1",
    -0x20,              "\xe0",
    -- int 8 stores a 8-bit signed integer
    -0x21,              "\xd0\xdf",
    -0x7f,              "\xd0\x81",
    -0x80,              "\xd0\x80",
    -- int 16 stores a 16-bit big-endian signed integer
    -0x81,              "\xd1\xff\x7f",
    -0x7fff,            "\xd1\x80\x01",
    -0x8000,            "\xd1\x80\x00",
    -- int 32 stores a 32-bit big-endian signed integer
    -0x8001,            "\xd2\xff\xff\x7f\xff",
    -0x10000,           "\xd2\xff\xff\x00\x00",
    -0x10001,           "\xd2\xff\xfe\xff\xff",
    -0x7fffffff,        "\xd2\x80\x00\x00\x01",
    -0x80000000,        "\xd2\x80\x00\x00\x00",
    -- int 64 stores a 64-bit big-endian signed integer
    -0x80000001,        "\xd3\xff\xff\xff\xff\x7f\xff\xff\xff",
    -0xffffffff,        "\xd3\xff\xff\xff\xff\x00\x00\x00\x01",
    -0x100000000,       "\xd3\xff\xff\xff\xff\x00\x00\x00\x00",
    -0x100000001,       "\xd3\xff\xff\xff\xfe\xff\xff\xff\xff",
    -0xfffffffff,       "\xd3\xff\xff\xff\xf0\x00\x00\x00\x01",
    -0x1000000000,      "\xd3\xff\xff\xff\xf0\x00\x00\x00\x00",
    -0x1000000001,      "\xd3\xff\xff\xff\xef\xff\xff\xff\xff",
    -0xffffffffff,      "\xd3\xff\xff\xff\x00\x00\x00\x00\x01",
    -0x10000000000,     "\xd3\xff\xff\xff\x00\x00\x00\x00\x00",
    -0x10000000001,     "\xd3\xff\xff\xfe\xff\xff\xff\xff\xff",
    -0xfffffffffff,     "\xd3\xff\xff\xf0\x00\x00\x00\x00\x01",
    -0x100000000000,    "\xd3\xff\xff\xf0\x00\x00\x00\x00\x00",
    -0x100000000001,    "\xd3\xff\xff\xef\xff\xff\xff\xff\xff",
    -0xffffffffffff,    "\xd3\xff\xff\x00\x00\x00\x00\x00\x01",
    -0x1000000000000,   "\xd3\xff\xff\x00\x00\x00\x00\x00\x00",
    -0x1000000000001,   "\xd3\xff\xfe\xff\xff\xff\xff\xff\xff",
    -- fixstr stores a byte array whose length is upto 31 bytes
    "",                 "\xa0",
    "a",                "\xa1a",
    "Hello World\n",    "\xacHello World\n",
    string.rep("@", 0x1f), "\xbf" .. string.rep("@", 0x1f),
    -- str 8 stores a byte array whose length is upto (2^8)-1 bytes
    string.rep("@", 0x20), "\xd9\x20" .. string.rep("@", 0x20),
    string.rep("@", 0xff), "\xd9\xff" .. string.rep("@", 0xff),
    -- str 16 stores a byte array whose length is upto (2^16)-1 bytes
    string.rep("@", 0x100), "\xda\x01\x00" .. string.rep("@", 0x100),
    string.rep("@", 0xffff), "\xda\xff\xff" .. string.rep("@", 0xffff),
    -- str 32 stores a byte array whose length is upto (2^32)-1 bytes
    string.rep("@", 0x10000), "\xdb\x00\x01\x00\x00" .. string.rep("@", 0x10000),

    -- fixarray stores an array whose length is upto 15 elements:
    {},                 "\x90",
    {0},                "\x91\x00",
    {0,0,0,0,0},        "\x95\x00\x00\x00\x00\x00",
    {{{}}},             "\x91\x91\x90",
    tabrep(15),         "\x9f" .. string.rep("@", 15),
    -- array 16 stores an array whose length is upto (2^16)-1 elements
    tabrep(16),         "\xdc\x00\x10" .. string.rep("@", 16),
    tabrep(0xffff),     "\xdc\xff\xff" .. string.rep("@", 0xffff),
    -- array 32 stores an array whose length is upto (2^32)-1 elements
    tabrep(0x10000),    "\xdd\x00\x01\x00\x00" .. string.rep("@", 0x10000),
    tabrep(0x1ffff),    "\xdd\x00\x01\xff\xff" .. string.rep("@", 0x1ffff),
    -- These are really slow tests, but pass
    -- tabrep(0x100000),    "\xdd\x00\x10\x00\x00" .. string.rep("@", 0x100000),
    -- tabrep(0x1000000),    "\xdd\x01\x00\x00\x00" .. string.rep("@", 0x1000000),

    {name="Tim"},      "\x81\xa4name\xa3Tim",
    {[{{}}]={{}}},     "\x81\x91\x90\x91\x90",
    {[0]=0,[1]=1,[2]=2}, "\x83\x00\x00\x01\x01\x02\x02",
    maprep(15),        "\x8f\x00@\x01@\x02@\x03@\x04@\x05@\x06@\x07@\x08@\x09@\x0a@\x0b@\x0c@\x0d@\x0e@",
    maprep(16),        "\xde\x00\x10\x00@\x01@\x02@\x03@\x04@\x05@\x06@\x07@\x08@\x09@\x0a@\x0b@\x0c@\x0d@\x0e@\x0f@",
    3.1415926535898,   "\xCB\x40\x09\x21\xFB\x54\x44\x2D\x28",
    1/0,               "\xCA\x7F\x80\x00\x00",
    -1/0,              "\xCA\xFF\x80\x00\x00",
    0/0,               "\xCA\xFF\xC0\x00\x00",

}

local patt = string.rep("@", 10) .. "*"

local function pretty(value)
  local t = type(value)
  if t == "number" then
    if value ~= value or value ~= math.floor(value) or value == math.huge or value == -math.huge then
      return colorize("number", tostring(value))
    end
    if value < 0 then
      return colorize("number", string.format("-0x%x", -value))
    end
    return colorize("number", string.format("0x%x", value))
  elseif t == "string" then
    return dump(value):gsub(patt, function (m)
      return (colorize("nil", "[", "string") .. "@x" .. #m .. colorize("nil", "]", "string"))
    end)
  elseif t == "table" and #value > 100 then
    return colorize("nil", "[", "table") .. "table:" .. #value .. colorize("nil", "]")
  end
  return dump(value)
end

print("Encoding tests...")
for i = 1, #tests, 2 do
  local input, output = tests[i], tests[i + 1]
  local actual = encode(input)
  if actual == output then
    print("Encode Pass: " .. pretty(input) .. " -> " .. pretty(output))
  else
    print("Encode Fail: " .. pretty(input) .. "\n  expected: " .. pretty(output) .. "\n  actual:   " .. pretty(actual))
    -- print(string.format("'" .. string.rep("\\x%02X", #actual) .. "'", string.byte(actual, 1, #actual)))
    return -1
  end
  input, output = output, input
  local len
  actual, len = decode(input, 0)
  if dump(actual) == dump(output) and len == #input then
    print("Decode Pass: " .. pretty(input) .. " -> " .. pretty(output))
  else
    print("Decode Fail: " .. pretty(input) .. "\n  expected: " .. pretty(output) .. "\n  actual:   " .. pretty(actual) .. "\n  len:      " .. dump(len))
    return -1
  end
end
