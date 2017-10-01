//
//  RequirementsBrowserViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 10/1/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class RequirementsBrowserViewController: UIViewController {

    @IBOutlet var tableView: UITableView!
    
    /*func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }*/
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let path = Bundle.main.path(forResource: "test_major", ofType: "reql") {
            let reqsList = try? RequirementsList(contentsOf: path)
            print(reqsList)
        }
    }
}
