#!/bin/bash

TARGET=$1

OUTPUT=$(./vault_sweep.sh "$TARGET")

echo "$OUTPUT"

if echo "$OUTPUT" | grep -q "\[WARN\]"
then
    echo "ALERT: Dangerous files detected!"
      notify-send \
    "Vault Sweep Alert" \
    "Dangerous scripts detected"


    echo "$OUTPUT" >> logs/watchdog_alerts.log
fi
