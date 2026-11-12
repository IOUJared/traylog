# TrayLog

A small, local-first iPhone app for tracking a clear-aligner plan — Visaline,
Invisalign, Spark, or any other brand. Tell it how many trays you have, how long
you wear each one, and when the current tray started; TrayLog keeps the schedule
and reminds you on change day.

No account, no server, no analytics, no third-party dependencies. Your plan
stays in `UserDefaults` on your phone.

## What it does

- Shows the current tray, the day within that tray, and overall treatment
  progress
- Shows the change day, "in N days" / "due today" / "N days overdue", and a
  projected finish date
- Sends one local notification on change day at the time you choose
- Records a tray change in one tap; the next tray starts that day, so changing
  early or late shifts the rest of the schedule instead of drifting
- Handles the final tray and marks the plan complete
- Works with notifications denied — the plan screen carries the same
  information
- Delete the plan and its reminder at any time

## Requirements

- iPhone on iOS 17 or later
- macOS with Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) to
  build from source (`brew install xcodegen`)

## Build and run

```sh
open TrayLog.xcodeproj
```

The Xcode project is committed, so no extra tooling is needed to build. It is
generated from `project.yml`; after editing that file, regenerate it with
`xcodegen generate` (`brew install xcodegen`).

Select your iPhone and run. To install without a paid Apple Developer account,
use a free Apple ID with Xcode's personal team (the app must be re-signed every
7 days), or sideload with AltStore/SideStore.

### Tests

The schedule and reminder logic lives in the `TrayLogCore` package and runs
anywhere Swift 6 runs:

```sh
swift test --package-path Core
```

The GitHub Actions workflow runs those tests on Linux and builds the app for the
iOS Simulator on macOS. The iOS build cannot be verified on a Linux host.

## How the schedule works

A plan stores the current tray and the day that tray started. The change day is
`trayStartDate + daysPerTray`. Recording a change moves the baseline to the day
you record it, which is why a late change does not leave the rest of the plan
permanently shifted. All date math uses `Calendar` day boundaries, so DST and
local midnight are handled correctly.

Only one notification is pending at a time. Saving a plan, changing a tray, or
disabling reminders replaces or removes it.

## Privacy

- No networking code, no accounts, no telemetry
- Data stored locally in `UserDefaults`
- Notifications are generated on-device
- MIT licensed, so the claims above are verifiable

## Limitations

TrayLog is a schedule and reminder tool, not a medical device. It does not judge
tray fit or decide when your teeth are ready. Follow your orthodontist's plan,
and contact them if a tray will not seat or hurts more than expected.

## License

MIT. See [LICENSE](LICENSE).
