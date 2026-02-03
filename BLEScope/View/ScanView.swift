import SwiftUI
import CoreBluetooth

struct ScanView: View {
    @EnvironmentObject var ble: BLEManager
    @State private var filterText = ""
    @State private var serviceFilterText = ""

    var filteredDevices: [DiscoveredPeripheral] {
        let trimmed = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ble.discovered }
        return ble.discovered.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
            || $0.id.uuidString.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    TextField("Filter name or UUID", text: $filterText)
                        .textFieldStyle(.roundedBorder)

                    Button(ble.isScanning ? "Stop" : "Scan") {
                        ble.isScanning ? ble.stopScan() : ble.startScan()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.top, 12)

                List(filteredDevices) { device in
                    NavigationLink {
                        PeripheralDetailView(peripheral: device.peripheral)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HighlightText(text: device.name, query: filterText)
                                    .font(.headline)
                                    .textSelection(.enabled)
                                HighlightText(text: device.id.uuidString, query: filterText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("RSSI: \(device.rssi)")
                                    .font(.caption)
                                Text(device.isConnectable ? "Connectable" : "Unknown")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("BLE Scanner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") { ble.discovered.removeAll() }
                }
            }
        }
        .onAppear {
            if ble.centralState == .poweredOn && !ble.isScanning && ble.discovered.isEmpty {
                ble.startScan()
            }
        }
    }
}

private struct HighlightText: View {
    let text: String
    let query: String

    var body: some View {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(text)
        } else {
            highlightedText()
        }
    }

    private func highlightedText() -> Text {
        let lowerText = text.lowercased()
        let lowerQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lowerQuery.isEmpty, let range = lowerText.range(of: lowerQuery) else {
            return Text(text)
        }

        var attributed = AttributedString(text)
        if let attrRange = Range(range, in: attributed) {
            attributed[attrRange].foregroundColor = .yellow
            attributed[attrRange].backgroundColor = .yellow.opacity(0.25)
        }
        return Text(attributed)
    }
}
