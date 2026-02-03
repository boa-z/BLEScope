import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var ble: BLEManager
    private let projectURL = URL(string: "https://github.com/boa-z/BLEScope")!

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var gitBranch: String {
        Bundle.main.infoDictionary?["GitBranch"] as? String ?? "unknown"
    }

    private var gitCommitShort: String {
        Bundle.main.infoDictionary?["GitCommitShort"] as? String ?? "unknown"
    }

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
                Section("Logs") {
                    Toggle("Keep Logs On Exit", isOn: $ble.keepLogsOnExit)
                    Button("Clear Logs & History") {
                        ble.clearLogsAndHistory()
                    }
                    .foregroundColor(.red)
                }
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(appVersion) - \(gitBranch)/\(gitCommitShort)")
                            .foregroundColor(.secondary)
                    }
                    Link("Project URL", destination: projectURL)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
