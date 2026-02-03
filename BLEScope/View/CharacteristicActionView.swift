import SwiftUI
import CoreBluetooth

struct CharacteristicActionView: View {
    @EnvironmentObject var ble: BLEManager
    @Environment(\.dismiss) private var dismiss
    let characteristic: CharacteristicInfo

    @State private var inputMode = 0
    @State private var inputText = ""
    @State private var enableNotify = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Characteristic") {
                    Text("Service: \(characteristic.serviceUUID.uuidString)")
                        .font(.caption)
                    Text("UUID: \(characteristic.uuid.uuidString)")
                        .font(.caption)
                    Text("Properties: \(characteristic.properties.shortDescription)")
                        .font(.caption)
                }

                Section("Latest Value") {
                    Text(characteristic.lastValue?.hexString() ?? "--")
                        .font(.footnote)
                        .textSelection(.enabled)
                    Text(characteristic.lastValue?.asciiString() ?? "--")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }

                Section("Actions") {
                    Button("Read") {
                        ble.readValue(serviceUUID: characteristic.serviceUUID, characteristicUUID: characteristic.uuid)
                    }

                    Toggle("Notify", isOn: $enableNotify)
                        .onChange(of: enableNotify) { value in
                            ble.toggleNotify(serviceUUID: characteristic.serviceUUID, characteristicUUID: characteristic.uuid, enable: value)
                        }
                }

                Section("Write") {
                    Picker("Input", selection: $inputMode) {
                        Text("HEX").tag(0)
                        Text("ASCII").tag(1)
                    }
                    .pickerStyle(.segmented)

                    TextField("Enter data", text: $inputText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    Button("Send") {
                        let data: Data?
                        if inputMode == 0 {
                            data = inputText.hexToData()
                        } else {
                            data = inputText.data(using: .utf8)
                        }

                        guard let payload = data, !payload.isEmpty else {
                            errorMessage = "Invalid or empty payload"
                            showError = true
                            return
                        }

                        ble.writeValue(serviceUUID: characteristic.serviceUUID, characteristicUUID: characteristic.uuid, data: payload)
                    }
                }
            }
            .navigationTitle("Characteristic")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                enableNotify = characteristic.isNotifying
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .onTapEndEditing()
    }
}
