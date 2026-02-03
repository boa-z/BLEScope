import SwiftUI
import CoreBluetooth

struct PeripheralDetailView: View {
    @EnvironmentObject var ble: BLEManager
    let peripheral: CBPeripheral
    @State private var selectedCharacteristic: CharacteristicInfo?

    private var isConnected: Bool {
        ble.connectedPeripheral?.identifier == peripheral.identifier
    }

    var body: some View {
        List {
            Section("Device") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(peripheral.name ?? "(no name)")
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                HStack {
                    Text("UUID")
                    Spacer()
                    Text(peripheral.identifier.uuidString)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                HStack {
                    Text("Status")
                    Spacer()
                    Text(isConnected ? "Connected" : "Not Connected")
                        .foregroundColor(isConnected ? .green : .secondary)
                }
                Button(isConnected ? "Disconnect" : "Connect") {
                    isConnected ? ble.disconnect() : ble.connect(peripheral)
                }
                .buttonStyle(.borderedProminent)
            }

            if isConnected {
                Section("Services & Characteristics") {
                    ForEach(ble.services) { service in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Service: \(service.uuid.uuidString)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            ForEach(service.characteristics) { characteristic in
                                Button {
                                    selectedCharacteristic = characteristic
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(characteristic.uuid.uuidString)
                                                .font(.footnote)
                                            Text(characteristic.properties.shortDescription)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if characteristic.isNotifying {
                                            Text("Notifying")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(peripheral.name ?? "Peripheral")
        .sheet(item: $selectedCharacteristic) { char in
            CharacteristicActionView(characteristic: char)
                .environmentObject(ble)
        }
    }
}
