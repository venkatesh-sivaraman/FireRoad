//
//  CourseDetailsViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/12/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol CourseDetailsDelegate: class {
    func courseDetails(added course: Course)
    func courseDetailsRequestedDetails(about course: Course)
}

enum CourseDetailItem {
    case title
    case description
    case units
    case instructors
    case requirements
    case related
    case equivalent
    case joint
    case prerequisites
    case corequisites
    case courseListAccessory
}

class CourseDetailsViewController: UITableViewController, CourseListCellDelegate {

    var course: Course? = nil {
        didSet {
            if self.course != nil {
                (self.sectionTitles, self.detailMapping) = self.generateMapping()
            } else {
                self.detailMapping = [:]
                self.sectionTitles = []
            }
        }
    }
    weak var delegate: CourseDetailsDelegate? = nil
    var sectionTitles: [String] = []
    var detailMapping: [IndexPath: CourseDetailItem] = [:]
    
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
        self.tableView.contentInset = UIEdgeInsetsMake(8.0, 0.0, 0.0, 0.0)
        self.tableView.estimatedRowHeight = 60.0
        
    }
    
    func addCourseButtonPressed(sender: AnyObject) {
        self.delegate?.courseDetails(added: self.course!)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.navigationController != nil {
            self.navigationController?.setNavigationBarHidden(false, animated: true)
            self.navigationController?.navigationBar.shadowImage = UIImage()
            self.navigationController?.navigationBar.isTranslucent = true
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
        var titles: [String] = [""]
        var rowIndex: Int = 3, sectionIndex: Int = 0
        if (course!.writingRequirement != nil && course!.writingRequirement!.characters.count > 0) ||
            (course!.communicationRequirement != nil && course!.communicationRequirement!.characters.count > 0) ||
            (course!.GIRAttribute != nil && course!.GIRAttribute!.characters.count > 0) ||
            (course!.hassAttribute != nil && course!.hassAttribute!.characters.count > 0) {
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .requirements
            rowIndex += 1
        }
        mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .instructors
        rowIndex = 0
        sectionIndex += 1
        
        if course!.prerequisites.count > 0 {
            var prereqs: [String] = [], coreqs: [String] = []
            for req in course!.prerequisites {
                if req.range(of: "[") != nil {
                    coreqs.append(req)
                } else {
                    prereqs.append(req)
                }
            }
            if prereqs.count > 0 {
                titles.append("Prerequisites")
                mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .prerequisites
                //mapping[IndexPath(row: rowIndex + 1, section: sectionIndex)] = .courseListAccessory
                rowIndex = 0
                sectionIndex += 1
            }
            if coreqs.count > 0 {
                titles.append("Corequisites")
                mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .corequisites
                rowIndex = 0
                sectionIndex += 1
            }
            
        }
        if course!.jointSubjects.count > 0 {
            titles.append("Joint Subjects")
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .joint
            rowIndex = 0
            sectionIndex += 1
        }
        if course!.equivalentSubjects.count > 0 {
            titles.append("Equivalent Subjects")
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .equivalent
            rowIndex = 0
            sectionIndex += 1
        }
        if course!.relatedSubjects.count > 0 {
            titles.append("Related")
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .related
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
        case .title:
            id = "TitleCell"
        case .description:
            id = "DescriptionCell"
        case .units, .instructors, .requirements:
            id = "MetadataCell"
        case .related, .equivalent, .joint, .prerequisites, .corequisites:
            id = "CourseListCell"
        case .courseListAccessory:
            id = "CourseListAccessoryCell"
        }
        return id
    }


    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.sectionTitles.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.detailMapping.filter({ $0.key.section == section }).count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cellType = self.cellType(for: self.detailMapping[indexPath]!)
        if cellType == "DescriptionCell" || cellType == "MetadataCell" {
            return UITableViewAutomaticDimension
        } else if cellType == "CourseListCell" {
            return 124.0
        }
        return 60.0
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if self.sectionTitles[section].characters.count > 0 {
            return 44.0
        }
        return 0.0
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if self.sectionTitles[section].characters.count > 0 {
            if let cell = tableView.dequeueReusableCell(withIdentifier: "HeaderView") {
                cell.textLabel?.text = self.sectionTitles[section]
                return cell
            }
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
        case .title:
            textLabel?.text = self.course!.subjectTitle
        case .description:
            textLabel?.text = self.course!.subjectDescription
        case .units:
            textLabel?.text = "Units"
            detailTextLabel?.text = "\(self.course!.totalUnits) total\n(\(self.course!.lectureUnits)-\(self.course!.labUnits)-\(self.course!.preparationUnits))"
        case .instructors:
            textLabel?.text = "Instructors"
            if course!.isOfferedFall && course!.isOfferedSpring {
                detailTextLabel?.text = "Fall – \(self.course!.fallInstructors.joined(separator: ", "))\nSpring – \(self.course!.springInstructors.joined(separator: ", "))"
            } else if course!.isOfferedFall {
                detailTextLabel?.text = self.course!.fallInstructors.joined(separator: ",")
            } else if course!.isOfferedSpring {
                detailTextLabel?.text = self.course!.springInstructors.joined(separator: ",")
            }
        case .requirements:
            textLabel?.text = "Fulfills"
            var reqs: [String] = []
            if self.course!.GIRAttributeDescription != nil && self.course!.GIRAttributeDescription!.characters.count > 0 {
                reqs.append(self.course!.GIRAttributeDescription!)
            }
            if self.course!.communicationReqDescription != nil && self.course!.communicationReqDescription!.characters.count > 0 {
                reqs.append(self.course!.communicationReqDescription!)
            }
            if self.course!.hassAttributeDescription != nil && self.course!.hassAttributeDescription!.characters.count > 0 {
                reqs.append(self.course!.hassAttributeDescription!)
            }
            if self.course!.writingReqDescription != nil && self.course!.writingReqDescription!.characters.count > 0 {
                reqs.append(self.course!.writingReqDescription!)
            }
            detailTextLabel?.text = reqs.joined(separator: ", ")
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
            for myID in self.course!.prerequisites {
                if myID.range(of: "[") != nil || myID.range(of: "{") != nil {
                    continue
                }
                let equivCourse = CourseManager.shared.getCourse(withID: myID)
                if equivCourse != nil {
                    (cell as! CourseListCell).courses.append(equivCourse!)
                } else if myID.contains("GIR") {
                    (cell as! CourseListCell).courses.append(Course(courseID: "GIR", courseTitle: descriptionForGIR(attribute: myID).replacingOccurrences(of: "GIR", with: "").trimmingCharacters(in: .whitespaces), courseDescription: ""))
                }
            }
            (cell as! CourseListCell).delegate = self
            (cell as! CourseListCell).collectionView.reloadData()
        case .corequisites:
            (cell as! CourseListCell).courses = []
            for id in self.course!.prerequisites {
                if id.range(of: "[") == nil || id.range(of: "{") != nil {
                    continue
                }
                let myID = id.substring(with: (id.index(id.startIndex, offsetBy: 1))..<(id.index(id.endIndex, offsetBy: -1)))
                let equivCourse = CourseManager.shared.getCourse(withID: myID)
                if equivCourse != nil {
                    (cell as! CourseListCell).courses.append(equivCourse!)
                } else if myID.contains("GIR") {
                    (cell as! CourseListCell).courses.append(Course(courseID: "GIR", courseTitle: descriptionForGIR(attribute: myID).replacingOccurrences(of: "GIR", with: "").trimmingCharacters(in: .whitespaces), courseDescription: ""))
                }
            }
            (cell as! CourseListCell).delegate = self
            (cell as! CourseListCell).collectionView.reloadData()
        case .courseListAccessory:
            var list: [String] = []
            switch self.detailMapping[IndexPath(row: indexPath.row - 1, section: indexPath.section)]! {
            case .prerequisites, .corequisites:
                list = self.course!.prerequisites
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
    
    func courseListCellSelected(_ course: Course) {
        self.delegate?.courseDetailsRequestedDetails(about: course)
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
