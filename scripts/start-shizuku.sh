#!/data/data/com.termux/files/usr/bin/bash
# Inicia servidor Shizuku via UI (Android 11+ sem root)
# Chamado pelo Termux:Boot no boot do Android e pelo .bashrc como fallback
#
# Uso: bash ~/scripts/start-shizuku.sh
#
# NOTA: O método app_process (shizuku_start.sh) não funciona no Shizuku 13+ (classe obfuscada).
# Solução: abrir o app + tap automático no botão "Começar"
# Coordenadas válidas quando o servidor NÃO está rodando: (270, 1455)

sleep 5  # aguardar sistema estabilizar

# Verificar se já está rodando
if pgrep -f shizuku_server > /dev/null 2>&1; then
  echo "[Shizuku] já rodando"
  exit 0
fi

echo "[Shizuku] iniciando via UI..."

# Abrir o app Shizuku
am start -n moe.shizuku.privileged.api/moe.shizuku.manager.MainActivity > /dev/null 2>&1
sleep 4

# Tocar no botão 'Começar' (posição quando servidor NÃO está rodando)
input tap 270 1455
sleep 5

# Verificar resultado
if pgrep -f shizuku_server > /dev/null 2>&1; then
  echo "[Shizuku] ✅ servidor iniciado via UI"
else
  echo "[Shizuku] ❌ falha ao iniciar — abra o Shizuku manualmente"
fi
