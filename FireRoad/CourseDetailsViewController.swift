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
    func courseDetails(addedCourseToSchedule course: Course)
    func courseDetailsRequestedDetails(about course: Course)
    func courseDetailsRequestedPostReqs(for course: Course)
    func courseDetailsRequestedOpen(url: URL)
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
    case reqHeader
    case prerequisites
    case corequisites
    case schedule
    case courseListAccessory
    case button
    case url
    case courseEvaluations
    case notes
    case rate
    case enrollment
    case evalRating
    case evalHours
    case warning
}

enum CourseDetailSectionTitle {
    static let none = ""
    static let prerequisites = "Prerequisites"
    static let corequisites = "Corequisites"
    static let jointSubjects = "Joint Subjects"
    static let equivalentSubjects = "Equivalent Subjects"
    static let schedule = "Schedule"
    static let related = "Related"
    static let notes = "Notes"
    static let ratings = "Ratings"
}

class CourseDetailsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CourseListCellDelegate, PopDownTableMenuDelegate, UITextViewDelegate, RequirementsListDisplay, RequirementsListViewControllerDelegate {

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
    
    var showsSemesterDialog = true
    var hasViewAppeared = false
    
    @IBOutlet var tableView: UITableView!
    @IBOutlet var tableViewBottomConstraint: NSLayoutConstraint?
    
    var displayStandardMode = false {
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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        updateScrollViewForDisplayMode()
        
        if #available(iOS 11.0, *) {
            self.navigationItem.largeTitleDisplayMode = .never
        }

        NotificationCenter.default.addObserver(self, selector: #selector(CourseDetailsViewController.courseManagerFinishedLoading(_:)), name: .CourseManagerFinishedLoading, object: nil)
        
        preferredContentSize = CGSize(width: preferredContentSize.width, height: 520.0)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.setToolbarHidden(true, animated: true)
        
        NotificationCenter.default.addObserver(self, selector: #selector(CourseDetailsViewController.keyboardChangedFrame(_:)), name: .UIKeyboardDidChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(CourseDetailsViewController.keyboardWillChangeFrame(_:)), name: .UIKeyboardWillChangeFrame, object: nil)
        
        hasViewAppeared = true
        loadSubjectsOrDisplay()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func courseManagerFinishedLoading(_ note: Notification) {
        loadSubjectsOrDisplay()
    }
    
    var courseLoadingHUD: MBProgressHUD?
    
    var restoredCourseID: String?
    
    func loadSubjectsOrDisplay() {
        guard hasViewAppeared else {
            return
        }
        self.navigationItem.title = self.restoredCourseID ?? self.course?.subjectID
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(CourseDetailsViewController.addCourseButtonPressed(sender:)))
        if !CourseManager.shared.isLoaded, restoredCourseID != nil {
            self.navigationItem.rightBarButtonItem?.isEnabled = false
            guard courseLoadingHUD == nil else {
                return
            }
            let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            hud.mode = .determinateHorizontalBar
            hud.label.text = "Loading subjects…"
            courseLoadingHUD = hud
            DispatchQueue.global(qos: .background).async {
                let initialProgress = CourseManager.shared.loadingProgress
                while !CourseManager.shared.isLoaded {
                    DispatchQueue.main.async {
                        hud.progress = (CourseManager.shared.loadingProgress - initialProgress) / (1.0 - initialProgress)
                    }
                    usleep(100)
                }
                let newCourse = self.restoredCourseID != nil ? CourseManager.shared.getCourse(withID: self.restoredCourseID!) : nil
                if let course = newCourse {
                    CourseManager.shared.loadCourseDetailsSynchronously(about: course)
                }
                self.restoredCourseID = nil
                DispatchQueue.main.async {
                    self.navigationItem.rightBarButtonItem?.isEnabled = true
                    self.course = newCourse
                    self.updateRequirementsStatus()
                    self.tableView.reloadData()
                    hud.hide(animated: true)
                }
            }
            return
        }
        self.navigationItem.rightBarButtonItem?.isEnabled = true
        self.updateRequirementsStatus()
        if course == nil, let id = restoredCourseID,
            let newCourse = CourseManager.shared.getCourse(withID: id) {
            self.course = newCourse
            self.tableView.reloadData()
            CourseManager.shared.loadCourseDetails(about: newCourse, { _ in
                self.course = newCourse
                self.updateRequirementsStatus()
                self.tableView.reloadData()
            })
        }
    }
    
    @objc func addCourseButtonPressed(sender: AnyObject) {
        //self.delegate?.courseDetails(added: self.course!)
        if showsSemesterDialog {
            guard let popDown = self.storyboard?.instantiateViewController(withIdentifier: "PopDownTableMenu") as? PopDownTableMenuController,
                let rootTab = rootParent as? RootTabViewController else {
                    print("No pop down table menu in storyboard!")
                    return
            }
            navigationItem.rightBarButtonItem?.isEnabled = false
            popDown.course = self.course
            popDown.currentUser = rootTab.currentUser
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
        } else {
            delegate?.courseDetails(added: self.course!, to: nil)
        }
    }
    
    // MARK: - State Preservation
    
    static let courseIDRestorationKey = "CourseDetails.courseID"
    static let showsSemesterDialogRestorationKey = "CourseDetails.showsSemesterDialog"
    static let displayStandardRestorationKey = "CourseDetails.displayStandard"

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(course?.subjectID, forKey: CourseDetailsViewController.courseIDRestorationKey)
        coder.encode(showsSemesterDialog, forKey: CourseDetailsViewController.showsSemesterDialogRestorationKey)
        coder.encode(displayStandardMode, forKey: CourseDetailsViewController.displayStandardRestorationKey)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        restoredCourseID = coder.decodeObject(forKey: CourseDetailsViewController.courseIDRestorationKey) as? String
        showsSemesterDialog = coder.decodeBool(forKey: CourseDetailsViewController.showsSemesterDialogRestorationKey)
        displayStandardMode = coder.decodeBool(forKey: CourseDetailsViewController.displayStandardRestorationKey)
    }
    
    // MARK: - Pop Down Table Menu
    
    var popDownOldNavigationTitle: String?
    
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourseToFavorites course: Course) {
        if CourseManager.shared.favoriteCourses.contains(course) {
            CourseManager.shared.markCourseAsNotFavorite(course)
        } else {
            CourseManager.shared.markCourseAsFavorite(course)
        }
        popDownTableMenuCanceled(tableMenu)
    }
    
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourseToSchedule course: Course) {
        delegate?.courseDetails(addedCourseToSchedule: course)
        popDownTableMenuCanceled(tableMenu)
    }
    
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourse course: Course, to semester: UserSemester) {
        self.delegate?.courseDetails(added: course, to: semester)
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
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func generateMapping() -> ([String], [IndexPath: CourseDetailItem]) {
        var mapping: [IndexPath: CourseDetailItem] = [ IndexPath(row: 0, section: 0): .title ]
        var titles: [String] = [CourseDetailSectionTitle.none]
        var rowIndex: Int = 1, sectionIndex: Int = 0
        
        if course!.isHistorical {
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .warning
            rowIndex += 1
        }
        
        mapping[IndexPath(row: rowIndex, section: 0)] = .description
        rowIndex += 1
        mapping[IndexPath(row: rowIndex, section: 0)] = .units
        rowIndex += 1
        
        if course!.enrollmentNumber > 0 {
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .enrollment
            rowIndex += 1
        }
        if course!.communicationRequirement != nil ||
            course!.girAttribute != nil ||
            course?.hassAttribute?.count != 0 {
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .requirements
            rowIndex += 1
        }
        if course!.instructors.count > 0 {
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .instructors
            rowIndex += 1
        }
        mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .offered
        rowIndex += 1
        if !course!.isGeneric {
            if course!.rating > 0.0 {
                rowIndex = 0
                sectionIndex += 1
                titles.append(CourseDetailSectionTitle.ratings)
                mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .header
                rowIndex += 1
                mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .rate
                rowIndex += 1
                mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .evalRating
                if course!.inClassHours > 0.0 || course!.outOfClassHours > 0.0 {
                    rowIndex += 1
                    mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .evalHours
                }
            } else {
                mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .rate
                rowIndex += 1
            }
        }

        rowIndex = 0
        sectionIndex += 1

        if let prereqs = course?.prerequisites {
            titles.append(CourseDetailSectionTitle.prerequisites)
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .header
            if course!.eitherPrereqOrCoreq {
                rowIndex += 1
                mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .description
            }
            if prereqs.requirements != nil {
                rowIndex += 1
                mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .reqHeader
            }
            rowIndex += 1
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .prerequisites
            //mapping[IndexPath(row: rowIndex + 1, section: sectionIndex)] = .courseListAccessory
            rowIndex = 0
            sectionIndex += 1
        }
        if let coreqs = course!.corequisites {
            titles.append(CourseDetailSectionTitle.corequisites)
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .header
            if coreqs.requirements != nil {
                rowIndex += 1
                mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .reqHeader
            }
            rowIndex += 1
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .corequisites
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
            rowIndex = 0
            sectionIndex += 1
        }
        
        if course!.isGeneric {
            titles.append(CourseDetailSectionTitle.none)
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .button
        } else {
            titles.append(CourseDetailSectionTitle.none)
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .button
            if course?.url != nil {
                rowIndex += 1
                mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .url
            }
            rowIndex += 1
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .courseEvaluations
            rowIndex = 0
            sectionIndex += 1
            
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
            
            titles.append(CourseDetailSectionTitle.notes)
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .header
            rowIndex += 1
            mapping[IndexPath(row: rowIndex, section: sectionIndex)] = .notes
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
        case .units, .instructors, .requirements, .offered, .schedule, .enrollment, .evalRating, .evalHours:
            id = "MetadataCell"
        case .related, .equivalent, .joint, .prerequisites, .corequisites:
            id = "CourseListCell"
        case .courseListAccessory:
            id = "CourseListAccessoryCell"
        case .button:
            id = "ButtonCell"
        case .url, .courseEvaluations:
            id = "URLCell"
        case .reqHeader:
            id = "ReqHeaderCell"
        case .notes:
            id = "NotesCell"
        case .rate:
            id = "RateCell"
        case .warning:
            id = "WarningCell"
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
        let dataType = self.detailMapping[indexPath]!
        let cellType = self.cellType(for: dataType)
        if cellType == "DescriptionCell" || cellType == "MetadataCell" || cellType == "RateCell" {
            return UITableViewAutomaticDimension
        } else if cellType == "CourseListCell" {
            return 124.0
        } else if dataType == .header {
            return 40.0
        } else if dataType == .notes {
            return 180.0
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
        return self.detailMapping[indexPath] == .button || self.detailMapping[indexPath] == .url || self.detailMapping[indexPath] == .courseEvaluations
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
            var title = course?.subjectTitle ?? ""
            if let level = course?.subjectLevel, level != .undergraduate {
                title += " (\(level.rawValue))"
            }
            textLabel?.text = title
        case .warning:
            if course!.isHistorical {
                if let lastOffered = course!.sourceSemester {
                    let offeredSemester = lastOffered.components(separatedBy: "-").joined(separator: " ").capitalizingFirstLetter()
                    textLabel?.text = "This subject is no longer offered (last offered in \(offeredSemester))."
                } else {
                    textLabel?.text = "This subject is no longer offered."
                }
            }
        case .button:
            if course?.isGeneric == true {
                textLabel?.text = "Find Fulfilling Subjects"
            } else {
                textLabel?.text = "Find Classes With \(self.course!.subjectID!) as Prerequisite"
            }
        case .description:
            if self.sectionTitles[indexPath.section] == CourseDetailSectionTitle.prerequisites {
                if course!.eitherPrereqOrCoreq {
                    textLabel?.text = "Fulfill either the prerequisites or the corequisites."
                }
            } else {
                textLabel?.text = self.course!.subjectDescription
            }
        case .reqHeader:
            if self.sectionTitles[indexPath.section] == CourseDetailSectionTitle.prerequisites {
                if let title = course!.prerequisites?.thresholdDescription {
                    textLabel?.text = title.capitalizingFirstLetter() + ":"
                }
            } else if self.sectionTitles[indexPath.section] == CourseDetailSectionTitle.corequisites {
                if let title = course!.corequisites?.thresholdDescription {
                    textLabel?.text = title.capitalizingFirstLetter() + ":"
                }
            }
        case .units:
            textLabel?.text = "Units"
            var message = ""
            if self.course?.isVariableUnits == true {
                message = "arranged"
            } else {
                message = "\(self.course!.totalUnits) total\n(\(self.course!.lectureUnits)-\(self.course!.labUnits)-\(self.course!.preparationUnits))"
            }
            if self.course?.hasFinal == true {
                message += "\nHas final"
            }
            if self.course?.pdfOption == true {
                message += "\n[P/D/F]"
            }
            detailTextLabel?.text = message
        case .enrollment:
            textLabel?.text = "Enrollment"
            detailTextLabel?.text = "\(course!.enrollmentNumber) (average)"
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
                reqs.append(hass.map({ $0.rawValue }).joined(separator: ", "))
            }
            detailTextLabel?.text = reqs.joined(separator: ", ")
        case .offered:
            textLabel?.text = "Offered"
            var seasons: [String] = []
            if self.course!.isOfferedFall {
                seasons.append("Fall")
            }
            if self.course!.isOfferedIAP {
                seasons.append("IAP")
            }
            if self.course!.isOfferedSpring {
                seasons.append("Spring")
            }
            if self.course!.isOfferedSummer {
                seasons.append("Summer")
            }
            var offeredString = ""
            if self.course!.offeringPattern == .alternateYears, let notOffered = self.course?.notOfferedYear {
                offeredString = "\nNot offered \(notOffered)"
            }
            var quarterString = ""
            if self.course!.quarterOffered != .wholeSemester {
                var attachmentWord = ""
                if self.course!.quarterOffered == .beginningOnly {
                    quarterString = "\n1st quarter"
                    attachmentWord = "ends"
                } else if self.course!.quarterOffered == .endOnly {
                    quarterString = "\n2nd quarter"
                    attachmentWord = "starts"
                }
                if let date = self.course?.quarterBoundaryDate {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d"
                    quarterString += " – \(attachmentWord) \(formatter.string(from: date))"
                }
            }
            detailTextLabel?.text = seasons.joined(separator: ", ") + quarterString + offeredString
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
            } else if items.count >= 5 {
                detailTextLabel?.text = "\(items.count) sections"
            } else {
                let itemDescriptions = items.map({ (itemSet) -> String in
                    return itemSet.map({ $0.stringEquivalent(withLocation: false) }).joined(separator: ", ") + (itemSet.first?.location != nil ? " (\(itemSet.first!.location!))" : "")
                }).joined(separator: "\n")
                detailTextLabel?.text = itemDescriptions
            }
        case .related:
            (cell as! CourseListTableCell).courses = []
            for (myID, _) in self.course!.relatedSubjects {
                if let relatedCourse = CourseManager.shared.getCourse(withID: myID) {
                    (cell as! CourseListTableCell).courses.append(relatedCourse)
                }
            }
            (cell as! CourseListTableCell).delegate = self
            (cell as! CourseListTableCell).collectionView.reloadData()
        case .equivalent:
            (cell as! CourseListTableCell).courses = []
            for myID in self.course!.equivalentSubjects {
                let equivCourse = CourseManager.shared.getCourse(withID: myID)
                if equivCourse != nil {
                    (cell as! CourseListTableCell).courses.append(equivCourse!)
                }
            }
            (cell as! CourseListTableCell).delegate = self
            (cell as! CourseListTableCell).collectionView.reloadData()
        case .prerequisites:
            if let tableCell = cell as? CourseListTableCell,
                let prereqs = course?.prerequisites {
                fillCourseListCell(tableCell, with: prereqs)
            }
//            (cell as! CourseListTableCell).delegate = self
//            (cell as! CourseListTableCell).collectionView.reloadData()
        case .corequisites:
            if let tableCell = cell as? CourseListTableCell,
                let coreqs = course?.corequisites {
                fillCourseListCell(tableCell, with: coreqs)
            }
//            (cell as! CourseListTableCell).delegate = self
//            (cell as! CourseListTableCell).collectionView.reloadData()
        case .courseListAccessory:
            var list: [String] = []
            switch self.detailMapping[IndexPath(row: indexPath.row - 1, section: indexPath.section)]! {
            case .prerequisites:
                list = self.course!.prerequisites?.requiredCourses.compactMap({ $0.subjectID }) ?? []
            case .corequisites:
                list = self.course!.corequisites?.requiredCourses.compactMap({ $0.subjectID }) ?? []
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
            (cell as! CourseListTableCell).courses = []
            for myID in self.course!.jointSubjects {
                let equivCourse = CourseManager.shared.getCourse(withID: myID)
                if equivCourse != nil {
                    (cell as! CourseListTableCell).courses.append(equivCourse!)
                }
            }
            (cell as! CourseListTableCell).delegate = self
            (cell as! CourseListTableCell).collectionView.reloadData()
        case .url:
            textLabel?.text = "View on Registrar Site"
        case .courseEvaluations:
            textLabel?.text = "View Subject Evaluations"
        case .rate:
            textLabel?.text = "My Rating"
            (cell.viewWithTag(34) as? RatingView)?.course = self.course
        case .evalRating:
            textLabel?.text = "Average Rating"
            detailTextLabel?.text = String(format: "%.1f/7.0", course!.rating)
        case .evalHours:
            textLabel?.text = "Hours"
            detailTextLabel?.text = String(format: "%.1f/week", course!.inClassHours + course!.outOfClassHours)
        case .notes:
            guard let textView = cell.viewWithTag(56) as? UITextView else {
                break
            }
            textView.text = CourseManager.shared.notes(for: course!.subjectID!) ?? ""
            textView.placeholder = "Take notes here…"
            textView.delegate = self
        }
        if showsSemesterDialog {
            (cell as? CourseListTableCell)?.longPressTarget = self
            (cell as? CourseListTableCell)?.longPressAction = #selector(CourseDetailsViewController.longPressOnCourseCell(_:))
        }

        return cell
    }
    
    func courseListCell(_ cell: CourseListCell, selected course: Course) {
        guard let tableCell = cell as? CourseListTableCell,
            let indexPath = tableView.indexPath(for: tableCell),
            let detailItemType = self.detailMapping[indexPath] else {
            return
        }
        let statement: RequirementsListStatement? = detailItemType == .prerequisites ? self.course?.prerequisites : self.course?.corequisites
        
        handleCourseListCellSelection(tableCell, of: course, with: statement)
        //self.delegate?.courseDetailsRequestedDetails(about: course)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let detailItemType = self.detailMapping[indexPath] else {
            return
        }
        if detailItemType == .button {
            if course?.isGeneric == true {
                delegate?.courseDetailsRequestedDetails(about: self.course!)
            } else {
                delegate?.courseDetailsRequestedPostReqs(for: self.course!)
            }
        } else if detailItemType == .url,
            let urlString = course?.url,
            let url = URL(string: urlString) {
            delegate?.courseDetailsRequestedOpen(url: url)
        } else if detailItemType == .courseEvaluations,
            let url = URL(string: "https://edu-apps.mit.edu/ose-rpt/subjectEvaluationSearch.htm?search=Search&subjectCode=\(course!.subjectID!)") {
            delegate?.courseDetailsRequestedOpen(url: url)
        }
    }
    
    @objc func longPressOnCourseCell(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began,
            showsSemesterDialog,
            let cell = sender.view as? CourseThumbnailCell,
            let id = cell.course?.subjectID,
            CourseManager.shared.getCourse(withID: id) != nil,
            let rootTab = rootParent as? RootTabViewController else {
            return
        }
        guard let popDown = self.storyboard?.instantiateViewController(withIdentifier: "PopDownTableMenu") as? PopDownTableMenuController else {
            print("No pop down table menu in storyboard!")
            return
        }
        navigationItem.rightBarButtonItem?.isEnabled = false
        popDownOldNavigationTitle = navigationItem.title
        navigationItem.title = "(\(id))"
        popDown.course = cell.course
        popDown.currentUser = rootTab.currentUser
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
        let generator = UIImpactFeedbackGenerator()
        generator.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            popDown.show(animated: true)
            generator.impactOccurred()
        }
    }
    
    // MARK: - Requirements Cells
    
    func updateRequirementsStatus() {
        guard let rootTab = rootParent as? RootTabViewController,
            let user = rootTab.currentUser,
            let course = course else {
                return
        }
        user.evaluateRequirements(for: course)
    }
    
    var allowsProgressAssertions: Bool { return false }
    
    func courseBrowserViewController() -> CourseBrowserViewController? {
        let browser = self.storyboard!.instantiateViewController(withIdentifier: RequirementsConstants.courseListVCIdentifier) as? CourseBrowserViewController
        let bgColor: UIColor
        if displayStandardMode {
            if #available(iOS 13.0, *) {
                bgColor = .systemBackground
            } else {
                bgColor = .white
            }
        } else {
            bgColor = .clear
        }
        browser?.view.backgroundColor = bgColor
        return browser
    }
    
    func childRequirementsViewController() -> RequirementsListViewController? {
        guard let listVC = self.storyboard!.instantiateViewController(withIdentifier: RequirementsConstants.listVCIdentifier) as? RequirementsListViewController else {
            return nil
        }
        listVC.showsManualProgressControls = false
        listVC.delegate = self
        listVC.displayStandardMode = displayStandardMode
        return listVC
    }

    func selectIndexPath(for tableCell: CourseListTableCell, at courseIndex: Int) {
        // Do nothing
    }
    
    func requirementsListViewControllerUpdatedFavorites(_ vc: RequirementsListViewController) {
        
    }
    
    func requirementsListViewControllerUpdatedFulfillmentStatus(_ vc: RequirementsListViewController) {
        updateRequirementsStatus()
    }
    
    func showInformationalViewController(_ vc: UIViewController, from cell: UICollectionViewCell) {
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func pushViewController(_ viewController: UIViewController, animated: Bool) {
        navigationController?.pushViewController(viewController, animated: animated)
    }
    
    // MARK: - Text View
    
    func textViewDidChange(_ textView: UITextView) {
        textView.updatePlaceholder()
        CourseManager.shared.setNotes(textView.text, for: course!.subjectID!)
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        guard let indexPath = detailMapping.first(where: { $1 == .notes })?.key else {
            return
        }
        tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
    }
    
    @objc func keyboardChangedFrame(_ note: Notification) {
        guard let indexPath = detailMapping.first(where: { $1 == .notes })?.key else {
            return
        }
        if tableView.cellForRow(at: indexPath)?.viewWithTag(56)?.isFirstResponder == true {
            tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        }
    }
    
    @objc func keyboardWillChangeFrame(_ sender: Notification) {
        if displayStandardMode {
            let endY = self.view.convert((sender.userInfo![UIKeyboardFrameEndUserInfoKey]! as! CGRect), from: nil).origin.y

            if let bottomConstraint = tableViewBottomConstraint {
                let newConstant: CGFloat = self.view.frame.size.height - endY
                let curve: UIViewAnimationOptions = UIViewAnimationOptions(rawValue: (sender.userInfo![UIKeyboardAnimationCurveUserInfoKey] as! NSNumber).uintValue)
                self.view.setNeedsLayout()
                UIView.animate(withDuration: sender.userInfo![UIKeyboardAnimationDurationUserInfoKey] as! TimeInterval, delay: 0.0, options: [curve, .beginFromCurrentState], animations: {
                    bottomConstraint.constant = newConstant
                    self.view.layoutIfNeeded()
                }, completion: nil)
            }
        }
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

    // MARK: - Course Display Manager
    
    func addCourse(_ course: Course, to semester: UserSemester? = nil) -> UserSemester? {
        delegate?.courseDetails(added: course, to: semester)
        updateRequirementsStatus()
        return semester
    }
    
    func addCourseToSchedule(_ course: Course) {
        delegate?.courseDetails(addedCourseToSchedule: course)
    }

    func viewDetails(for course: Course, showGenericDetails: Bool) {
        delegate?.courseDetailsRequestedDetails(about: course)
    }
    
    func viewDetails(for course: Course, from cell: UICollectionViewCell, showGenericDetails: Bool) {
        delegate?.courseDetailsRequestedDetails(about: course)
    }
}
