#!/data/data/com.termux/files/usr/bin/bash
# NX ADB Monitor - verifica wireless debugging e alerta se offline
# Cron: */15 * * * * bash /sdcard/nx_adb_monitor.sh
LOG=/sdcard/nx_adb_monitor.log

# Testar se alguma porta ADB responde localmente
ADB_PORT=$(ss -tlnp 2>/dev/null | grep -oP ':\K[0-9]+' | grep -E '^[3-5][0-9]{4}$' | head -1)
if [ -z "$ADB_PORT" ]; then
  echo "$(date): ADB OFFLINE - sem porta ADB detectada" >> $LOG
  # Alertar via Telegram
  curl -s -X POST "https://api.telegram.org/bot7580573651:AAGL1_pjvFQKlc9jCs2dVy2CdZ5E9_7QSsU/sendMessage" \
    -H 'Content-Type: application/json' \
    -d '{"chat_id": "5504780869", "text": "⚠️ ADB Wireless OFFLINE no A34!\nReativar manualmente em:\nConfiguracoes > Opcoes do desenvolvedor > Depuracao sem fio", "parse_mode": "HTML"}' > /dev/null 2>&1
fi
