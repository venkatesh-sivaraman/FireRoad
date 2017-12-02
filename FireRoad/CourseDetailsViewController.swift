//
//  CourseDetailsViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/12/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol CourseDetailsDelegate: class {
    func courseDetails(added course: Course, to semester: UserSemester?)
    func courseDetailsRequestedDetails(about course: Course)
    func courseDetailsRequestedPostReqs(for course: Course)
}

enum CourseDetailItem {
    case header
    case title
    case description
    case units
    case instructors
    case requirements
    case offered
    case related
    case equivalent
    case joint
    case prerequisites
    case corequisites
    case schedule
    case courseListAccessory
    case button
}

enum CourseDetailSectionTitle {
    static let none = ""
    static let prerequisites = "Prerequisites"
    static let corequisites = "Corequisites"
    static let jointSubjects = "Joint Subjects"
    static let equivalentSubjects = "Equivalent Subjects"
    static let schedule = "Schedule"
    static let related = "Related"
}

class CourseDetailsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CourseListCellDelegate, PopDownTableMenuDelegate {

    var course: Course? = nil {
        didSet {
            if let newCourse = course {
                (self.sectionTitles, self.detailMapping) = self.generateMapping()
                CourseManager.shared.markCourseAsRecentlyViewed(newCourse)
            } else {
                self.detailMapping = [:]
                self.sectionTitles = []
            }
        }
    }
    weak var delegate: CourseDetailsDelegate? = nil
    var sectionTitles: [String] = []
    var detailMapping: [IndexPath: CourseDetailItem] = [:]
    
    @IBOutlet var tableView: UITableView!
    
    var displayStandardMode = false {
        didSet {
            updateScrollViewForDisplayMode()
        }
    }
    
    func updateScrollViewForDisplayMode() {
        loadViewIfNeeded()
        self.tableView.contentInset = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 8.0, right: 0.0)
        if !displayStandardMode {
            self.tableView.backgroundColor = UIColor.clear
            self.tableView.estimatedRowHeight = 60.0
            if #available(iOS 11.0, *) {
                self.tableView.contentInsetAdjustmentBehavior = .automatic
            }
            //self.navigationController?.navigationBar.shadowImage = UIImage()
            self.navigationController?.navigationBar.isTranslucent = true
        } else {
            self.tableView.backgroundColor = UIColor.white
            self.tableView.estimatedRowHeight = 60.0
            if #available(iOS 11.0, *) {
                self.tableView.contentInsetAdjustmentBehavior = .automatic
            }
            self.navigationController?.navigationBar.shadowImage = nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        if self.course != nil {
            self.navigationItem.title = self.course!.subjectID
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(CourseDetailsViewController.addCourseButtonPressed(sender:)))
        }
        updateScrollViewForDisplayMode()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    @objc func addCourseButtonPressed(sender: AnyObject) {
        //self.delegate?.courseDetails(added: self.course!)
        guard let popDown = self.storyboard?.instantiateViewController(withIdentifier: "PopDownTableMenu") as? PopDownTableMenuController else {
            print("No pop down table menu in storyboard!")
            return
        }
        navigationItem.rightBarButtonItem?.isEnabled = false
        popDown.course = self.course
        popDown.delegate = self
        let containingView: UIView = self.view
        containingView.addSubview(popDown.view)
        popDown.view.translatesAutoresizingMaskIntoConstraints = false
        popDown.view.leftAnchor.constraint(equalTo: containingView.leftAnchor).isActive = true
        popDown.view.rightAnchor.constraint(equalTo: containingView.rightAnchor).isActive = true
        popDown.view.bottomAnchor.constraint(equalTo: containingView.bottomAnchor).isActive = true
        popDown.view.topAnchor.constraint(equalTo: containingView.topAnchor, constant: navigationController?.navigationBar.frame.size.height ?? 0.0).isActive = true
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
    
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourse course: Course, to semester: UserSemester) {
        self.delegate?.courseDetails(added: course, to: semester)
        popDownTableMenuCanceled(tableMenu)
    }
    
    func popDownTableMenuCanceled(_ tableMenu: PopDownTableMenuController) {
        navigationItem.rightBarButtonItem?.isEnabled = true
        tableMenu.hide(animated: true) {
            tableMenu.willMove(toParentViewController: nil)
            tableMenu.view.removeFromSuperview()
            tableMenu.removeFromParentViewController()
            tableMenu.didMove(toParentViewController: nil)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func generateMapping() -> ([String], [IndexPath: CourseDetailItem]) {
        var mapping: [IndexPath: CourseDetailItem] = [
            IndexPath(row: 0, section: 0): .title,
            IndexPath(row: 1, section: 0): .description,
            IndexPath(row: 2, section: 0): .units,
            ]
        var titles: [String] = [CourseDetailSectionTitle.none]
        var rowIndex: Int = 3, sectionIndex: Int = 0
        if course!.communicationRequirement != nil ||
            course!.girAttribute != nil ||
            course?.hassAttribute != nil {
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .requirements
            rowIndex += 1
        }
        if course!.instructors.count > 0 {
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .instructors
            rowIndex += 1
        }
        mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .offered
        rowIndex += 1
        
        rowIndex = 0
        sectionIndex += 1

        if course!.prerequisites.flatMap({ $0 }).count > 0 {
            titles.append(CourseDetailSectionTitle.prerequisites)
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .header
            rowIndex += 1
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .description
            if course!.prerequisites.first(where: { $0.count > 1 }) != nil {
                for _ in course!.prerequisites {
                    rowIndex += 1
                    mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .prerequisites
                }
            } else {
                rowIndex += 1
                mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .prerequisites
            }
            //mapping[IndexPath(row: rowIndex + 1, section: sectionIndex)] = .courseListAccessory
            rowIndex = 0
            sectionIndex += 1
        }
        if course!.corequisites.flatMap({ $0 }).count > 0 {
            titles.append(CourseDetailSectionTitle.corequisites)
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .header
            rowIndex += 1
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .description
            if course!.corequisites.first(where: { $0.count > 1 }) != nil {
                for _ in course!.corequisites {
                    rowIndex += 1
                    mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .corequisites
                }
            } else {
                rowIndex += 1
                mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .corequisites
            }
            //mapping[IndexPath(row: rowIndex + 1, section: sectionIndex)] = .courseListAccessory
            rowIndex = 0
            sectionIndex += 1
        }
        if course!.jointSubjects.count > 0 {
            titles.append(CourseDetailSectionTitle.jointSubjects)
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .header
            rowIndex += 1
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .joint
            rowIndex = 0
            sectionIndex += 1
        }
        if course!.equivalentSubjects.count > 0 {
            titles.append(CourseDetailSectionTitle.equivalentSubjects)
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .header
            rowIndex += 1
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .equivalent
            rowIndex = 0
            sectionIndex += 1
        }
        if course!.relatedSubjects.count > 0 {
            titles.append(CourseDetailSectionTitle.related)
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .header
            rowIndex += 1
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .related
            rowIndex += 1
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .button
            rowIndex = 0
            sectionIndex += 1
        }
        if let schedule = course?.schedule, schedule.count > 0 {
            titles.append(CourseDetailSectionTitle.schedule)
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .header
            rowIndex += 1
            for _ in 0..<schedule.count {
                mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .schedule
                rowIndex += 1
            }
            rowIndex = 0
            sectionIndex += 1
        }
        
        if rowIndex == 0 {
            sectionIndex -= 1
        }
        return (titles, mapping)
    }
    
    func cellType(for detailItemType: CourseDetailItem) -> String {
        var id: String = ""
        switch detailItemType {
        case .header:
            id = "HeaderView"
        case .title:
            id = "TitleCell"
        case .description:
            id = "DescriptionCell"
        case .units, .instructors, .requirements, .offered, .schedule:
            id = "MetadataCell"
        case .related, .equivalent, .joint, .prerequisites, .corequisites:
            id = "CourseListCell"
        case .courseListAccessory:
            id = "CourseListAccessoryCell"
        case .button:
            id = "ButtonCell"
        }
        return id
    }


    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.sectionTitles.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.detailMapping.filter({ $0.key.section == section }).count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cellType = self.cellType(for: self.detailMapping[indexPath]!)
        if cellType == "DescriptionCell" || cellType == "MetadataCell" {
            if sectionTitles[indexPath.section] == CourseDetailSectionTitle.prerequisites || sectionTitles[indexPath.section] == CourseDetailSectionTitle.corequisites {
                return 32.0
            }
            return UITableViewAutomaticDimension
        } else if cellType == "CourseListCell" {
            return 124.0
        }
        return 60.0
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return -CGFloat.greatestFiniteMagnitude
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return self.detailMapping[indexPath] == .button
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let detailItemType = self.detailMapping[indexPath]!
        let id = self.cellType(for: detailItemType)
        let cell = tableView.dequeueReusableCell(withIdentifier: id, for: indexPath)

        var textLabel = cell.viewWithTag(12) as? UILabel,
        detailTextLabel = cell.viewWithTag(34) as? UILabel
        if textLabel == nil {
            textLabel = cell.textLabel
        }
        if detailTextLabel == nil {
            detailTextLabel = cell.detailTextLabel
        }
        
        switch detailItemType {
        case .header:
            textLabel?.text = self.sectionTitles[indexPath.section]
        case .title:
            textLabel?.text = self.course!.subjectTitle
        case .button:
            textLabel?.text = "Find Classes With \(self.course!.subjectID!) as Prerequisite"
        case .description:
            if self.sectionTitles[indexPath.section] == CourseDetailSectionTitle.prerequisites {
                if course!.prerequisites.first(where: { $0.count > 1 }) == nil {
                    textLabel?.text = "Fulfill all of the following:"
                } else if course!.prerequisites.count == 1 {
                    textLabel?.text = "Fulfill any of the following:"
                } else {
                    textLabel?.text = "Fulfill one from each row:"
                }
            } else if self.sectionTitles[indexPath.section] == CourseDetailSectionTitle.corequisites {
                if course!.corequisites.first(where: { $0.count > 1 }) == nil {
                    textLabel?.text = "Fulfill all of the following:"
                } else if course!.corequisites.count == 1 {
                    textLabel?.text = "Fulfill any of the following:"
                } else {
                    textLabel?.text = "Fulfill one from each row:"
                }
            } else {
                textLabel?.text = self.course!.subjectDescription
            }
        case .units:
            textLabel?.text = "Units"
            detailTextLabel?.text = "\(self.course!.totalUnits) total\n(\(self.course!.lectureUnits)-\(self.course!.labUnits)-\(self.course!.preparationUnits))"
        case .instructors:
            textLabel?.text = "Instructor\(self.course!.instructors.count != 1 ? "s" : "")"
            detailTextLabel?.text = self.course!.instructors.joined(separator: ",")
        case .requirements:
            textLabel?.text = "Fulfills"
            var reqs: [String] = []
            if let gir = self.course?.girAttribute {
                reqs.append(gir.descriptionText())
            }
            if let comm = self.course?.communicationRequirement {
                reqs.append(comm.rawValue)
            }
            if let hass = self.course?.hassAttribute {
                reqs.append(hass.rawValue)
            }
            detailTextLabel?.text = reqs.joined(separator: ", ")
        case .offered:
            textLabel?.text = "Offered"
            var seasons: [String] = []
            if self.course!.isOfferedFall {
                seasons.append("fall")
            }
            if self.course!.isOfferedIAP {
                seasons.append("IAP")
            }
            if self.course!.isOfferedSpring {
                seasons.append("spring")
            }
            if self.course!.isOfferedSummer {
                seasons.append("summer")
            }
            var offeredString = ""
            if self.course!.offeringPattern == .alternateYears, let notOffered = self.course?.notOfferedYear {
                offeredString = "\nNot offered \(notOffered)"
            }
            var quarterString = ""
            if self.course!.quarterOffered != .wholeSemester {
                var attachmentWord = ""
                if self.course!.quarterOffered == .beginningOnly {
                    quarterString = "\n1st half"
                    attachmentWord = "ends"
                } else if self.course!.quarterOffered == .endOnly {
                    quarterString = "\n2nd half"
                    attachmentWord = "starts"
                }
                if let date = self.course?.quarterBoundaryDate {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d"
                    quarterString += " – \(attachmentWord) \(formatter.string(from: date))"
                }
            }
            detailTextLabel?.text = seasons.joined(separator: ", ").capitalized + quarterString + offeredString
        case .schedule:
            textLabel?.text = ""
            detailTextLabel?.text = ""
            guard let schedule = course?.schedule else {
                break
            }
            let order = CourseScheduleType.ordering.filter({ schedule[$0] != nil })
            var scheduleType = ""
            let scheduleRows = detailMapping.filter({ $0.key.section == indexPath.section && $0.value == .schedule })
            let sortedRows = scheduleRows.sorted(by: { $0.key.item < $1.key.item })
            if let indexOfRow = sortedRows.index(where: { $0.key.item == indexPath.row }),
                order.count > indexOfRow {
                scheduleType = order[indexOfRow]
            } else {
                print("Unknown schedule type in this schedule: \(schedule.keys)")
                break
            }
            
            textLabel?.text = scheduleType
            guard let items = schedule[scheduleType] else {
                break
            }
            if items.count == 0 {
                detailTextLabel?.text = "TBA"
            } else {
                let itemDescriptions = items.map({ (itemSet) -> String in
                    return itemSet.map({ $0.stringEquivalent(withLocation: false) }).joined(separator: ", ") + (itemSet.first?.location != nil ? " (\(itemSet.first!.location!))" : "")
                }).joined(separator: "\n")
                detailTextLabel?.text = itemDescriptions
            }
        case .related:
            (cell as! CourseListCell).courses = []
            for (myID, _) in self.course!.relatedSubjects {
                if let relatedCourse = CourseManager.shared.getCourse(withID: myID) {
                    (cell as! CourseListCell).courses.append(relatedCourse)
                }
            }
            (cell as! CourseListCell).delegate = self
            (cell as! CourseListCell).collectionView.reloadData()
        case .equivalent:
            (cell as! CourseListCell).courses = []
            for myID in self.course!.equivalentSubjects {
                let equivCourse = CourseManager.shared.getCourse(withID: myID)
                if equivCourse != nil {
                    (cell as! CourseListCell).courses.append(equivCourse!)
                }
            }
            (cell as! CourseListCell).delegate = self
            (cell as! CourseListCell).collectionView.reloadData()
        case .prerequisites:
            (cell as! CourseListCell).courses = []
            let prereqs = self.course!.prerequisites.contains(where: { $0.count > 1 }) ? self.course!.prerequisites[indexPath.row - 2] : self.course!.prerequisites.flatMap({ $0 })
            for myID in prereqs {
                if myID.range(of: "[") != nil || myID.range(of: "{") != nil {
                    continue
                }
                let equivCourse = CourseManager.shared.getCourse(withID: myID)
                if equivCourse != nil {
                    (cell as! CourseListCell).courses.append(equivCourse!)
                } else if prereqs.count == 1, myID.lowercased().contains("permission of instructor") {
                    (cell as! CourseListCell).courses.append(Course(courseID: "None", courseTitle: "(Permission of instructor)", courseDescription: ""))
                } else if let gir = GIRAttribute(rawValue: myID) {
                    (cell as! CourseListCell).courses.append(Course(courseID: "GIR", courseTitle: gir.descriptionText().replacingOccurrences(of: "GIR", with: "").trimmingCharacters(in: .whitespaces), courseDescription: myID))
                }
            }
            (cell as! CourseListCell).delegate = self
            (cell as! CourseListCell).collectionView.reloadData()
        case .corequisites:
            (cell as! CourseListCell).courses = []
            let coreqs = self.course!.corequisites.contains(where: { $0.count > 1 }) ? self.course!.corequisites[indexPath.row - 2] : self.course!.corequisites.flatMap({ $0 })
            for myID in coreqs {
                // Useful when the corequisites were notated in brackets, but not anymore
                //let myID = String(id[(id.index(id.startIndex, offsetBy: 1))..<(id.index(id.endIndex, offsetBy: -1))])
                let equivCourse = CourseManager.shared.getCourse(withID: myID)
                if equivCourse != nil {
                    (cell as! CourseListCell).courses.append(equivCourse!)
                } else if let gir = GIRAttribute(rawValue: myID) {
                    (cell as! CourseListCell).courses.append(Course(courseID: "GIR", courseTitle: gir.descriptionText().replacingOccurrences(of: "GIR", with: "").trimmingCharacters(in: .whitespaces), courseDescription: myID))
                }
            }
            (cell as! CourseListCell).delegate = self
            (cell as! CourseListCell).collectionView.reloadData()
        case .courseListAccessory:
            var list: [String] = []
            switch self.detailMapping[IndexPath(row: indexPath.row - 1, section: indexPath.section)]! {
            case .prerequisites:
                list = self.course!.prerequisites.flatMap({ $0 })
            case .corequisites:
                list = self.course!.corequisites.flatMap({ $0 })
            case .equivalent:
                list = self.course!.equivalentSubjects
            case .joint:
                list = self.course!.jointSubjects
            default: break
            }
            for comp in list {
                if comp.contains("{") {
                    textLabel?.text = comp.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
                    break
                }
            }
        case .joint:
            (cell as! CourseListCell).courses = []
            for myID in self.course!.jointSubjects {
                let equivCourse = CourseManager.shared.getCourse(withID: myID)
                if equivCourse != nil {
                    (cell as! CourseListCell).courses.append(equivCourse!)
                }
            }
            (cell as! CourseListCell).delegate = self
            (cell as! CourseListCell).collectionView.reloadData()
        }

        return cell
    }
    
    func courseListCell(_ cell: CourseListCell, selected course: Course) {
        self.delegate?.courseDetailsRequestedDetails(about: course)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.courseDetailsRequestedPostReqs(for: self.course!)
    }
    
    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
