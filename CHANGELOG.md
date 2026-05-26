# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-05-25

### Added
- Initial Flutter project structure with Riverpod state management and SQLite database integration.
- Modern, neon-themed dark mode UI for the Dashboard, Speedometer, and Telemetry Cards.
- GPS Tracking and Speedometer logic utilizing `geolocator`.
- BLE Scanner and JK-BMS connection framework using `flutter_blue_plus`.
- GitHub Actions workflow (`build_web.yml`) for automatic Flutter Web compilation.
- GitHub Actions workflow (`build_apk.yml`) for automatic Android APK compilation.
- `assets/images/` directory added to satisfy `pubspec.yaml` requirements.

### Fixed
- **[Web]** Fixed unhandled Web exceptions and crashes caused by `flutter_blue_plus` and `geolocator` by explicitly bypassing hardware-specific calls on the Web platform.
- **[Web]** Fixed mobile browser UI scaling (tiny text issue) by adding the missing `<meta name="viewport">` tag to `web/index.html`.
- **[Android]** Resolved Android APK build failures (exit code 2) by forcefully wiping corrupted Android folders before the CI build.
- **[Android]** Fixed `flutter_blue_plus` build rejections by automatically enforcing `minSdkVersion 21`, `compileSdkVersion 34`, and `Kotlin 1.9.22` in the GitHub Actions workflow.
- **[Android]** Fixed dependency conflict with Android SDK 34 by upgrading `share_plus` to `^10.0.0` and `wakelock_plus` to `^1.2.8`.
- **[BLE]** Fixed connection issues with legacy JK BMS models (Mx1200) by expanding the polling loop to include `55 AA EB 90` reverse-header probes and short RS485 `55 AA 00 FF` probes.
- **[BLE]** Fixed `FC AA 06` and `FC 55 06` rejection errors by broadcasting polling commands to ALL available BMS write characteristics instead of just one.
- **[BLE]** Fixed a major issue where the BMS total voltage was reported incorrectly (e.g., >11,000V) on older firmware variants by summing individual cell voltages as a fallback.
- **[BLE]** Fixed a bug where the BMS BLE name got unintentionally corrupted (`U...`) because the app blindly wrote polling commands to the Generic Access Device Name characteristic. Write characteristics are now strictly filtered.
- **[UI]** Removed the broken "Turn Off BLE" toggle switch from the scanner page since Android 13+ prevents apps from programmatically disabling Bluetooth.
