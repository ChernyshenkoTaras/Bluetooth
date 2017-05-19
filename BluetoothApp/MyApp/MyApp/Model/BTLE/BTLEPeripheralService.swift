//
//  BTLEPeripheralService.swift
//  MyApp
//
//  Created by Taras Chernyshenko on 5/9/17.
//  Copyright © 2017 Taras Chernyshenko. All rights reserved.
//

import Foundation
import CoreBluetooth

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

protocol BTLEPeripheralServiceDelegate: class {
    func dataToBroadcastForPeripheralService(_ service: BTLEPeripheralService,
        for peripheralIdentifier: String) -> Data
    func peripheralServiceDidUpdateState(_ service: BTLEPeripheralService)
}

class BTLEPeripheralService: NSObject, CBPeripheralManagerDelegate {
    
    private let NOTIFY_MTU = 20
    
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
        transferCharacteristic = CBMutableCharacteristic(
            type: transferCharacteristicUUID,
            properties: CBCharacteristicProperties.notify,
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
    
    /** Catch when someone subscribes to our characteristic, then start sending them data
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        
        
        // Get the data
        guard self.peripheralManager?.state == .poweredOn else {
            return
        }
        
        print("Central subscribed to characteristic")
        dataToSend = self.delegate?.dataToBroadcastForPeripheralService(self, for: central.identifier.uuidString) ?? Data()
        // Reset the index
        sendDataIndex = 0;
        // Start sending
        sendData()
    }
    
    /** Recognise when the central unsubscribes
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("Central unsubscribed from characteristic")
    }
    
    // First up, check if we're meant to be sending an EOM
    fileprivate var sendingEOM = false;
    
    /** Sends the next amount of data to the connected central
     */
    fileprivate func sendData() {
        if sendingEOM {
            // send it
            let didSend = peripheralManager?.updateValue(
                "EOM".data(using: String.Encoding.utf8)!,
                for: transferCharacteristic!,
                onSubscribedCentrals: nil
            )
            
            // Did it send?
            if (didSend == true) {
                
                // It did, so mark it as sent
                sendingEOM = false
                
                print("Sent: EOM")
            }
            
            // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
            return
        }
        
        // We're not sending an EOM, so we're sending data
        
        // Is there any left to send?
        guard sendDataIndex! < dataToSend!.count else {
            // No data left.  Do nothing
            return
        }
        
        // There's data left, so send until the callback fails, or we're done.
        var didSend = true
        
        while didSend {
            // Make the next chunk
            
            // Work out how big it should be
            var amountToSend = dataToSend!.count - sendDataIndex!;
            
            // Can't be longer than 20 bytes
            if (amountToSend > NOTIFY_MTU) {
                amountToSend = NOTIFY_MTU;
            }
            
            // Copy out the data we want
            let chunk = dataToSend!.withUnsafeBytes{(body: UnsafePointer<UInt8>) in
                return Data(
                    bytes: body + sendDataIndex!,
                    count: amountToSend
                )
            }
            
            // Send it
            didSend = peripheralManager!.updateValue(
                chunk as Data,
                for: transferCharacteristic!,
                onSubscribedCentrals: nil
            )
            
            // If it didn't work, drop out and wait for the callback
            if (!didSend) {
                return
            }
            
            let stringFromData = NSString(
                data: chunk as Data,
                encoding: String.Encoding.utf8.rawValue
            )
            
            print("Sent: \(stringFromData ?? "")")
            
            // It did send, so update our index
            sendDataIndex! += amountToSend;
            
            // Was it the last one?
            if (sendDataIndex! >= dataToSend!.count) {
                
                // It was - send an EOM
                
                // Set this so if the send fails, we'll send it next time
                sendingEOM = true
                
                // Send it
                let eomSent = peripheralManager!.updateValue(
                    "EOM".data(using: String.Encoding.utf8)!,
                    for: transferCharacteristic!,
                    onSubscribedCentrals: nil
                )
                
                if (eomSent) {
                    // It sent, we're all done
                    sendingEOM = false
                    print("Sent: EOM")
                }
                
                return
            }
        }
    }
    
    /** This callback comes in when the PeripheralManager is ready to send the next chunk of data.
     *  This is to ensure that packets will arrive in the order they are sent
     */
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        sendData()
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print(error)
        }
    }
}
