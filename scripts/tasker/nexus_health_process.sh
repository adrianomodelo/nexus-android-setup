#!/data/data/com.termux/files/usr/bin/bash
# Nexus Health - Processar dados e enviar webhook

node -e '
const fs = require("fs");
function readJSON(f) { try { return JSON.parse(fs.readFileSync(f, "utf8")); } catch(e) { return { records: [] }; } }

const steps = readJSON("/sdcard/hc_steps.json");
const hr = readJSON("/sdcard/hc_hr.json");
const hrv = readJSON("/sdcard/hc_hrv.json");
const sleep = readJSON("/sdcard/hc_sleep.json");
const spo2 = readJSON("/sdcard/hc_spo2.json");

let totalSteps = 0;
if (steps.records) steps.records.forEach(r => totalSteps += (r.count || 0));

let hrSum = 0, hrCount = 0, hrMin = 999, hrMax = 0;
if (hr.records) hr.records.forEach(r => {
  (r.samples || []).forEach(s => {
    const bpm = s.beatsPerMinute || 0;
    if (bpm > 0) { hrSum += bpm; hrCount++; if (bpm < hrMin) hrMin = bpm; if (bpm > hrMax) hrMax = bpm; }
  });
});
const hrAvg = hrCount > 0 ? Math.round(hrSum / hrCount) : 0;
if (hrMin === 999) hrMin = 0;

let hrvAvg = 0;
if (hrv.records && hrv.records.length > 0) {
  let sum = 0;
  hrv.records.forEach(r => sum += (r.heartRateVariabilityMillis || 0));
  hrvAvg = Math.round(sum / hrv.records.length);
}

let sleepMinutes = 0;
if (sleep.records) sleep.records.forEach(r => {
  if (r.startTime && r.endTime) sleepMinutes += Math.round((r.endTime - r.startTime) / 60000);
});

let spo2Avg = 0;
if (spo2.records && spo2.records.length > 0) {
  let sum = 0;
  spo2.records.forEach(r => sum += ((r.percentage && r.percentage.value) || 0));
  spo2Avg = Math.round(sum / spo2.records.length * 10) / 10;
}

const payload = {
  source: "galaxy_watch7",
  timestamp: new Date().toISOString(),
  steps: totalSteps,
  heart_rate: { avg: hrAvg, min: hrMin, max: hrMax, samples: hrCount },
  hrv: hrvAvg,
  sleep: { minutes: sleepMinutes, hours: parseFloat((sleepMinutes / 60).toFixed(1)) },
  spo2: spo2Avg,
  device: "SM-A346M"
};

fs.writeFileSync("/sdcard/nexus_health_data.json", JSON.stringify(payload, null, 2));
console.log(JSON.stringify(payload));
'

PAYLOAD=$(cat /sdcard/nexus_health_data.json)
curl -s -X POST "https://n8n.opsnx.com.br/webhook/health-data" -H "Content-Type: application/json" -d "$PAYLOAD" || echo "webhook failed"
echo "Done"
