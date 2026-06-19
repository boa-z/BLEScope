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

## CI and AltStore
- `build.yml` builds unsigned iOS `.ipa` artifacts and Mac Catalyst `.dmg` artifacts, then publishes default-branch and manually requested nightly releases.
- `update_source.yml` regenerates the AltStore-compatible source manifest (`apps.json`) from the nightly release and uploads it back to the release asset.

AltStore source URL:

```text
https://github.com/boa-z/BLEScope/releases/download/nightly/apps.json
```

The nightly release asset is the install source of truth; the repository copy at `.github/apps.json` is only the manifest template used by the workflow.

## Usage
1. Build and run on a real iOS device.
2. Open **Devices** tab to scan and connect.
3. Tap a characteristic to read, write, or toggle notifications.
4. View logs in **Logs** tab.
5. Export logs as CSV from **Logs** tab.
6. Adjust filters in **Settings** tab.

## Notes
- iOS apps cannot access Classic Bluetooth (SPP/RFCOMM). BLEScope is BLE-only.
