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

class RequirementsListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISplitViewControllerDelegate, CourseListCellDelegate, CourseDetailsDelegate {

    struct PresentationItem {
        var cellType: RequirementsListCellType
        var statement: RequirementsListStatement?
        var text: String?
    }
    
    @IBOutlet var tableView: UITableView!
    var requirementsList: RequirementsListStatement?
    var presentationItems: [(title: String, items: [PresentationItem])] = []
    
    let courseCellIdentifier = "CourseCell"
    let listVCIdentifier = "RequirementsList"

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
            if requirement.thresholdDescription.characters.count > 0 {
                titleText += " (\(requirement.thresholdDescription))"
            }
            items.append(PresentationItem(cellType: cellType, statement: nil, text: titleText))
        }
        if let description = requirement.contentDescription {
            items.append(PresentationItem(cellType: .description, statement: nil, text: description))
        }
        
        if level == 0,
            requirement.title == nil, requirement.thresholdDescription.characters.count > 0 {
            items.append(PresentationItem(cellType: .title2, statement: nil, text: requirement.thresholdDescription.capitalizingFirstLetter() + ":"))
        }
        if requirement.minimumNestDepth <= 1, (requirement.maximumNestDepth <= 2 || level > 0) {
            items.append(PresentationItem(cellType: .courseList, statement: requirement, text: nil))
            if requirement.thresholdDescription.characters.count > 0 {
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
    
    func buildPresentationItems(from list: RequirementsListStatement) -> [(title: String, items: [PresentationItem])] {
        guard let requirements = list.requirements else {
            return []
        }
        
        var ret: [(title: String, items: [PresentationItem])] = []
        if list.minimumNestDepth <= 1 {
            ret.append(("", presentationItems(for: list)))
        } else {
            for topLevelRequirement in requirements {
                var rows: [PresentationItem] = []
                if let reqs = topLevelRequirement.requirements {
                    for req in reqs {
                        rows += presentationItems(for: req)
                    }
                } else {
                    rows = presentationItems(for: topLevelRequirement)
                    // Remove the title
                    rows.removeFirst()
                }
                ret.append((topLevelRequirement.title ?? "", rows))
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
        if presentationItems[section].title.characters.count > 0 {
            return 44.0
        }
        return 0.0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if presentationItems[section].title.characters.count > 0 {
            if let cell = tableView.dequeueReusableCell(withIdentifier: "HeaderView") {
                ((cell.viewWithTag(12) as? UILabel) ?? cell.textLabel)?.text = presentationItems[section].title
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
                } else if $0.contains("GIR") {
                    return Course(courseID: "GIR", courseTitle: descriptionForGIR(attribute: $0).replacingOccurrences(of: "GIR", with: "").trimmingCharacters(in: .whitespaces), courseDescription: "")
                }
                if let whitespaceRange = $0.rangeOfCharacter(from: .whitespaces) {
                    return Course(courseID: String($0[$0.startIndex..<whitespaceRange.lowerBound]), courseTitle: String($0[whitespaceRange.upperBound..<$0.endIndex]), courseDescription: "")
                } else if $0.characters.count > 8 {
                    return Course(courseID: "", courseTitle: $0, courseDescription: "")
                }
                return Course(courseID: $0, courseTitle: "", courseDescription: "")
            }
            
            courseListCell.delegate = self
            
        } else {
            textLabel?.text = item.text ?? ""
        }
        return cell
    }
    
    func courseListCell(_ cell: CourseListCell, selected course: Course) {
        if let id = course.subjectID,
            let actualCourse = CourseManager.shared.getCourse(withID: id),
            actualCourse == course {
            viewDetails(for: course)
        } else if let ip = tableView.indexPath(for: cell) {
            guard let item = presentationItems[ip.section].items[ip.row].statement,
                let requirements = item.requirements,
                let courseIndex = cell.courses.index(of: course) else {
                return
            }
            
            if let reqString = requirements[courseIndex].requirement {
                print(reqString)
            } else {
                let listVC = self.storyboard!.instantiateViewController(withIdentifier: listVCIdentifier) as! RequirementsListViewController
                listVC.requirementsList = requirements[courseIndex]
                self.navigationController?.pushViewController(listVC, animated: true)
            }
        }
    }
    
    func courseDetails(added course: Course) {
        
    }
    
    func courseDetailsRequestedDetails(about course: Course) {
        viewDetails(for: course)
    }
    
    func viewDetails(for course: Course) {
        CourseManager.shared.loadCourseDetails(about: course) { (success) in
            if success {
                let details = self.storyboard!.instantiateViewController(withIdentifier: "CourseDetails") as! CourseDetailsViewController
                details.course = course
                details.delegate = self
                details.displayStandardMode = true
                self.navigationController?.pushViewController(details, animated: true)
            } else {
                print("Failed to load course details!")
            }
        }
    }
}
