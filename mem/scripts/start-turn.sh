#!/bin/bash
# Requirements Section: ### start-turn.sh file: mem/scripts/start-turn.sh
date -u +%s > "/tmp/$(id -u)-botz-turn-start"
if [ $? -ne 0 ]; then
    printf 'ERROR: Could not record the turn start epoch to /tmp; check /tmp is writable.\n' >&2
    exit 1
fi
