//
//  RequirementsBrowserViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 10/1/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class RequirementsBrowserViewController: UITableViewController, UISplitViewControllerDelegate, RequirementsListViewControllerDelegate {
    
    enum RequirementBrowserTableSection: String {
        case user = "My Courses"
        case majors = "Majors"
        case minors = "Minors"
        case other = "Other"
        
        static let ordering: [RequirementBrowserTableSection] = [.user, .majors, .minors, .other]
    }
    
    enum SortMode: String {
        case alphabetical = "By Name"
        case byProgress = "By Progress"
    }
    
    private static let sortModeDefaultsKey = "RequirementsBrowser.SortMode"
    
    var sortMode: SortMode = .alphabetical {
        didSet {
            UserDefaults.standard.set(sortMode.rawValue, forKey: RequirementsBrowserViewController.sortModeDefaultsKey)
        }
    }
    
    var organizedRequirementLists: [(RequirementBrowserTableSection, [RequirementsList])] = []
    
    let listCellIdentifier = "RequirementsListCell"
    let noCoursesCellIdentifier = "NoCoursesCell"
    let listVCIdentifier = "RequirementsListVC"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        splitViewController?.preferredDisplayMode = .allVisible
        splitViewController?.delegate = self
        
        RequirementsListManager.shared.loadRequirementsLists()
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .always
        } else {
            // Fallback on earlier versions
        }
        
        sortMode = SortMode(rawValue: UserDefaults.standard.string(forKey: RequirementsBrowserViewController.sortModeDefaultsKey) ?? "") ?? .alphabetical

        NotificationCenter.default.addObserver(self, selector: #selector(RequirementsBrowserViewController.courseManagerFinishedLoading(_:)), name: .CourseManagerFinishedLoading, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let ip = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: ip, animated: true)
        }
        loadRequirementsOrDisplay()
    }
    
    func reloadRequirements() {
        DispatchQueue.global().async {
            RequirementsListManager.shared.reloadRequirementsLists()
            DispatchQueue.main.async {
                self.loadRequirementsOrDisplay()
            }
        }
    }
    
    func updateRequirementsStatus(keepingSelectedRow: Bool = false) {
        guard let tabVC = rootParent as? RootTabViewController,
            let currentUser = tabVC.currentUser else {
                return
        }
        var selectedList: RequirementsList?
        
        if keepingSelectedRow {
            let row = tableView.indexPathForSelectedRow
            selectedList = row != nil ? organizedRequirementLists[row!.section].1[row!.row] : nil
        }
        
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
            let lists = organizedCategories[key] ?? []
            guard lists.count > 0 || key == .user else {
                continue
            }
            organizedRequirementLists.append((key, lists.sorted(by: { sortMode == .alphabetical ? (($0.mediumTitle ?? "").localizedStandardCompare($1.mediumTitle ?? "") == .orderedAscending) : ($0.percentageFulfilled > $1.percentageFulfilled) })))
        }
        
        if keepingSelectedRow {
            UIView.transition(with: self.tableView, duration: 0.2, options: .transitionCrossDissolve, animations: {
                self.tableView.reloadData()
            }, completion: { completed in
                if completed, let selectedList = selectedList {
                    // Find the list in the new organization
                    guard let section = self.organizedRequirementLists.index(where: { $0.1.contains(selectedList) }),
                        let row = self.organizedRequirementLists[section].1.index(of: selectedList) else {
                            return
                    }
                    let ip = IndexPath(row: row, section: section)
                    self.tableView.selectRow(at: ip, animated: true, scrollPosition: .middle)
                }
            })
        } else {
            tableView.reloadData()
        }
    }
    
    var courseLoadingHUD: MBProgressHUD?
    
    func loadRequirementsOrDisplay() {
        if !CourseManager.shared.isLoaded {
            guard courseLoadingHUD == nil else {
                return
            }
            let hud = MBProgressHUD.showAdded(to: self.splitViewController?.view ?? self.view, animated: true)
            hud.mode = .determinateHorizontalBar
            hud.label.text = "Loading requirements…"
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
    
    @objc func courseManagerFinishedLoading(_ note: Notification) {
        loadRequirementsOrDisplay()
    }
    
    // MARK: - Sorting
    
    @IBAction func sortButtonPressed(_ sender: UIBarButtonItem) {
        let action = UIAlertController(title: "Sort requirements…", message: nil, preferredStyle: .actionSheet)
        let handler = { (action: UIAlertAction) in
            self.sortMode = SortMode(rawValue: action.title ?? "") ?? self.sortMode
            self.updateRequirementsStatus(keepingSelectedRow: true)
        }
        action.addAction(UIAlertAction(title: SortMode.alphabetical.rawValue, style: .default, handler: handler))
        action.addAction(UIAlertAction(title: SortMode.byProgress.rawValue, style: .default, handler: handler))
        
        if traitCollection.userInterfaceIdiom == .pad {
            action.modalPresentationStyle = .popover
            action.popoverPresentationController?.barButtonItem = sender
            present(action, animated: true, completion: nil)
        } else {
            action.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(action, animated: true, completion: nil)
        }
    }
    
    // MARK: - State Preservation
    
    static let selectedIDRestorationKey = "browser.selectedListID"
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        if let ip = tableView.indexPathForSelectedRow {
            coder.encode(organizedRequirementLists[ip.section].1[ip.row].listID, forKey: RequirementsBrowserViewController.selectedIDRestorationKey)
        } else {
            coder.encode(nil, forKey: RequirementsBrowserViewController.selectedIDRestorationKey)
        }
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        let selectedID = coder.decodeObject(forKey: RequirementsBrowserViewController.selectedIDRestorationKey) as? String
        if let splitVC = self.splitViewController {
            var setList = false
            splitVC.enumerateChildViewControllers { vc in
                guard let listVC = vc as? RequirementsListViewController else {
                    return
                }
                listVC.delegate = self
                if !setList, let id = selectedID {
                    listVC.requirementsList = RequirementsListManager.shared.requirementList(withID: id)
                    setList = true
                }
            }
        }
        super.decodeRestorableState(with: coder)
    }
    
    // MARK: - Table View
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return organizedRequirementLists.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0, organizedRequirementLists[section].1.count == 0 {
            return 1
        }
        return organizedRequirementLists[section].1.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return organizedRequirementLists[section].0.rawValue
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if organizedRequirementLists[section].0 == .user {
            return "Courses of study are saved along with your roads in the My Road tab. Add courses by finding their requirements below, then toggling the heart icon."
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0, organizedRequirementLists[indexPath.section].1.count == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: noCoursesCellIdentifier, for: indexPath)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: listCellIdentifier, for: indexPath)
        let textLabel = cell.viewWithTag(12) as? UILabel
        let detailTextLabel = cell.viewWithTag(34) as? UILabel
        let descriptionTextLabel = cell.viewWithTag(78) as? UILabel
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
        if let colorView = cell.viewWithTag(11) {
            if let department = list.shortTitle?.components(separatedBy: .punctuationCharacters).first(where: { $0.count > 0 }) {
                colorView.backgroundColor = CourseManager.shared.color(forDepartment: department)
                descriptionTextLabel?.text = list.titleNoDegree ?? (list.title ?? "")
            } else {
                colorView.backgroundColor = .lightGray
                descriptionTextLabel?.text = list.title ?? ""
            }
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
    
    func requirementsListViewControllerUpdatedFavorites(_ vc: RequirementsListViewController) {
        let row = tableView.indexPathForSelectedRow
        let list = row != nil ? organizedRequirementLists[row!.section].1[row!.row] : nil
        updateRequirementsStatus()
        UIView.transition(with: self.tableView, duration: 0.2, options: .transitionCrossDissolve, animations: {
            self.tableView.reloadData()
        }, completion: { completed in
            if completed, let selectedList = list {
                // Find the list in the new organization
                guard let section = self.organizedRequirementLists.index(where: { $0.1.contains(selectedList) }),
                    let row = self.organizedRequirementLists[section].1.index(of: selectedList) else {
                        return
                }
                let ip = IndexPath(row: row, section: section)
                self.tableView.selectRow(at: ip, animated: true, scrollPosition: .middle)
            }
        })
        
    }
}
