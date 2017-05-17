//
//  PersonBTDiscoveryManager.swift
//

import UIKit

protocol PersonBTDiscoveryManagerDelegate: class {
    func personBTDiscoveryManager(manager: PersonBTDiscoveryManager, didUpdatePersonList persons: [NearbyPerson])
}

class PersonBTDiscoveryManager: BTDiscoveryManager {
    
    class var sharedInstance : PersonBTDiscoveryManager {
        struct Static {
            static let instance = PersonBTDiscoveryManager()
        }
        return Static.instance
    }
    // interval for filtering persons, old persons(with seen date + interval < current date) will be removed after this interval
    private let personInvalidationInterval: TimeInterval = 10
    private var personInvalidationTimer: Timer!
    
    private(set) var nearbyPersons: [NearbyPerson] = []
    
    var showNotifications: Bool = true
    
    weak var personDelegate: PersonBTDiscoveryManagerDelegate?
    
    override init() {
        super.init()
//        self.personInvalidationTimer = Timer.scheduledTimer(timeInterval: self.personInvalidationInterval, target: self, selector: #selector(PersonBTDiscoveryManager.filterNearbyPersons), userInfo: nil, repeats: true)
    }
    
    override func stopMode(mode: Mode) {
        super.stopMode(mode: mode)
        self.nearbyPersons.removeAll(keepingCapacity: false)
        self.personDelegate?.personBTDiscoveryManager(manager: self, didUpdatePersonList: self.nearbyPersons)
    }
    
    override func centralService(_ srvice: BTLECentralService, didReceive data: Data, from PeripheralIdentifier: String) {
        var deserializedResponse = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
        deserializedResponse!["rssi"] = srvice.rssis[PeripheralIdentifier] as AnyObject!
        if let data = deserializedResponse {
            let person = NearbyPerson(dictionary: data)
            self.addNearbyPerson(newPerson: person)
        }
    }
    
    override func dataToBroadcastForPeripheralService(_ service: BTLEPeripheralService, for peripheralIdentifier: String) -> Data {
        let person = NearbyPerson.current
        var dictionary = person.dictionaryValue()
        dictionary["identifier"] = peripheralIdentifier as AnyObject?
        dictionary["username"] = Settings.current.username as AnyObject?
        let imageData =  UIImageJPEGRepresentation(Settings.current.image, 0)!
        dictionary["image"] = imageData.base64EncodedString() as AnyObject?
        dictionary["rssi"] = "" as AnyObject?
        
        let data = try? JSONSerialization.data(withJSONObject: dictionary, options: JSONSerialization.WritingOptions())
        return data!
    }
    
    func filterNearbyPersons() {
        if (self.nearbyPersons.count == 0) {
            return
        }
        
        let filteredNearbyPersons = self.nearbyPersons.filter { person in
            let lastSeenTimeInterval = person.lastSeenDate?.timeIntervalSinceReferenceDate ?? 0
            return NSDate().timeIntervalSinceReferenceDate - lastSeenTimeInterval < self.personInvalidationInterval
        }
        
        let oldNearbyPersonsCount = self.nearbyPersons.count
        self.nearbyPersons = filteredNearbyPersons
        if (filteredNearbyPersons.count != oldNearbyPersonsCount) {
            self.personDelegate?.personBTDiscoveryManager(manager: self, didUpdatePersonList: self.nearbyPersons)
        }
    }
    
    private func addNearbyPerson(newPerson: NearbyPerson) {
        let existingPerson = self.nearbyPersons.filter {
            $0.identifier == newPerson.identifier }.first
        if existingPerson != nil {
            existingPerson!.lastSeenDate = NSDate()
            if (newPerson.identifier != existingPerson!.identifier) {
                existingPerson!.updateWithPerson(person: newPerson)
                self.personDelegate?.personBTDiscoveryManager(manager: self, didUpdatePersonList: self.nearbyPersons)
            }
        }
        else {
            newPerson.lastSeenDate = NSDate()
            self.nearbyPersons.append(newPerson)
            self.personDelegate?.personBTDiscoveryManager(manager: self, didUpdatePersonList: self.nearbyPersons)
        }
    }
}
