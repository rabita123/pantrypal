#!/usr/bin/env bash
# PantryPal test harness runner.
#
#   tool/run_tests.sh              offline suites only (unit + widget)
#   tool/run_tests.sh --network    also run the live backend contract tests
#   tool/run_tests.sh --e2e        also run end-to-end tests on a device
#   tool/run_tests.sh --all        everything
#
# Raw JSON output and a summary land in test_reports/.

set -uo pipefail
cd "$(dirname "$0")/.."

OUT=test_reports
mkdir -p "$OUT"

RUN_NETWORK=0
RUN_E2E=0
for arg in "$@"; do
  case "$arg" in
    --network) RUN_NETWORK=1 ;;
    --e2e)     RUN_E2E=1 ;;
    --all)     RUN_NETWORK=1; RUN_E2E=1 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

status=0

echo "── Analyzing ───────────────────────────────────────────"
flutter analyze --no-fatal-infos > "$OUT/analyze.txt" 2>&1 || status=1
tail -3 "$OUT/analyze.txt"

echo
echo "── Unit + widget tests ─────────────────────────────────"
flutter test test/unit test/widget \
  --exclude-tags network \
  --reporter=json > "$OUT/offline.json" 2>"$OUT/offline.err" || status=1
python3 tool/summarize.py "$OUT/offline.json" "offline"

if [ "$RUN_NETWORK" = 1 ]; then
  echo
  echo "── Backend contract tests (live network) ───────────────"
  flutter test test/unit/backend_connectivity_test.dart \
    --tags network \
    --reporter=json > "$OUT/network.json" 2>"$OUT/network.err" || status=1
  python3 tool/summarize.py "$OUT/network.json" "network"
fi

if [ "$RUN_E2E" = 1 ]; then
  echo
  echo "── End-to-end tests ────────────────────────────────────"
  DEVICE="${DEVICE:-$(flutter devices --machine 2>/dev/null \
    | python3 -c 'import json,sys
ds=json.load(sys.stdin)
pick=[d for d in ds if d.get("targetPlatform","").startswith("ios") and d.get("emulator")]
print((pick or ds)[0]["id"] if ds else "")' 2>/dev/null)}"

  if [ -z "$DEVICE" ]; then
    echo "no device available — skipping E2E"
    status=1
  else
    echo "device: $DEVICE"
    flutter test integration_test/app_test.dart -d "$DEVICE" \
      --reporter=json > "$OUT/e2e.json" 2>"$OUT/e2e.err" || status=1
    python3 tool/summarize.py "$OUT/e2e.json" "e2e"
  fi
fi

echo
echo "Reports written to $OUT/"
exit $status
