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
- Follow-up: signed builds passed, iPhone installation succeeded, and the user confirmed iPhone launch after developer trust. Follow-up additionally confirmed Ultra 2 installation and launch. The user confirmed receipt of the 10-second test notification. Actual sound output, real 78-entry WatchConnectivity transfer/scheduling, and OS pending-limit behavior remain unverified.
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
- First iPhone launch was denied by the device security service. Local signature/profile checks passed. The user then explicitly trusted their developer profile and confirmed that the iPhone app opened successfully.
- Initial direct Ultra 2 installation timed out while establishing the network tunnel; this was later resolved as recorded below.

## Installation-failure diagnosis after OS update

- Both physical devices were detected on iOS/watchOS 27.2. Watch Developer Mode was confirmed enabled both by the user and device metadata.
- A fresh developer pairing with the Mac was completed by the user; the pairing timestamp updated. Direct Mac-to-Watch transfer still failed before app transfer while establishing the local-network tunnel.
- A targeted iPhone Console stream captured the real reason for the iPhone Watch-app installation failure: `MIInstallerErrorDomain Code=111`, indicating that the watch bundle is authorized by a **free provisioning profile**, but installation **from this source is not allowed**. This is distinct from the Mac-to-Watch network tunnel timeout.
- The earlier suggestion to install the free-signed Watch app through the iPhone Watch app was incorrect for this setup. The setup guide now directs free-signed installs through Xcode directly to the physical Watch. No repeated iPhone Watch-app installs are advised.
- Targeted Console streaming was stopped after diagnosis. No raw device logs, identifiers, or profiles are published.

## Successful Ultra 2 installation

- After the user placed Mac, iPhone, and Watch on the same Wi-Fi, the previous tunnel timeout no longer blocked progress. The next explicit failure was that the Watch was locked while the developer disk image was being mounted.
- After the user unlocked the Watch, direct installation with `devicectl device install app` succeeded on the physical Ultra 2 running watchOS 27.2 (`App installed`, bundle ID `jp.isobem.watchalarm.native20261030.watchkitapp`).
- This is a successful free-development-signed installation directly from the Mac, distinct from the iPhone Watch-app source that was rejected.
- Notification authorization, notification sound/firing, actual 78-entry import, and WatchConnectivity end-to-end scheduling still need separate verification. Installation alone does not validate those features.

- Launch on the physical Ultra 2 succeeded with `devicectl device process launch`.
- The user then confirmed that the app's 10-second standard test notification arrived. This verifies basic local-notification delivery, but is not a claim of verified custom audio or verified real 78-entry scheduling.
