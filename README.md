# VoltRide ⚡

VoltRide is a smart GPS Speedometer, Trip Recorder, and JK-BMS Battery Monitor specifically designed for Electric Vehicles (EV). It features a modern, neon-inspired dark mode UI, telemetry dashboards, real-time GPS tracking, and Bluetooth Low Energy (BLE) integration with Jikong Battery Management Systems (JK-BMS).

## 🚀 Features
- **Real-Time GPS Telemetry**: Accurate speed tracking, max speed, average speed, and trip duration.
- **JK-BMS Integration**: Connects directly via BLE to read State of Charge (SOC), voltage, current, and temperature from your Jikong BMS.
- **Trip Recording**: Track and save your EV rides locally using an internal SQLite database.
- **Cross-Platform Support**: 
  - **Android APK**: Full functionality including GPS and Bluetooth BLE for live vehicle monitoring.
  - **Web Dashboard**: View your dashboard directly from any browser (Note: Web Bluetooth is not supported on iOS Safari, so the BLE feature is bypassed on the web).

## 🛠️ Tech Stack
- **Framework**: Flutter & Dart
- **State Management**: Riverpod (`flutter_riverpod`)
- **Database**: SQLite (`sqflite`)
- **Bluetooth**: `flutter_blue_plus`
- **Location/GPS**: `geolocator`
- **Charts & Maps**: `fl_chart`, `flutter_map`

## 📦 Download & Installation
You do not need to build the app manually to try it out. VoltRide uses GitHub Actions to automatically build the latest versions whenever code is updated.

1. Go to the [Actions tab](https://github.com/aanmochtar80/VoltRide/actions) in this repository.
2. Click on the latest successful **Build Android APK** workflow.
3. Scroll down to the **Artifacts** section and download `voltride-android-apk.zip`.
4. Extract the ZIP file and install the `app-release.apk` on your Android device.

*(Don't forget to grant Location and Nearby Devices / Bluetooth permissions when you first open the app!)*

## 🖥️ Web Version
You can access the live web version of VoltRide (hosted via Cloudflare/aaPanel) at:
👉 `https://voltride.mytunnels.my.id/`

*Note: The web version is intended for UI previews and dashboard testing. Bluetooth connectivity to the JK-BMS requires the Android native app.*
