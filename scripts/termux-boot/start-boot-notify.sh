#!/data/data/com.termux/files/usr/bin/bash
# Esperar rede estabilizar
sleep 30

# Coletar informações
TIMESTAMP=$(date '+%d/%m/%Y %H:%M:%S')
UPTIME=$(uptime 2>/dev/null | sed 's/.*up /up /' | sed 's/,.*//' || echo 'N/A')

# Bateria via Termux API
BATTERY=$(termux-battery-status 2>/dev/null | grep '"percentage"' | grep -o '[0-9]*' || echo '?')

# Tailscale: verificar se responde via ping
if ping -c 1 -W 3 100.109.120.68 >/dev/null 2>&1; then
  TAILSCALE="100.109.120.68 (UP)"
else
  # Retry após mais 30s
  sleep 30
  if ping -c 1 -W 3 100.109.120.68 >/dev/null 2>&1; then
    TAILSCALE="100.109.120.68 (UP - delayed)"
  else
    TAILSCALE="DOWN"
  fi
fi

# Verificar sshd
SSHD=$(pgrep -x sshd >/dev/null 2>&1 && echo "RUNNING" || echo "STOPPED")

# Enviar notificação Telegram
BOT_TOKEN="7580573651:AAGL1_pjvFQKlc9jCs2dVy2CdZ5E9_7QSsU"
CHAT_ID="5504780869"

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  -d parse_mode="Markdown" \
  -d text="📱 *Nexus Android Boot*
🕐 ${TIMESTAMP}
📍 SM-A346M
⏱ ${UPTIME}
🌐 Tailscale: ${TAILSCALE}
🔋 Bateria: ${BATTERY}%
🔌 sshd: ${SSHD}"
