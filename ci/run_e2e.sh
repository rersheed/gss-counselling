#!/usr/bin/env bash
# Called inside the Android emulator step of .github/workflows/e2e-evidence.yml
set -o pipefail
mkdir -p evidence/logs
adb shell settings put system time_12_24 12 || true
timeout 1800 flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_flow_test.dart \
  --dart-define=SUPABASE_URL=http://10.0.2.2:54321 \
  --dart-define=SUPABASE_ANON_KEY="$ANON_KEY" 2>&1 | tee evidence/logs/e2e_test.log
