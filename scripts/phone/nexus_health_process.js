// =============================================================================
// Nexus Health Process - Node.js processor
// Reads Health Connect JSON files exported by Tasker, computes aggregated
// metrics from individual records (NOT COUNT_TOTAL - Android 16 bug),
// saves result to JSON and sends to n8n webhook.
// =============================================================================

const fs = require('fs');
const https = require('https');

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------
const DATA_DIR = '/sdcard';
const WEBHOOK_URL = 'https://n8n.opsnx.com.br/webhook/health-data';
const OUTPUT_FILE = `${DATA_DIR}/nexus_health_data.json`;

const FILES = {
  steps: `${DATA_DIR}/hc_steps.json`,
  hr: `${DATA_DIR}/hc_hr.json`,
  hrv: `${DATA_DIR}/hc_hrv.json`,
  sleep: `${DATA_DIR}/hc_sleep.json`,
  spo2: `${DATA_DIR}/hc_spo2.json`,
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function readJSON(filepath) {
  try {
    if (!fs.existsSync(filepath)) {
      console.log(`  [SKIP] File not found: ${filepath}`);
      return { records: [] };
    }
    const raw = fs.readFileSync(filepath, 'utf8').trim();
    if (!raw) {
      console.log(`  [SKIP] File empty: ${filepath}`);
      return { records: [] };
    }
    const data = JSON.parse(raw);
    return data && Array.isArray(data.records) ? data : { records: [] };
  } catch (err) {
    console.log(`  [ERROR] Reading ${filepath}: ${err.message}`);
    return { records: [] };
  }
}

function round1(n) {
  return Math.round(n * 10) / 10;
}

// ---------------------------------------------------------------------------
// Processors - compute metrics from individual records
// ---------------------------------------------------------------------------

function processSteps(data) {
  let total = 0;
  for (const record of data.records) {
    total += record.count || 0;
  }
  console.log(`  Steps: ${total} (from ${data.records.length} records)`);
  return total;
}

function processHeartRate(data) {
  let sum = 0;
  let count = 0;
  let min = Infinity;
  let max = -Infinity;

  for (const record of data.records) {
    const samples = record.samples || [];
    for (const sample of samples) {
      const bpm = sample.beatsPerMinute;
      if (typeof bpm === 'number' && bpm > 0) {
        sum += bpm;
        count++;
        if (bpm < min) min = bpm;
        if (bpm > max) max = bpm;
      }
    }
  }

  const result = {
    avg: count > 0 ? Math.round(sum / count) : 0,
    min: count > 0 ? Math.round(min) : 0,
    max: count > 0 ? Math.round(max) : 0,
    samples: count,
  };

  console.log(`  Heart Rate: avg=${result.avg} min=${result.min} max=${result.max} samples=${result.samples}`);
  return result;
}

function processHRV(data) {
  let sum = 0;
  let count = 0;

  for (const record of data.records) {
    const value = record.heartRateVariabilityMillis;
    if (typeof value === 'number' && value > 0) {
      sum += value;
      count++;
    }
  }

  const result = {
    avg_rmssd: count > 0 ? round1(sum / count) : 0,
    samples: count,
  };

  console.log(`  HRV: avg_rmssd=${result.avg_rmssd} samples=${result.samples}`);
  return result;
}

function processSleep(data) {
  let totalMs = 0;

  for (const record of data.records) {
    if (record.startTime && record.endTime) {
      const start = new Date(record.startTime).getTime();
      const end = new Date(record.endTime).getTime();
      if (!isNaN(start) && !isNaN(end) && end > start) {
        totalMs += end - start;
      }
    }
  }

  const totalMinutes = Math.round(totalMs / 60000);
  const totalHours = round1(totalMinutes / 60);

  console.log(`  Sleep: ${totalMinutes}min (${totalHours}h) from ${data.records.length} records`);
  return {
    total_minutes: totalMinutes,
    total_hours: totalHours,
  };
}

function processSpO2(data) {
  let sum = 0;
  let count = 0;
  let min = Infinity;

  for (const record of data.records) {
    const value = record.percentage && record.percentage.value;
    if (typeof value === 'number' && value > 0) {
      sum += value;
      count++;
      if (value < min) min = value;
    }
  }

  const result = {
    avg: count > 0 ? round1(sum / count) : 0,
    min: count > 0 ? round1(min) : 0,
    samples: count,
  };

  console.log(`  SpO2: avg=${result.avg} min=${result.min} samples=${result.samples}`);
  return result;
}

// ---------------------------------------------------------------------------
// Webhook sender using built-in https module
// ---------------------------------------------------------------------------

function sendWebhook(payload) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(payload);
    const parsed = new URL(WEBHOOK_URL);

    const options = {
      hostname: parsed.hostname,
      port: parsed.port || 443,
      path: parsed.pathname + parsed.search,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        console.log(`  Webhook response: ${res.statusCode} ${data.substring(0, 200)}`);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(data);
        } else {
          reject(new Error(`Webhook HTTP ${res.statusCode}: ${data.substring(0, 200)}`));
        }
      });
    });

    req.on('error', (err) => {
      reject(new Error(`Webhook request failed: ${err.message}`));
    });

    req.setTimeout(15000, () => {
      req.destroy();
      reject(new Error('Webhook request timed out (15s)'));
    });

    req.write(body);
    req.end();
  });
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log(`[${new Date().toISOString()}] Processing health data...`);

  // Read all JSON files
  console.log('Reading health data files...');
  const stepsData = readJSON(FILES.steps);
  const hrData = readJSON(FILES.hr);
  const hrvData = readJSON(FILES.hrv);
  const sleepData = readJSON(FILES.sleep);
  const spo2Data = readJSON(FILES.spo2);

  // Process each metric
  console.log('Computing metrics...');
  const steps = processSteps(stepsData);
  const heartRate = processHeartRate(hrData);
  const hrv = processHRV(hrvData);
  const sleep = processSleep(sleepData);
  const spo2 = processSpO2(spo2Data);

  // Build payload
  const now = new Date();
  const offset = -3; // BRT UTC-3
  const local = new Date(now.getTime() + offset * 3600000);
  const isoLocal = local.toISOString().replace('Z', '-03:00');

  const payload = {
    source: 'nexus-android',
    device: 'Galaxy A34 + Watch 7',
    timestamp: isoLocal,
    steps: steps,
    heart_rate: heartRate,
    hrv: hrv,
    sleep: sleep,
    spo2: spo2,
  };

  // Save to file
  try {
    fs.writeFileSync(OUTPUT_FILE, JSON.stringify(payload, null, 2));
    console.log(`Saved to ${OUTPUT_FILE}`);
  } catch (err) {
    console.log(`ERROR saving file: ${err.message}`);
  }

  // Send to webhook
  console.log(`Sending to webhook: ${WEBHOOK_URL}`);
  try {
    await sendWebhook(payload);
    console.log('Webhook sent successfully');
  } catch (err) {
    console.log(`WARNING: ${err.message}`);
    // Don't exit with error - data is saved locally even if webhook fails
  }

  console.log('Done.');
}

main().catch((err) => {
  console.error(`FATAL: ${err.message}`);
  process.exit(1);
});
