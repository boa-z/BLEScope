import Foundation
import CoreBluetooth

struct DiscoveredPeripheral: Identifiable, Hashable {
    let id: UUID
    var name: String
    var rssi: NSNumber
    var isConnectable: Bool
    var peripheral: CBPeripheral

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

struct LogEntry: Identifiable {
    enum Direction: String {
        case rx = "RX"
        case tx = "TX"
        case event = "EVT"
        case error = "ERR"
    }

    let id = UUID()
    let timestamp: Date
    let direction: Direction
    let peripheralName: String
    let serviceUUID: String?
    let characteristicUUID: String?
    let data: Data?
    let note: String?
}
