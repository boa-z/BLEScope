import Foundation
import CoreBluetooth

struct DiscoveredPeripheral: Identifiable, Hashable {
    let id: UUID
    var name: String
    var rssi: NSNumber
    var isConnectable: Bool
    var peripheral: CBPeripheral
    var lastConnectedAt: Date?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DiscoveredPeripheral, rhs: DiscoveredPeripheral) -> Bool {
        lhs.id == rhs.id
    }
}

struct ServiceInfo: Identifiable {
    let id: String
    let uuid: CBUUID
    var characteristics: [CharacteristicInfo]
}

struct CharacteristicInfo: Identifiable {
    let id: String
    let peripheralId: UUID
    let serviceUUID: CBUUID
    let uuid: CBUUID
    var properties: CBCharacteristicProperties
    var isNotifying: Bool
    var lastValue: Data?
}

struct CharacteristicKey: Hashable {
    let serviceUUID: CBUUID
    let characteristicUUID: CBUUID
}

struct LogEntry: Identifiable, Codable {
    enum Direction: String, Codable {
        case rx = "RX"
        case tx = "TX"
        case event = "EVT"
        case error = "ERR"
    }

    let id: UUID
    let timestamp: Date
    let direction: Direction
    let peripheralName: String
    let peripheralId: String?
    let serviceUUID: String?
    let characteristicUUID: String?
    let data: Data?
    let note: String?
}

struct ConnectionStep: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
}
