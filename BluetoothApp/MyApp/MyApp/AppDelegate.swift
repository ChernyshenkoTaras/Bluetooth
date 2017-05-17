//
//  AppDelegate.swift
//  MyApp
//
//  Created by Taras Chernyshenko on 5/9/17.
//  Copyright © 2017 Taras Chernyshenko. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        if Settings.current.username == nil {
            self.showSetupController()
        } else {
            self.showMainController()
        }
        
        NotificationCenter.default.addObserver(forName: .setupComplete,
            object: nil, queue: nil) { (notification) in
            self.showMainController()
        }
        
        Fabric.with([Crashlytics.self])

        return true
    }
    
    private func showMainController() {
        let identifier = "MainControllerIdentifier"
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: identifier)
        if self.window == nil {
            self.window = UIWindow(frame: UIScreen.main.bounds)
        }
        self.window?.backgroundColor = UIColor.white
        self.window?.rootViewController = controller
        self.window?.makeKeyAndVisible()
    }
    
    private func showSetupController() {
        let identifier = "SetupViewControllerIdentifier"
        guard let controller = UIStoryboard(name: "Main",
            bundle: nil).instantiateViewController(withIdentifier:
            identifier) as? SetupViewController else { return }
        controller.isFirstSetup = true
        if self.window == nil {
            self.window = UIWindow(frame: UIScreen.main.bounds)
        }
        self.window?.backgroundColor = UIColor.white
        self.window?.rootViewController = controller
        self.window?.makeKeyAndVisible()
    }
}

