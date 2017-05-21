//
//  BTLEPeripheralService.swift
//  MyApp
//
//  Created by Taras Chernyshenko on 5/9/17.
//  Copyright © 2017 Taras Chernyshenko. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol BTLEPeripheralServiceDelegate: class {
    func dataToBroadcastForPeripheralService(_ service: BTLEPeripheralService) -> Data
    func peripheralServiceDidUpdateState(_ service: BTLEPeripheralService)
}

class BTLEPeripheralService: NSObject, CBPeripheralManagerDelegate {
    
    private let NOTIFY_MTU = 100
    
    private var peripheralManager: CBPeripheralManager?
    private var transferCharacteristic: CBMutableCharacteristic?
    
    fileprivate var dataToSend: Data?
    private var sendDataIndex: Int?
    
    weak var delegate: BTLEPeripheralServiceDelegate?
    var state: CBPeripheralManagerState?
    var timer: Timer?
    
    init(delegate: BTLEPeripheralServiceDelegate) {
        super.init()
        self.delegate = delegate
    }
    
    func start() {
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func stop() {
        self.peripheralManager?.stopAdvertising()
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // Opt out from any other state
        self.delegate?.peripheralServiceDidUpdateState(self)
        guard peripheral.state == .poweredOn else { return }
        
        self.peripheralManager!.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey : [transferServiceUUID]
            ])
        print("self.peripheralManager powered on.")
        
        guard let data =  self.delegate?.dataToBroadcastForPeripheralService(self) else {
            return
        }

        transferCharacteristic = CBMutableCharacteristic(
            type: transferCharacteristicUUID,
            properties: CBCharacteristicProperties.read,
            value: nil,
            permissions: CBAttributePermissions.readable
        )
        
        let transferService = CBMutableService(
            type: transferServiceUUID,
            primary: true
        )
        
        transferService.characteristics = [transferCharacteristic!]
        
        peripheralManager!.add(transferService)
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print(error)
        }
    }
    
    var index = 0
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard let data =  self.delegate?.dataToBroadcastForPeripheralService(self) else {
            return
        }

        if (index >= data.count) {
            request.value = Data()
            peripheral.respond(to: request, withResult: .success)
            index = 0
            return
        }
        
        // Work out how big it should be
        var amountToSend = data.count - index;
        
        // Can't be longer than 20 bytes
        if (amountToSend > NOTIFY_MTU) {
            amountToSend = NOTIFY_MTU;
        }
        
        // Copy out the data we want
        let chunk = data.withUnsafeBytes{(body: UnsafePointer<UInt8>) in
            return Data(
                bytes: body + index,
                count: amountToSend
            )
        }
        
        let stringFromData = NSString(
            data: chunk as Data,
            encoding: String.Encoding.utf8.rawValue
        )
        
        print("Sent: \(stringFromData ?? "")")
        // It did send, so update our index
        index += amountToSend
        
        // Was it the last one?
            request.value = chunk
            peripheral.respond(to: request, withResult: .success)
    }
}
