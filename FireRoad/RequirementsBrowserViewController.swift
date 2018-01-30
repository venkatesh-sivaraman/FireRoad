//
//  RequirementsBrowserViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 10/1/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class RequirementsBrowserViewController: UITableViewController, UISplitViewControllerDelegate, RequirementsListViewControllerDelegate, UISearchResultsUpdating, UISearchControllerDelegate {
    
    enum RequirementBrowserTableSection: String {
        case user = "My Courses"
        case majors = "Majors"
        case minors = "Minors"
        case masters = "Masters"
        case other = "Other"
        
        static let ordering: [RequirementBrowserTableSection] = [.user, .majors, .minors, .masters, .other]
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
    
    var showAllElements: [RequirementBrowserTableSection: Bool] = [:]
    
    func elementDisplayCutoff(for section: RequirementBrowserTableSection) -> Int {
        if searchController?.isActive == true,
            let text = searchController?.searchBar.text,
            text.count > 0, let results = searchResults {
            return results.first(where: { $0.0 == section })?.1.count ?? 0
        }
        let rawCount = organizedRequirementLists.first(where: { $0.0 == section })?.1.count ?? 0
        return (showAllElements[section] ?? (section == .user)) ? rawCount : min(rawCount, 5)
    }
    
    var searchController: UISearchController?
    
    var organizedRequirementLists: [(RequirementBrowserTableSection, [RequirementsList])] = []
    var searchResults: [(RequirementBrowserTableSection, [RequirementsList])]?
    
    var displayedRequirementLists: [(RequirementBrowserTableSection, [RequirementsList])] {
        if searchController?.isActive == true,
            let text = searchController?.searchBar.text,
            text.count > 0, let results = searchResults {
            return results
        }
        return organizedRequirementLists
    }
    
    let listCellIdentifier = "RequirementsListCell"
    let noCoursesCellIdentifier = "NoCoursesCell"
    let showAllCellIdentifier = "ShowAllCell"
    let listVCIdentifier = "RequirementsListVC"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        splitViewController?.preferredDisplayMode = .allVisible
        splitViewController?.delegate = self
        
        RequirementsListManager.shared.loadRequirementsLists()
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = traitCollection.userInterfaceIdiom == .pad ? .never : .always
        } else {
            // Fallback on earlier versions
        }
        
        sortMode = .alphabetical

        NotificationCenter.default.addObserver(self, selector: #selector(RequirementsBrowserViewController.courseManagerFinishedLoading(_:)), name: .CourseManagerFinishedLoading, object: nil)
        
        searchController = UISearchController(searchResultsController: nil)
        searchController?.searchResultsUpdater = self
        searchController?.delegate = self
        searchController?.dimsBackgroundDuringPresentation = false
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
        }
        searchController?.searchBar.placeholder = "Filter requirements lists…"
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
        self.computedLists.removeAll()
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
            selectedList = row != nil ? displayedRequirementLists[row!.section].1[row!.row] : nil
        }
        
        var organizedCategories: [RequirementBrowserTableSection: [RequirementsList]] = [:]
        for reqList in RequirementsListManager.shared.requirementsLists {
            //reqList.computeRequirementStatus(with: courses)
            var category: RequirementBrowserTableSection = .other
            if currentUser.coursesOfStudy.contains(reqList.listID) {
                category = .user
            } else if reqList.listID.range(of: "major", options: .caseInsensitive) != nil {
                category = .majors
            } else if reqList.listID.range(of: "minor", options: .caseInsensitive) != nil {
                category = .minors
            } else if reqList.listID.range(of: "master", options: .caseInsensitive) != nil {
                category = .masters
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
        
        if searchResults != nil {
            updateSearchResults()
        }
        
        if keepingSelectedRow {
            UIView.transition(with: self.tableView, duration: 0.2, options: .transitionCrossDissolve, animations: {
                self.tableView.reloadData()
            }, completion: { completed in
                if completed, let selectedList = selectedList {
                    // Find the list in the new organization
                    guard let section = self.displayedRequirementLists.index(where: { $0.1.contains(selectedList) }),
                        let row = self.displayedRequirementLists[section].1.index(of: selectedList) else {
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
            coder.encode(displayedRequirementLists[ip.section].1[ip.row].listID, forKey: RequirementsBrowserViewController.selectedIDRestorationKey)
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
        return displayedRequirementLists.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0, displayedRequirementLists[section].1.count == 0 {
            return 1
        }
        let cutoff = elementDisplayCutoff(for: displayedRequirementLists[section].0)
        if cutoff != displayedRequirementLists[section].1.count {
            return cutoff + 1
        }
        return cutoff
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return displayedRequirementLists[section].0.rawValue
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if displayedRequirementLists[section].0 == .user {
            return "Add courses of study by finding their requirements below, then toggling the heart icon. The courses you select are saved along with your roads in the My Road tab."
        }
        return nil
    }
    
    lazy var progressComputeQueue = ComputeQueue(label: "RequirementsBrowser.computeProgress")
    var computedLists = Set<String>()
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0, displayedRequirementLists[indexPath.section].1.count == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: noCoursesCellIdentifier, for: indexPath)
            return cell
        }
        let cutoff = elementDisplayCutoff(for: displayedRequirementLists[indexPath.section].0)
        if cutoff != displayedRequirementLists[indexPath.section].1.count, indexPath.row == cutoff {
            let cell = tableView.dequeueReusableCell(withIdentifier: showAllCellIdentifier, for: indexPath)
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: listCellIdentifier, for: indexPath)
        let textLabel = cell.viewWithTag(12) as? UILabel
        let detailTextLabel = cell.viewWithTag(34) as? UILabel
        let descriptionTextLabel = cell.viewWithTag(78) as? UILabel
        let list = displayedRequirementLists[indexPath.section].1[indexPath.row]
        let titleText = list.mediumTitle ?? "No title"
        textLabel?.text = titleText
        if CourseManager.shared.isLoaded, !progressComputeQueue.contains(list.listID) {
            let fulfillmentIndicator = cell.viewWithTag(56)
            progressComputeQueue.async(taskName: list.listID) {
                if !self.computedLists.contains(list.listID),
                    let user = (self.rootParent as? RootTabViewController)?.currentUser {
                    list.computeRequirementStatus(with: user.allCourses)
                    self.computedLists.insert(list.listID)
                }
                let progress = list.percentageFulfilled
                DispatchQueue.main.async {
                    guard textLabel?.text == titleText else {
                        return
                    }
                    if progress > 0.0 {
                        UIView.transition(with: cell, duration: 0.1, options: .transitionCrossDissolve, animations: {
                            detailTextLabel?.text = "\(Int(round(progress)))%"
                            detailTextLabel?.textColor = UIColor.white
                            fulfillmentIndicator?.backgroundColor = UIColor(hue: 0.005 * CGFloat(progress), saturation: 0.9, brightness: 0.7, alpha: 1.0)
                            fulfillmentIndicator?.layer.cornerRadius = RequirementsListViewController.fulfillmentIndicatorCornerRadius
                            fulfillmentIndicator?.layer.masksToBounds = true
                        }, completion: nil)
                    } else {
                        detailTextLabel?.text = ""
                        fulfillmentIndicator?.backgroundColor = UIColor.clear
                    }
                }
            }
            detailTextLabel?.text = ""
            fulfillmentIndicator?.backgroundColor = UIColor.clear
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
        let cutoff = elementDisplayCutoff(for: displayedRequirementLists[indexPath.section].0)
        if cutoff != displayedRequirementLists[indexPath.section].1.count, indexPath.row == cutoff {
            showAllElements[displayedRequirementLists[indexPath.section].0] = true
            tableView.deselectRow(at: indexPath, animated: true)
            tableView.reloadData()
            return
        }

        let reqList = displayedRequirementLists[indexPath.section].1[indexPath.row]
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
        updateRequirementsStatus(keepingSelectedRow: true)
    }
    
    // MARK: - Search
    
    func updateSearchResults(for searchController: UISearchController) {
        updateSearchResults()
        tableView.reloadData()
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
        searchResults = nil
    }
    
    func updateSearchResults(with searchTerm: String? = nil) {
        guard let searchTerm = (searchTerm ?? searchController?.searchBar.text)?.lowercased() else {
            searchResults = nil
            return
        }
        
        searchResults = []
        for (section, lists) in organizedRequirementLists {
            let filteredLists = lists.filter {
                $0.title?.lowercased().contains(searchTerm) == true ||
                $0.mediumTitle?.lowercased().contains(searchTerm) == true
            }
            if filteredLists.count > 0 {
                searchResults?.append((section, filteredLists))
            }
        }
    }
}
