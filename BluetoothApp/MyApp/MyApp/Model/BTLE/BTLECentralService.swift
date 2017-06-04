//
//  BTLECentralService.swift
//  MyApp
//
//  Created by Taras Chernyshenko on 5/9/17.
//  Copyright © 2017 Taras Chernyshenko. All rights reserved.
//

import Foundation
import CoreBluetooth

let transferServiceUUIDString = "ca9a9753-7c75-4591-9038-26c163098aca"
let transferCharacteristicUUIDString = "655d83c1-f49b-45a9-b321-047814bc6729"
let transferServiceUUID: CBUUID = CBUUID(string: transferServiceUUIDString)
let transferCharacteristicUUID: CBUUID = CBUUID(string: transferCharacteristicUUIDString)

protocol BTLECentralServiceDelegate: class {
    func centralService(_ srvice: BTLECentralService, didReceive data: Data,
        from PeripheralIdentifier: String)
    func centralService(_ service: BTLECentralService,
        discover PeripheralIdentifier: String)
    func centralServiceDidUpdateState(_ srvice: BTLECentralService)
}

class BTLECentralService: NSObject, CBCentralManagerDelegate,
    CBPeripheralDelegate {
    
    var centralManager: CBCentralManager?
    fileprivate var data: [String : NSMutableData] = [:]
    
    weak var delegate: BTLECentralServiceDelegate?
    private var peripherals: [CBPeripheral] = []
    private var discoveredPeripherals: [CBPeripheral] = []
    
    var state: CBCentralManagerState?
    var rssis: [String : String] = [:]
    var timer: Timer?
    
    init(delegate: BTLECentralServiceDelegate){
        super.init()
        self.delegate = delegate
    }
    
    func restart() {
        self.stop()
        self.start()
    }
    
    func start() {
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func stop() {
        self.discoveredPeripherals = []
        self.centralManager?.stopScan()
//        for peripheral in self.peripherals {
//            self.centralManager?.cancelPeripheralConnection(peripheral)
//        }
//        self.peripherals = []
    }
    
    //MARK: CBCentralManagerDelegate methods
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.delegate?.centralServiceDidUpdateState(self)
        guard let centralManager = self.centralManager else { return }
        
        switch centralManager.state {
            case .poweredOn: self.scan()
            case .poweredOff: print("poweredOff")
            case .resetting: print("resetting")
            case .unauthorized: print("unauthorized")
            case .unknown: print("unknown")
            case .unsupported: print("unsupported")
        }
    }
    
    func scan() {
        self.centralManager?.scanForPeripherals(withServices: [transferServiceUUID], options: nil)
        print("Scanning started")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if self.discoveredPeripherals.contains(peripheral) { return }
        
        self.delegate?.centralService(self, discover: peripheral.identifier.uuidString)
        
        self.rssis[peripheral.identifier.uuidString] = "\(RSSI)"
        
        if !self.peripherals.contains(peripheral) {
            self.peripherals.append(peripheral)
            peripheral.delegate = self
            self.centralManager?.connect(peripheral, options: nil)
            print("Connecting to peripheral \(peripheral)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral). (\(error!.localizedDescription))")
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Peripheral Connected with identifier: \(peripheral.identifier.uuidString)")
        peripheral.discoverServices([transferServiceUUID])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("Discover services for peripheralIdentifier: \(peripheral.identifier.uuidString)")

        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics([transferCharacteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("Discover characteristics for periphrralIdentifier: \(peripheral.identifier.uuidString)")

        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        // Again, we loop through the array, just in case.
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid.isEqual(transferCharacteristicUUID) {
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    /** This callback lets us know more data has arrived via notification on the characteristic
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else {
            print("Invalid data")
            return
        }

        if data.count == 0 {
            self.delegate?.centralService(self, didReceive: self.data[peripheral.identifier.uuidString]! as Data,
                from: peripheral.identifier.uuidString)
            self.data[peripheral.identifier.uuidString] = nil
            self.discoveredPeripherals.append(peripheral)
            self.centralManager?.cancelPeripheralConnection(peripheral)
        } else {
            if self.data[peripheral.identifier.uuidString] == nil {
                self.data[peripheral.identifier.uuidString] = NSMutableData()
            }
            self.data[peripheral.identifier.uuidString]?.append(data)
            peripheral.readValue(for: characteristic)
        }
    }

    /** Once the disconnection happens, we need to clean up our local copy of the peripheral
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Peripheral Disconnected")
        for peripheral in self.peripherals {
                peripheral.delegate = self
                self.centralManager?.cancelPeripheralConnection(peripheral)
        }
        self.peripherals = []
        self.scan()
        
        if let error = error {
            print(error.localizedDescription)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
        didModifyServices invalidatedServices: [CBService]) {
        print("Modified peripheral with identifier: \(peripheral.identifier.uuidString)")
        for service in invalidatedServices {
            peripheral.discoverCharacteristics([transferCharacteristicUUID], for: service)
        }
    }
}
