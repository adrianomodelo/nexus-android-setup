#!/bin/bash
# Reconecta ADB ao celular via Tailscale
# Uso: ./adb-connect-celular.sh [IP] [PORTA]
#
# NOTA: A porta ADB pode mudar a cada reboot.
# Se falhar, verificar em: Configurações → Opções do desenvolvedor → Depuração sem fio

CELULAR_IP="${1:-100.112.7.26}"
CELULAR_PORT="${2:-36565}"

echo "Conectando ao celular ($CELULAR_IP:$CELULAR_PORT)..."
adb connect "$CELULAR_IP:$CELULAR_PORT"

echo ""
echo "Verificando modelo:"
adb -s "$CELULAR_IP:$CELULAR_PORT" shell getprop ro.product.model 2>/dev/null || echo "Falhou — verifique IP e porta"

echo ""
echo "Dispositivos ADB ativos:"
adb devices
