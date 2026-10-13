#!/bin/sh
# Runs every headless test against the game's source. Set LUA to another
# interpreter to test it too, e.g. a Lua built with LUA_32BITS (the
# Playdate's number size):  LUA=~/lua32 tools/sim/run.sh
set -e
cd "$(dirname "$0")"
LUA=${LUA:-lua}
SRC=../../source
$LUA ../story_check.lua 2000 --source $SRC | tail -1
$LUA unit_items.lua $SRC
$LUA unit_rules.lua $SRC
$LUA unit_gates.lua $SRC 200
$LUA unit_polish.lua $SRC
$LUA unit_drops.lua $SRC
$LUA unit_layers.lua $SRC
$LUA stress.lua $SRC 500 | tail -2
wins=0
for seed in $(seq 1 30); do
	if $LUA play.lua $SRC $seed - - god 2>/dev/null | grep -q "won true"; then wins=$((wins + 1)); fi
done
echo "bot (no enemies): won $wins/30"
