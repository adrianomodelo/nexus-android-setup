#!/bin/bash
# Concede todas as permissões necessárias ao ecossistema Nexus via ADB
# Executar APÓS conectar via: ./adb-connect-celular.sh
#
# Uso: ./grant-permissions.sh [IP:PORTA]
# Exemplo: ./grant-permissions.sh 100.112.7.26:44007
#
# ⚠️  MANAGE_EXTERNAL_STORAGE (Termux) NÃO pode ser concedida via ADB no Android 16.
#     Conceder manualmente: Configurações → Apps → Termux → Permissões →
#     Arquivos e mídia → Permitir gerenciamento de todos os arquivos

TARGET="${1:-}"
ADB_CMD="adb"
if [ -n "$TARGET" ]; then
  ADB_CMD="adb -s $TARGET"
fi

echo "=== Permissões Termux ==="
# MANAGE_EXTERNAL_STORAGE: conceder manualmente via Settings (Android 16 bloqueia via ADB)
$ADB_CMD shell pm grant com.termux android.permission.READ_EXTERNAL_STORAGE && echo "✓ READ_EXTERNAL_STORAGE"
$ADB_CMD shell pm grant com.termux android.permission.WRITE_EXTERNAL_STORAGE && echo "✓ WRITE_EXTERNAL_STORAGE"
echo "⚠  MANAGE_EXTERNAL_STORAGE — conceder manualmente via Settings"

echo ""
echo "=== Permissões Tasker ==="
$ADB_CMD shell pm grant net.dinglisch.android.taskerm android.permission.WRITE_SECURE_SETTINGS && echo "✓ WRITE_SECURE_SETTINGS"
$ADB_CMD shell pm grant net.dinglisch.android.taskerm android.permission.READ_LOGS && echo "✓ READ_LOGS"

echo ""
echo "=== Permissões TaskerHealthConnect (Health Connect) ==="
$ADB_CMD shell pm grant com.rafapps.taskerhealthconnect android.permission.health.READ_STEPS && echo "✓ READ_STEPS"
$ADB_CMD shell pm grant com.rafapps.taskerhealthconnect android.permission.health.READ_HEART_RATE && echo "✓ READ_HEART_RATE"
$ADB_CMD shell pm grant com.rafapps.taskerhealthconnect android.permission.health.READ_SLEEP && echo "✓ READ_SLEEP"
$ADB_CMD shell pm grant com.rafapps.taskerhealthconnect android.permission.health.READ_OXYGEN_SATURATION && echo "✓ READ_OXYGEN_SATURATION"
$ADB_CMD shell pm grant com.rafapps.taskerhealthconnect android.permission.health.READ_HEART_RATE_VARIABILITY && echo "✓ READ_HEART_RATE_VARIABILITY"
$ADB_CMD shell pm grant com.rafapps.taskerhealthconnect android.permission.health.READ_BLOOD_PRESSURE && echo "✓ READ_BLOOD_PRESSURE"

echo ""
echo "=== ADB WiFi permanente (sobrevive reboot) ==="
$ADB_CMD shell settings put global adb_wifi_enabled 1 && echo "✓ adb_wifi_enabled=1"

echo ""
echo "=== Concluído ==="
