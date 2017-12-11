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
    
    enum RequirementBrowserTableSection: String {
        case user = "My Courses"
        case majors = "Majors"
        case minors = "Minors"
        case other = "Other"
        
        static let ordering: [RequirementBrowserTableSection] = [.user, .majors, .minors, .other]
    }
    
    var organizedRequirementLists: [(RequirementBrowserTableSection, [RequirementsList])] = []
    
    let listCellIdentifier = "RequirementsListCell"
    let listVCIdentifier = "RequirementsListVC"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        splitViewController?.preferredDisplayMode = .allVisible
        splitViewController?.delegate = self
        
        RequirementsListManager.shared.loadRequirementsLists()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    func updateRequirementsStatus() {
        if let tabVC = rootParent as? RootTabViewController,
            let currentUser = tabVC.currentUser {
            let courses = currentUser.allCourses
            var organizedCategories: [RequirementBrowserTableSection: [RequirementsList]] = [:]
            for reqList in RequirementsListManager.shared.requirementsLists {
                reqList.computeRequirementStatus(with: courses)
                var category: RequirementBrowserTableSection = .other
                if currentUser.coursesOfStudy.contains(reqList.listID) {
                    category = .user
                } else if reqList.listID.range(of: "major", options: .caseInsensitive) != nil {
                    category = .majors
                } else if reqList.listID.range(of: "minor", options: .caseInsensitive) != nil {
                    category = .minors
                }
                if organizedCategories[category] == nil {
                    organizedCategories[category] = [reqList]
                } else {
                    organizedCategories[category]?.append(reqList)
                }
            }
            organizedRequirementLists = []
            
            for key in RequirementBrowserTableSection.ordering {
                guard let lists = organizedCategories[key], lists.count > 0 else {
                    continue
                }
                organizedRequirementLists.append((key, lists.sorted(by: { $0.percentageFulfilled > $1.percentageFulfilled })))
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
        updateRequirementsStatus()
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
        return organizedRequirementLists.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return organizedRequirementLists[section].1.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return organizedRequirementLists[section].0.rawValue
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: listCellIdentifier, for: indexPath)
        let textLabel = cell.viewWithTag(12) as? UILabel
        let detailTextLabel = cell.viewWithTag(34) as? UILabel
        let list = organizedRequirementLists[indexPath.section].1[indexPath.row]
        textLabel?.text = list.mediumTitle ?? "No title"
        if CourseManager.shared.isLoaded {
            let progress = list.percentageFulfilled
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
        let reqList = organizedRequirementLists[indexPath.section].1[indexPath.row]
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
