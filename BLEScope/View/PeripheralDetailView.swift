import SwiftUI
import CoreBluetooth

struct PeripheralDetailView: View {
    @EnvironmentObject var ble: BLEManager
    let peripheral: CBPeripheral
    @State private var selectedCharacteristic: CharacteristicInfo?
    @State private var showSteps = false

    private enum ServiceCategory: Int, CaseIterable {
        case deviceInformation
        case standard
        case custom

        var title: String {
            switch self {
            case .deviceInformation: return "Device Information"
            case .standard: return "Standard Services"
            case .custom: return "Custom Services"
            }
        }
    }

    private var isConnected: Bool {
        ble.isConnected(peripheral.identifier)
    }

    private var groupedServices: [(category: ServiceCategory, services: [ServiceInfo])] {
        let grouped = Dictionary(grouping: ble.services(for: peripheral)) { service -> ServiceCategory in
            let uuid = normalizedUUIDString(service.uuid)
            if uuid == "180A" { return .deviceInformation }
            if standardServiceNames[uuid] != nil { return .standard }
            return .custom
        }
        return ServiceCategory.allCases.compactMap { category in
            guard let services = grouped[category], !services.isEmpty else { return nil }
            return (category, services)
        }
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
                    isConnected ? ble.disconnect(peripheral) : ble.connect(peripheral)
                }
                .buttonStyle(.borderedProminent)
                if let status = ble.connectionStatusById[peripheral.identifier] {
                    HStack {
                        Text("Step")
                        Spacer()
                        Text(status)
                            .foregroundColor(.secondary)
                    }
                    .onLongPressGesture {
                        showSteps = true
                    }
                }
            }

            if isConnected {
                ForEach(groupedServices, id: \.category) { group in
                    Section(group.category.title) {
                        ForEach(group.services) { service in
                            VStack(alignment: .leading, spacing: 6) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(serviceDisplayName(for: service.uuid))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(service.uuid.uuidString)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .textSelection(.enabled)
                                }

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
                                                    .lineLimit(2)
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
        }
        .listStyle(.insetGrouped)
        .navigationTitle(peripheral.name ?? "Peripheral")
        .sheet(item: $selectedCharacteristic) { char in
            CharacteristicActionView(characteristic: char)
                .environmentObject(ble)
        }
        .sheet(isPresented: $showSteps) {
            NavigationStack {
                List(ble.connectionSteps(for: peripheral)) { step in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(step.message)
                            .font(.body)
                        Text(Self.stepTimeFormatter.string(from: step.timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .navigationTitle("Connection Steps")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showSteps = false
                        }
                    }
                }
            }
        }
    }

    private func serviceDisplayName(for uuid: CBUUID) -> String {
        let key = normalizedUUIDString(uuid)
        if let name = standardServiceNames[key] {
            return name
        }
        if key == "180A" { return "Device Information" }
        return "Custom Service"
    }

    private func normalizedUUIDString(_ uuid: CBUUID) -> String {
        uuid.uuidString.uppercased()
    }

    private static let stepTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

private let standardServiceNames: [String: String] = [
    "1800": "Generic Access",
    "1801": "Generic Attribute",
    "180A": "Device Information",
    "180F": "Battery Service",
    "180D": "Heart Rate",
    "1810": "Blood Pressure",
    "1811": "Alert Notification",
    "1812": "Human Interface Device",
    "1816": "Cycling Speed and Cadence",
    "1818": "Cycling Power",
    "1819": "Location and Navigation",
    "181A": "Environmental Sensing",
    "181C": "User Data",
    "181D": "Weight Scale",
    "181E": "Bond Management",
    "181F": "Continuous Glucose Monitoring",
    "1820": "Internet Protocol Support",
    "1822": "Pulse Oximeter",
    "1826": "Fitness Machine"
]
