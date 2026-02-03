import Foundation
import CoreBluetooth

final class BLEManager: NSObject, ObservableObject {
    @Published var centralState: CBManagerState = .unknown
    @Published var isScanning = false
    @Published var discovered: [DiscoveredPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var services: [ServiceInfo] = []
    @Published var logs: [LogEntry] = []
    @Published var hideUnnamedDevices: Bool {
        didSet {
            UserDefaults.standard.set(hideUnnamedDevices, forKey: "ble_hide_unnamed")
            updateDiscovered()
        }
    }
    @Published var rssiThreshold: Int {
        didSet {
            UserDefaults.standard.set(rssiThreshold, forKey: "ble_rssi_threshold")
            updateDiscovered()
        }
    }

    private let queue = DispatchQueue(label: "BLEManagerQueue")
    private var central: CBCentralManager!

    private var peripheralsById: [UUID: CBPeripheral] = [:]
    private var rssiById: [UUID: NSNumber] = [:]
    private var smoothedRssiById: [UUID: Double] = [:]
    private var connectableById: [UUID: Bool] = [:]
    private var nameById: [UUID: String] = [:]
    private var discoveryOrder: [UUID] = []
    private var displayOrder: [UUID] = []
    private let rssiAlpha = 0.2
    private let resortInterval: TimeInterval = 2.0
    private var lastResortAt: Date = .distantPast

    private var characteristicsByKey: [CharacteristicKey: CBCharacteristic] = [:]

    override init() {
        self.hideUnnamedDevices = UserDefaults.standard.bool(forKey: "ble_hide_unnamed")
        let savedThreshold = UserDefaults.standard.object(forKey: "ble_rssi_threshold") as? Int
        self.rssiThreshold = savedThreshold ?? -90
        super.init()
        central = CBCentralManager(delegate: self, queue: queue)
    }

    func startScan() {
        guard centralState == .poweredOn else {
            appendLog(direction: .error, note: "Bluetooth not powered on")
            return
        }
        discovered.removeAll()
        rssiById.removeAll()
        smoothedRssiById.removeAll()
        connectableById.removeAll()
        nameById.removeAll()
        discoveryOrder.removeAll()
        displayOrder.removeAll()
        lastResortAt = .distantPast
        central.scanForPeripherals(withServices: nil,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        isScanning = true
        appendLog(direction: .event, note: "Scan started")
    }

    func stopScan() {
        central.stopScan()
        isScanning = false
        appendLog(direction: .event, note: "Scan stopped")
    }


    func connect(_ peripheral: CBPeripheral) {
        central.connect(peripheral, options: nil)
        appendLog(direction: .event, peripheral: peripheral, note: "Connecting")
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            central.cancelPeripheralConnection(peripheral)
        }
    }

    func readValue(serviceUUID: CBUUID, characteristicUUID: CBUUID) {
        let key = CharacteristicKey(serviceUUID: serviceUUID, characteristicUUID: characteristicUUID)
        guard let char = characteristicsByKey[key] else { return }
        guard char.properties.contains(.read) else {
            appendLog(direction: .error, peripheral: connectedPeripheral, serviceUUID: serviceUUID, characteristicUUID: characteristicUUID, note: "Characteristic not readable")
            return
        }
        connectedPeripheral?.readValue(for: char)
        appendLog(direction: .tx, peripheral: connectedPeripheral, serviceUUID: serviceUUID, characteristicUUID: characteristicUUID, note: "Read requested")
    }

    func writeValue(serviceUUID: CBUUID, characteristicUUID: CBUUID, data: Data) {
        let key = CharacteristicKey(serviceUUID: serviceUUID, characteristicUUID: characteristicUUID)
        guard let char = characteristicsByKey[key] else { return }

        let canWrite = char.properties.contains(.write)
        let canWriteWithoutResponse = char.properties.contains(.writeWithoutResponse)
        guard canWrite || canWriteWithoutResponse else {
            appendLog(direction: .error, peripheral: connectedPeripheral, serviceUUID: serviceUUID, characteristicUUID: characteristicUUID, note: "Characteristic not writable")
            return
        }

        let type: CBCharacteristicWriteType = canWrite ? .withResponse : .withoutResponse
        connectedPeripheral?.writeValue(data, for: char, type: type)
        appendLog(direction: .tx, peripheral: connectedPeripheral, serviceUUID: serviceUUID, characteristicUUID: characteristicUUID, data: data, note: "Write")
    }

    func toggleNotify(serviceUUID: CBUUID, characteristicUUID: CBUUID, enable: Bool) {
        let key = CharacteristicKey(serviceUUID: serviceUUID, characteristicUUID: characteristicUUID)
        guard let char = characteristicsByKey[key] else { return }
        guard char.properties.contains(.notify) || char.properties.contains(.indicate) else {
            appendLog(direction: .error, peripheral: connectedPeripheral, serviceUUID: serviceUUID, characteristicUUID: characteristicUUID, note: "Characteristic not notifiable")
            return
        }
        connectedPeripheral?.setNotifyValue(enable, for: char)
        appendLog(direction: .event, peripheral: connectedPeripheral, serviceUUID: serviceUUID, characteristicUUID: characteristicUUID, note: enable ? "Notify enabled" : "Notify disabled")
    }

    func clearLogs() {
        logs.removeAll()
    }

    func clearHistory(serviceUUID: CBUUID, characteristicUUID: CBUUID, direction: LogEntry.Direction) {
        let service = serviceUUID.uuidString
        let characteristic = characteristicUUID.uuidString
        logs.removeAll {
            $0.direction == direction
            && $0.serviceUUID == service
            && $0.characteristicUUID == characteristic
        }
    }

    func exportLogs() -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        var lines: [String] = []
        lines.append("timestamp,direction,peripheral,service,characteristic,hex,ascii,note")
        for log in logs {
            let ts = formatter.string(from: log.timestamp)
            let hex = log.data?.hexString() ?? ""
            let ascii = log.data?.asciiString() ?? ""
            let line = [
                ts,
                log.direction.rawValue,
                log.peripheralName,
                log.serviceUUID ?? "",
                log.characteristicUUID ?? "",
                hex,
                ascii,
                log.note ?? ""
            ].map { $0.replacingOccurrences(of: ",", with: " ") }
             .joined(separator: ",")
            lines.append(line)
        }

        let content = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ble_logs_\(Int(Date().timeIntervalSince1970)).csv")

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            appendLog(direction: .error, note: "Export failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func appendLog(direction: LogEntry.Direction,
                           peripheral: CBPeripheral? = nil,
                           serviceUUID: CBUUID? = nil,
                           characteristicUUID: CBUUID? = nil,
                           data: Data? = nil,
                           note: String? = nil) {
        let name = peripheral?.name ?? connectedPeripheral?.name ?? "--"
        let entry = LogEntry(
            timestamp: Date(),
            direction: direction,
            peripheralName: name,
            serviceUUID: serviceUUID?.uuidString,
            characteristicUUID: characteristicUUID?.uuidString,
            data: data,
            note: note
        )
        DispatchQueue.main.async {
            self.logs.insert(entry, at: 0)
        }
    }

    private func updateDiscovered() {
        let now = Date()
        if now.timeIntervalSince(lastResortAt) >= resortInterval {
            displayOrder = peripheralsById.keys.sorted {
                (smoothedRssiById[$0] ?? -127) > (smoothedRssiById[$1] ?? -127)
            }
            lastResortAt = now
        } else {
            for id in discoveryOrder where !displayOrder.contains(id) {
                displayOrder.append(id)
            }
        }

        let items: [DiscoveredPeripheral] = displayOrder.compactMap { id in
            guard let peripheral = peripheralsById[id] else { return nil }
            let name = nameById[id] ?? peripheral.name ?? ""
            let rssi = rssiById[id]?.intValue ?? -127
            if hideUnnamedDevices && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return nil
            }
            if rssi < rssiThreshold {
                return nil
            }
            return DiscoveredPeripheral(
                id: id,
                name: name.isEmpty ? "(no name)" : name,
                rssi: rssiById[id] ?? 0,
                isConnectable: connectableById[id] ?? false,
                peripheral: peripheral
            )
        }

        DispatchQueue.main.async {
            self.discovered = items
        }
    }

    private func rebuildServices() {
        var list: [ServiceInfo] = []
        for (key, char) in characteristicsByKey {
            if let index = list.firstIndex(where: { $0.uuid == key.serviceUUID }) {
                var service = list[index]
                service.characteristics.append(
                    CharacteristicInfo(
                        id: "\(key.serviceUUID.uuidString)|\(key.characteristicUUID.uuidString)",
                        serviceUUID: key.serviceUUID,
                        uuid: key.characteristicUUID,
                        properties: char.properties,
                        isNotifying: char.isNotifying,
                        lastValue: char.value
                    )
                )
                list[index] = service
            } else {
                let info = ServiceInfo(
                    id: key.serviceUUID.uuidString,
                    uuid: key.serviceUUID,
                    characteristics: [
                        CharacteristicInfo(
                            id: "\(key.serviceUUID.uuidString)|\(key.characteristicUUID.uuidString)",
                            serviceUUID: key.serviceUUID,
                            uuid: key.characteristicUUID,
                            properties: char.properties,
                            isNotifying: char.isNotifying,
                            lastValue: char.value
                        )
                    ]
                )
                list.append(info)
            }
        }

        list.sort { $0.uuid.uuidString < $1.uuid.uuidString }
        for idx in list.indices {
            list[idx].characteristics.sort { $0.uuid.uuidString < $1.uuid.uuidString }
        }

        DispatchQueue.main.async {
            self.services = list
        }
    }

}

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            self.centralState = central.state
        }
        appendLog(direction: .event, note: "Central state: \(central.state)" )
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        peripheralsById[peripheral.identifier] = peripheral
        rssiById[peripheral.identifier] = RSSI
        let current = smoothedRssiById[peripheral.identifier] ?? RSSI.doubleValue
        let next = rssiAlpha * RSSI.doubleValue + (1.0 - rssiAlpha) * current
        smoothedRssiById[peripheral.identifier] = next

        if !discoveryOrder.contains(peripheral.identifier) {
            discoveryOrder.append(peripheral.identifier)
        }

        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            nameById[peripheral.identifier] = name
        }

        if let connectable = advertisementData[CBAdvertisementDataIsConnectable] as? Bool {
            connectableById[peripheral.identifier] = connectable
        }

        updateDiscovered()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        central.stopScan()
        DispatchQueue.main.async { self.isScanning = false }
        DispatchQueue.main.async {
            self.connectedPeripheral = peripheral
        }
        appendLog(direction: .event, peripheral: peripheral, note: "Connected")

        characteristicsByKey.removeAll()
        DispatchQueue.main.async { self.services.removeAll() }

        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        appendLog(direction: .error, peripheral: peripheral, note: "Connect failed: \(error?.localizedDescription ?? "unknown")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        appendLog(direction: .event, peripheral: peripheral, note: "Disconnected")
        DispatchQueue.main.async {
            self.connectedPeripheral = nil
            self.services.removeAll()
        }
    }
}

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            appendLog(direction: .error, peripheral: peripheral, note: "Discover services failed: \(error.localizedDescription)")
            return
        }
        peripheral.services?.forEach { service in
            peripheral.discoverCharacteristics(nil, for: service)
        }
        appendLog(direction: .event, peripheral: peripheral, note: "Services discovered")
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error = error {
            appendLog(direction: .error, peripheral: peripheral, serviceUUID: service.uuid, note: "Discover characteristics failed: \(error.localizedDescription)")
            return
        }
        service.characteristics?.forEach { char in
            let key = CharacteristicKey(serviceUUID: service.uuid, characteristicUUID: char.uuid)
            characteristicsByKey[key] = char
        }
        rebuildServices()
        appendLog(direction: .event, peripheral: peripheral, serviceUUID: service.uuid, note: "Characteristics discovered")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            appendLog(direction: .error, peripheral: peripheral, serviceUUID: characteristic.service?.uuid, characteristicUUID: characteristic.uuid, note: "Update value failed: \(error.localizedDescription)")
            return
        }
        if let serviceUUID = characteristic.service?.uuid {
            let key = CharacteristicKey(serviceUUID: serviceUUID, characteristicUUID: characteristic.uuid)
            characteristicsByKey[key] = characteristic
        }
        appendLog(direction: .rx, peripheral: peripheral, serviceUUID: characteristic.service?.uuid, characteristicUUID: characteristic.uuid, data: characteristic.value, note: "Notify/Read")
        rebuildServices()
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            appendLog(direction: .error, peripheral: peripheral, serviceUUID: characteristic.service?.uuid, characteristicUUID: characteristic.uuid, note: "Write failed: \(error.localizedDescription)")
            return
        }
        appendLog(direction: .event, peripheral: peripheral, serviceUUID: characteristic.service?.uuid, characteristicUUID: characteristic.uuid, note: "Write ack")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            appendLog(direction: .error, peripheral: peripheral, serviceUUID: characteristic.service?.uuid, characteristicUUID: characteristic.uuid, note: "Notify state failed: \(error.localizedDescription)")
            return
        }
        if let serviceUUID = characteristic.service?.uuid {
            let key = CharacteristicKey(serviceUUID: serviceUUID, characteristicUUID: characteristic.uuid)
            characteristicsByKey[key] = characteristic
        }
        rebuildServices()
    }
}
