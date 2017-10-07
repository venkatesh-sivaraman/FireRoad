//
//  RequirementsBrowserViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 10/1/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class RequirementsBrowserViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISplitViewControllerDelegate {

    @IBOutlet var tableView: UITableView!
    
    var requirementsLists: [RequirementsList] = []
    
    let listCellIdentifier = "RequirementsListCell"
    let listVCIdentifier = "RequirementsListVC"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        splitViewController?.preferredDisplayMode = .allVisible
        splitViewController?.delegate = self
        
        if let resourcePath = Bundle.main.resourcePath,
            let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
            for pathName in contents where pathName.contains(".reql") {
                let fullPath = URL(fileURLWithPath: resourcePath).appendingPathComponent(pathName).path
                if let reqList = try? RequirementsList(contentsOf: fullPath) {
                    requirementsLists.append(reqList)
                }
            }
        }
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        guard let secondaryAsNavController = secondaryViewController as? UINavigationController,
            let topAsDetailController = secondaryAsNavController.topViewController as? RequirementsListViewController else {
                return false
        }
        if topAsDetailController.requirementsList == nil {
            // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
            return true
        }
        return false

    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return requirementsLists.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: listCellIdentifier, for: indexPath)
        cell.textLabel?.text = requirementsLists[indexPath.row].mediumTitle ?? "No title"
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let reqList = requirementsLists[indexPath.row]
        guard let nav = storyboard?.instantiateViewController(withIdentifier: listVCIdentifier) as? UINavigationController,
            let listVC = nav.topViewController as? RequirementsListViewController else {
            return
        }
        
        listVC.requirementsList = reqList
        splitViewController?.showDetailViewController(nav, sender: self)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
