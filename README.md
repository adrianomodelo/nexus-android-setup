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
3. A porta **principal ADB** fica visível na tela de "Depuração sem fio" (ex: `36565`)

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
adb connect 100.112.7.26:36565
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

## 4. SSH via Termux

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
ssh -p 8022 -i ~/.ssh/id_rsa 100.112.7.26
```

- **IP Tailscale do celular:** `100.112.7.26`
- **Porta Termux SSH:** `8022`
- **Hostname:** `a34-de-adriano`

### 4.3 Manter sshd automático no Termux
```bash
# Em ~/.bashrc do Termux:
sshd 2>/dev/null || true
```

---

## 5. Automação via UI (uiautomator)

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

## 6. Pipeline de Dados de Saúde (Galaxy Watch 7 → n8n)

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

## 7. Bugs Conhecidos e Workarounds

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

## 8. Script de Reconexão Rápida

Salvar como `~/workspace/scripts/adb-connect-celular.sh`:

```bash
#!/bin/bash
# Reconecta ADB ao celular via Tailscale
CELULAR_IP="100.112.7.26"
CELULAR_PORT="36565"

echo "Conectando ao celular ($CELULAR_IP:$CELULAR_PORT)..."
adb connect $CELULAR_IP:$CELULAR_PORT

echo "Verificando conexão..."
adb -s $CELULAR_IP:$CELULAR_PORT shell getprop ro.product.model

echo "Dispositivos conectados:"
adb devices
```

> **Nota sobre a porta:** A porta principal ADB (`36565` neste setup) pode mudar a cada reboot do celular se o sistema Android a reatribuir dinamicamente. Em caso de falha, verificar a porta atual em **Configurações → Opções do desenvolvedor → Depuração sem fio**.

---

## 9. Referências

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

---

*Mantido pelo time Nexus. Dúvidas: [adrianomodelo](https://github.com/adrianomodelo)*
