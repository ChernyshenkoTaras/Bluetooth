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
let transferServiceUUID = CBUUID(string: transferServiceUUIDString)
let transferCharacteristicUUID = CBUUID(string: transferCharacteristicUUIDString)

protocol BTLECentralServiceDelegate: class {
    func centralService(_ srvice: BTLECentralService, didReceive data: Data,
        from PeripheralIdentifier: String)
    func centralServiceDidUpdateState(_ srvice: BTLECentralService)
}

class BTLECentralService: NSObject, CBCentralManagerDelegate,
    CBPeripheralDelegate {
    
    var centralManager: CBCentralManager?
    var discoveredPeripheral: CBPeripheral?
    fileprivate var data = NSMutableData()
    
    weak var delegate: BTLECentralServiceDelegate?
    var state: CBCentralManagerState?
    var rssis: [String : String] = [:]
    
    init(delegate: BTLECentralServiceDelegate){
        super.init()
        self.delegate = delegate
    }
    
    func start() {
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func stop() {
        self.centralManager?.stopScan()
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
    
    /** Scan for peripherals - specifically for our service's 128bit CBUUID
     */
    func scan() {
        
        centralManager?.scanForPeripherals(
            withServices: [transferServiceUUID], options: [
                CBCentralManagerScanOptionAllowDuplicatesKey : NSNumber(value: true as Bool)
            ]
        )
        print("Scanning started")
    }
    
    /** This callback comes whenever a peripheral that is advertising the TRANSFER_SERVICE_UUID is discovered.
     *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
     *  we start the connection process
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        
        if self.discoveredPeripheral != peripheral {
            // And connect
            self.cancelPeripheralConnection()
            self.discoveredPeripheral = peripheral
            self.rssis[peripheral.identifier.uuidString] = "\(RSSI)"
            
            print("Connecting to peripheral \(peripheral)")
            centralManager?.connect(peripheral, options: nil)
        }
    }
    
    /** If the connection fails for whatever reason, we need to deal with it.
     */
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral). (\(error!.localizedDescription))")
        self.cleanup()
    }
    
    /** We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Peripheral Connected")

        // Clear the data that we may already have
        data.length = 0
        peripheral.delegate = self
        peripheral.discoverServices([transferServiceUUID])
    }
    
    /** The Transfer Service was discovered
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            self.cleanup()
            return
        }
        
        guard let services = peripheral.services else {
            return
        }
        
        // Discover the characteristic we want...
        
        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        for service in services {
            peripheral.discoverCharacteristics([transferCharacteristicUUID], for: service)
        }
    }
    
    /** The Transfer characteristic was discovered.
     *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Deal with errors (if any)
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            self.cleanup()
            self.discoveredPeripheral = nil
            return
        }
        
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        // Again, we loop through the array, just in case.
        for characteristic in characteristics {
            // And check if it's the right one
            if characteristic.uuid.isEqual(transferCharacteristicUUID) {
                // If it is, subscribe to it
                peripheral.setNotifyValue(true, for: characteristic)
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
        
        guard let stringFromData = String(data: characteristic.value!, encoding: .utf8) else {
            print("Invalid data")
            return
        }
        
        // Have we got everything we need?
        if stringFromData == "EOM" {
            // We have, so show the data,
            self.delegate?.centralService(self, didReceive: self.data as Data, from: peripheral.identifier.uuidString)
            
            // Cancel our subscription to the characteristic
            peripheral.setNotifyValue(false, for: characteristic)
            
            // and disconnect from the peripehral
            centralManager?.cancelPeripheralConnection(peripheral)
        } else {
            peripheral.setNotifyValue(true, for: characteristic)
            data.append(characteristic.value!)
            print("Received: \(stringFromData)")
        }
    }
    
    /** The peripheral letting us know whether our subscribe/unsubscribe happened or not
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error changing notification state: \(error.localizedDescription)")
        }
        
        // Exit if it's not the transfer characteristic
        guard characteristic.uuid.isEqual(transferCharacteristicUUID) else {
            return
        }
        
        // Notification has started
        if characteristic.isNotifying && characteristic.value != nil {
            print("Notification began on \(characteristic)")
        } else { // Notification has stopped
            print("Notification stopped on (\(characteristic))  Disconnecting")
            self.centralManager?.cancelPeripheralConnection(peripheral)
        }
    }
    
    /** Once the disconnection happens, we need to clean up our local copy of the peripheral
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Peripheral Disconnected")
        self.cleanup()
        if let error = error {
            print(error.localizedDescription)
        }
    }
    
    fileprivate func cleanup() {
        // See if we are subscribed to a characteristic on the peripheral
        
        guard self.discoveredPeripheral?.state != .connected else { return }
        
        guard let services = discoveredPeripheral?.services else {
            self.cancelPeripheralConnection()
            return
        }
        
        for service in services {
            for characteristic in service.characteristics ?? [] {
                if characteristic.uuid.isEqual(transferCharacteristicUUID) &&
                    characteristic.isNotifying {
                    discoveredPeripheral?.setNotifyValue(false, for: characteristic)
                    return
                }
            }
        }
    }
    
    fileprivate func cancelPeripheralConnection() {
        // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
        if let peripheral = self.discoveredPeripheral {
            self.centralManager?.cancelPeripheralConnection(peripheral)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
        didModifyServices invalidatedServices: [CBService]) {
        print("Modified")
    }
}
