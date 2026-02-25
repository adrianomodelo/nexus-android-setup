# Tasker — Tasks e Profiles

## nexus_health.tsk.xml

**Task:** Nexus Health Ler (ID 100)
**Profile:** Nexus Saúde Diário (ID 100) — executa às 08:00 todo dia

### Como importar no Tasker

1. Copiar o arquivo `.tsk.xml` para o celular:
   ```bash
   adb push nexus_health.tsk.xml /sdcard/nexus_health.tsk.xml
   ```
2. No Tasker: menu hamburger → **Import** → selecionar o arquivo
3. Ativar o profile associado

### Dependências obrigatórias

- App **TaskerHealthConnect** instalado
- Permissões Health Connect concedidas via ADB (ver README raiz)
- Variável `%WEBHOOK_URL` configurada no Tasker com a URL do n8n

### Variáveis usadas pela task

| Variável | Descrição |
|---|---|
| `%start_ms` | Timestamp epoch (ms) de 24h atrás |
| `%end_ms` | Timestamp epoch (ms) agora |
| `%steps_raw` | JSON bruto dos StepsRecord |
| `%hr_raw` | JSON bruto dos HeartRateRecord |
| `%hrv_raw` | JSON bruto do HRV |
| `%sleep_raw` | JSON bruto do SleepSessionRecord |
| `%spo2_raw` | JSON bruto do OxygenSaturationRecord |
| `%health_payload` | JSON final montado para envio |
