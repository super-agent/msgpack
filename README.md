# msgpack-lua

[![Build Status](https://travis-ci.org/super-agent/msgpack.svg?branch=master)](https://travis-ci.org/super-agent/msgpack)

Luajit implementation of msgpack format

Currently this module implements a subset of the msgpack v5 protocol.

It can encode and decode, integers, nil, booleans, strings, arrays, and maps.

```lua
local msgpack = require('msgpack')

local data = msgpack.encode({1,2,3})
local decoded = msgpack.decode(data, 0)
```

## msgpack.encode(value) -> data

To encode a value, pass in the raw lua value and a string will be returned
containing the encoded binary data.

## msgpack.decode(data, offset) -> value, bytes

To decode, pass in the data and an offset to start at (normally 0).
It will return the decoded value along with how many bytes were consumed.
