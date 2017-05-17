//
//  BluetoothLEDiscoveryManager.swift
//

import Foundation
import CoreBluetooth

protocol BTDiscoveryManagerDelegate: class {
    func btDiscoveryManager(manager: BTDiscoveryManager, didReceiveData data: NSData!)
}

protocol BTDiscoveryManagerDataSource: class {
    func dataToBroadcastForBTDiscoveryManager(manager: BTDiscoveryManager, peripheralIdentifier: String) -> NSData!
}

func |(a: BTDiscoveryManager.Mode, b: BTDiscoveryManager.Mode) -> BTDiscoveryManager.Mode {
    return BTDiscoveryManager.Mode(rawValue: a.rawValue | b.rawValue)!
}

func &(a: BTDiscoveryManager.Mode, b: BTDiscoveryManager.Mode) -> BTDiscoveryManager.Mode {
    return BTDiscoveryManager.Mode(rawValue: a.rawValue & b.rawValue)!
}

func ^(a: BTDiscoveryManager.Mode, b: BTDiscoveryManager.Mode) -> BTDiscoveryManager.Mode {
    return BTDiscoveryManager.Mode(rawValue: a.rawValue ^ b.rawValue)!
}

class BTDiscoveryManager: NSObject, BTLECentralServiceDelegate, BTLEPeripheralServiceDelegate {
    
    enum Mode: UInt {
        case Broadcasting = 0b001
        case Receiving = 0b010
        case Duplex = 0b011
        case None = 0b000
    }
    
    weak var delegate: BTDiscoveryManagerDelegate?
    weak var dataSource: BTDiscoveryManagerDataSource?
    
    private(set) var mode: Mode = .None
    
    var isBluetoothOn: Bool {
        get {
            return self.centralService?.state == CBCentralManagerState.poweredOn || self.peripheralService?.state == CBPeripheralManagerState.poweredOn
        }
    }
    
    var isBluetoothOff: Bool {
        get {
            return self.centralService?.state == CBCentralManagerState.poweredOff || self.peripheralService?.state == CBPeripheralManagerState.poweredOff
        }
    }
    
    private var centralService: BTLECentralService?
    private var peripheralService: BTLEPeripheralService?
    
    override init() {
        super.init()
        self.centralService = BTLECentralService(delegate: self)
        self.peripheralService = BTLEPeripheralService(delegate: self)
    }
    
    private func startCentralService() {
        if (self.centralService == nil) {
            self.centralService = BTLECentralService(delegate: self)
        }
        self.centralService?.start()
    }
    
    private func stopCentralService() {
        self.centralService?.stop()
        self.centralService = nil
    }
    
    func startMode(mode: Mode) {
        self.mode = self.mode | mode
        switch mode {
        case .Broadcasting:
            self.peripheralService?.start()
        case .Receiving:
            self.startCentralService()
        case .Duplex:
            self.startCentralService()
            self.peripheralService?.start()

        default:
            return
        }
    }
    
    func stopMode(mode: Mode) {
        self.mode = self.mode ^ mode
        switch mode {
        case .Broadcasting:
            self.peripheralService?.stop()
        case .Receiving:
            self.stopCentralService()
        case .Duplex:
            self.stopCentralService()
            self.peripheralService?.stop()
        default:
            return
        }
    }
    
    // MARK: BTCentralService delegate
    
    func centralService(_ srvice: BTLECentralService, didReceive data: Data, from PeripheralIdentifier: String) {
        self.delegate?.btDiscoveryManager(manager: self, didReceiveData: data as NSData!)
    }
    
    func centralServiceDidUpdateState(_ srvice: BTLECentralService) {
        // cold start require powered on state
        if (srvice.state == .poweredOn &&
            (self.mode & Mode.Receiving) != .None) {
            self.startMode(mode: .Receiving)
        }
    }
    
    // MARK: BTPeripheralService delegate
    
    func dataToBroadcastForPeripheralService(_ service: BTLEPeripheralService, for peripheralIdentifier: String) -> Data {
        return self.dataSource?.dataToBroadcastForBTDiscoveryManager(manager: self, peripheralIdentifier: peripheralIdentifier) as! Data
    }
    
    func peripheralServiceDidUpdateState(_ service: BTLEPeripheralService) {
        if (peripheralService?.state == .poweredOff) {
            print("error")
        }
        // cold start require powered on state
        if (peripheralService?.state == .poweredOn &&
            (self.mode & Mode.Broadcasting) != .None) {
            self.startMode(mode: .Broadcasting)
        }
    }
}
