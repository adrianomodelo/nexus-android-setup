# Nexus Android Setup

Documentação completa para configurar acesso ADB remoto ao celular Android (Samsung Galaxy A34) integrado ao ecossistema Nexus (VPS + n8n + Telegram).

## Objetivo

Permitir que o PC Home (ou qualquer máquina autorizada) controle o celular remotamente via **ADB over WiFi/Tailscale**, conceda permissões elevadas a apps, automatize leitura de dados de saúde do **Galaxy Watch 7** e integre tudo ao pipeline Nexus.

---

## Stack Envolvida

| Componente | Função |
|---|---|
| Samsung Galaxy A34 (SM-A346M) | Host principal — Android 16 |
| Galaxy Watch 7 | Fonte de dados de saúde |
| Samsung Health → Health Connect | Bridge nativa Watch → Android |
| Tasker | Orquestrador de automações no Android |
| TaskerHealthConnect (plugin) | Leitura do Health Connect via Tasker |
| Termux | Terminal Linux no Android + SSH server |
| Termux:Boot | Auto-start de scripts no boot do Android |
| Termux:API | Integração com recursos nativos do Android |
| Shizuku | Permissões elevadas (ADB-level) sem root |
| Tailscale | VPN mesh para acesso remoto seguro |
| ADB Wireless | Controle remoto e concessão de permissões |
| n8n (VPS Nexus) | Receptor de webhooks + processamento |
| Supabase | Persistência de dados históricos |
| Telegram / nexus-bot | Notificações e alertas |

---

## Pré-requisitos

### No PC (Linux)
```bash
sudo apt-get install -y adb
adb version  # Android Debug Bridge version 1.0.41+
```

### No Celular
- Android com **Opções do Desenvolvedor** disponíveis
- App **Tasker** instalado (pago, Google Play)
- App **TaskerHealthConnect** instalado (plugin gratuito, Google Play)
- App **Termux** instalado (F-Droid — versão Google Play está desatualizada)
- App **Tailscale** instalado e conectado à mesma tailnet

---

## 1. Habilitar ADB Wireless no Celular

### 1.1 Ativar Opções do Desenvolvedor
1. **Configurações → Sobre o telefone**
2. Toque **7 vezes** em **"Número da versão"**
3. Insira o PIN/padrão se solicitado
4. Mensagem: *"Você agora é um desenvolvedor!"*

### 1.2 Ativar Depuração Sem Fio
1. **Configurações → Opções do desenvolvedor**
2. Ativar **"Depuração sem fio"** (toggle ON)

### 1.3 Obter credenciais de emparelhamento
1. Tocar em **"Emparelhar dispositivo com código de emparelhamento"**
2. Anotar:
   - **IP do celular** (ex: `192.168.x.x` ou IP Tailscale `100.x.x.x`)
   - **Porta de emparelhamento** (ex: `33417`)
   - **Código de 6 dígitos** (ex: `518212`)
3. A porta **principal ADB** fica visível na tela de "Depuração sem fio" (ex: `44007`)

---

## 2. Conectar via ADB

> **Recomendado:** usar **IP Tailscale** do celular para acesso de qualquer lugar, não só da rede local.

### 2.1 Emparelhar (apenas na primeira vez)
```bash
adb pair <IP_CELULAR>:<PORTA_PAIRING> <CODIGO_6_DIGITOS>
# Exemplo:
adb pair 100.112.7.26:33417 518212
```

### 2.2 Conectar
```bash
adb connect <IP_CELULAR>:<PORTA_PRINCIPAL>
# Exemplo:
adb connect 100.112.7.26:44007
```

### 2.3 Verificar conexão
```bash
adb devices
# Deve listar o dispositivo como "device" (não "unauthorized")

adb shell "whoami && getprop ro.product.model"
# Saída esperada:
# shell
# SM-A346M
```

### 2.4 Manter ADB WiFi entre reboots
```bash
adb shell settings put global adb_wifi_enabled 1
```

---

## 3. Conceder Permissões via ADB

Permissões que o Android normalmente não permite conceder pela UI — exigem ADB.

### 3.1 Termux — Acesso ao Armazenamento
```bash
adb shell pm grant com.termux android.permission.MANAGE_EXTERNAL_STORAGE
adb shell pm grant com.termux android.permission.READ_EXTERNAL_STORAGE
adb shell pm grant com.termux android.permission.WRITE_EXTERNAL_STORAGE
```

### 3.2 Tasker — Permissões Elevadas
```bash
# Necessário para Tasker modificar configurações do sistema
adb shell pm grant net.dinglisch.android.taskerm android.permission.WRITE_SECURE_SETTINGS

# Necessário para Tasker ler logs do sistema
adb shell pm grant net.dinglisch.android.taskerm android.permission.READ_LOGS
```

### 3.3 TaskerHealthConnect — Dados de Saúde (Galaxy Watch 7)
```bash
adb shell pm grant com.rafapps.taskerhealthconnect android.permission.health.READ_STEPS
adb shell pm grant com.rafapps.taskerhealthconnect android.permission.health.READ_HEART_RATE
adb shell pm grant com.rafapps.taskerhealthconnect android.permission.health.READ_SLEEP
adb shell pm grant com.rafapps.taskerhealthconnect android.permission.health.READ_OXYGEN_SATURATION
adb shell pm grant com.rafapps.taskerhealthconnect android.permission.health.READ_HEART_RATE_VARIABILITY
adb shell pm grant com.rafapps.taskerhealthconnect android.permission.health.READ_BLOOD_PRESSURE
```

> **Nota:** O app Galaxy Watch 7 sincroniza automaticamente dados com o Samsung Health, que os repassa ao Health Connect (nativo no Android 13+). O TaskerHealthConnect lê do Health Connect.

---

## 4. Setup Completo do Termux

### 4.1 Instalar pacotes essenciais
```bash
# Dentro do Termux no celular (ou via SSH):
pkg update -y && yes Y | pkg upgrade
pkg install -y git jq python nodejs tmux vim curl wget termux-api
```

### 4.2 Configurar termux-services para sshd automático no boot
```bash
pkg install -y termux-services
sv-enable sshd
sv up sshd
```

### 4.3 Configurar ~/.bashrc
```bash
cat > ~/.bashrc << 'EOF'
# === NEXUS ANDROID — Termux Config ===

# sshd fallback caso services não esteja rodando
if ! pgrep -f sshd > /dev/null 2>&1; then
  sshd
fi

# Aliases
alias ll="ls -lah"
alias g="git"
alias py="python"
alias status-nexus="termux-battery-status && echo --- && uptime && echo --- && df -h /sdcard"

export PATH="$HOME/.local/bin:$PATH"
export EDITOR=vim
EOF
```

### 4.4 Configurar git
```bash
git config --global user.name "Adriano Nexus"
git config --global user.email "adrianomodelo@users.noreply.github.com"
git config --global init.defaultBranch main
```

---

## 5. SSH via Termux

Para acesso shell completo ao celular (não só ADB):

### 4.1 Configurar SSH no Termux
```bash
# Dentro do Termux no celular:
pkg install openssh
sshd  # inicia servidor SSH na porta 8022

# Copiar chave pública do PC:
# No PC:
ssh-copy-id -p 8022 -i ~/.ssh/id_rsa 100.112.7.26
# OU
adb shell "mkdir -p /data/data/com.termux/files/home/.ssh"
cat ~/.ssh/id_rsa.pub | adb shell "cat >> /data/data/com.termux/files/home/.ssh/authorized_keys"
```

### 4.2 Conectar ao Termux via SSH
```bash
ssh -p 8022 -i ~/.ssh/id_rsa -o IdentitiesOnly=yes u0a454@100.112.7.26

# Ou via alias (~/.ssh/config):
ssh ssh-celular
```

- **IP Tailscale do celular:** `100.112.7.26`
- **Porta Termux SSH:** `8022`
- **Usuário:** `u0a454`
- **Alias:** `ssh-celular` (configurar em `~/.ssh/config`)

### 4.3 Manter sshd automático no Termux
```bash
# Em ~/.bashrc do Termux:
sshd 2>/dev/null || true
```

---

## 6. Automação via UI (uiautomator)

Para interagir com apps que não têm API — útil para clicar em botões, preencher formulários, etc.

```bash
# Capturar layout atual da tela
adb shell uiautomator dump /sdcard/ui.xml
adb pull /sdcard/ui.xml /tmp/ui.xml

# Analisar elementos (buscar texto/bounds)
grep -o 'text="[^"]*" .* bounds="[^"]*"' /tmp/ui.xml

# Clicar em coordenadas (calcular centro do bounds)
adb shell input tap 666 904

# Screenshot remota
adb exec-out screencap -p > /tmp/screen.png
```

---

## 7. Pipeline de Dados de Saúde (Galaxy Watch 7 → n8n)

### 6.1 Fluxo completo
```
Galaxy Watch 7
      ↓ sync automático BLE
Samsung Health (app)
      ↓ bridge nativa
Health Connect (Android 16)
      ↓ TaskerHealthConnect plugin
Tasker (task agendada às 08:00)
      ↓ HTTP POST webhook
n8n (n8n.opsnx.com.br)
      ↓                ↓
Supabase          Telegram
(histórico)      (notificações)
```

### 6.2 Task Tasker — Estrutura (ver `tasker/nexus_health.tsk.xml`)

A task **"Nexus Health Ler"** (ID 100) executa às 08:00–08:01 diariamente e:

1. Calcula `start_ms` (yesterday) e `end_ms` (now) em epoch ms
2. Lê **StepsRecord** via TaskerHealthConnect
3. Lê **HeartRateRecord**
4. Lê **HeartRateVariabilityRmssdRecord**
5. Lê **SleepSessionRecord**
6. Lê **OxygenSaturationRecord**
7. Agrega via JavaScript no Tasker:
   - Soma total de passos
   - BPM atual + BPM médio
   - HRV (último registro)
   - Sono em minutos e horas
   - SpO2 (último registro)
8. Monta JSON e salva em `/sdcard/nexus_health_data.json`
9. Envia via webhook ao n8n

### 6.3 Payload enviado ao n8n
```json
{
  "source": "galaxy_watch_7",
  "timestamp": "2026-02-25T08:00:00.000Z",
  "heart_rate": 72,
  "heart_rate_avg": 68,
  "steps": 8432,
  "hrv": 45.2,
  "sleep_minutes": 420,
  "sleep_hours": 7.0,
  "spo2": 98.0,
  "device": "Samsung A34 + Watch 7"
}
```

---

## 8. Bugs Conhecidos e Workarounds

### Android 16 + TaskerHealthConnect — `COUNT_TOTAL` Bug

**Problema:** O plugin TaskerHealthConnect ao tentar ler dados agregados (ex: `AggregateStepsRecord`) causa `java.lang.NoSuchFieldException: COUNT_TOTAL` no Android 16.

**Issue:** [github.com/RafhaanShah/TaskerHealthConnect/issues/22](https://github.com/RafhaanShah/TaskerHealthConnect/issues/22)

**Workaround aplicado:**
- Ler **registros individuais** (`StepsRecord`) em vez de dados agregados
- Somar manualmente via JavaScript no Tasker:
```javascript
var sd = JSON.parse('%steps_raw' || '{}');
var steps = 0;
if (sd.records) {
  sd.records.forEach(function(r) { steps += (r.count || 0); });
}
```

---

## 9. Script de Reconexão Rápida

Salvar como `~/workspace/scripts/adb-connect-celular.sh`:

```bash
#!/bin/bash
# Reconecta ADB ao celular via Tailscale
CELULAR_IP="100.112.7.26"
CELULAR_PORT="44007"

echo "Conectando ao celular ($CELULAR_IP:$CELULAR_PORT)..."
adb connect $CELULAR_IP:$CELULAR_PORT

echo "Verificando conexão..."
adb -s $CELULAR_IP:$CELULAR_PORT shell getprop ro.product.model

echo "Dispositivos conectados:"
adb devices
```

> **Nota sobre a porta:** A porta principal ADB (`44007` neste setup) pode mudar a cada reboot do celular se o sistema Android a reatribuir dinamicamente. Em caso de falha, verificar a porta atual em **Configurações → Opções do desenvolvedor → Depuração sem fio**.

---

## 10. Shizuku — Permissões Elevadas sem Root

Shizuku permite que apps obtenham permissões equivalentes ao ADB (muito além do normal) sem necessidade de root. Essencial para automações avançadas via Tasker.

### 10.1 Instalar Shizuku

```bash
# Baixar APK (GitHub releases)
wget -O /tmp/shizuku.apk https://github.com/RikkaApps/Shizuku/releases/latest/download/shizuku-*.apk

# Instalar via ADB
adb -s 100.112.7.26:<PORTA> install -r /tmp/shizuku.apk
```

### 10.2 Iniciar servidor Shizuku

```bash
# Gerar script de start manualmente
adb -s 100.112.7.26:<PORTA> shell '
APK=$(pm path moe.shizuku.privileged.api | sed "s/package://")
cat > /data/local/tmp/shizuku_start.sh << EOF
#!/system/bin/sh
CLASSPATH=$APK
exec /system/bin/app_process -Djava.class.path="\$CLASSPATH" /system/bin --nice-name=shizuku moe.shizuku.server.Starter "\$@"
EOF
chmod 755 /data/local/tmp/shizuku_start.sh'

# Executar (em background)
adb -s 100.112.7.26:<PORTA> shell 'sh /data/local/tmp/shizuku_start.sh' &

# Verificar se subiu
adb -s 100.112.7.26:<PORTA> shell 'ps -A | grep shizuku_server'
```

### 10.3 Testar via rish (shell Shizuku)

```bash
# Extrair rish do APK
unzip -o /tmp/shizuku.apk assets/rish assets/rish_shizuku.dex -d /tmp/shizuku_rish/

# Enviar para o device
adb push /tmp/shizuku_rish/assets/rish /data/local/tmp/rish
adb push /tmp/shizuku_rish/assets/rish_shizuku.dex /data/local/tmp/rish_shizuku.dex
adb shell 'chmod 755 /data/local/tmp/rish && chmod 400 /data/local/tmp/rish_shizuku.dex'

# Testar (deve retornar uid=shell com grupos elevados)
adb shell 'RISH_APPLICATION_ID=moe.shizuku.privileged.api sh /data/local/tmp/rish -c "id"'
```

### 10.4 Auto-start no boot (via Termux:Boot)

```bash
# No Termux:
mkdir -p ~/.termux/boot

cat > ~/scripts/start-shizuku.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
sleep 10
pgrep -f shizuku_server > /dev/null && exit 0
sh /data/local/tmp/shizuku_start.sh
EOF
chmod +x ~/scripts/start-shizuku.sh

cat > ~/.termux/boot/start-shizuku.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
sleep 10
bash ~/scripts/start-shizuku.sh
EOF
chmod +x ~/.termux/boot/start-shizuku.sh
```

### 10.5 Instalar Termux:Boot

> ⚠️ Usar APK do **F-Droid** (mesma assinatura do Termux instalado). A versão GitHub debug não é compatível.

```bash
wget -O /tmp/termux-boot-fdroid.apk "https://f-droid.org/repo/com.termux.boot_7.apk"
adb -s 100.112.7.26:<PORTA> install -r /tmp/termux-boot-fdroid.apk
```

---

## 11. Tasker — Configuração das Tasks

Os arquivos XML das tasks ficam em `scripts/tasker/` no repositório e devem ser importados no Tasker.

### 11.1 Arquivos disponíveis

| Arquivo | Task ID | Função |
|---|---|---|
| `nexus_health.tsk.xml` | 100 | Lê Health Connect → monta payload → POST n8n |
| `nexus_boot.tsk.xml` | 101 | Notifica Telegram no boot (IP + bateria) |
| `nexus_battery.tsk.xml` | 102 | Alerta Telegram quando bateria < 20% |

### 11.2 Importar no Tasker

```bash
# Enviar XMLs para o celular (PC → celular)
adb push scripts/tasker/nexus_health.tsk.xml /sdcard/Tasker/tasks/
adb push scripts/tasker/nexus_boot.tsk.xml /sdcard/Tasker/tasks/
adb push scripts/tasker/nexus_battery.tsk.xml /sdcard/Tasker/tasks/
```

No Tasker:
1. Aba **Tasks** → Menu (⋮) → **Import** → selecionar cada arquivo em `/sdcard/Tasker/tasks/`
2. Aba **Profiles** → importar os perfis dos mesmos arquivos

### 11.3 Configurar variável `%WEBHOOK_URL`

No Tasker:
1. Ícone de globo (Vars) → **Add** → Nome: `WEBHOOK_URL`
2. Valor: `https://n8n.staging.opsnx.com.br/webhook/nexus-health`

### 11.4 Perfis configurados

| Profile | Trigger | Task |
|---|---|---|
| Nexus Saúde Diário | 08:00 diário | Nexus Health Ler (ID 100) |
| Nexus Boot | Boot completo | Nexus Boot (ID 101) |
| Nexus Battery Alert | Bateria < 20% | Nexus Battery Alert (ID 102) |

### 11.5 Workflow da Task de Saúde

```
act0: JS — calcula start_ms (ontem 00:00) e end_ms (agora) em epoch ms
act1: Plugin — lê StepsRecord (TaskerHealthConnect)
act2: JS — salva em %steps_raw
act3: Plugin — lê HeartRateRecord
act4: JS — salva em %hr_raw
act5: Plugin — lê HeartRateVariabilityRmssdRecord
act6: JS — salva em %hrv_raw
act7: Plugin — lê SleepSessionRecord
act8: JS — salva em %sleep_raw
act9: Plugin — lê OxygenSaturationRecord
act10: JS — salva em %spo2_raw
act11: JS — agrega todos, aplica workaround Android 16, monta JSON payload
act12: Shell — salva payload em /sdcard/nexus_health_data.json (fallback)
act13: JS (Java interop) — POST payload para %WEBHOOK_URL via HttpURLConnection
```

---

## 12. n8n — Webhook de Saúde

### Workflow criado: "🏃 Nexus Health - Watch 7 Pipeline"

- **URL Produção:** `https://n8n.staging.opsnx.com.br/webhook/nexus-health`
- **Método:** POST
- **Content-Type:** `application/json`
- **ID n8n:** `5fg84kOVmnGicgUo`

### Payload esperado

```json
{
  "source": "galaxy_watch_7",
  "timestamp": "2026-02-25T08:00:00.000Z",
  "heart_rate": 82,
  "heart_rate_avg": 68,
  "steps": 8432,
  "hrv": 45.2,
  "sleep_minutes": 420,
  "sleep_hours": 7.0,
  "spo2": 98.0,
  "device": "Samsung A34 + Watch 7"
}
```

### Pipeline n8n

```
Webhook POST → Formatar Dados (JS) → Telegram Adriano → Resposta OK
```

O Telegram envia relatório formatado com emojis de status (✅/⚠️/❌) baseado nos valores.

---

## 13. Referências

- [ADB Wireless Debugging — Android Developers](https://developer.android.com/tools/adb#wireless-android11-command-line)
- [TaskerHealthConnect — GitHub](https://github.com/RafhaanShah/TaskerHealthConnect)
- [Termux Wiki — Remote Access](https://wiki.termux.com/wiki/Remote_Access)
- [Health Connect API — Tipos de Registro](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/package-summary)
- [Tailscale — Documentação](https://tailscale.com/kb)

---

## Histórico

| Data | Evento |
|---|---|
| 2026-02-25 | Setup inicial — ADB Wireless + permissões + pipeline Watch 7 → n8n |
| 2026-02-25 | Atualização — porta ADB `44007`, usuário SSH `u0a454`, alias `ssh-celular` |
| 2026-02-25 | Reinstalação completa — setup Termux (git, jq, python, nodejs, tmux, vim, termux-api), termux-services para sshd, fix MANAGE_EXTERNAL_STORAGE (manual no Android 16) |
| 2026-02-25 | Shizuku v13.6.0 instalado — servidor via app_process, rish testado, auto-start via Termux:Boot |
| 2026-02-25 | n8n webhook criado — "🏃 Nexus Health - Watch 7 Pipeline" em `n8n.staging.opsnx.com.br/webhook/nexus-health` |
| 2026-02-25 | Tasks Tasker criadas — nexus_health (ID 100 + act13 HTTP POST), nexus_boot (ID 101), nexus_battery (ID 102) |

---

*Mantido pelo time Nexus. Dúvidas: [adrianomodelo](https://github.com/adrianomodelo)*
