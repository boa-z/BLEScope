import SwiftUI
import CoreBluetooth

struct CharacteristicActionView: View {
    @EnvironmentObject var ble: BLEManager
    @Environment(\.dismiss) private var dismiss
    let characteristic: CharacteristicInfo

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

                Section("History") {
                    NavigationLink("History") {
                        CharacteristicHistoryView(characteristic: characteristic)
                            .environmentObject(ble)
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
        }
        .onTapEndEditing()
    }
}

private struct CharacteristicHistoryView: View {
    @EnvironmentObject var ble: BLEManager
    let characteristic: CharacteristicInfo
    @State private var inputMode = 0
    @State private var inputText = ""
    @State private var enableNotify = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showTimestamp = true

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack {
                    Text("HISTORY")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Toggle("Timestamp", isOn: $showTimestamp)
                        .font(.caption2)
                        .toggleStyle(.switch)
                }
                TerminalPanel(
                    entries: combinedEntries,
                    showTimestamp: showTimestamp
                )
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Form {
                Section("Actions") {
                    Button("Read") {
                        ble.readValue(peripheralId: characteristic.peripheralId, serviceUUID: characteristic.serviceUUID, characteristicUUID: characteristic.uuid)
                    }

                    Toggle("Notify", isOn: $enableNotify)
                        .onChange(of: enableNotify) { value in
                            ble.toggleNotify(peripheralId: characteristic.peripheralId, serviceUUID: characteristic.serviceUUID, characteristicUUID: characteristic.uuid, enable: value)
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

                        ble.writeValue(peripheralId: characteristic.peripheralId, serviceUUID: characteristic.serviceUUID, characteristicUUID: characteristic.uuid, data: payload)
                    }
                }

                Section {
                    Button("Clear History") {
                        ble.clearHistory(peripheralId: characteristic.peripheralId, serviceUUID: characteristic.serviceUUID, characteristicUUID: characteristic.uuid, direction: .rx)
                        ble.clearHistory(peripheralId: characteristic.peripheralId, serviceUUID: characteristic.serviceUUID, characteristicUUID: characteristic.uuid, direction: .tx)
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("History")
        .onAppear {
            enableNotify = characteristic.isNotifying
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var combinedEntries: [LogEntry] {
        let filtered = ble.logs.filter {
            ($0.direction == .rx || $0.direction == .tx)
            && $0.peripheralId == characteristic.peripheralId.uuidString
            && $0.serviceUUID == characteristic.serviceUUID.uuidString
            && $0.characteristicUUID == characteristic.uuid.uuidString
        }
        let sorted = filtered.sorted { $0.timestamp < $1.timestamp }
        return Array(sorted.suffix(200))
    }
}

private struct TerminalPanel: View {
    let entries: [LogEntry]
    let showTimestamp: Bool
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            if showTimestamp {
                                Text("$ [\(timeFormatter.string(from: entry.timestamp))]")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(entryLine(entry))
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                                .foregroundColor(colorForDirection(entry.direction))
                        }
                        .id(entry.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(height: 260)
            .onChange(of: entries.count, initial: false) { _, _ in
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
        .padding(12)
        .background(Color.black.opacity(0.92))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private func entryLine(_ entry: LogEntry) -> String {
        let prefix = entry.direction == .rx ? "RX" : "TX"
        let hex = entry.data?.hexString() ?? "--"
        let ascii = entry.data?.asciiString() ?? "--"
        return "[\(prefix)] \(hex) | \(ascii)"
    }

    private func colorForDirection(_ direction: LogEntry.Direction) -> Color {
        switch direction {
        case .rx: return .blue
        case .tx: return .green
        case .event: return .orange
        case .error: return .red
        }
    }
}
