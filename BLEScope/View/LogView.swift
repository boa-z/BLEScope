import SwiftUI

struct LogView: View {
    @EnvironmentObject var ble: BLEManager
    @State private var showShare = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            List(ble.logs) { log in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(log.direction.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(colorForDirection(log.direction))
                            .foregroundColor(.white)
                            .cornerRadius(4)

                        Text(log.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(log.peripheralName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let service = log.serviceUUID {
                        Text("S: \(service)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if let char = log.characteristicUUID {
                        Text("C: \(char)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let data = log.data {
                        Text(data.hexString())
                            .font(.footnote)
                            .textSelection(.enabled)
                        Text(data.asciiString())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }

                    if let note = log.note, !note.isEmpty {
                        Text(note)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") { ble.clearLogs() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        exportURL = ble.exportLogs()
                        showShare = exportURL != nil
                    }
                }
            }
            .sheet(isPresented: $showShare) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
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
