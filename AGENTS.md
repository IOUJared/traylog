# TrayLog agent guide

## What this is

TrayLog is a small, local-first iPhone app for tracking a clear-aligner
treatment plan (Visaline, Invisalign, or any other brand). The user enters tray
count, days per tray, and when the current tray started; the app shows tray
progress and schedules one local notification on change day. There is no
account, no server, and no analytics. Success means the user can answer "which
tray am I on, and when do I change?" in one glance and gets a reliable reminder.

## Stack and entry points

- Language and runtime: Swift 6 (iOS 17+), Foundation-only core
- Framework: SwiftUI, UserNotifications, Observation
- Main entry point: `App/TrayLogApp.swift` → `App/Views/RootView.swift`
- Key directories:
  - `Core/` — platform-independent Swift package (`TrayLogCore`) with the
    treatment-plan model and all schedule/reminder date math; tested on Linux
    and in CI
  - `App/` — SwiftUI app target; no business rules that belong in `Core`
  - `project.yml` — XcodeGen spec; the Xcode project is generated, not edited

## Commands

| Task | Command |
| --- | --- |
| Install | `brew install xcodegen` (macOS only) |
| Dev | `open TrayLog.xcodeproj` (regenerate with `xcodegen generate` after editing `project.yml`) |
| Test | `swift test --package-path Core` |
| Lint | (none configured; Swift 6 warnings are errors in the app target) |
| Typecheck | `swift build --package-path Core` |
| Build | `xcodebuild -project TrayLog.xcodeproj -scheme TrayLog -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` |

This repository is developed on Linux, where the iOS SDK is unavailable. Local
verification is `swift test --package-path Core`; the iOS build is verified by
GitHub Actions on `macos-15`. Do not claim the app builds or runs on a device
without that CI result or a local Xcode build.

## Architecture and boundaries

- `TrayLogCore` owns the model and every date calculation. It must stay free of
  SwiftUI, UIKit, and UserNotifications so it keeps compiling and testing on
  Linux.
- Schedule semantics: a plan stores `currentTray` and `trayStartDate` (the day
  the current tray started). Changing trays moves the baseline to the day the
  user records the change, so early and late changes shift the rest of the
  schedule without drift.
- `App/PlanStore.swift` persists one plan as JSON in `UserDefaults`, validates
  decoded values through `TreatmentPlan.validated()`, and asks
  `NotificationScheduler` to replace the single pending reminder.
- Only one change reminder is pending at a time, under the fixed identifier
  `tray-change-next`. Rescheduling removes it first.
- No networking, no third-party dependencies, no data collection.

## Conventions and gotchas

- Calendar arithmetic uses `Calendar`, never `TimeInterval` day math; DST and
  local-midnight boundaries are covered by tests.
- `daysUntilChange` may be negative (overdue); `dayNumberInTray` clamps to
  `1...daysPerTray`; `overallProgress` clamps to `0...1`.
- User-facing strings live in the app target; `Core` exposes values only.
- The app must remain useful with notifications denied: the plan screen and
  overdue state carry the same information.
- `SWIFT_TREAT_WARNINGS_AS_ERRORS` is on; keep the build warning-free.

## Verification before completion

1. `swift test --package-path Core` passes.
2. The GitHub Actions `Build iOS app` job passes on the pushed commit.
3. Any schedule or reminder change has a test in
   `Core/Tests/TrayLogCoreTests/TreatmentPlanTests.swift` that fails without it.

## Domain glossary

| Term | Meaning |
| --- | --- |
| tray | One numbered clear-aligner stage in the plan |
| change day | The day the current tray's wear period ends and the next begins |
| overdue | `today >= changeDate` and the user has not recorded a change |
| plan | `totalTrays`, `daysPerTray`, current tray, and the day the current tray started |
| reminder | The single local notification scheduled for the next change day |

## Decisions

- Native SwiftUI over React Native: smallest dependency-free surface and real
  system notifications; verified in CI rather than locally (Linux host).
- Store the current tray's start date instead of the original start date, so
  early/late changes adjust the schedule without rewriting history.
- Schedule one pending reminder, not one per future tray: the schedule shifts
  whenever a change is recorded.
- MIT license, public repository.
