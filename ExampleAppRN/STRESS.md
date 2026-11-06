# JS timers + status stress mode

Reproduces wix/Detox#4966: `+[DTXSyncManager statusWithCompletionHandler:]` racing with JS timer
create/delete/cleanup work in `DTXJSTimerSyncResource`.

Bundle id: `org.reactjs.native.example.ReactNativeTesterApp`

## What it does

- JS (`StressPanel.tsx`): a "Start/Stop JS Timer Stress" button. While running, every 5 ms it creates
  20 non-repeating `setTimeout` timers (random 0-99 ms) and clears ~60% of the outstanding ones with
  `clearTimeout` before they fire. Created/cleared/fired counts are shown on screen (updated every 500 ms).
- Native (`ios/ReactNativeTesterApp/TimerStressStatusPoller.m`): only active with launch argument
  `-TimerStressAutoStart YES`. Two seconds after launch it polls `statusWithCompletionHandler:` from a
  dedicated serial queue (next call 5 ms after the previous completes, never more than one outstanding),
  with a watchdog on another queue, and shows a small overlay (top of screen, non-interactive).
- The same launch argument also auto-starts the JS stress (read via React Native `Settings`).
- Manual mode: tapping the button without the launch argument runs only the JS timers; native polling
  is not started.

## Build and run

    cd ExampleAppRN
    xcodebuild build -workspace ios/ReactNativeTesterApp.xcworkspace -scheme ReactNativeTesterApp \
      -configuration Release -destination 'generic/platform=iOS Simulator' \
      -derivedDataPath "$TMPDIR/rn-stress-dd" IPHONEOS_DEPLOYMENT_TARGET=15.1 GCC_TREAT_WARNINGS_AS_ERRORS=NO
    xcrun simctl install <udid> "$TMPDIR/rn-stress-dd/Build/Products/Release-iphonesimulator/ReactNativeTesterApp.app"
    xcrun simctl launch --console-pty <udid> org.reactjs.native.example.ReactNativeTesterApp -TimerStressAutoStart YES

On Xcode 27 the DetoxSync target's deployment target (12.2) is below the supported minimum, so
`IPHONEOS_DEPLOYMENT_TARGET=15.1` must be passed on the xcodebuild command line, as above.

Release embeds the JS bundle, so Metro is not needed. Lines are also appended to
`Documents/timer-stress.log` (`xcrun simctl get_app_container <udid> <bundle id> data`).

## Checking a DetoxSync change

On this branch the DetoxSync sources are those of master, where the status call is expected to hang
(`STATUS_HANG` in the log). To test a fix, check out the fix's DetoxSync sources
(e.g. `git checkout <fix ref> -- DetoxSync/`), rebuild with the command above (use a separate
`-derivedDataPath` per variant) and run the stress again.

## Log lines (all prefixed `[TimerStress]`)

- `JS_TIMER_RESOURCE=...`: logged once; whether `DTXJSTimerSyncResource` exists and whether the
  `RCTTiming createTimerForNextFrame:...` IMP now lives in libobjc (a block trampoline, i.e. replaced).
  On iOS 27 `dladdr` does not resolve the trampoline address, so this reads `createTimer IMP image unknown`;
  treat it as an indirect check only.
- `STATUS_HANG pendingSeconds=... polls=...`: a status call has been outstanding for more than 10 s
  (logged once per hung call; summaries keep printing).
- `EMPTY_TIMERS resource=...`: a completed status listed `js_timers` as busy with a missing or empty
  `timers` array.
- `TIMER_STRESS_SUMMARY polls=... jsTimersBusy=... emptyTimers=... hangs=... maxLatencyMs=... pendingMs=...`
  every 5 s. `jsTimersBusy` counts responses where `js_timers` was busy (shows the race window is exercised);
  `pendingMs` is the age of the currently outstanding call (0 if none).

## A/B runner script

`scripts/run-timer-stress.sh <path to .app> <label> [runs=10] [seconds=60] [outdir]` creates a fresh
simulator (`TimerStress-<label>`; override with `SIM_DEVICE_TYPE`, default `iPhone 18 Pro`, and
`SIM_RUNTIME`, default newest iOS runtime), then for each run reinstalls the app, launches it with
`-TimerStressAutoStart YES`, waits, pulls `Documents/timer-stress.log` into `run-N.log` (console output goes
to `run-N.console.log`), terminates the app, and appends a row to `summary.tsv` (hangs, empty timers, last
summary's polls / jsTimersBusy / maxLatencyMs, `JS_TIMER_RESOURCE`, status `ok|hang|crashed|crashed_or_no_summary`). A hang is
detected from the file log, so it works even though the app keeps running with a stuck status call.
The simulator is shut down and deleted on exit. Results default to `./timer-stress-results/<label>-<timestamp>`
(git-ignored). A final `TOTALS` line is printed. Build one app per variant (fix and master DetoxSync sources)
with separate derived data paths and run the script once for each.
