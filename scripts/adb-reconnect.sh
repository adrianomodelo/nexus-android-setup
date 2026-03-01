#!/bin/bash
# =============================================================================
# adb-reconnect.sh - Reconexão automática com Samsung Galaxy A34 (Nexus Android)
# Tenta múltiplas camadas: SSH (Tailscale) → ADB scan → ADB connect
# =============================================================================

set -euo pipefail

TAILSCALE_IP="100.109.120.68"
SSH_PORT=8022
SSH_USER="u0a454"
SSH_KEY="$HOME/.ssh/id_rsa"
ADB_PORT_RANGE="30000-44000"
DEVICE_SERIAL=""

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1"; }
ok()  { echo -e "${GREEN}✅ $1${NC}"; }
err() { echo -e "${RED}❌ $1${NC}"; }
warn(){ echo -e "${YELLOW}⚠️  $1${NC}"; }

# ==== Camada 1: Verificar Tailscale ====
check_tailscale() {
    log "Camada 1: Verificando Tailscale..."
    if ping -c 1 -W 2 "$TAILSCALE_IP" &>/dev/null; then
        ok "Tailscale OK ($TAILSCALE_IP respondendo)"
        return 0
    else
        err "Tailscale não respondendo"
        return 1
    fi
}

# ==== Camada 2: Verificar SSH ====
check_ssh() {
    log "Camada 2: Verificando SSH..."
    if ssh -p "$SSH_PORT" -i "$SSH_KEY" -o IdentitiesOnly=yes -o ConnectTimeout=5 -o BatchMode=yes \
       "${SSH_USER}@${TAILSCALE_IP}" "echo OK" &>/dev/null; then
        ok "SSH OK (porta $SSH_PORT)"
        return 0
    else
        err "SSH não acessível (porta $SSH_PORT)"
        return 1
    fi
}

# ==== Camada 3: Verificar ADB existente ====
check_adb_existing() {
    log "Camada 3: Verificando ADB conectado..."
    local device
    device=$(adb devices 2>/dev/null | grep "$TAILSCALE_IP" | grep -w "device" | awk '{print $1}')
    if [ -n "$device" ]; then
        DEVICE_SERIAL="$device"
        ok "ADB já conectado: $device"
        return 0
    else
        warn "Nenhuma conexão ADB ativa com $TAILSCALE_IP"
        return 1
    fi
}

# ==== Camada 4: Scan de portas ADB ====
# Retorna porta encontrada via stdout. Logs vão para stderr.
scan_adb_port() {
    log "Camada 4: Scanning portas ADB ($ADB_PORT_RANGE)..." >&2
    local start_port end_port found_port=""
    start_port=$(echo "$ADB_PORT_RANGE" | cut -d- -f1)
    end_port=$(echo "$ADB_PORT_RANGE" | cut -d- -f2)

    # Scan rápido com nmap se disponível
    if command -v nmap &>/dev/null; then
        log "  Usando nmap para scan rápido..." >&2
        found_port=$(nmap -p "$ADB_PORT_RANGE" --open -T4 "$TAILSCALE_IP" 2>/dev/null \
            | grep "^[0-9]" | grep "open" | head -1 | cut -d/ -f1)
    fi

    # Excluir porta 8022 (sshd Termux, não é ADB)
    if [ "$found_port" = "8022" ]; then
        found_port=""
    fi

    # Fallback: scan sequencial com timeout curto
    if [ -z "$found_port" ]; then
        log "  Scan sequencial (pode demorar ~30s)..." >&2
        for port in $(seq "$start_port" 100 "$end_port"); do
            local block_end=$((port + 99))
            [ "$block_end" -gt "$end_port" ] && block_end="$end_port"

            for p in $(seq "$port" "$block_end"); do
                if (echo >/dev/tcp/"$TAILSCALE_IP"/"$p") 2>/dev/null; then
                    found_port="$p"
                    break 2
                fi
            done
        done
    fi

    if [ -n "$found_port" ]; then
        ok "Porta ADB encontrada: $found_port" >&2
        echo "$found_port"
        return 0
    else
        err "Nenhuma porta ADB encontrada no range $ADB_PORT_RANGE" >&2
        return 1
    fi
}

# ==== Camada 5: Conectar ADB ====
connect_adb() {
    local port="$1"
    log "Camada 5: Conectando ADB em $TAILSCALE_IP:$port..."

    if adb connect "$TAILSCALE_IP:$port" 2>&1 | grep -q "connected"; then
        DEVICE_SERIAL="$TAILSCALE_IP:$port"
        ok "ADB conectado: $DEVICE_SERIAL"
        return 0
    else
        err "Falha ao conectar ADB em $TAILSCALE_IP:$port"
        return 1
    fi
}

# ==== Iniciar sshd via ADB (fallback) ====
start_sshd_via_adb() {
    if [ -z "$DEVICE_SERIAL" ]; then
        err "Sem conexão ADB para iniciar sshd"
        return 1
    fi

    log "Iniciando sshd no Termux via ADB..."
    # Abrir Termux
    adb -s "$DEVICE_SERIAL" shell "am start -n com.termux/.app.TermuxActivity" &>/dev/null
    sleep 2
    # Enviar comando para iniciar sshd
    adb -s "$DEVICE_SERIAL" shell "input text 'sshd'"
    sleep 0.5
    adb -s "$DEVICE_SERIAL" shell "input keyevent KEYCODE_ENTER"
    sleep 2

    # Verificar se SSH agora funciona
    if check_ssh; then
        ok "sshd iniciado com sucesso via ADB"
        return 0
    else
        warn "sshd pode ter iniciado mas SSH ainda não responde"
        return 1
    fi
}

# ==== Status completo ====
show_status() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo "  📱 Nexus Android - Status de Conexão"
    echo "═══════════════════════════════════════════"
    echo ""

    local tailscale_ok=false ssh_ok=false adb_ok=false

    check_tailscale && tailscale_ok=true
    check_ssh && ssh_ok=true
    check_adb_existing && adb_ok=true

    echo ""
    echo "───────────────────────────────────────────"
    echo -e "  Tailscale: $([ "$tailscale_ok" = true ] && echo -e "${GREEN}ONLINE${NC}" || echo -e "${RED}OFFLINE${NC}")"
    echo -e "  SSH:       $([ "$ssh_ok" = true ] && echo -e "${GREEN}ONLINE${NC}" || echo -e "${RED}OFFLINE${NC}")"
    echo -e "  ADB:       $([ "$adb_ok" = true ] && echo -e "${GREEN}$DEVICE_SERIAL${NC}" || echo -e "${RED}DISCONNECTED${NC}")"
    echo "───────────────────────────────────────────"
    echo ""
}

# ==== Main ====
main() {
    echo ""
    log "🔄 Nexus Android Reconnect"
    echo ""

    # 1. Verificar Tailscale
    if ! check_tailscale; then
        err "Tailscale está offline. O celular pode estar desligado ou sem internet."
        err "Aguarde o boot completar ou verifique o dispositivo fisicamente."
        exit 1
    fi

    # 2. Verificar SSH
    if check_ssh; then
        ok "Tudo OK! SSH acessível via Tailscale."

        # Verificar ADB também (best-effort, não falha se ADB não conectar)
        if ! check_adb_existing; then
            warn "ADB desconectado. Scanning porta..."
            local port
            if port=$(scan_adb_port); then
                connect_adb "$port" || warn "ADB requer novo pareamento após reboot"
            else
                warn "ADB wireless indisponível (normal após reboot)"
            fi
        fi

        show_status
        exit 0
    fi

    # 3. SSH falhou — verificar ADB
    warn "SSH está down. Tentando via ADB..."

    if check_adb_existing; then
        # ADB conectado, tentar iniciar sshd
        start_sshd_via_adb
    else
        # ADB não conectado — scan de porta
        local port
        if port=$(scan_adb_port); then
            if connect_adb "$port"; then
                # ADB conectado, iniciar sshd
                start_sshd_via_adb
            fi
        else
            err "Todas as conexões falharam!"
            err "Verifique se o celular está ligado e com internet."
            exit 1
        fi
    fi

    show_status
}

# Executar
main "$@"
