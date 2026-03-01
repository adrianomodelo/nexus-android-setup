#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# Nexus Health Process - Bash wrapper
# Runs daily at 08:05 via cron in Termux
# Calls Node.js to process Health Connect JSON files and send to n8n webhook
# ==============================================================================

LOG="/sdcard/nexus_health_cron.log"
NODE="/data/data/com.termux/files/usr/bin/node"
SCRIPT="/sdcard/nexus_health_process.js"

echo "========================================" >> "$LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Health process started" >> "$LOG"

if [ ! -f "$NODE" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Node.js not found at $NODE" >> "$LOG"
  exit 1
fi

if [ ! -f "$SCRIPT" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Script not found at $SCRIPT" >> "$LOG"
  exit 1
fi

"$NODE" "$SCRIPT" >> "$LOG" 2>&1
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Health process completed successfully" >> "$LOG"
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Health process failed with exit code $EXIT_CODE" >> "$LOG"
fi

echo "" >> "$LOG"
