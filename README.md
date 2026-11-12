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
- Home-screen widget (small and medium) plus lock-screen accessory widgets with
  the tray, day, and change countdown
- Shows the change day, "in N days" / "due today" / "N days overdue", and a
  projected finish date
- Calendar tab with every tray's change day marked, month navigation, progress,
  and a list of the next five switches
- Sends one local notification on change day at the time you choose
- Records a tray change in one tap; the next tray starts that day, so changing
  early or late shifts the rest of the schedule instead of drifting
- Set the schedule from either the whole-treatment start date or the current
  tray's start; the other date is calculated
- Handles the final tray and marks the plan complete
- Works with notifications denied — the plan screen carries the same
  information
- Delete the plan and its reminder at any time

## Requirements

- iPhone on iOS 17 or later
- A paid Apple Developer Program membership to install the **widget** (App
  Groups are not available to free Apple IDs) and to use TestFlight
- macOS with Xcode 16+ to build from source

Free Apple ID builds can still run the app if you remove the widget dependency
and the App Group entitlement, but the widget needs the paid account.

## Build and run

```sh
open TrayLog.xcodeproj
```

The Xcode project is committed, so no extra tooling is needed to build. It is
generated from `project.yml`; after editing that file, regenerate it with
`xcodegen generate` (`brew install xcodegen`).

Select your iPhone and run. With a free Apple ID, remove the widget target and
the App Group entitlement first (see Requirements); then use Xcode's personal
team and re-sign every 7 days.

### Tests

The schedule and reminder logic lives in the `TrayLogCore` package and runs
anywhere Swift 6 runs:

```sh
swift test --package-path Core
```

The GitHub Actions workflow runs those tests on Linux and builds the app for the
iOS Simulator on macOS. The iOS build cannot be verified on a Linux host.

## Widget

`TrayLogWidget` is a WidgetKit extension embedded in the app. It reads the plan
from the shared App Group `group.com.ioujared.traylog`, so adding, editing, or
advancing a tray refreshes the widget immediately.

Families: small, medium, lock-screen circular, and lock-screen rectangular. It
builds a week of daily entries so the countdown rolls over at midnight without
opening the app, and the widget shows an empty state until a plan exists.

Both targets carry the App Group entitlement in `Config/`. Register the group in
the developer portal and enable it on both App IDs before signing.

## TestFlight

`.github/workflows/testflight.yml` archives the app and uploads it to App Store
Connect on a `v*` tag or manual dispatch. It needs a paid Apple Developer
Program membership, an App Store Connect API key, and the App Group above. Full
setup and troubleshooting: [docs/testflight.md](docs/testflight.md).

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
- Data stored in the shared App Group container on your phone
- Notifications are generated on-device
- MIT licensed, so the claims above are verifiable

## Limitations

TrayLog is a schedule and reminder tool, not a medical device. It does not judge
tray fit or decide when your teeth are ready. Follow your orthodontist's plan,
and contact them if a tray will not seat or hurts more than expected.

## License

MIT. See [LICENSE](LICENSE).
