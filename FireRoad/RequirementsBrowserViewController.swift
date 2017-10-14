//
//  RequirementsBrowserViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 10/1/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class RequirementsBrowserViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISplitViewControllerDelegate, RequirementsListViewControllerDelegate {

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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateRequirementsStatus()
    }
    
    func updateRequirementsStatus() {
        if let tabVC = rootParent as? RootTabViewController,
            let currentUser = tabVC.currentUser {
            let courses = currentUser.allCourses
            for reqList in requirementsLists {
                reqList.computeRequirementStatus(with: courses)
            }
            tableView.reloadData()
        }
    }
    
    var courseLoadingHUD: MBProgressHUD?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let ip = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: ip, animated: true)
        }
        
        if !CourseManager.shared.isLoaded {
            guard courseLoadingHUD == nil else {
                return
            }
            let hud = MBProgressHUD.showAdded(to: self.splitViewController?.view ?? self.view, animated: true)
            hud.mode = .determinateHorizontalBar
            hud.label.text = "Loading courses…"
            courseLoadingHUD = hud
            DispatchQueue.global(qos: .background).async {
                let initialProgress = CourseManager.shared.loadingProgress
                while !CourseManager.shared.isLoaded {
                    DispatchQueue.main.async {
                        hud.progress = (CourseManager.shared.loadingProgress - initialProgress) / (1.0 - initialProgress)
                    }
                    usleep(100)
                }
                DispatchQueue.main.async {
                    self.updateRequirementsStatus()
                    hud.hide(animated: true)
                }
            }
            return
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
        let textLabel = cell.viewWithTag(12) as? UILabel
        let detailTextLabel = cell.viewWithTag(34) as? UILabel
        textLabel?.text = requirementsLists[indexPath.row].mediumTitle ?? "No title"
        if CourseManager.shared.isLoaded {
            let progress = requirementsLists[indexPath.row].percentageFulfilled
            let fulfillmentIndicator = cell.viewWithTag(56)
            if progress > 0.0 {
                detailTextLabel?.text = "\(Int(round(progress)))%"
                detailTextLabel?.textColor = UIColor.white
                fulfillmentIndicator?.backgroundColor = UIColor(hue: 0.005 * CGFloat(progress), saturation: 0.9, brightness: 0.7, alpha: 1.0)
                fulfillmentIndicator?.layer.cornerRadius = RequirementsListViewController.fulfillmentIndicatorCornerRadius
                fulfillmentIndicator?.layer.masksToBounds = true
            } else {
                detailTextLabel?.text = ""
                fulfillmentIndicator?.backgroundColor = UIColor.clear
            }
        } else {
            detailTextLabel?.text = ""
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let reqList = requirementsLists[indexPath.row]
        guard let nav = storyboard?.instantiateViewController(withIdentifier: listVCIdentifier) as? UINavigationController,
            let listVC = nav.topViewController as? RequirementsListViewController else {
            return
        }
        
        listVC.delegate = self
        listVC.requirementsList = reqList
        splitViewController?.showDetailViewController(nav, sender: self)
       // tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func requirementsListViewControllerUpdatedFulfillmentStatus(_ vc: RequirementsListViewController) {
        let row = tableView.indexPathForSelectedRow
        tableView.reloadData()
        tableView.selectRow(at: row, animated: false, scrollPosition: .none)
    }
}
