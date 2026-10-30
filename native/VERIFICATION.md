# Verification — 2026-10-30 JST

Environment: macOS arm64, Xcode 27.1 (27A9275), Swift 6.4 (project Swift language mode 5), iOS 27.1 / watchOS 27.0 SDKs. Minimum deployment: iOS 17 / watchOS 10.

## Passed

- `Scripts/test_core.sh`: strict JSON validation, all 78 synthetic entries round-trip without loss, OFF preservation, duplicate preservation, correct weekday/local hour, weekly mode, bounded 60-occurrence rolling mode, refill, capacity exhaustion, empty snapshot, DST gap, future dates.
- iOS device **unsigned** Debug build with embedded watchOS companion: `BUILD SUCCEEDED`. Includes Swift compilation/linking for both targets and ValidateEmbeddedBinary.
- iOS Simulator generic **unsigned** Debug build with embedded watchOS Simulator companion: `BUILD SUCCEEDED`. This was compilation only, not a simulator UI/runtime test.
- Generated project: `plutil -lint` passed; shared iPhone/Watch schemes included; Watch Info.plist has `WKApplication = true` and matching `WKCompanionAppBundleIdentifier`; Watch app embedded at `WatchAlarm.app/Watch/WatchAlarmWatch.app`.

Commands (from repository root):

```sh
sh native/Scripts/test_core.sh
xcodebuild -project native/WatchAlarm.xcodeproj -scheme WatchAlarm -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/WatchAlarm-device CODE_SIGNING_ALLOWED=NO build
xcodebuild -project native/WatchAlarm.xcodeproj -scheme WatchAlarm -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/WatchAlarm-simulator CODE_SIGNING_ALLOWED=NO build
```

## Limitations / not tested

- `UNNotificationSound(named:)` was confirmed **unavailable on watchOS** by actual compiler error and installed SDK header (`soundNamed: ... API_UNAVAILABLE(watchos, tvos)`). Final app uses `.default` for Watch notifications. CAF playback is manual foreground preview only. No custom Watch notification sound or automatic background chime is claimed.
- Original Haneda CAF could not be retrieved: specified /mnt/data path absent; referenced conversation returned no attachments. Not included, not auditioned, actual duration not measured. An optional resource slot and validated CAF transfer/foreground-preview path are implemented.
- No physical iPhone/Ultra 2 installation, signing, WatchConnectivity end-to-end delivery, actual sound output, notification permission interaction, notification firing, or OS pending-limit behavior was tested.
- No access to the user's browser-local 78 real settings. Tests use synthetic 78-entry data; existing HTML copy JSON is required for migration.
- Simulator service was unavailable in this execution environment. Generic simulator compilation still succeeded; no simulator launch was attempted.
- Xcode reports the benign App Intents metadata warning (no AppIntents.framework dependency). No App Intents features are used.
- Notification capacity is conservatively bounded to 60, not a guaranteed watchOS API contract. Rolling mode requires opening the Watch app before the first unreserved occurrence; arbitrary unattended long-term scheduling is not guaranteed. Simultaneous alarms beyond capacity cannot all be scheduled.

## Existing content protection

Publication adds only `native/` on a new branch based on main commit `3ebb1e8c14e970899d1192bc65b70675acf35e9d`. The Git tree is constructed using the original tree as its base, preserving both original blobs:

- `watch-alarm.html`: `4436417642e39a7cb05eb52cfbb163fcba7c969f`
- `apple-touch-icon.png`: `f95d42d28c2a12ffa9539ca587349396f5eaad45`

No main ref update, HTML changes, browser storage changes, or Clock alarm changes are performed.

## Device signing follow-up

- Both targets were successfully signed using an existing local Apple Development identity and automatic provisioning (`BUILD SUCCEEDED`). No certificate, provisioning profile, device ID, or developer-team configuration is included in the repository.
- The original sample bundle IDs were unavailable for registration. Defaults are now `jp.isobem.watchalarm.native20261030` and `jp.isobem.watchalarm.native20261030.watchkitapp`, with a matching companion bundle ID. This also keeps the new install separate from earlier Watch Alarm apps.
- A paired Ultra 2 and a cable-connected iPhone were detected. Detection alone does not establish successful installation. Device-transfer results must be checked separately.

- iPhone installation was confirmed by `devicectl` (`App installed`). Local code-signature verification passed, and both generated profiles include the intended devices. Profiles expire on 2026-11-06 (JST); this is a development install that needs renewal/re-signing.
- First iPhone launch was denied by the device security service, reporting invalid signature, inadequate entitlements, or a developer profile not explicitly trusted. Local signature/profile checks passed; user-side developer-trust confirmation remains necessary. Successful app execution is not yet claimed.
- Direct Ultra 2 installation timed out while establishing the network tunnel. Watch installation/execution is not yet confirmed.
