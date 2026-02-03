# BLEScope

BLEScope is a SwiftUI-based BLE debugging tool for iOS.

## Features
- Scan and filter BLE peripherals
- Connect and disconnect
- Discover services and characteristics
- Read, write (HEX/ASCII), and toggle notify/indicate
- Live logs with timestamps
- HEX and ASCII views for payloads
- Export logs to CSV
- Settings: hide unnamed devices, RSSI threshold filter

## Requirements
- iOS device with BLE (real device required)
- Xcode 12+ (or newer)

## Usage
1. Build and run on a real iOS device.
2. Open **Devices** tab to scan and connect.
3. Tap a characteristic to read, write, or toggle notifications.
4. View logs in **Logs** tab.
5. Export logs as CSV from **Logs** tab.
6. Adjust filters in **Settings** tab.

## Notes
- iOS apps cannot access Classic Bluetooth (SPP/RFCOMM). BLEScope is BLE-only.
