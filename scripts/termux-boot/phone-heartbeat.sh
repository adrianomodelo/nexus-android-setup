#!/data/data/com.termux/files/usr/bin/bash
# Phone heartbeat - envia ping a cada 30min para monitoramento

TIMESTAMP=$(date -Iseconds)
UPTIME=$(uptime 2>/dev/null | sed 's/.*up //' | sed 's/,.*//' || echo 'N/A')
BATTERY=$(dumpsys battery 2>/dev/null | grep level | awk '{print $2}' || echo '?')
TAILSCALE=$(ip addr show tailscale0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 || echo 'down')
SSHD=$(pgrep -x sshd > /dev/null && echo 'running' || echo 'stopped')

# Enviar para n8n webhook
curl -s -X POST "https://n8n.opsnx.com.br/webhook/phone-heartbeat" \
  -H 'Content-Type: application/json' \
  -d "{
    \"device\": \"SM-A346M\",
    \"timestamp\": \"${TIMESTAMP}\",
    \"uptime\": \"${UPTIME}\",
    \"battery\": \"${BATTERY}\",
    \"tailscale\": \"${TAILSCALE}\",
    \"sshd\": \"${SSHD}\"
  }" > /dev/null 2>&1

# Fallback: se n8n não responder, salvar localmente
if [ $? -ne 0 ]; then
  echo "${TIMESTAMP} | battery:${BATTERY}% | tailscale:${TAILSCALE} | sshd:${SSHD}" >> /sdcard/phone-heartbeat.log
fi
