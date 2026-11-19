#!/usr/bin/env bash
# Called inside the Android emulator step of .github/workflows/e2e-evidence.yml
set -o pipefail
mkdir -p evidence/logs
adb shell settings put system time_12_24 12 || true
timeout 1200 flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_flow_test.dart \
  --dart-define=SUPABASE_URL=http://10.0.2.2:54321 \
  --dart-define=SUPABASE_ANON_KEY="$ANON_KEY" 2>&1 | tee evidence/logs/e2e_test.log

status=$?
grep 'STEP|' evidence/logs/e2e_test.log | sed 's/^I\/flutter ([ 0-9]*): //' > evidence/logs/e2e_steps.txt || true
echo "Steps passed: $(grep -c '|PASS|' evidence/logs/e2e_steps.txt)  failed: $(grep -c '|FAIL|' evidence/logs/e2e_steps.txt)"
if [ "$status" -ne 0 ] || grep -q '|FAIL|' evidence/logs/e2e_steps.txt || ! grep -q '|TC19|' evidence/logs/e2e_steps.txt; then exit 1; fi
