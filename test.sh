#!/bin/bash
set -e
if [ -z "$LUA" ];
then
  LUA=luvit/2.10.1 $0
  LUA=luajit/2.0.4 $0
  LUA=lua/5.1.5 $0
  LUA=lua/5.2.4 $0
  # LUA=lua/5.3.2 $0 # There is no bitop library for lua5.3
else
  echo "Testing on $LUA"
  source .travis/setenv.sh
  lit install luvit/pretty-print
  lua test.lua
fi
