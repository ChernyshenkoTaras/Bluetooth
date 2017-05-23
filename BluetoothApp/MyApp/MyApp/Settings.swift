//
//  Settings.swift
//  MyApp
//
//  Created by Taras Chernyshenko on 5/13/17.
//  Copyright © 2017 Taras Chernyshenko. All rights reserved.
//

import UIKit

class Settings {
    
    private let UsernameIdentifier = "UsernameIdentifier"
    private let ImageIdentifier = "ImageIdentifier"
    
    static let current = Settings(userDefaults: UserDefaults.standard)
    
    private init(userDefaults: UserDefaults? = nil) {
        self.userDefaults = userDefaults
    }
    
    private let userDefaults: UserDefaults?
    
    var username: String? {
        get {
            return self.userDefaults?.object(forKey: UsernameIdentifier) as? String
        }
        set {
            self.userDefaults?.set(newValue, forKey: UsernameIdentifier)
        }
    }
    
    var image: UIImage {
        get {
            if let data = self.userDefaults?.object(forKey: ImageIdentifier) as? Data {
                return UIImage(data: data)!
            } else {
                return UIImage(named: "user_image")!
            }
        }
        set {
            if let image = newValue.resized(withPercentage: 0.005) {
                let data = UIImageJPEGRepresentation(image, 0)
                self.userDefaults?.set(data, forKey: ImageIdentifier)
            }
        }
    }
}
