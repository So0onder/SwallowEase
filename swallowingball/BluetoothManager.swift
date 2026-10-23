import Foundation
import CoreBluetooth
import Combine

final class BluetoothManager: NSObject, ObservableObject {
    @Published var discoveredDevices: [CBPeripheral] = []
    
    @Published var connectedPeripheral: CBPeripheral?
    @Published var connectedDeviceName: String? = nil
    
    @Published var bluetoothStateText: String = "Bluetooth not ready"
    @Published var isBluetoothReady: Bool = false
    @Published var isScanning: Bool = false
    @Published var isConnected: Bool = false
    
    // MARK: - Real-time Pressure Data
    @Published var currentPressureN: Float = 0.0
    @Published var normalizedPressure: Double = 0.0
    
    private var centralManager: CBCentralManager!
    private var discoveredDeviceIDs: Set<UUID> = []
    
    // MARK: - BLE UUIDs
    let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    let notifyCharUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    
    private let targetDeviceName = "ForceMeter"
    
    // 用于曲线显示归一化，后续可改为可配置项
    private let maxPressureN: Float = 50.0
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    func startScan() {
        guard centralManager.state == .poweredOn else {
            bluetoothStateText = "Bluetooth is not powered on"
            return
        }
        
        discoveredDevices.removeAll()
        discoveredDeviceIDs.removeAll()
        isScanning = true
        bluetoothStateText = "Scanning..."
        
        // 第一阶段先扫全部，避免广播包没带 service UUID 时扫不到
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func stopScan() {
        centralManager.stopScan()
        isScanning = false
        bluetoothStateText = isConnected ? "Connected" : "Scan stopped"
    }
    
    func connect(_ peripheral: CBPeripheral) {
        guard centralManager.state == .poweredOn else { return }
        
        bluetoothStateText = "Connecting to \(peripheral.name ?? "device")..."
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnectCurrentDevice() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    private func updatePressure(_ pressureN: Float) {
        let safePressure = max(0.0, pressureN)
        currentPressureN = safePressure
        
        let normalized = max(0.0, min(Double(safePressure / maxPressureN), 1.0))
        normalizedPressure = normalized
    }
    
    private func parseIncomingPressureData(_ data: Data) {
        guard data.count >= 4 else {
            print("Received data too short: \(data.count) bytes")
            return
        }
        
        // 4字节 Float32, Little-endian
        let bytes = Array(data.prefix(4))
        let bitPattern =
            UInt32(bytes[0]) |
            (UInt32(bytes[1]) << 8) |
            (UInt32(bytes[2]) << 16) |
            (UInt32(bytes[3]) << 24)
        
        let pressure = Float32(bitPattern: bitPattern)
        
        guard pressure.isFinite else {
            print("Received invalid Float32 pressure value")
            return
        }
        
        updatePressure(pressure)
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            bluetoothStateText = "Bluetooth state unknown"
            isBluetoothReady = false
        case .resetting:
            bluetoothStateText = "Bluetooth resetting"
            isBluetoothReady = false
        case .unsupported:
            bluetoothStateText = "Bluetooth unsupported"
            isBluetoothReady = false
        case .unauthorized:
            bluetoothStateText = "Bluetooth unauthorized"
            isBluetoothReady = false
        case .poweredOff:
            bluetoothStateText = "Bluetooth is off"
            isBluetoothReady = false
        case .poweredOn:
            bluetoothStateText = "Bluetooth ready"
            isBluetoothReady = true
        @unknown default:
            bluetoothStateText = "Unknown Bluetooth state"
            isBluetoothReady = false
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        guard !discoveredDeviceIDs.contains(peripheral.identifier) else { return }
        discoveredDeviceIDs.insert(peripheral.identifier)
        
        let deviceName = peripheral.name ?? ""
        
        if deviceName == targetDeviceName {
            discoveredDevices.insert(peripheral, at: 0)
        } else {
            discoveredDevices.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        connectedDeviceName = peripheral.name ?? targetDeviceName
        isConnected = true
        isScanning = false
        bluetoothStateText = "Connected to \(connectedDeviceName ?? "device")"
        
        central.stopScan()
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        isConnected = false
        bluetoothStateText = "Failed to connect"
        
        if let error = error {
            print("Failed to connect: \(error.localizedDescription)")
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
            connectedDeviceName = nil
            isConnected = false
            bluetoothStateText = "Disconnected"
            currentPressureN = 0
            normalizedPressure = 0
        }
        
        if let error = error {
            print("Disconnected with error: \(error.localizedDescription)")
        }
    }
}

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Discover services error: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services where service.uuid == serviceUUID {
            print("Target service found: \(service.uuid)")
            peripheral.discoverCharacteristics([notifyCharUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error = error {
            print("Discover characteristics error: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics where characteristic.uuid == notifyCharUUID {
            print("Target notify characteristic found: \(characteristic.uuid)")
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("Notification state update error: \(error.localizedDescription)")
            return
        }
        
        print("Notification enabled for \(characteristic.uuid): \(characteristic.isNotifying)")
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("Update value error: \(error.localizedDescription)")
            return
        }
        
        guard characteristic.uuid == notifyCharUUID,
              let data = characteristic.value else { return }
        
        parseIncomingPressureData(data)
    }
}
