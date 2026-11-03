# UnFat

A native iOS 26 calorie, macro and workout tracker for iPhone: fast food logging (recents, barcode, photo draft), gym sessions with a rest-timer Live Activity, and Home/Lock Screen widgets. Swift 6, SwiftUI, SwiftData + CloudKit, WidgetKit, ActivityKit, HealthKit. Turkish UI.

## Building without a Mac

The project is developed on Windows. There is no local Xcode; every build runs on GitHub Actions (`macos-26` runners):

- `ios/project.yml` is an [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec. CI runs `xcodegen generate`; the `.xcodeproj` is never committed.
- Every push under `ios/` runs the UnFatCore package tests and the app unit tests on an iPhone simulator.
- Manual runs (`gh workflow run ios.yml -f target=<target>`):
  - `compile`: tests only
  - `device-ipa`: development-signed IPA artifact, installed over USB
  - `testflight`: signed and uploaded to TestFlight
  - `screenshots`: simulator screenshots of every debug `-UNFAT_SCREEN` route

## Layout

- `ios/UnFat/`: app target
- `ios/UnFatWidgets/`: widget extension
- `ios/Shared/`: code compiled into both
- `ios/UnFatCore/`: pure Swift package with the nutrition and training logic
- `ios/UnFatTests/`: app unit tests

## Docs

- [Spec](docs/SPEC.md)
- [Plan](docs/PLAN.md)
- [File map](filemap.md)
- [Research](docs/research/)
