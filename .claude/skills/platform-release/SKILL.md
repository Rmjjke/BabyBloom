---
name: platform-release
description: Bump, archive, upload and tag a BabyBloom build for App Store Connect / TestFlight. The Dev Lead runs it; the owner confirms the upload before the tag.
---
executor: agent   # the Dev Lead runs every step; the owner confirms the upload before the tag

# platform-release

Recipe as it shipped 1.0.2 (25) and 1.0.3 (26) in September 2026
(`.team/desk/done.md`, `.team/knowledge.md` § Build quirks). App id in ASC:
`6799234275`. Every network step needs `dangerouslyDisableSandbox`.

## 0. Pre-checks (before anything else)

- Apple endpoints: `curl -s -o /dev/null -w "%{http_code}\n" --max-time 15 https://idmsa.apple.com`
  — `000` = the VPN excludes Apple; the archive would fail ~20 min later with
  a misleading "No signing certificate". Fix the network first.
- Which ASC version accepts the build: `GET /v1/apps/6799234275/appStoreVersions`
  (JWT from `.team/desk/legacy/jwt.sh`). A build attaches only to the version
  with ITS version string, and a released version's train is closed.
- Which build numbers are taken: `GET /v1/builds?filter[app]=6799234275`
  (`altool --list-builds` no longer exists in Xcode 26).

## Version bump

`project.yml` → `settings.base`: `MARKETING_VERSION` (match the ASC version in
PREPARE_FOR_SUBMISSION) and `CURRENT_PROJECT_VERSION` (next free build
number). Then `xcodegen generate` and check the pbxproj diff carries both
values for the app AND the widget. On a branch `chore/release-<ver>-build-<n>`,
commit `chore: version <ver>, build <n> for TestFlight`, PR, merge. The
archive is made from `main` after that merge.

## Tests

Full suite per `platform-test-runner` on `main` at the bump commit.

## Package

- Amplitude key: present, 32 chars, not the template placeholder (the
  Release archive refuses otherwise — `docs/release/app-store-connect-testflight.md`
  Step 6 has the check command). Never print the key; never publish build
  logs from that copy.
- Archive (Release, generic iOS device):

      xcodebuild -project BabyBloom.xcodeproj -scheme BabyBloom \
        -configuration Release -destination 'generic/platform=iOS' \
        -archivePath .superpowers/archive/Nenita-<n>.xcarchive \
        -allowProvisioningUpdates archive

- After any key change, compare the archived key's sha256 prefix with the
  last good one (sha8 `c5b38caf` since build 24):
  `PlistBuddy -c "Print :AmplitudeAPIKey" <xcarchive>/Products/Applications/BabyBloom.app/Info.plist | shasum -a 256 | cut -c1-8`
  — and probe it (`POST https://api2.amplitude.com/2/httpapi` with an empty
  events list → 200 / `events_ingested: 0`).

## Upload

    xcodebuild -exportArchive \
      -archivePath .superpowers/archive/Nenita-<n>.xcarchive \
      -exportOptionsPlist .superpowers/ExportUpload.plist \
      -exportPath .superpowers/export -allowProvisioningUpdates \
      -authenticationKeyPath <ASC .p8 key path — see .team/knowledge.md> \
      -authenticationKeyID <key id> -authenticationKeyIssuerID <issuer id>

`destination: upload` writes no `.ipa`; an empty exportPath is normal.
Success = "Upload succeeded"; then poll `GET /v1/builds?filter[app]=6799234275`
until the build's `processingState` is `VALID` (3–5 min so far). Report
upload time and VALID time to the Manager; the OWNER confirms.

TODO (unverified by the wizard): the archive and export command lines are
reconstructed from knowledge.md and the archives on disk, not rerun here;
confirm them on the next release and fix this section.

## Tag

Only after the owner confirms the upload: `git tag v<ver>+<n> <merge hash>`
and push the tag. (No tags exist before 1.0.3; tagging starts with the next
release.)

## Rule

A shipped build is never rebuilt — a fix ships as a new build number (and
a new version once the current one is released).
