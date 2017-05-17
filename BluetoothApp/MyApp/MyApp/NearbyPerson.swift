//
//  NearbyPerson.swift
//

import UIKit

class NearbyPerson: NSObject {
    
    var identifier: String!
    var username: String!
    var image: UIImage!
    var rssi: String!
    var lastSeenDate: NSDate?
    
    init(dictionary: [String: AnyObject]) {
        super.init()
        self.identifier = dictionary["identifier"] as? String ?? ""
        self.username = dictionary["username"] as? String ?? ""
        if let data = dictionary["image"] as? String {
            self.image = UIImage(data: Data(base64Encoded: data)!)!
        } else {
            self.image = UIImage(named: "user_image")!
        }
        self.rssi = dictionary["rssi"] as! String
        
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateWithPerson(person: NearbyPerson) {
        self.identifier = person.identifier
    }
    
    func dictionaryValue() -> [String: AnyObject] {
        let dictionary = [String: AnyObject]()
        return dictionary
    }
    
    class var current: NearbyPerson {
        get {
            let person = NearbyPerson(dictionary: [
                "identifier" : "test" as AnyObject,
                "username" : Settings.current.username as AnyObject,
                "image" : Settings.current.image,
                "rssi" : "" as AnyObject]
            )
            return person
        }
    }
}

