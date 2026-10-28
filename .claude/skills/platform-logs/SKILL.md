---
name: platform-logs
description: Capture and slice BabyBloom's app logs on an iOS simulator (unified logging, subsystem com.nenita.app). Reference for the dev/QA flows; not an entry point.
---
executor: agent

# platform-logs

The app logs through `os.Logger(subsystem: "com.nenita.app", category: …)`
(categories seen: `Analytics`, `ReviewPrompt`, `SeedScenario`). The widget
runs in its own process (`BabyBloomWidget`), so filter by subsystem, not
by process, to see both.

## Capture

Live, to a file, on YOUR device by id (never `booted` — several
simulators are usually booted here):

    mkdir -p <out-dir>
    xcrun simctl spawn <udid> log stream --level debug \
      --predicate 'subsystem == "com.nenita.app"' --style compact \
      > <out-dir>/app.log 2>&1 &
    echo $! > <out-dir>/log.pid          # stop: kill $(cat <out-dir>/log.pid)

After the fact (the simulator keeps a log archive):

    xcrun simctl spawn <udid> log show --style compact --info --debug \
      --predicate 'subsystem == "com.nenita.app"' \
      --start '<YYYY-MM-DD HH:MM:SS>' --end '<YYYY-MM-DD HH:MM:SS>' \
      > <out-dir>/app.log

Narrow further with `AND category == "Analytics"` in the predicate.
Crashes: `~/Library/Logs/DiagnosticReports/BabyBloom-*.ips` (newest first).

## Noise strip

The subsystem predicate already drops system chatter. Also drop the
`log stream` banner line (`Filtering the log data using …`). Do not strip
`fault` or `error` lines from other subsystems when the app crashed —
for a crash, rerun `log show` with `--predicate 'process == "BabyBloom"'`.

## Slice

By window: `log show --start/--end` (above). For a captured stream file,
lines start with a timestamp: `awk '$1" "$2 >= "<from>" && $1" "$2 <= "<to>"' app.log`.

## Output

Return the file paths and one line:
`logs: <n> lines, <e> error/fault, first error: <line or none>` —
counts via `grep -c -E ' (E|F[a-z]*) ' app.log` (compact style marks the
level in the second column: `Df` default, `I` info, `D` debug, `E` error,
`F` fault).

TODO (unverified by the wizard): the compact-style level letters above
were taken from Apple's `log` man page, not from a run on this machine —
confirm on the first capture and fix this paragraph.
