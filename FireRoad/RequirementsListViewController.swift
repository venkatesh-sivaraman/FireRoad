//
//  RequirementsListViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 10/1/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

enum RequirementsListCellType: String {
    case title = "TitleCell"
    case title1 = "Title1Cell"
    case title2 = "Title2Cell"
    case description = "DescriptionCell"
    case courseList = "CourseListCell"
    case courseListAccessory = "CourseListAccessoryCell"
    case url = "URLCell"
}

protocol RequirementsListViewControllerDelegate: class {
    func requirementsListViewControllerUpdatedFulfillmentStatus(_ vc: RequirementsListViewController)
    func requirementsListViewControllerUpdatedFavorites(_ vc: RequirementsListViewController)
}

class RequirementsListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISplitViewControllerDelegate, RequirementsListDisplay, CourseDetailsDelegate, RequirementsProgressDelegate, UIPopoverPresentationControllerDelegate, PopDownTableMenuDelegate, CourseViewControllerProvider {

    struct PresentationItem {
        var cellType: RequirementsListCellType
        var statement: RequirementsListStatement?
        var text: String?
        var url: String?
        
        init(cellType: RequirementsListCellType, statement: RequirementsListStatement?, text: String?, url: String? = nil) {
            self.cellType = cellType
            self.statement = statement
            self.text = text
            self.url = url
        }
    }
    
    @IBOutlet var tableView: UITableView!
    var requirementsList: RequirementsListStatement? {
        didSet {
            if isViewLoaded, requirementsList != oldValue {
                if let reqsList = requirementsList {
                    presentationItems = buildPresentationItems(from: reqsList)
                } else {
                    presentationItems = []
                }
            }
        }
    }
    var presentationItems: [(title: String, statement: RequirementsListStatement, items: [PresentationItem])] = []
    
    var showsManualProgressControls: Bool = true
    var allowsProgressAssertions: Bool { return true }
    
    static let fulfillmentIndicatorCornerRadius = CGFloat(6.0)
    
    weak var delegate: RequirementsListViewControllerDelegate?

    func recursivelyExtractCourses(from statement: RequirementsListStatement) -> [Course] {
        if let req = statement.requirement,
            let course = CourseManager.shared.getCourse(withID: req) {
            return [course]
        } else if let reqs = statement.requirements {
            return reqs.reduce([], { $0 + recursivelyExtractCourses(from: $1) })
        }
        return []
    }
    
    func presentationItems(for requirement: RequirementsListStatement, at level: Int = 0, alwaysShowTitle: Bool = false) -> [PresentationItem] {
        var items: [PresentationItem] = []
        if let title = requirement.title {
            let cellType: RequirementsListCellType = level <= 2 ? .title1 : .title2
            var titleText = title
            if requirement.thresholdDescription.count > 0, requirement.connectionType != .all, !requirement.isPlainString {
                titleText += " (\(requirement.thresholdDescription))"
            }
            items.append(PresentationItem(cellType: cellType, statement: requirement, text: titleText))
        } else if requirement.thresholdDescription.count > 0, (requirement.connectionType != .all || alwaysShowTitle), !requirement.isPlainString {
            items.append(PresentationItem(cellType: .title2, statement: requirement, text: requirement.thresholdDescription.capitalizingFirstLetter() + ":"))
        }
        if let description = requirement.contentDescription, description.count > 0 {
            items.append(PresentationItem(cellType: .description, statement: requirement, text: description))
        }
        
        if level == 0,
            requirement.title == nil, requirement.thresholdDescription.count > 0,
            !(requirement.connectionType != .all || alwaysShowTitle) {
            items.append(PresentationItem(cellType: .title2, statement: nil, text: requirement.thresholdDescription.capitalizingFirstLetter() + ":"))
        }
        if requirement.minimumNestDepth <= 1 ||
            (requirement.requirements != nil &&
            requirement.requirements!.filter({ $0.requirement != nil }).count > 0),
            requirement.requirements?.first(where: { $0.title != nil && $0.title!.count > 0 }) == nil {
            // Show all the child requirements in a single row
            items.append(PresentationItem(cellType: .courseList, statement: requirement, text: nil))
            if requirement.thresholdDescription.count > 0 {
                //items.append(PresentationItem(cellType: .courseListAccessory, statement: nil, text: requirement.thresholdDescription))
                // Indicate this on the cell somehow
            }
        } else if let reqs = requirement.requirements {
            // Show each child requirement as a separate row
            let showTitles = reqs.contains(where: { $0.connectionType == .all && $0.requirements != nil && $0.requirements!.count > 0 }) && reqs.contains(where: { $0.connectionType == .any })
            for req in reqs {
                items += presentationItems(for: req, at: level + 1, alwaysShowTitle: showTitles)
            }
        }
        
        return items
    }
    
    func buildPresentationItems(from list: RequirementsListStatement) -> [(title: String, statement: RequirementsListStatement, items: [PresentationItem])] {
        guard let requirements = list.requirements else {
            return []
        }
        
        var ret: [(title: String, statement: RequirementsListStatement, items: [PresentationItem])] = []
        if list.maximumNestDepth <= 1 {
            ret.append(("", list, presentationItems(for: list)))
        } else {
            if let description = list.contentDescription, description.count > 0 {
                var rows: [PresentationItem] = []
                if let title = list.title, title.count > 0 {
                    rows.append(PresentationItem(cellType: .title, statement: list, text: title))
                }
                rows.append(PresentationItem(cellType: .description, statement: list, text: description))
                ret.append(("", list, rows))
            }
            if let reqList = list as? RequirementsList {
                ret.append(("", list, [PresentationItem(cellType: .url, statement: list, text: "Request a Correction", url: CourseManager.urlBase + "/requirements/edit/" + reqList.listID)]))
            }
            for topLevelRequirement in requirements {
                var rows: [PresentationItem] = presentationItems(for: topLevelRequirement)
                // Remove the title
                rows.removeFirst()
                if topLevelRequirement.connectionType != .all || (topLevelRequirement.threshold != nil && topLevelRequirement.threshold!.cutoff > 1),
                    topLevelRequirement.thresholdDescription.count > 0,
                    !topLevelRequirement.isPlainString {
                    var indexToInsert = 0
                    if rows[indexToInsert].cellType == .description {
                        indexToInsert += 1
                    }
                    rows.insert(PresentationItem(cellType: .title2, statement: nil, text: topLevelRequirement.thresholdDescription.capitalizingFirstLetter() + ":"), at: indexToInsert)
                }
                ret.append((topLevelRequirement.title ?? "", topLevelRequirement, rows))
            }
        }
        if ret.count > 0, let url = (requirementsList as? RequirementsList)?.webURL {
            let last = ret[ret.count - 1]
            ret[ret.count - 1] = (last.title, last.statement, last.items + [PresentationItem(cellType: .url, statement: nil, text: "View Requirements on Catalog Site", url: url.absoluteString)])
        }
        
        return ret
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let reqsList = requirementsList {
            presentationItems = buildPresentationItems(from: reqsList)
        } else {
            presentationItems = []
        }

        NotificationCenter.default.addObserver(self, selector: #selector(RequirementsListViewController.courseManagerFinishedLoading(_:)), name: .CourseManagerFinishedLoading, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(RequirementsListViewController.courseManagerSyncedPreferences(_:)), name: .CourseManagerPreferenceSynced, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadRequirementsOrDisplay()
        selectedIndexPath = nil
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    func updateRequirementsStatus() {
        if let list = requirementsList as? RequirementsList {
            navigationItem.title = list.mediumTitle
        } else {
            navigationItem.title = requirementsList?.shortDescription
        }
        if let tabVC = rootParent as? RootTabViewController,
            let currentUser = tabVC.currentUser {
            requirementsList?.currentUser = currentUser
            requirementsList?.computeRequirementStatus(with: currentUser.creditCourses)
            if presentationItems.count == 0, let reqsList = requirementsList {
                presentationItems = buildPresentationItems(from: reqsList)
            }
            tableView.reloadData()
        }
        delegate?.requirementsListViewControllerUpdatedFulfillmentStatus(self)
        updateFavoritesButton()
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
    
    @objc func courseManagerFinishedLoading(_ note: Notification) {
        loadRequirementsOrDisplay()
    }
    
    @objc func courseManagerSyncedPreferences(_ note: Notification) {
        updateRequirementsStatus()
    }
    
    // MARK: - Appearance
    
    var displayStandardMode = true {
        didSet {
            updateScrollViewForDisplayMode()
        }
    }
    
    func updateScrollViewForDisplayMode() {
        loadViewIfNeeded()
        self.tableView.contentInset = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 8.0, right: 0.0)
        if !displayStandardMode {
            self.view.backgroundColor = UIColor.clear
            self.tableView.backgroundColor = UIColor.clear
            self.tableView.estimatedRowHeight = 60.0
            if #available(iOS 11.0, *) {
                self.tableView.contentInsetAdjustmentBehavior = .automatic
            }
            //self.navigationController?.navigationBar.shadowImage = UIImage()
            self.navigationController?.navigationBar.isTranslucent = true
        } else {
            if #available(iOS 13.0, *) {
                self.view.backgroundColor = UIColor.systemBackground
                self.tableView.backgroundColor = UIColor.systemBackground
            } else {
                self.view.backgroundColor = UIColor.white
                self.tableView.backgroundColor = UIColor.white
            }
            self.tableView.estimatedRowHeight = 60.0
            if #available(iOS 11.0, *) {
                self.tableView.contentInsetAdjustmentBehavior = .automatic
            }
            self.navigationController?.navigationBar.shadowImage = nil
        }
    }
    
    // MARK: - State Preservation
    
    static let selectedIndexPathRestorationKey = "requirementsList.selectedIndexPath"
    var selectedIndexPath: [Int]?
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(selectedIndexPath, forKey: RequirementsListViewController.selectedIndexPathRestorationKey)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        
        if let reqList = requirementsList,
            let nav = navigationController,
            let index = nav.viewControllers.index(of: self),
            index < nav.viewControllers.count - 1 {
            
            if let nextList = nav.viewControllers[index + 1] as? RequirementsListViewController,
                let selectedIP = coder.decodeObject(forKey: RequirementsListViewController.selectedIndexPathRestorationKey) as? [Int],
                selectedIP.count == 3 {
                presentationItems = buildPresentationItems(from: reqList)
                if let parentStatement = presentationItems[selectedIP[0]].items[selectedIP[1]].statement,
                    let reqs = parentStatement.requirements,
                    selectedIP[2] < reqs.count {
                    nextList.requirementsList = reqs[selectedIP[2]]
                }
            } else if let nextDetails = nav.viewControllers[index + 1] as? CourseDetailsViewController {
                nextDetails.delegate = self
            } else if let nextBrowser = nav.viewControllers[index + 1] as? CourseBrowserViewController {
                nextBrowser.delegate = self
            }
        }
    }
    
    // MARK: - Favorites
    
    func updateFavoritesButton() {
        if let tabVC = rootParent as? RootTabViewController,
            let currentUser = tabVC.currentUser,
            let list = requirementsList as? RequirementsList {
            let image = (currentUser.coursesOfStudy.contains(list.listID)) ? UIImage(named: "heart-small-filled") : UIImage(named: "heart-small")
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(toggleFavorites(sender:)))
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }
    
    @objc func toggleFavorites(sender: AnyObject) {
        guard let tabVC = rootParent as? RootTabViewController,
            let currentUser = tabVC.currentUser,
            let list = requirementsList as? RequirementsList else {
                return
        }
        var title = ""
        if currentUser.coursesOfStudy.contains(list.listID) {
            currentUser.removeCourseOfStudy(list.listID)
            title = "Removed from My Courses"
        } else {
            currentUser.addCourseOfStudy(list.listID)
            title = "Added to My Courses"
        }
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud.mode = .customView
        let imageView = UIImageView(image: UIImage(named: "Checkmark"))
        imageView.frame = CGRect(x: 0.0, y: 0.0, width: 72.0, height: 72.0)
        hud.customView = imageView
        hud.label.text = title
        hud.isSquare = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            hud.hide(animated: true)
        }
        updateFavoritesButton()
        delegate?.requirementsListViewControllerUpdatedFavorites(self)
    }
    
    // MARK: - Table View
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return presentationItems.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return presentationItems[section].items.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cellType = presentationItems[indexPath.section].items[indexPath.row].cellType
        if cellType == .courseList {
            return 124.0
        } else if cellType == .url {
            return 54.0
        }
        return UITableViewAutomaticDimension
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if presentationItems[section].title.count > 0 {
            return 44.0
        }
        return 0.0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if presentationItems[section].title.count > 0 {
            if let cell = tableView.dequeueReusableCell(withIdentifier: "HeaderView") {
                ((cell.viewWithTag(12) as? UILabel) ?? cell.textLabel)?.text = presentationItems[section].title
                let detailTextLabel = (cell.viewWithTag(34) as? UILabel) ?? cell.detailTextLabel
                let fulfillmentIndicator = cell.viewWithTag(56)
                let (text, color) = progressInformation(for: presentationItems[section].statement)
                detailTextLabel?.text = text
                detailTextLabel?.textColor = UIColor.white
                fulfillmentIndicator?.backgroundColor = color
                fulfillmentIndicator?.layer.cornerRadius = RequirementsListViewController.fulfillmentIndicatorCornerRadius
                fulfillmentIndicator?.layer.masksToBounds = true
                detailTextLabel?.sizeToFit()
                return cell
            }
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = presentationItems[indexPath.section].items[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: item.cellType.rawValue, for: indexPath)
        if displayStandardMode {
            if #available(iOS 13.0, *) {
                cell.backgroundColor = UIColor.systemBackground
            } else {
                cell.backgroundColor = UIColor.white
            }
        } else {
            cell.backgroundColor = UIColor.clear
        }
        
        var textLabel = cell.viewWithTag(12) as? UILabel,
        detailTextLabel = cell.viewWithTag(34) as? UILabel
        if textLabel == nil {
            textLabel = cell.textLabel
        }
        if detailTextLabel == nil {
            detailTextLabel = cell.detailTextLabel
        }

        if item.cellType == .courseList,
            let courseListCell = cell as? CourseListTableCell,
            let statement = item.statement {
            
            fillCourseListCell(courseListCell, with: statement)
            courseListCell.longPressTarget = self
            courseListCell.longPressAction = #selector(RequirementsListViewController.longPressOnRequirementsCell(_:))

        } else {
            textLabel?.text = item.text ?? ""
            let fulfillmentIndicator = cell.viewWithTag(56)
            if item.cellType == .title || item.cellType == .title1 || item.cellType == .title2,
                indexPath.section != 0 || indexPath.row != 0 { //Exclude the main title
                let (text, color) = progressInformation(for: item.statement)
                detailTextLabel?.text = text
                detailTextLabel?.textColor = UIColor.white
                fulfillmentIndicator?.backgroundColor = color
                fulfillmentIndicator?.layer.cornerRadius = RequirementsListViewController.fulfillmentIndicatorCornerRadius
                fulfillmentIndicator?.layer.masksToBounds = true
            } else {
                detailTextLabel?.text = ""
                fulfillmentIndicator?.backgroundColor = UIColor.clear
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = presentationItems[indexPath.section].items[indexPath.row]
        guard item.cellType == .url,
            let urlString = item.url,
            let url = URL(string: urlString) else {
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    func progressInformation(for requirement: RequirementsListStatement?) -> (String, UIColor) {
        if let req = requirement {
            let progress = req.percentageFulfilled
            if progress > 0.0 {
                return ("\(Int(round(progress)))%", UIColor(hue: 0.005 * CGFloat(progress), saturation: 0.5, brightness: 0.8, alpha: 1.0))
            }
        }
        return ("", UIColor.clear)
    }
    
    func courseListCell(_ cell: CourseListCell, selected course: Course) {
        guard let tableCell = cell as? CourseListTableCell else {
            return
        }
        var statement: RequirementsListStatement?
        if let ip = tableView.indexPath(for: tableCell) {
            statement = presentationItems[ip.section].items[ip.row].statement
        }
        handleCourseListCellSelection(tableCell, of: course, with: statement)
    }
    
    func courseDetails(added course: Course, to semester: UserSemester?) {
        _ = addCourse(course, to: semester)
    }
    
    func courseDetailsRequestedDetails(about course: Course) {
        viewDetails(for: course)
    }
    
    func courseDetailsRequestedPostReqs(for course: Course) {
        let listVC = self.storyboard!.instantiateViewController(withIdentifier: "CourseListVC") as! CourseBrowserViewController
        listVC.searchTerm = course.subjectID ?? ""
        if let gir = course.girAttribute, gir != .lab, gir != .rest {
            listVC.searchTerm = gir.rawValue
        }
        listVC.searchOptions = SearchOptions.noFilter.filterSearchFields(.searchPrereqs).replace(oldValue: .containsSearchTerm, with: .matchesSearchTerm)
        listVC.showsHeaderBar = false
        listVC.delegate = self
        listVC.managesNavigation = false
        if #available(iOS 13.0, *) {
            listVC.view.backgroundColor = UIColor.systemBackground
        } else {
            listVC.view.backgroundColor = UIColor.white
        }
        showInformationalViewController(listVC)
    }
    
    func courseDetails(addedCourseToSchedule course: Course) {
        addCourseToSchedule(course)
    }
    
    func courseDetailsRequestedOpen(url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func addCourse(_ course: Course, to semester: UserSemester? = nil) -> UserSemester? {
        guard let tabVC = rootParent as? RootTabViewController else {
            print("Root isn't a tab bar controller!")
            return nil
        }
        if presentedViewController != nil {
            dismiss(animated: true, completion: nil)
            popoverNavigationController = nil
        }
        let ret = tabVC.addCourse(course, to: semester)
        updateRequirementsStatus()
        return ret
    }
    
    func addCourseToSchedule(_ course: Course) {
        guard let tabVC = rootParent as? RootTabViewController else {
            print("Root isn't a tab bar controller!")
            return
        }
        if presentedViewController != nil {
            dismiss(animated: true, completion: nil)
            popoverNavigationController = nil
        }
        tabVC.addCourseToSchedule(course)
    }
    
    // MARK: - View Controller Transitions
    
    func showManualProgressViewController(for requirement: RequirementsListStatement, from selectedCell: UICollectionViewCell) {
        guard showsManualProgressControls,
            let progressVC = self.storyboard?.instantiateViewController(withIdentifier: RequirementsConstants.requirementsProgressVCIdentifier) as? RequirementsProgressController else {
            return
        }
        progressVC.delegate = self
        progressVC.requirement = requirement
        progressVC.modalPresentationStyle = .popover
        progressVC.popoverPresentationController?.delegate = self
        progressVC.popoverPresentationController?.sourceRect = selectedCell.bounds
        progressVC.popoverPresentationController?.sourceView = selectedCell
        self.present(progressVC, animated: true, completion: nil)
    }
    
    func childRequirementsViewController() -> RequirementsListViewController? {
        guard let listVC = self.storyboard!.instantiateViewController(withIdentifier: RequirementsConstants.listVCIdentifier) as? RequirementsListViewController else {
            return nil
        }
        listVC.delegate = self.delegate
        return listVC
    }
    
    func courseBrowserViewController() -> CourseBrowserViewController? {
        return self.storyboard!.instantiateViewController(withIdentifier: RequirementsConstants.courseListVCIdentifier) as? CourseBrowserViewController
    }
    
    var popoverNavigationController: UINavigationController?
    
    /// Shows the view controller in a popover on iPad, and pushes it on iPhone.
    func showInformationalViewController(_ vc: UIViewController, from rect: CGRect = CGRect.zero) {
        if traitCollection.horizontalSizeClass == .regular,
            traitCollection.userInterfaceIdiom == .pad {
            vc.restorationIdentifier = nil
            if let nav = popoverNavigationController {
                nav.pushViewController(vc, animated: true)
            } else {
                let nav = UINavigationController(rootViewController: vc)
                nav.modalPresentationStyle = .popover
                nav.popoverPresentationController?.sourceRect = rect
                nav.popoverPresentationController?.sourceView = self.view
                nav.popoverPresentationController?.delegate = self
                present(nav, animated: true)
                popoverNavigationController = nav
            }
        } else {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func showInformationalViewController(_ vc: UIViewController, from cell: UICollectionViewCell) {
        let bounds = cell.convert(cell.bounds, to: self.view)
        showInformationalViewController(vc, from: bounds)
    }
    
    func selectIndexPath(for tableCell: CourseListTableCell, at courseIndex: Int) {
        if let tableIP = tableView.indexPath(for: tableCell) {
            selectedIndexPath = [tableIP.section, tableIP.row, courseIndex]
        }
    }
    
    func pushViewController(_ viewController: UIViewController, animated: Bool) {
        self.navigationController?.pushViewController(viewController, animated: animated)
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        if popoverNavigationController != nil {
            dismiss(animated: true, completion: nil)
            popoverNavigationController = nil
        }
    }
    
    func viewDetails(for course: Course, showGenericDetails: Bool = false) {
        viewDetails(for: course, from: nil, showGenericDetails: showGenericDetails)
    }
    
    func viewDetails(for course: Course, from cell: UICollectionViewCell, showGenericDetails: Bool) {
        let bounds = cell.convert(cell.bounds, to: self.view)
        viewDetails(for: course, from: bounds, showGenericDetails: showGenericDetails)
    }
    
    func viewDetails(for course: Course, from rect: CGRect?, showGenericDetails: Bool = false) {
        generateDetailsViewController(for: course, showGenericDetails: showGenericDetails) { (details, list) in
            if let detailVC = details {
                detailVC.delegate = self
                detailVC.displayStandardMode = self.displayStandardMode
                self.showInformationalViewController(detailVC, from: rect ?? CGRect.zero)
            } else if let listVC = list {
                listVC.delegate = self
                listVC.showsHeaderBar = false
                listVC.managesNavigation = false
                if !self.displayStandardMode {
                    listVC.view.backgroundColor = UIColor.clear
                }
                self.showInformationalViewController(listVC, from: rect ?? CGRect.zero)
            }
        }
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        popoverNavigationController = nil
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
    // MARK: - Course Thumbnail Cell Delegate
    
    func courseThumbnailCellWantsAdd(_ cell: CourseThumbnailCell) {
        guard let course = cell.course else {
            return
        }
        
        showAddCoursePopDownMenu(for: course)
    }
    
    func courseThumbnailCellWantsViewDetails(_ cell: CourseThumbnailCell) {
        guard let course = cell.course else {
            return
        }
        viewDetails(for: course, from: cell, showGenericDetails: false)
    }
    
    func courseThumbnailCellWantsSubstitute(_ cell: CourseThumbnailCell) {
        
    }
    
    func courseThumbnailCellWantsNoSubstitute(_ cell: CourseThumbnailCell) {
        
    }
    
    func courseThumbnailCellWantsIgnore(_ cell: CourseThumbnailCell) {
        
    }
    
    // MARK: - Manual Progress
    
    func requirementsProgressUpdated(_ controller: RequirementsProgressController) {
        updateRequirementsStatus()
    }
    
    // MARK: - Pop Down Table Menu
    
    var popDownOldNavigationTitle: String?

    @objc func longPressOnRequirementsCell(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began,
            let cell = sender.view as? CourseThumbnailCell,
            let id = cell.course?.subjectID,
            id.count > 0,
            let course = CourseManager.shared.getCourse(withID: id) else {
                return
        }
        showAddCoursePopDownMenu(for: course)
    }
    
    func showAddCoursePopDownMenu(for course: Course) {
        guard let popDown = self.storyboard?.instantiateViewController(withIdentifier: "PopDownTableMenu") as? PopDownTableMenuController,
            let id = course.subjectID else {
                return
        }

        navigationItem.rightBarButtonItem?.isEnabled = false
        popDownOldNavigationTitle = navigationItem.title
        navigationItem.title = "(\(id))"
        popDown.course = course
        popDown.delegate = self
        let containingView: UIView = self.view
        containingView.addSubview(popDown.view)
        popDown.view.translatesAutoresizingMaskIntoConstraints = false
        popDown.view.leftAnchor.constraint(equalTo: containingView.leftAnchor).isActive = true
        popDown.view.rightAnchor.constraint(equalTo: containingView.rightAnchor).isActive = true
        popDown.view.bottomAnchor.constraint(equalTo: containingView.bottomAnchor).isActive = true
        popDown.view.topAnchor.constraint(equalTo: containingView.topAnchor).isActive = true
        popDown.willMove(toParentViewController: self)
        self.addChildViewController(popDown)
        popDown.didMove(toParentViewController: self)
        let generator = UIImpactFeedbackGenerator()
        generator.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            popDown.show(animated: true)
            generator.impactOccurred()
        }
    }
    
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourseToFavorites course: Course) {
        if CourseManager.shared.favoriteCourses.contains(course) {
            CourseManager.shared.markCourseAsNotFavorite(course)
        } else {
            CourseManager.shared.markCourseAsFavorite(course)
        }
        popDownTableMenuCanceled(tableMenu)
    }
    
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourseToSchedule course: Course) {
        addCourseToSchedule(course)
        popDownTableMenuCanceled(tableMenu)
    }
    
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourse course: Course, to semester: UserSemester) {
        _ = addCourse(course, to: semester)
        popDownTableMenuCanceled(tableMenu)
    }
    
    func popDownTableMenuCanceled(_ tableMenu: PopDownTableMenuController) {
        navigationItem.rightBarButtonItem?.isEnabled = true
        if let oldTitle = popDownOldNavigationTitle {
            navigationItem.title = oldTitle
        }
        tableMenu.hide(animated: true) {
            tableMenu.willMove(toParentViewController: nil)
            tableMenu.view.removeFromSuperview()
            tableMenu.removeFromParentViewController()
            tableMenu.didMove(toParentViewController: nil)
        }
    }
}
