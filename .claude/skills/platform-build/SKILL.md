---
name: platform-build
description: How to build BabyBloom (iOS/SwiftUI/XcodeGen) and state where the artifact landed. Consumed by desk-task and e2e-tests; not an entry point.
---

# platform-build — BabyBloom

executor: agent

## Always regenerate first

The Xcode project is generated from `project.yml`. If `project.yml` changed
(or you are unsure), regenerate before building:

    xcodegen generate

XcodeGen silently ignores unknown/misplaced keys. After a `project.yml`
edit, confirm the generated project actually reflects the change — never
assume the key took.

## Simulator build (the default)

    xcodebuild -project BabyBloom.xcodeproj \
      -scheme BabyBloom \
      -configuration Debug \
      -destination 'platform=iOS Simulator,name=iPhone 17' \
      -derivedDataPath .superpowers/build \
      build

Artifact:

    .superpowers/build/Build/Products/Debug-iphonesimulator/BabyBloom.app

with the widget embedded at `BabyBloom.app/PlugIns/BabyBloomWidget.appex`.
Always state this path in the result — the e2e and run steps need it.

Available simulators: `xcrun simctl list devices available`. Prefer a booted
one; `iPhone 17` is the working default on this machine.

## Device / archive build

Requires network access to Apple's developer endpoints, which are blocked by
the split-tunnel VPN on this machine. **Pre-check before archiving:**

    curl -s -o /dev/null -w "%{http_code}\n" --max-time 15 https://idmsa.apple.com

Anything but `000` is fine; `000` means the VPN is excluding Apple and the
build will fail ~20 minutes later with a *misleading* "No signing certificate
iOS Distribution found". Details and the working upload command are in
`.desk/knowledge.md`. Bash needs `dangerouslyDisableSandbox` for any network
step — the sandbox has none.

**The Amplitude key must be present for an archive.** It lives only in the
gitignored `Config/Secrets.xcconfig` (template:
`Config/Secrets.example.xcconfig`; the repo is public — never commit it). A
Release **archive** FAILS on purpose in the pre-build phase "Refuse a Release
archive without the Amplitude key" when the key is empty, still the
template's placeholder, or not 32 characters (`error: AMPLITUDE_API_KEY is
…`), because the build would ship with analytics off or rejected; any other
Release build only warns, and Debug builds do not care. Check the KEY, not
just the file, without printing it:

    sed -n 's/^AMPLITUDE_API_KEY *= *//p' Config/Secrets.xcconfig 2>/dev/null | tr -d '[:space:]' | awk '{ k = $0 } END { print (length(k) == 32 && k != "your-amplitude-api-key") ? "key OK (32 chars)" : "key MISSING or malformed" }'

**Never paste a raw xcodebuild log from a checkout that has the file:**
xcodebuild prints every build setting as an `export` line for each script
phase, the key included. Pipe the log through
`sed "s/$(sed -n 's/^AMPLITUDE_API_KEY *= *//p' Config/Secrets.xcconfig)/<REDACTED>/g"`
before sharing it.

## Reporting

State: (1) succeeded / failed, (2) the artifact path on success, (3) on
failure the first real compiler error with its `file:line` — not the tail of
the log. Warnings are not failures; do not report a build as broken because
of them.

## Known build failures and what they mean

- `error: WidgetResources/Localization/<lang>.json is out of sync` — the
  pre-build guard. Fix by copying the app's JSON over the widget copy, do not
  disable the script.
