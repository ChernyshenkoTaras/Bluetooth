//
//  ViewController.swift
//  MyApp
//
//  Created by Taras Chernyshenko on 5/9/17.
//  Copyright © 2017 Taras Chernyshenko. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDelegate,
    UITableViewDataSource, PersonBTDiscoveryManagerDelegate {

    @IBOutlet private weak var tableView: UITableView?
    
    private let manager: PersonBTDiscoveryManager = PersonBTDiscoveryManager()
    
    var nearbyPersons: [NearbyPerson] {
        return self.manager.nearbyPersons
    }
    
    @IBAction func refreshNearbyPersonPressed(sender: AnyObject) {
        self.manager.stopMode(mode: .Receiving)
        self.manager.startMode(mode: .Receiving)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView?.delegate = self
        self.tableView?.dataSource = self
//
        self.manager.personDelegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.manager.startMode(mode: .Duplex)
    }
    //MARK: UITableViewDataSource methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.nearbyPersons.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let person = self.nearbyPersons[indexPath.row]
        cell.textLabel?.text = person.username
        cell.imageView?.image = person.image
        cell.isUserInteractionEnabled = false
        cell.detailTextLabel?.text = "RSSI:" + person.rssi!
        return cell
    }
    
    // MARK: BTLEDiscoveryManager delegate
    
    func personBTDiscoveryManager(manager: PersonBTDiscoveryManager,
        didUpdatePersonList persons: [NearbyPerson]) {
        self.tableView?.reloadData()
    }
}

