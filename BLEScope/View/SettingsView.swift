import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var ble: BLEManager

    var body: some View {
        NavigationStack {
            Form {
                Section("Scanner") {
                    Toggle("Hide Unnamed Devices", isOn: $ble.hideUnnamedDevices)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("RSSI Threshold")
                            Spacer()
                            Text("\(ble.rssiThreshold) dBm")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(ble.rssiThreshold) },
                            set: { ble.rssiThreshold = Int($0) }
                        ), in: -100...0, step: 1)
                        Text("Only show devices with RSSI >= threshold")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
