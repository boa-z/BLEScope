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

                Section("Last Value") {
                    Text(characteristic.lastValue?.hexString() ?? "--")
                        .font(.footnote)
                        .textSelection(.enabled)
                    Text(characteristic.lastValue?.asciiString() ?? "--")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }

                Section("Read History") {
                    HStack {
                        Spacer()
                        Button("Clear History") {
                            ble.clearHistory(serviceUUID: characteristic.serviceUUID, characteristicUUID: characteristic.uuid, direction: .rx)
                        }
                        .font(.caption)
                    }
                    TerminalPanel(
                        title: "READ STREAM",
                        entries: readEntries
                    )
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

    private var readEntries: [LogEntry] {
        let filtered = ble.logs.filter {
            $0.direction == .rx
            && $0.serviceUUID == characteristic.serviceUUID.uuidString
            && $0.characteristicUUID == characteristic.uuid.uuidString
        }
        return Array(filtered.prefix(200)).reversed()
    }
}

private struct TerminalPanel: View {
    let title: String
    let entries: [LogEntry]
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Spacer()
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("$ [\(timeFormatter.string(from: entry.timestamp))]")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(entry.data?.hexString() ?? "--")
                                    .font(.system(.footnote, design: .monospaced))
                                    .textSelection(.enabled)
                                    .foregroundColor(.green)
                                Text(entry.data?.asciiString() ?? "--")
                                    .font(.system(.footnote, design: .monospaced))
                                    .textSelection(.enabled)
                                    .foregroundColor(.green)
                            }
                            .id(entry.id)
                        }
                    }
                }
                .frame(height: 220)
                .onChange(of: entries.count) { _ in
                    if let last = entries.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                .onAppear {
                    if let last = entries.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.9))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
