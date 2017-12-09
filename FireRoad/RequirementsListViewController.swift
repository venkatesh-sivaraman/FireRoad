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
    case title2 = "Title2Cell"
    case description = "DescriptionCell"
    case courseList = "CourseListCell"
    case courseListAccessory = "CourseListAccessoryCell"
}

protocol RequirementsListViewControllerDelegate: class {
    func requirementsListViewControllerUpdatedFulfillmentStatus(_ vc: RequirementsListViewController)
}

class RequirementsListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISplitViewControllerDelegate, CourseListCellDelegate, CourseDetailsDelegate, CourseBrowserDelegate, UIPopoverPresentationControllerDelegate {

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
    
    func presentationItems(for requirement: RequirementsListStatement, at level: Int = 0) -> [PresentationItem] {
        var items: [PresentationItem] = []
        if let title = requirement.title {
            let cellType: RequirementsListCellType = level == 0 ? .title : .title2
            var titleText = title
            if requirement.thresholdDescription.count > 0 {
                titleText += " (\(requirement.thresholdDescription))"
            }
            items.append(PresentationItem(cellType: cellType, statement: requirement, text: titleText))
        } else if requirement.thresholdDescription.count > 0 {
            items.append(PresentationItem(cellType: level == 0 ? .title : .title2, statement: requirement, text: requirement.thresholdDescription.capitalizingFirstLetter() + ":"))
        }
        if let description = requirement.contentDescription, description.count > 0 {
            items.append(PresentationItem(cellType: .description, statement: requirement, text: description))
        }
        
        if level == 0,
            requirement.title == nil, requirement.thresholdDescription.count > 0 {
            items.append(PresentationItem(cellType: .title2, statement: nil, text: requirement.thresholdDescription.capitalizingFirstLetter() + ":"))
        }
        if requirement.minimumNestDepth <= 1, (requirement.maximumNestDepth <= 2 || level > 0) {
            items.append(PresentationItem(cellType: .courseList, statement: requirement, text: nil))
            if requirement.thresholdDescription.count > 0 {
                //items.append(PresentationItem(cellType: .courseListAccessory, statement: nil, text: requirement.thresholdDescription))
                // Indicate this on the cell somehow
            }
        } else if let reqs = requirement.requirements {
            for req in reqs {
                items += presentationItems(for: req, at: level + 1)
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
                if topLevelRequirement.connectionType != .all, topLevelRequirement.thresholdDescription.count > 0 {
                    rows.insert(PresentationItem(cellType: .title2, statement: topLevelRequirement, text: topLevelRequirement.thresholdDescription.capitalizingFirstLetter() + ":"), at: 0)
                }
                ret.append((topLevelRequirement.title ?? "", topLevelRequirement, rows))
            }
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
        if let list = requirementsList as? RequirementsList {
            navigationItem.title = list.mediumTitle
        } else {
            navigationItem.title = requirementsList?.shortDescription
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateRequirementsStatus()
    }
    
    func updateRequirementsStatus() {
        if let tabVC = rootParent as? RootTabViewController,
            let currentUser = tabVC.currentUser {
            requirementsList?.computeRequirementStatus(with: currentUser.allCourses)
            tableView.reloadData()
        }
        delegate?.requirementsListViewControllerUpdatedFulfillmentStatus(self)
        updateFavoritesButton()
    }
    
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
            let courseListCell = cell as? CourseListCell,
            let statement = item.statement {
            
            let requirementStrings = (statement.requirements?.map({ $0.shortDescription })) ?? [statement.shortDescription]
            courseListCell.courses = requirementStrings.map {
                if let course = CourseManager.shared.getCourse(withID: $0) {
                    return course
                } else if let gir = GIRAttribute(rawValue: $0) {
                    return Course(courseID: "GIR", courseTitle: gir.descriptionText().replacingOccurrences(of: "GIR", with: "").trimmingCharacters(in: .whitespaces), courseDescription: "")
                }
                if let whitespaceRange = $0.rangeOfCharacter(from: .whitespaces) {
                    return Course(courseID: String($0[$0.startIndex..<whitespaceRange.lowerBound]), courseTitle: String($0[whitespaceRange.upperBound..<$0.endIndex]), courseDescription: "")
                } else if $0.count > 8 {
                    return Course(courseID: "", courseTitle: $0, courseDescription: "")
                }
                return Course(courseID: $0, courseTitle: "", courseDescription: "")
            }
            if let reqs = statement.requirements {
                courseListCell.fulfillmentIndications = reqs.map {
                    ($0.fulfillmentProgress, $0.threshold.cutoff)
                }
            } else {
                courseListCell.fulfillmentIndications = [(statement.fulfillmentProgress, statement.threshold.cutoff)]
            }
            
            courseListCell.delegate = self
            
        } else {
            textLabel?.text = item.text ?? ""
            let fulfillmentIndicator = cell.viewWithTag(56)
            if item.cellType == .title || item.cellType == .title2,
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
        guard let courseIndex = cell.courses.index(of: course),
            let selectedCell = cell.collectionView.cellForItem(at: IndexPath(item: courseIndex, section: 0)) else {
                return
        }
        if let id = course.subjectID,
            let actualCourse = CourseManager.shared.getCourse(withID: id),
            actualCourse == course {
            viewDetails(for: course, from: selectedCell.convert(selectedCell.bounds, to: self.view))
        } else if let ip = tableView.indexPath(for: cell) {
            guard let item = presentationItems[ip.section].items[ip.row].statement else {
                return
            }
            let requirements = item.requirements ?? [item]
            
            if let reqString = requirements[courseIndex].requirement?.replacingOccurrences(of: "GIR:", with: "") {
                let listVC = self.storyboard!.instantiateViewController(withIdentifier: courseListVCIdentifier) as! CourseBrowserViewController
                listVC.searchTerm = reqString
                listVC.searchOptions = [.offeredAnySemester, .containsSearchTerm, .fulfillsGIR, .fulfillsHASS, .fulfillsCIH, .fulfillsCIHW, .searchRequirements]
                listVC.delegate = self
                listVC.showsHeaderBar = false
                listVC.managesNavigation = false
                showInformationalViewController(listVC, from: selectedCell.convert(selectedCell.bounds, to: self.view))
            } else {
                let listVC = self.storyboard!.instantiateViewController(withIdentifier: listVCIdentifier) as! RequirementsListViewController
                listVC.requirementsList = requirements[courseIndex]
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
        listVC.searchTerm = (course.subjectID ?? "") + " " + (course.girAttribute?.descriptionText() ?? "")
        listVC.searchOptions = [.offeredAnySemester, .containsSearchTerm, .fulfillsGIR, .anyRequirement, .searchPrereqs]
        listVC.showsHeaderBar = false
        listVC.delegate = self
        listVC.managesNavigation = false
        listVC.view.backgroundColor = UIColor.clear
        showInformationalViewController(listVC)
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
    
    var popoverNavigationController: UINavigationController?
    
    /// Shows the view controller in a popover on iPad, and pushes it on iPhone.
    func showInformationalViewController(_ vc: UIViewController, from rect: CGRect = CGRect.zero) {
        if traitCollection.horizontalSizeClass == .regular,
            traitCollection.userInterfaceIdiom == .pad {
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
}
