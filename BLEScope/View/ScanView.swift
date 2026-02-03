import SwiftUI
import CoreBluetooth

struct ScanView: View {
    @EnvironmentObject var ble: BLEManager
    @State private var filterText = ""

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
                                Text(device.name)
                                    .font(.headline)
                                Text(device.id.uuidString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
