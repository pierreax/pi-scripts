#!/bin/bash
# Simple idle checker - run every 5 minutes via cron

IDLE_LIMIT=900  # 15 minutes
LOG_FILE="/var/log/retropie-idle.log"

# Get latest input time
latest_input=$(find /dev/input/event* -type c -printf "%T@ %p\n" 2>/dev/null | sort -n | tail -n 1 | awk '{print $1}')
now=$(date +%s)

if [ -z "$latest_input" ]; then
    exit 0
fi

idle_seconds=$(echo "$now - $latest_input" | bc | cut -d. -f1)

if [ "$idle_seconds" -ge "$IDLE_LIMIT" ]; then
    if pgrep -f emulationstation > /dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] No input for $idle_seconds seconds - stopping EmulationStation" >> "$LOG_FILE"
        pkill -TERM -f emulationstation
    fi
fi
