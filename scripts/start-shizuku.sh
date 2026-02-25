#!/data/data/com.termux/files/usr/bin/bash
# Inicia servidor Shizuku via ADB
# Chamado pelo Termux:Boot no boot do Android e pelo .bashrc como fallback
#
# Uso: bash ~/scripts/start-shizuku.sh

sleep 5  # aguardar sistema estabilizar

# Verificar se já está rodando
if pgrep -f shizuku_server > /dev/null 2>&1; then
  echo "[Shizuku] já rodando"
  exit 0
fi

# Verificar se o script de start existe
if [ ! -f /data/local/tmp/shizuku_start.sh ]; then
  echo "[Shizuku] ERRO: /data/local/tmp/shizuku_start.sh não encontrado"
  echo "[Shizuku] Regenerar: ver README seção 10.2"
  exit 1
fi

sh /data/local/tmp/shizuku_start.sh &
sleep 3

pgrep -f shizuku_server > /dev/null && echo "[Shizuku] ✅ servidor iniciado" || echo "[Shizuku] ❌ falha ao iniciar"
