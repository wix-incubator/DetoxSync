#!/usr/bin/env bash
# Runs the JS timer + status stress mode repeatedly on a fresh simulator and summarizes the logs.
# Usage: run-timer-stress.sh <path to .app> <label> [runs=10] [seconds=60] [outdir]
# Env:   SIM_DEVICE_TYPE (default "iPhone 18 Pro"), SIM_RUNTIME (default: newest available iOS runtime id)
set -euo pipefail

BUNDLE_ID="org.reactjs.native.example.ReactNativeTesterApp"

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <path to .app> <label> [runs=10] [seconds=60] [outdir]" >&2
  exit 2
fi
APP="$1"
LABEL="$2"
RUNS="${3:-10}"
SECONDS_PER_RUN="${4:-60}"
OUTDIR="${5:-./timer-stress-results/${LABEL}-$(date +%Y%m%d-%H%M%S)}"
DEVICE_TYPE="${SIM_DEVICE_TYPE:-iPhone 18 Pro}"

[[ -d "$APP" ]] || { echo "app not found: $APP" >&2; exit 2; }
mkdir -p "$OUTDIR"

RUNTIME="${SIM_RUNTIME:-}"
if [[ -z "$RUNTIME" ]]; then
  RUNTIME="$(xcrun simctl list runtimes -j | /usr/bin/python3 -I -c '
import json, sys
rts = [r for r in json.load(sys.stdin)["runtimes"]
       if r.get("isAvailable", True) and r.get("platform", "iOS") == "iOS"
       and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS")]
def key(r):
    return tuple(int(p) for p in r["version"].split(".") if p.isdigit())
rts.sort(key=key)
print(rts[-1]["identifier"] if rts else "")
')"
fi
[[ -n "$RUNTIME" ]] || { echo "no iOS simulator runtime found" >&2; exit 1; }

UDID=""
LAUNCH_PID=""
cleanup() {
  set +e
  if [[ -n "$LAUNCH_PID" ]] && kill -0 "$LAUNCH_PID" 2>/dev/null; then kill "$LAUNCH_PID"; fi
  if [[ -n "$UDID" ]]; then
    xcrun simctl shutdown "$UDID" >/dev/null 2>&1
    xcrun simctl delete "$UDID" >/dev/null 2>&1
  fi
}
trap cleanup EXIT

echo "runtime=$RUNTIME device=$DEVICE_TYPE out=$OUTDIR"
UDID="$(xcrun simctl create "TimerStress-$LABEL" "$DEVICE_TYPE" "$RUNTIME")"
echo "simulator $UDID"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null

SUMMARY="$OUTDIR/summary.tsv"
printf 'run\thangs\tempty\tpolls\tjsTimersBusy\tmaxLatencyMs\tjs_timer_resource\tstatus\n' > "$SUMMARY"

total_hangs=0; total_empty=0; hung_runs=0; crashed_runs=0

for ((n = 1; n <= RUNS; n++)); do
  echo "== run $n/$RUNS"
  CONSOLE="$OUTDIR/run-$n.console.log"
  RUNLOG="$OUTDIR/run-$n.log"
  xcrun simctl uninstall "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl install "$UDID" "$APP"

  xcrun simctl launch --console-pty --terminate-running-process "$UDID" "$BUNDLE_ID" \
    -TimerStressAutoStart YES > "$CONSOLE" 2>&1 &
  LAUNCH_PID=$!

  sleep "$SECONDS_PER_RUN"

  rm -f "$RUNLOG"
  DATA="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data 2>/dev/null || true)"
  if [[ -n "$DATA" && -f "$DATA/Documents/timer-stress.log" ]]; then
    cp "$DATA/Documents/timer-stress.log" "$RUNLOG"
  else
    : > "$RUNLOG"
  fi

  # Is the app still running? (launchctl list inside the sim lists UIKitApplication:<bundle>)
  alive=no
  # (capture first: `grep -q` closing the pipe early makes the pipeline fail under pipefail)
  services="$(xcrun simctl spawn "$UDID" launchctl list 2>/dev/null || true)"
  if grep -q "UIKitApplication:$BUNDLE_ID" <<<"$services"; then alive=yes; fi

  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  if kill -0 "$LAUNCH_PID" 2>/dev/null; then kill "$LAUNCH_PID" 2>/dev/null || true; fi
  wait "$LAUNCH_PID" 2>/dev/null || true
  LAUNCH_PID=""

  hangs="$(grep -c 'STATUS_HANG' "$RUNLOG" || true)"
  empty="$(grep -c 'EMPTY_TIMERS' "$RUNLOG" || true)"
  last="$(grep 'TIMER_STRESS_SUMMARY' "$RUNLOG" | tail -n 1 || true)"
  polls="$(sed -n 's/.*polls=\([0-9]*\).*/\1/p' <<<"$last")"
  busy="$(sed -n 's/.*jsTimersBusy=\([0-9]*\).*/\1/p' <<<"$last")"
  maxlat="$(sed -n 's/.*maxLatencyMs=\([0-9.]*\).*/\1/p' <<<"$last")"
  res="$(grep -o 'JS_TIMER_RESOURCE=.*' "$RUNLOG" | head -n 1 || true)"
  res="${res#JS_TIMER_RESOURCE=}"

  status=ok
  if [[ -z "$last" ]]; then
    status=crashed_or_no_summary
  elif [[ "$alive" != yes ]]; then
    status=crashed
  elif ((hangs > 0)); then
    status=hang
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$hangs" "$empty" "${polls:--}" "${busy:--}" "${maxlat:--}" "${res:--}" "$status" >> "$SUMMARY"
  echo "   hangs=$hangs empty=$empty polls=${polls:--} busy=${busy:--} maxLatencyMs=${maxlat:--} status=$status"

  total_hangs=$((total_hangs + hangs))
  total_empty=$((total_empty + empty))
  if ((hangs > 0)); then hung_runs=$((hung_runs + 1)); fi
  if [[ "$status" == crashed* ]]; then crashed_runs=$((crashed_runs + 1)); fi
done

echo "TOTALS label=$LABEL runs=$RUNS seconds=$SECONDS_PER_RUN runsWithHang=$hung_runs totalHangs=$total_hangs totalEmptyTimers=$total_empty crashedRuns=$crashed_runs summary=$SUMMARY" | tee -a "$SUMMARY.totals"
