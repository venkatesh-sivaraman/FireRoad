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

class RequirementsListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISplitViewControllerDelegate, CourseListCellDelegate, CourseDetailsDelegate, CourseBrowserDelegate, RequirementsProgressDelegate, UIPopoverPresentationControllerDelegate, PopDownTableMenuDelegate {

    struct PresentationItem {
        var cellType: RequirementsListCellType
        var statement: RequirementsListStatement?
        var text: String?
    }
    
    @IBOutlet var tableView: UITableView!
    var requirementsList: RequirementsListStatement?
    var presentationItems: [(title: String, statement: RequirementsListStatement, items: [PresentationItem])] = []
    
    let courseCellIdentifier = "CourseCell"
    let listVCIdentifier = "RequirementsList"
    let courseListVCIdentifier = "CourseListVC"
    let requirementsProgressVCIdentifier = "RequirementsProgressVC"
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
        if requirement.minimumNestDepth <= 1, (requirement.maximumNestDepth <= 2 || level > 0),
            requirement.requirements?.first(where: { $0.title != nil && $0.title!.count > 0 }) == nil {
            items.append(PresentationItem(cellType: .courseList, statement: requirement, text: nil))
            if requirement.thresholdDescription.count > 0 {
                //items.append(PresentationItem(cellType: .courseListAccessory, statement: nil, text: requirement.thresholdDescription))
                // Indicate this on the cell somehow
            }
        } else if let reqs = requirement.requirements {
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
            for topLevelRequirement in requirements {
                var rows: [PresentationItem] = presentationItems(for: topLevelRequirement)
                // Remove the title
                rows.removeFirst()
                if topLevelRequirement.connectionType != .all || topLevelRequirement.threshold.cutoff > 1,
                    topLevelRequirement.thresholdDescription.count > 0,
                    (topLevelRequirement.contentDescription ?? "").count == 0 || topLevelRequirement.threshold.cutoff > 1,
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
        if ret.count > 0, (requirementsList as? RequirementsList)?.webURL != nil {
            let last = ret[ret.count - 1]
            ret[ret.count - 1] = (last.title, last.statement, last.items + [PresentationItem(cellType: .url, statement: nil, text: "View Requirements on Catalog Site")])
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
            requirementsList?.computeRequirementStatus(with: currentUser.allCourses)
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
                return cell
            }
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = presentationItems[indexPath.section].items[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: item.cellType.rawValue, for: indexPath)
        
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
            
            let requirementStrings = (statement.requirements?.map({ $0.shortDescription })) ?? [statement.shortDescription]
            courseListCell.courses = requirementStrings.map {
                if let course = CourseManager.shared.getCourse(withID: $0) {
                    return course
                } else if let gir = GIRAttribute(rawValue: $0) {
                    return Course(courseID: "GIR", courseTitle: gir.descriptionText().replacingOccurrences(of: "GIR", with: "").trimmingCharacters(in: .whitespaces), courseDescription: "")
                }
                if let whitespaceRange = $0.rangeOfCharacter(from: .whitespaces),
                    Int(String($0[$0.startIndex..<whitespaceRange.lowerBound])) != nil ||
                        String($0[$0.startIndex..<whitespaceRange.lowerBound]).contains(".") {
                    return Course(courseID: String($0[$0.startIndex..<whitespaceRange.lowerBound]), courseTitle: String($0[whitespaceRange.upperBound..<$0.endIndex]), courseDescription: "")
                } else if $0.count > 8 {
                    return Course(courseID: "", courseTitle: $0, courseDescription: "")
                }
                return Course(courseID: $0, courseTitle: "", courseDescription: "")
            }
            if let reqs = statement.requirements {
                courseListCell.fulfillmentIndications = reqs.map {
                    ($0.fulfillmentProgress(for: $0.threshold.criterion), $0.threshold.cutoff, $0.threshold.criterion == .units)
                }
            } else {
                courseListCell.fulfillmentIndications = [(statement.fulfillmentProgress(for: statement.threshold.criterion), statement.threshold.cutoff, statement.threshold.criterion == .units)]
            }
            
            courseListCell.delegate = self
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
            let url = (requirementsList as? RequirementsList)?.webURL else {
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    func progressInformation(for requirement: RequirementsListStatement?) -> (String, UIColor) {
        if let req = requirement,
            req.connectionType == .all || req.threshold.cutoff > 0 {
            let progress = req.percentageFulfilled
            if progress > 0.0 {
                return ("\(Int(round(progress)))%", UIColor(hue: 0.005 * CGFloat(progress), saturation: 0.5, brightness: 0.8, alpha: 1.0))
            }
        }
        return ("", UIColor.clear)
    }
    
    func courseListCell(_ cell: CourseListCell, selected course: Course) {
        guard let tableCell = cell as? CourseListTableCell,
            let courseIndex = cell.courses.index(of: course),
            let selectedCell = cell.collectionView.cellForItem(at: IndexPath(item: courseIndex, section: 0)) else {
                return
        }
        if let id = course.subjectID,
            let actualCourse = CourseManager.shared.getCourse(withID: id),
            actualCourse == course {
            viewDetails(for: course, from: selectedCell.convert(selectedCell.bounds, to: self.view))
        } else if let ip = tableView.indexPath(for: tableCell) {
            guard let item = presentationItems[ip.section].items[ip.row].statement else {
                return
            }
            let requirements = item.requirements ?? [item]
            
            if requirements[min(requirements.count, courseIndex)].isPlainString {
                // Show the progress selector
                guard let progressVC = self.storyboard?.instantiateViewController(withIdentifier: requirementsProgressVCIdentifier) as? RequirementsProgressController else {
                    return
                }
                progressVC.delegate = self
                progressVC.requirement = requirements[min(requirements.count, courseIndex)]
                progressVC.modalPresentationStyle = .popover
                progressVC.popoverPresentationController?.delegate = self
                progressVC.popoverPresentationController?.sourceRect = selectedCell.bounds
                progressVC.popoverPresentationController?.sourceView = selectedCell
                self.present(progressVC, animated: true, completion: nil)

            } else if let reqString = requirements[courseIndex].requirement?.replacingOccurrences(of: "GIR:", with: "") {
                let listVC = self.storyboard!.instantiateViewController(withIdentifier: courseListVCIdentifier) as! CourseBrowserViewController
                listVC.searchTerm = reqString
                if let ciAttribute = CommunicationAttribute(rawValue: reqString) {
                    listVC.searchOptions = [.offeredAnySemester, .containsSearchTerm, (ciAttribute == .ciH ? .fulfillsCIH : .fulfillsCIHW), .searchRequirements]
                } else if HASSAttribute(rawValue: reqString) != nil {
                    listVC.searchOptions = [.offeredAnySemester, .containsSearchTerm, .fulfillsHASS, .searchRequirements]
                } else {
                    listVC.searchOptions = [.offeredAnySemester, .containsSearchTerm, .fulfillsGIR, .fulfillsHASS, .fulfillsCIH, .fulfillsCIHW, .searchRequirements]
                }
                listVC.delegate = self
                listVC.showsHeaderBar = false
                listVC.managesNavigation = false
                showInformationalViewController(listVC, from: selectedCell.convert(selectedCell.bounds, to: self.view))
            } else {
                if let tableIP = tableView.indexPath(for: tableCell) {
                    selectedIndexPath = [tableIP.section, tableIP.row, courseIndex]
                }
                let listVC = self.storyboard!.instantiateViewController(withIdentifier: listVCIdentifier) as! RequirementsListViewController
                listVC.requirementsList = requirements[courseIndex]
                listVC.delegate = self.delegate
                self.navigationController?.pushViewController(listVC, animated: true)
            }
        }
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
        listVC.searchOptions = [.offeredAnySemester, .containsSearchTerm, .fulfillsGIR, .anyRequirement, .searchPrereqs]
        listVC.showsHeaderBar = false
        listVC.delegate = self
        listVC.managesNavigation = false
        listVC.view.backgroundColor = UIColor.white
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
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        if popoverNavigationController != nil {
            dismiss(animated: true, completion: nil)
            popoverNavigationController = nil
        }
    }
    
    func viewDetails(for course: Course) {
        viewDetails(for: course, from: nil)
    }
    
    func viewDetails(for course: Course, from rect: CGRect?) {
        if let id = course.subjectID,
            CourseManager.shared.getCourse(withID: id) != nil {
            CourseManager.shared.loadCourseDetails(about: course) { (success) in
                if success {
                    let details = self.storyboard!.instantiateViewController(withIdentifier: "CourseDetails") as! CourseDetailsViewController
                    details.course = course
                    details.delegate = self
                    details.displayStandardMode = true
                    self.showInformationalViewController(details, from: rect ?? CGRect.zero)
                } else {
                    print("Failed to load course details!")
                }
            }
        } else if course.subjectID == "GIR" {
            let listVC = self.storyboard!.instantiateViewController(withIdentifier: courseListVCIdentifier) as! CourseBrowserViewController
            let keyword = course.subjectDescription ?? (course.subjectTitle ?? "")
            listVC.searchTerm = GIRAttribute(rawValue: keyword)?.rawValue
            listVC.searchOptions = [.offeredAnySemester, .containsSearchTerm, .fulfillsGIR, .searchRequirements]
            listVC.delegate = self
            listVC.showsHeaderBar = false
            listVC.managesNavigation = false
            self.showInformationalViewController(listVC, from: rect ?? CGRect.zero)
        }
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        popoverNavigationController = nil
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
    // MARK: - Manual Progress
    
    func requirementsProgressUpdated(_ controller: RequirementsProgressController) {
        updateRequirementsStatus()
    }
    
    // MARK: - Pop Down Table Menu
    
    var popDownOldNavigationTitle: String?

    @objc func longPressOnRequirementsCell(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began,
            let popDown = self.storyboard?.instantiateViewController(withIdentifier: "PopDownTableMenu") as? PopDownTableMenuController,
            let cell = sender.view as? CourseThumbnailCell,
            let id = cell.course?.subjectID,
            id.count > 0,
            CourseManager.shared.getCourse(withID: id) != nil else {
                return
        }
        navigationItem.rightBarButtonItem?.isEnabled = false
        popDownOldNavigationTitle = navigationItem.title
        navigationItem.title = "(\(id))"
        popDown.course = cell.course
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            popDown.show(animated: true)
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
