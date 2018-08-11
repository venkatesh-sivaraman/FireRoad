//
//  ScheduleViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 11/17/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit
import EventKit
import EventKitUI

let SchedulePathExtension = ".sched"

class ScheduleViewController: UIViewController, PanelParentViewController, ScheduleGridDelegate, ScheduleConstraintDelegate, EKCalendarChooserDelegate, DocumentBrowseDelegate, CloudSyncManagerDelegate {
    var panelView: PanelViewController?
    var courseBrowser: CourseBrowserViewController?
    var showsSemesterDialogs: Bool {
        return false
    }
    
    var currentSchedule: ScheduleDocument? {
        didSet {
            validateAndUpdateSchedules()
        }
    }
    
    @IBOutlet var loadingView: UIView?
    @IBOutlet var loadingIndicator: UIActivityIndicatorView?
    @IBOutlet var loadingBackgroundView: UIView?
    
    @IBOutlet var scheduleNumberLabel: UILabel?
    @IBOutlet var shareButton: UIButton?
    @IBOutlet var shareItem: UIBarButtonItem?
    @IBOutlet var previousButton: UIButton?
    @IBOutlet var nextButton: UIButton?
    @IBOutlet var containerView: UIView!
    @IBOutlet var openButton: UIButton?
    @IBOutlet var openItem: UIBarButtonItem?
    
    var scheduleOptions: [Schedule] = []
    var courseColors: [Course: UIColor]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        justLoaded = true

        loadingBackgroundView?.layer.cornerRadius = 5.0
        
        // Do any additional setup after loading the view.
        findPanelChildViewController()
        
        updateToolbarButtons()
        updateNavigationButtons()
        updateNavigationBar(animated: false)
        loadRecentSchedule()
        
        courseBrowser?.showsGenericCourses = false
        
        let menu = UIMenuController.shared
        menu.menuItems = (menu.menuItems ?? []) + [
            UIMenuItem(title: MenuItemStrings.constrain, action: #selector(CourseThumbnailCell.constrain(_:)))
        ]
        
        NotificationCenter.default.addObserver(self, selector: #selector(ScheduleViewController.courseManagerFinishedLoading(_:)), name: .CourseManagerFinishedLoading, object: nil)
        
        CloudSyncManager.scheduleManager.delegate = self
    }
    
    func updateToolbarButtons() {
        shareButton?.setImage(shareButton?.image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .normal)
        openButton?.setImage(openButton?.image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .normal)
        nextButton?.setImage(nextButton?.image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .normal)
        previousButton?.setImage(previousButton?.image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .normal)
    }
    
    var justLoaded = false
    var addingNewScheduleDocument = false

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updatePanelViewCollapseHeight()
        if justLoaded, let schedule = currentSchedule, scheduleOptions.count > 0 {
            schedule.displayedScheduleIndex = schedule.displayedScheduleIndex < self.scheduleOptions.count ? max(schedule.displayedScheduleIndex, 0) : 0
            schedule.selectedSchedule = self.scheduleOptions[schedule.displayedScheduleIndex]
            updateScheduleGrid()
        }
        justLoaded = false
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        updateNavigationBar(newTraits: newCollection)
    }
    
    func updateNavigationBar(animated: Bool = true, newTraits: UITraitCollection? = nil) {
        let traits = newTraits ?? traitCollection
        navigationItem.title = "Schedule"
        let newHiddenValue = traits.horizontalSizeClass != .regular || traits.verticalSizeClass != .regular || traits.userInterfaceIdiom != .pad
        if newHiddenValue != navigationController?.isNavigationBarHidden {
            navigationController?.setNavigationBarHidden(newHiddenValue, animated: animated)
        }
    }
    
    @objc func courseManagerFinishedLoading(_ note: Notification) {
        updateDisplayedSchedules()
    }
    
    // MARK: - State Restoration
    
    static let panelVCRestorationKey = "ScheduleVC.panelVC"

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(panelView, forKey: ScheduleViewController.panelVCRestorationKey)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
    }
    
    // MARK: - Schedule Files
        
    let recentSchedulePathDefaultsKey = "recent-schedule-filepath"
    
    var schedulesDirectory: String? {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
    }
    
    func urlForSchedule(named name: String) -> URL? {
        return CloudSyncManager.scheduleManager.urlForUserFile(named: name)
    }
    
    func loadSchedule(named name: String) {
        guard let url = urlForSchedule(named: name) else {
            return
        }
        do {
            if CourseManager.shared.isLoaded {
                currentSchedule = try ScheduleDocument(contentsOfFile: url.path)
            }
            UserDefaults.standard.set(url.lastPathComponent, forKey: recentSchedulePathDefaultsKey)
        } catch {
            print("Error loading user: \(error)")
        }
    }
    
    func loadNewSchedule(named name: String, courses: [Course] = [], nonDuplicate: Bool = true, addToEmptyIfPossible: Bool = false) {
        if !CourseManager.shared.isLoaded {
            DispatchQueue.global().async {
                self.addingNewScheduleDocument = true
                while !CourseManager.shared.isLoaded {
                    usleep(100)
                }
                DispatchQueue.main.async {
                    let newCourses = courses.compactMap { CourseManager.shared.getCourse(withID: $0.subjectID!) }
                    self.loadNewSchedule(named: name, courses: newCourses, nonDuplicate: nonDuplicate, addToEmptyIfPossible: addToEmptyIfPossible)
                    self.addingNewScheduleDocument = false
                }
            }
            return
        }

        if addToEmptyIfPossible, let schedule = currentSchedule,
            schedule.courses.count == 0 {
            for course in courses {
                schedule.add(course: course)
            }
            updateDisplayedSchedules()
            return
        }
        
        var finalName = name
        if nonDuplicate,
            let putativeURL = urlForSchedule(named: finalName),
            FileManager.default.fileExists(atPath: putativeURL.path) {
            let base = (name as NSString).deletingPathExtension
            var newID = base + " 2"
            if let newURL = urlForSchedule(named: newID + SchedulePathExtension),
                FileManager.default.fileExists(atPath: newURL.path) {
                var counter = 3
                while let otherURL = urlForSchedule(named: base + " \(counter)" + SchedulePathExtension),
                    FileManager.default.fileExists(atPath: otherURL.path) {
                        counter += 1
                }
                newID = base + " \(counter)"
            }
            finalName = newID + SchedulePathExtension
        }
        
        currentSchedule = ScheduleDocument(courses: courses)
        if let url = self.urlForSchedule(named: finalName) {
            currentSchedule?.filePath = url.path
        }
        currentSchedule?.autosave()
        if let path = currentSchedule?.filePath {
            UserDefaults.standard.set((path as NSString).lastPathComponent, forKey: self.recentSchedulePathDefaultsKey)
        }
    }
    
    func loadRecentSchedule() {
        guard currentSchedule == nil else {
            return
        }
        if !CourseManager.shared.isLoaded {
            self.containerView.alpha = 0.0
            self.loadingView?.alpha = 1.0
            self.loadingView?.isHidden = false
            self.loadingIndicator?.startAnimating()
            
            DispatchQueue.global().async {
                while !CourseManager.shared.isLoaded {
                    usleep(100)
                    if self.addingNewScheduleDocument {
                        return
                    }
                }
                if !self.addingNewScheduleDocument {
                    var loaded = false
                    if let recentPath = UserDefaults.standard.string(forKey: self.recentSchedulePathDefaultsKey),
                        let url = self.urlForSchedule(named: recentPath) {
                        do {
                            try DispatchQueue.main.sync {
                                self.currentSchedule = try ScheduleDocument(contentsOfFile: url.path)
                            }
                            loaded = true
                        } catch {
                            print("Error loading user: \(error)")
                        }
                    }
                    if !loaded {
                        DispatchQueue.main.async {
                            self.loadNewSchedule(named: "First Steps\(SchedulePathExtension)")
                        }
                    }
                }
            }
        } else if !addingNewScheduleDocument {
            var loaded = false
            if let recentPath = UserDefaults.standard.string(forKey: recentSchedulePathDefaultsKey),
                let url = urlForSchedule(named: recentPath) {
                do {
                    currentSchedule = try ScheduleDocument(contentsOfFile: url.path)
                    loaded = true
                } catch {
                    print("Error loading user: \(error)")
                }
            }
            if !loaded {
                self.loadNewSchedule(named: "First Steps\(SchedulePathExtension)")
            }
        }
    }
    
    // MARK: - Schedule Generation
    
    func updateDisplayedSchedules(completion: (() -> Void)? = nil) {
        guard let schedule = currentSchedule else {
            return
        }
        loadScheduleOptions {
            // If the schedule document specifies a selected schedule, select it
            if let preload = schedule.preloadSections,
                let index = self.scheduleOptions.index(where: { (sched) -> Bool in
                    for (course, selectedSections) in preload {
                        for (section, index) in selectedSections {
                            if !sched.scheduleItems.contains(where: { $0.course == course && $0.sectionType == section && $0.scheduleItems == course.schedule?[section]?[index] }) {
                                return false
                            }
                        }
                    }
                    return true
                }) {
                schedule.displayedScheduleIndex = index
                schedule.selectedSchedule = self.scheduleOptions.count > 0 ? self.scheduleOptions[index] : nil
                schedule.preloadSections = nil
            } else {
                schedule.displayedScheduleIndex = schedule.displayedScheduleIndex < self.scheduleOptions.count ? max(schedule.displayedScheduleIndex, 0) : 0
                schedule.selectedSchedule = self.scheduleOptions.count > 0 ? self.scheduleOptions[schedule.displayedScheduleIndex] : nil
            }
            self.updateScheduleGrid()
            completion?()
        }
    }
    
    var loadingScheduleOptions = false
    
    func loadScheduleOptions(completion: @escaping () -> Void) {
        guard !loadingScheduleOptions else {
            return
        }
        let peripheralLoad = scheduleOptions.count > 0
        loadingScheduleOptions = true
        DispatchQueue.main.async {
            if !peripheralLoad {
                self.containerView.alpha = 0.0
            }
            self.loadingView?.alpha = 1.0
            self.loadingView?.isHidden = false
            self.loadingIndicator?.startAnimating()
        }
        DispatchQueue.global(qos: .background).async {
            guard let schedule = self.currentSchedule else {
                return
            }
            
            while !CourseManager.shared.isLoaded {
                usleep(100)
            }
            for course in schedule.courses {
                CourseManager.shared.loadCourseDetailsSynchronously(about: course)
            }
            schedule.removeCourses(where: { $0.schedule == nil || $0.schedule?.count == 0 })
            
            // Update course colors
            var departmentCounts: [String: Int] = [:]
            self.courseColors = [:]
            for course in schedule.courses {
                guard let dept = course.subjectCode else {
                    continue
                }
                if departmentCounts[dept] == nil {
                    departmentCounts[dept] = 0
                }
                self.courseColors?[course] = CourseManager.shared.color(forCourse: course, variantNumber: departmentCounts[dept] ?? 0)
                departmentCounts[dept]? += 1
            }
            
            if schedule.courses.count > 0 {
                self.scheduleOptions = self.generateSchedules(from: schedule.courses)
            } else {
                self.scheduleOptions = []
            }

            self.loadingScheduleOptions = false
            DispatchQueue.main.async {
                completion()
                if !peripheralLoad {
                    if let loadingView = self.loadingView {
                        self.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                        self.containerView.alpha = 0.0
                        UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                            self.containerView.alpha = 1.0
                            self.containerView.transform = CGAffineTransform.identity
                            loadingView.alpha = 0.0
                            loadingView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                        }, completion: { (completed) in
                            loadingView.isHidden = true
                            self.loadingIndicator?.stopAnimating()
                        })
                    }
                } else {
                    self.loadingView?.isHidden = true
                    self.loadingIndicator?.stopAnimating()
                }
            }
        }
    }
    
    private func generateSchedules(from courses: [Course]) -> [Schedule] {
        // Generate a list of ScheduleItem objects representing the possible schedule assignments for each section of each course.
        var scheduleConfigurations: [[ScheduleUnit]] = []
        var scheduleConfigurationsList: [ScheduleUnit] = []
        for course in courses {
            guard let schedule = course.schedule else {
                continue
            }
            for (section, sectionOptions) in schedule {
                var filteredOptions = sectionOptions
                if let constraint = currentSchedule?.allowedSections?[course]?[section] {
                    filteredOptions = constraint.map({ filteredOptions[$0] })
                }
                // Filter out sections with the same exact days and times
                var uniqueTimeOptions: [String: [CourseScheduleItem]] = [:]
                for option in filteredOptions {
                    let key = option.map({ $0.stringEquivalent(withLocation: false) }).joined(separator: ",")
                    if uniqueTimeOptions[key] == nil {
                        uniqueTimeOptions[key] = option
                    }
                }
                let allOptions = uniqueTimeOptions.map({ ScheduleUnit(course: course, sectionType: section, scheduleItems: $0.value) })
                guard allOptions.count > 0 else {
                    print("No options for \(course.subjectID!) \(section)")
                    continue
                }
                if section == CourseScheduleType.lecture {
                    scheduleConfigurations.insert(allOptions, at: 0)
                } else {
                    scheduleConfigurations.append(allOptions)
                }
                scheduleConfigurationsList += allOptions
            }
        }
        scheduleConfigurations.sort(by: { $0.count < $1.count })
        
        var conflictGroups: [[[ScheduleUnit]]] = CourseScheduleDay.ordering.map { _ in ScheduleSlotManager.slots.map({ _ in [] }) }
        var configurationConflictMapping: [ScheduleUnit: [Set<Int>]] = [:]
        for unit in scheduleConfigurationsList {
            var slotsOccupied = CourseScheduleDay.ordering.map { _ in Set<Int>() }
            for item in unit.scheduleItems {
                let startSlot = ScheduleSlotManager.slotIndex(for: item.startTime)
                let endSlot = ScheduleSlotManager.slotIndex(for: item.endTime)
                for slot in startSlot..<endSlot {
                    guard slot >= 0 && slot < ScheduleSlotManager.slots.count else {
                        continue
                    }
                    for (i, day) in CourseScheduleDay.ordering.enumerated() where item.days.contains(day) {
                        conflictGroups[i][slot].append(unit)
                        slotsOccupied[i].insert(slot)
                    }
                }
            }
            configurationConflictMapping[unit] = slotsOccupied
        }
        
        let results = recursivelyGenerateScheduleConfigurations(with: scheduleConfigurations, conflictGroups: conflictGroups, conflictMapping: configurationConflictMapping)
        let sorted = results.sorted(by: { $0.conflictCount < $1.conflictCount })
        if let minConflicts = sorted.first?.conflictCount {
            return sorted.filter({ $0.conflictCount <= (minConflicts == 0 ? 0 : minConflicts + 1) })
        }
        return sorted
    }
    
    /**
     - Parameters:
        * configurations: List of lists of schedule units. One schedule unit needs to
            be chosen from each inner list.
        * conflictGroups: The schedule units occupied by each slot on each day.
        * conflictMapping: The numbers of the slots occupied by each schedule unit.
        * prefixSchedule: The list of schedule units generated so far.
        * conflictCount: The current number of conflicts in the schedule.
        * conflictingSlots: The slots which, if occupied by the next added configuration,
            will create an additional conflict.
     
     - Returns: A list of schedules generated.
     */
    private func recursivelyGenerateScheduleConfigurations(with configurations: [[ScheduleUnit]], conflictGroups: [[[ScheduleUnit]]], conflictMapping: [ScheduleUnit: [Set<Int>]], prefixSchedule: [ScheduleUnit] = [], conflictCount: Int = 0, conflictingSlots: [Set<Int>]? = nil) -> [Schedule] {
        if prefixSchedule.count == configurations.count {
            return [Schedule(items: prefixSchedule, conflictCount: conflictCount)]
        }
        let conflictingSlotSets = conflictingSlots ?? CourseScheduleDay.ordering.map { _ in Set<Int>() }
        // Vary the next configuration in the list
        let changingConfigurationSet = configurations[prefixSchedule.count]
        var results: [Schedule] = []
        let sets: [(conflicts: Int, newConflicts: Int, union: [Set<Int>])] = changingConfigurationSet.map {
            guard let slots = conflictMapping[$0] else {
                return (Int.max, Int.max, [])
            }
            var allConflicts = 0
            var newConflictCount = 0
            var union: [Set<Int>] = []
            for (i, slot) in slots.enumerated() {
                allConflicts += slot.reduce(0, { $0 + conflictGroups[i][$1].count })
                newConflictCount += slot.intersection(conflictingSlotSets[i]).count
                union.append(slot.union(conflictingSlotSets[i]))
            }
            return (allConflicts, newConflictCount, union)
        }
        let minConflicts = sets.min(by: { $0.conflicts < $1.conflicts })?.conflicts ?? 0
        for (i, configuration) in changingConfigurationSet.enumerated() where sets[i].conflicts == minConflicts || sets[i].newConflicts == 0 {
            let (_, newConflictCount, union) = sets[i]
            results += recursivelyGenerateScheduleConfigurations(with: configurations, conflictGroups: conflictGroups, conflictMapping: conflictMapping, prefixSchedule: prefixSchedule + [configuration], conflictCount: conflictCount + newConflictCount, conflictingSlots: union)
        }
        if results.count == 0 {
            // Iterate again with the conflicting schedule items
            for (i, configuration) in changingConfigurationSet.enumerated() {
                let (_, newConflictCount, union) = sets[i]
                results += recursivelyGenerateScheduleConfigurations(with: configurations, conflictGroups: conflictGroups, conflictMapping: conflictMapping, prefixSchedule: prefixSchedule + [configuration], conflictCount: conflictCount + newConflictCount, conflictingSlots: union)
            }
        }
        return results
    }
    
    // MARK: - Displaying Schedule Grids
    
    var currentScheduleVC: UIViewController?
    
    func scheduleGrid(for page: Int) -> ScheduleGridViewController? {
        guard let vc = self.storyboard?.instantiateViewController(withIdentifier: "ScheduleGrid") as? ScheduleGridViewController,
            page >= 0,
            page < scheduleOptions.count else {
            return nil
        }
        vc.delegate = self
        vc.pageNumber = page
        vc.schedule = scheduleOptions[page]
        vc.courseColors = courseColors
        vc.topPadding = (panelView?.collapseHeight ?? 0.0) + (panelView?.view.convert(.zero, to: self.view).y ?? 0.0) + 12.0
        return vc
    }
    
    func updateNavigationButtons() {
        previousButton?.isEnabled = (currentSchedule?.displayedScheduleIndex ?? 0) > 0
        nextButton?.isEnabled = (currentSchedule?.displayedScheduleIndex ?? 0) < scheduleOptions.count - 1
    }
    
    func updateScheduleGrid() {
        guard let schedule = currentSchedule else {
            return
        }
        if let vc = currentScheduleVC as? ScheduleGridViewController,
            scheduleOptions.count > 0,
            schedule.displayedScheduleIndex >= 0,
            schedule.displayedScheduleIndex < scheduleOptions.count {
            vc.courseColors = courseColors
            vc.topPadding = (panelView?.collapseHeight ?? 0.0) + (panelView?.view.convert(.zero, to: self.view).y ?? 0.0) + 12.0
            self.scheduleNumberLabel?.text = "\(schedule.displayedScheduleIndex + 1) of \(scheduleOptions.count)"
            
            let scheduleToDisplay = scheduleOptions[schedule.displayedScheduleIndex]
            schedule.selectedSchedule = scheduleToDisplay
            vc.setSchedule(scheduleToDisplay, animated: isViewLoaded && view.window != nil)
        } else {
            if let vc = currentScheduleVC {
                vc.willMove(toParentViewController: nil)
                vc.view.removeFromSuperview()
                vc.removeFromParentViewController()
                vc.didMove(toParentViewController: nil)
                currentScheduleVC = nil
            }
            if let vcToDisplay = scheduleGrid(for: schedule.displayedScheduleIndex) {
                currentScheduleVC = vcToDisplay
                self.scheduleNumberLabel?.text = "\(schedule.displayedScheduleIndex + 1) of \(scheduleOptions.count)"
            } else if let noSchedulesView = self.storyboard?.instantiateViewController(withIdentifier: "NoSchedulesView") {
                currentScheduleVC = noSchedulesView
                currentSchedule?.selectedSchedule = nil
                self.scheduleNumberLabel?.text = "--"
            }
            if let vc = currentScheduleVC {
                vc.willMove(toParentViewController: self)
                vc.view.translatesAutoresizingMaskIntoConstraints = false
                containerView.addSubview(vc.view)
                vc.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
                vc.view.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
                vc.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
                vc.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
                addChildViewController(vc)
                vc.didMove(toParentViewController: self)
            }
        }
        updateNavigationButtons()
    }
    
    @IBAction func previousButtonTapped(_ sender: AnyObject) {
        currentSchedule?.displayedScheduleIndex -= 1
        updateScheduleGrid()
    }
    
    @IBAction func nextButtonTapped(_ sender: AnyObject) {
        currentSchedule?.displayedScheduleIndex += 1
        updateScheduleGrid()
    }
    
    // MARK: - Grid Delegate
    
    func validateAndUpdateSchedules() {
        guard let schedule = currentSchedule else {
            return
        }
        print(schedule.courses)
        let beforeUpdate = schedule.courses
        updateDisplayedSchedules(completion: {
            var noSchedCourses: [Course] = []
            for course in beforeUpdate {
                if course.schedule == nil || course.schedule!.count == 0 {
                    noSchedCourses.append(course)
                }
            }
            var alert: UIAlertController?
            if noSchedCourses.count == 1 {
                alert = UIAlertController(title: "No Schedule Information", message: "No schedule available for \(noSchedCourses.first!.subjectID!) at this time.", preferredStyle: .alert)
            } else if noSchedCourses.count > 1 {
                alert = UIAlertController(title: "No Schedule for \(noSchedCourses.count) Courses", message: "No schedule available at this time for the following subjects: \(noSchedCourses.compactMap({ $0.subjectID }).joined(separator: ", ")).", preferredStyle: .alert)
            }
            if let alertController = alert {
                alertController.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
        })
    }
    
    func addCourse(_ course: Course, to semester: UserSemester? = nil) -> UserSemester? {
        if currentSchedule == nil {
            loadRecentSchedule()
        }
        guard let schedule = currentSchedule,
            !course.isGeneric,
            schedule.add(course: course) else {
            return nil
        }
        
        schedule.displayedScheduleIndex = 0
        schedule.selectedSchedule = nil
        validateAndUpdateSchedules()
        
        self.panelView?.collapseView(to: self.panelView!.collapseHeight)
        return nil
    }

    func deleteCourseFromSchedules(_ course: Course) {
        currentSchedule?.remove(course: course)
        currentSchedule?.displayedScheduleIndex = 0
        currentSchedule?.selectedSchedule = nil
        updateDisplayedSchedules()
    }
    
    func scheduleGrid(_ gridVC: ScheduleGridViewController, wantsConstraintMenuFor course: Course, sender: UIView?) {
        guard let constraint = storyboard?.instantiateViewController(withIdentifier: "ScheduleConstraintVC") as? ScheduleConstraintViewController else {
            return
        }
        constraint.delegate = self
        constraint.course = course
        constraint.allowedSections = currentSchedule?.allowedSections?[course]
        let nav = UINavigationController(rootViewController: constraint)
        if let view = sender {
            nav.modalPresentationStyle = .popover
            nav.popoverPresentationController?.sourceView = view
            nav.popoverPresentationController?.sourceRect = view.bounds
        }
        present(nav, animated: true, completion: nil)
    }
    
    // MARK: - Constraints
    
    func scheduleConstraintViewControllerDismissed(_ vc: ScheduleConstraintViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    func scheduleConstraintViewController(_ vc: ScheduleConstraintViewController, updatedAllowedSections newAllowedSections: [String : [Int]]?) {
        guard let course = vc.course else {
            return
        }
        if currentSchedule?.allowedSections == nil {
            currentSchedule?.allowedSections = [:]
        }
        currentSchedule?.allowedSections?[course] = newAllowedSections
        currentSchedule?.displayedScheduleIndex = 0
        currentSchedule?.selectedSchedule = nil
        updateDisplayedSchedules()
    }
    
    // MARK: - Share
    
    @IBAction func shareButtonTapped(_ sender: AnyObject) {
        guard let displayedScheduleIndex = currentSchedule?.displayedScheduleIndex,
            displayedScheduleIndex >= 0, displayedScheduleIndex < scheduleOptions.count else {
            return
        }
        let scheduleString = scheduleOptions[displayedScheduleIndex].userStringRepresentation()
        let customItem = CustomActivity(title: "Add to Calendar", image: UIImage(named: "schedule")) {
            self.addCurrentScheduleToCalendar()
        }
        var activityItems: [Any] = [scheduleString]
        if let scrollView = (currentScheduleVC as? ScheduleGridViewController)?.scrollView {
            let provider = ScheduleItemProvider(placeholderItem: UIImage(), renderingBlock: { () -> Any in
                return scrollView.renderToImage()
            })
            activityItems.append(provider)
            let printProvider = ScheduleItemProvider(placeholderItem: UIImageView().viewPrintFormatter(), renderingBlock: { () -> Any in
                return ScheduleViewController.activityForPrinting(image: scrollView.renderToImage())
            })
            activityItems.append(printProvider)
        }
        let actionVC = UIActivityViewController(activityItems: activityItems, applicationActivities: [customItem])
        if traitCollection.userInterfaceIdiom == .pad,
            let barItem = sender as? UIBarButtonItem {
            actionVC.modalPresentationStyle = .popover
            actionVC.popoverPresentationController?.barButtonItem = barItem
        }
        present(actionVC, animated: true, completion: nil)
    }
    
    class func activityForPrinting(image: UIImage) -> Any {
        let maxWidth = CGFloat(540.0)
        let maxHeight = CGFloat(720.0)
        let scale = max(image.size.width / maxWidth, image.size.height / maxHeight, 1.0)
        
        let imageView = UIImageView(image: image)
        imageView.frame = CGRect(x: 0.0, y: 0.0, width: image.size.width / scale, height: image.size.height / scale)
        
        let printFormatter = imageView.viewPrintFormatter()
        //printFormatter.perPageContentInsets = UIEdgeInsets(top: 72.0, left: 72.0, bottom: 72.0, right: 72.0)
        return printFormatter
    }
    
    var eventStore: EKEventStore?
    
    func addCurrentScheduleToCalendar() {
        eventStore = EKEventStore()
        guard let store = eventStore else {
            return
        }
        store.requestAccess(to: .event) { (success, error) in
            if success {
                let options = UIAlertController(title: "Calendar Options", message: nil, preferredStyle: .alert)
                options.addAction(UIAlertAction(title: "Save to An Existing Calendar", style: .default, handler: { _ in
                    let calendarChooser = EKCalendarChooser(selectionStyle: .single, displayStyle: .writableCalendarsOnly, eventStore: store)
                    calendarChooser.showsCancelButton = true
                    calendarChooser.showsDoneButton = true
                    calendarChooser.delegate = self
                    let nav = UINavigationController(rootViewController: calendarChooser)
                    calendarChooser.navigationItem.prompt = "Choose a destination calendar for your schedule."
                    nav.modalPresentationStyle = .formSheet
                    self.present(nav, animated: true, completion: nil)
                }))
                options.addAction(UIAlertAction(title: "Save to Separate Calendars", style: .default, handler: { _ in
                    self.addScheduleToCalendar(separate: true)
                }))
                options.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                self.present(options, animated: true, completion: nil)
            } else {
                let alert = UIAlertController(title: "Could Not Save to Calendar", message: "To give FireRoad calendar access, please go to Settings > Privacy.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    func calendarChooserDidCancel(_ calendarChooser: EKCalendarChooser) {
        dismiss(animated: true, completion: nil)
        eventStore = nil
    }
    
    private func getStartDate(for scheduleItem: CourseScheduleItem, semester: CourseManager.Semester) -> Date? {
        var components = DateComponents()
        if semester.season == CourseManager.SemesterSeason.spring {
            components.month = 2
            components.weekday = 3
            components.weekdayOrdinal = 1
        } else {
            components.month = 9
            components.weekday = 4
            components.weekdayOrdinal = 1
        }
        components.year = semester.year
        guard let beginningOfSemester = Calendar.current.nextDate(after: Date.distantPast, matching: components, matchingPolicy: .nextTime, repeatedTimePolicy: .last, direction: .forward) else {
            return nil
        }
        
        let compCandidates = CourseScheduleDay.ordering.compactMap { day -> DateComponents? in
            guard scheduleItem.days.contains(day) else {
                return nil
            }
            var comps = DateComponents()
            comps.weekday = CourseScheduleDay.gregorianOrdering[day]
            comps.hour = scheduleItem.startTime.hour24
            comps.minute = scheduleItem.startTime.minute
            return comps
        }
        let candidates = compCandidates.compactMap {
            Calendar.current.nextDate(after: beginningOfSemester, matching: $0, matchingPolicy: .nextTime)
        }
        return candidates.min()
    }
    
    private func getRepeatEndDate(for scheduleItem: CourseScheduleItem, semester: CourseManager.Semester) -> Date? {
        var components = DateComponents()
        if semester.season == CourseManager.SemesterSeason.spring {
            components.month = 5
            components.weekday = 5
            components.weekdayOrdinal = 3
        } else {
            components.month = 9
            components.weekday = 4
            components.weekdayOrdinal = 2
        }
        components.year = semester.year
        return Calendar.current.nextDate(after: Date.distantPast, matching: components, matchingPolicy: .nextTime, repeatedTimePolicy: .last, direction: .forward)
    }
    
    private func eventKitDays(for days: CourseScheduleDay) -> [EKRecurrenceDayOfWeek] {
        var ret: [EKRecurrenceDayOfWeek] = []
        let mapping: [(CourseScheduleDay, EKWeekday)] = [
            (.monday, .monday),
            (.tuesday, .tuesday),
            (.wednesday, .wednesday),
            (.thursday, .thursday),
            (.friday, .friday),
            (.saturday, .saturday),
            (.sunday, .sunday)
        ]
        for (day, ekDay) in mapping {
            if days.contains(day) {
                ret.append(EKRecurrenceDayOfWeek(ekDay))
            }
        }
        
        return ret
    }

    func calendarChooserDidFinish(_ calendarChooser: EKCalendarChooser) {
        dismiss(animated: true, completion: nil)
        guard let calendar = calendarChooser.selectedCalendars.first else {
            return
        }
        addScheduleToCalendar(separate: false, calendar: calendar)
    }
    
    func addScheduleToCalendar(separate: Bool, calendar: EKCalendar? = nil) {
        guard let displayedScheduleIndex = currentSchedule?.displayedScheduleIndex,
            displayedScheduleIndex >= 0, displayedScheduleIndex < scheduleOptions.count,
            let semester = CourseManager.shared.catalogSemester,
            let store = eventStore else {
                return
        }
        do {
            let items = scheduleOptions[displayedScheduleIndex].scheduleItems
            var courseCalendars: [Course: EKCalendar] = [:]
            let existingCalendars = store.calendars(for: .event)
            for item in items {
                if separate {
                    if courseCalendars[item.course] == nil {
                        courseCalendars[item.course] = existingCalendars.first(where: { $0.title == (item.course.subjectID ?? "FireRoad") })
                    }
                    if courseCalendars[item.course] == nil {
                        let newCal = EKCalendar(for: .event, eventStore: store)
                        newCal.title = item.course.subjectID ?? "FireRoad"
                        newCal.source = store.defaultCalendarForNewEvents?.source
                        try store.saveCalendar(newCal, commit: true)
                        courseCalendars[item.course] = newCal
                    }
                }
                for scheduleTime in item.scheduleItems {
                    guard let start = getStartDate(for: scheduleTime, semester: semester),
                        let end = getRepeatEndDate(for: scheduleTime, semester: semester) else {
                            continue
                    }
                    let event = EKEvent(eventStore: store)
                    event.title = [item.course.subjectID ?? "", item.sectionType].joined(separator: " ")
                    event.location = scheduleTime.location
                    if !separate, let calendar = calendar {
                        event.calendar = calendar
                    } else if let cal = courseCalendars[item.course] {
                        event.calendar = cal
                    }
                    event.startDate = start
                    let (hours, minutes) = scheduleTime.startTime.delta(to: scheduleTime.endTime)
                    event.endDate = event.startDate.addingTimeInterval(Double(hours) * 3600.0 + Double(minutes) * 60.0)
                    event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, daysOfTheWeek: eventKitDays(for: scheduleTime.days), daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: EKRecurrenceEnd(end: end)))
                    try store.save(event, span: EKSpan.futureEvents, commit: false)
                }
            }
            try store.commit()
            let alert = UIAlertController(title: "Saved to Calendar", message: "The schedule has been saved to your calendar!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        } catch {
            print("Couldn't save to calendar: \(error)")
            let alert = UIAlertController(title: "Could Not Save to Calendar", message: "An error occurred - please try again later.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: - Loading Different Roads
    
    lazy var thumbnailImageComputeQueue = ComputeQueue(label: "ScheduleVC.thumbnailImage")
    
    @IBAction func openButtonPressed(_ sender: AnyObject) {
        guard CourseManager.shared.isLoaded,
            let browser = storyboard?.instantiateViewController(withIdentifier: "DocumentBrowser") as? DocumentBrowseViewController,
            let roadDir = CloudSyncManager.roadManager.filesDirectory,
            let dirContents = try? FileManager.default.contentsOfDirectory(atPath: roadDir) else {
                return
        }
        browser.delegate = self
        // Generate items
        var items: [(DocumentBrowseViewController.Item, Date?)] = []
        let todayFormatter = DateFormatter()
        todayFormatter.dateStyle = .none
        todayFormatter.timeStyle = .short
        let otherFormatter = DateFormatter()
        otherFormatter.dateStyle = .medium
        otherFormatter.timeStyle = .none
        for path in dirContents {
            let fullPath = (roadDir as NSString).appendingPathComponent(path)
            guard path.range(of: SchedulePathExtension)?.upperBound == path.endIndex,
                path[path.startIndex] != Character("."),
                let tempSchedule = try? ScheduleDocument(contentsOfFile: fullPath, readOnly: true) else {
                    continue
            }
            let attr = try? FileManager.default.attributesOfItem(atPath: fullPath)
            let modDate = attr?[FileAttributeKey.modificationDate] as? Date
            var components: [String] = []
            if let date = modDate {
                if Calendar.current.isDateInToday(date) {
                    components.append(todayFormatter.string(from: date))
                } else {
                    components.append(otherFormatter.string(from: date))
                }
            }
            var pluralizer = tempSchedule.courses.count != 1 ? "s" : ""
            components.append("\(tempSchedule.courses.count) course\(pluralizer)")
            let totalUnits = tempSchedule.courses.reduce(0, { $0 + $1.totalUnits })
            pluralizer = totalUnits != 1 ? "s" : ""
            components.append("\(totalUnits) unit\(pluralizer)")
            var item = DocumentBrowseViewController.Item(identifier: path, title: (path as NSString).deletingPathExtension, description: components.joined(separator: " • "), image: tempSchedule.emptyThumbnailImage())
            thumbnailImageComputeQueue.async {
                item.image = tempSchedule.generateThumbnailImage()
                DispatchQueue.main.async {
                    browser.update(item: item)
                }
            }
            items.append((item, modDate))
        }
        browser.items = items.sorted(by: {
            if $1.1 == nil && $0.1 == nil {
                return false
            } else if $1.1 == nil {
                return true
            } else if $0.1 == nil {
                return false
            }
            return $0.1!.compare($1.1!) == .orderedDescending
        }).map({ $0.0 })
        if browser.items.count > 1 {
            browser.itemToHighlight = browser.items.first(where: { $0.identifier == (currentSchedule?.filePath as NSString?)?.lastPathComponent })
        }
        
        let nav = UINavigationController(rootViewController: browser)
        browser.navigationItem.title = "My Schedules"
        if let barItem = sender as? UIBarButtonItem {
            browser.showsCancelButton = false
            nav.modalPresentationStyle = .popover
            nav.popoverPresentationController?.barButtonItem = barItem
            present(nav, animated: true, completion: nil)
        } else {
            browser.navigationItem.prompt = "Select an existing schedule or add a new one."
            browser.showsCancelButton = true
            present(nav, animated: true, completion: nil)
        }
    }
    
    func documentBrowserDismissed(_ browser: DocumentBrowseViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    func documentBrowserAddedItem(_ browser: DocumentBrowseViewController) {
        let alert = UIAlertController(title: "New Schedule", message: "Choose a title for your new schedule:", preferredStyle: .alert)
        let presenter = self.presentedViewController ?? self
        alert.addTextField { (tf) in
            tf.placeholder = "Title"
            tf.enablesReturnKeyAutomatically = true
            tf.clearButtonMode = .always
            tf.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { _ in
            guard let text = alert.textFields?.first?.text,
                text.count > 0 else {
                    let errorAlert = UIAlertController(title: "No Title", message: "You must choose a title in order to create the new schedule.", preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                    presenter.present(errorAlert, animated: true, completion: nil)
                    return
            }
            
            let newID = text + SchedulePathExtension
            guard let newURL = self.urlForSchedule(named: newID),
                !FileManager.default.fileExists(atPath: newURL.path) else {
                    let errorAlert = UIAlertController(title: "Schedule Already Exists", message: "Please choose another title.", preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                    presenter.present(errorAlert, animated: true, completion: nil)
                    return
            }
            
            self.dismiss(animated: true, completion: nil)
            self.loadNewSchedule(named: newID)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        presenter.present(alert, animated: true, completion: nil)
    }
    
    func documentBrowser(_ browser: DocumentBrowseViewController, deletedItem item: DocumentBrowseViewController.Item) {
        guard let url = urlForSchedule(named: item.identifier) else {
            return
        }
        CloudSyncManager.scheduleManager.deleteFile(with: (item.identifier as NSString).deletingPathExtension) { _ in
            if self.currentSchedule?.filePath == url.path {
                if let firstItem = browser.items.first {
                    self.loadSchedule(named: firstItem.identifier)
                } else if browser.navigationController?.modalPresentationStyle == .popover {
                    self.loadNewSchedule(named: "Schedule" + SchedulePathExtension)
                    self.dismiss(animated: true, completion: nil)
                } else {
                    self.currentSchedule = nil
                    self.scheduleOptions = []
                    self.updateScheduleGrid()
                }
            }
        }
    }
    
    func documentBrowser(_ browser: DocumentBrowseViewController, wantsRename item: DocumentBrowseViewController.Item, completion: @escaping ((DocumentBrowseViewController.Item?) -> Void)) {
        let alert = UIAlertController(title: "Rename Schedule", message: "Choose a new title:", preferredStyle: .alert)
        let presenter = self.presentedViewController ?? self
        alert.addTextField { (tf) in
            tf.placeholder = "Title"
            tf.text = item.title
            tf.enablesReturnKeyAutomatically = true
            tf.clearButtonMode = .always
            tf.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Rename", style: .default, handler: { _ in
            guard let text = alert.textFields?.first?.text,
                text.count > 0 else {
                    completion(nil)
                    return
            }
            
            CloudSyncManager.scheduleManager.renameFile(at: item.identifier, to: text, completion: { newURL in
                if let destURL = newURL {
                    let newItem = DocumentBrowseViewController.Item(identifier: destURL.lastPathComponent, title: text, description: item.description, image: item.image)
                    var shouldOpenNewRoad = false
                    if (self.currentSchedule?.filePath as NSString?)?.lastPathComponent == item.identifier {
                        self.currentSchedule = nil
                        shouldOpenNewRoad = true
                    }
                    if shouldOpenNewRoad {
                        self.loadSchedule(named: newItem.identifier)
                    }
                    completion(newItem)
                } else {
                    print("Failed to rename schedule")
                }
            })
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        presenter.present(alert, animated: true, completion: nil)
    }
    
    func documentBrowser(_ browser: DocumentBrowseViewController, wantsDuplicate item: DocumentBrowseViewController.Item, completion: @escaping ((DocumentBrowseViewController.Item?) -> Void)) {
        guard let oldURL = urlForSchedule(named: item.identifier) else {
            return
        }
        let presenter = self.presentedViewController ?? self
        
        let base = (item.identifier as NSString).deletingPathExtension
        var newID = base + " 2"
        if let newURL = urlForSchedule(named: newID + SchedulePathExtension),
            FileManager.default.fileExists(atPath: newURL.path) {
            var counter = 3
            while let otherURL = urlForSchedule(named: base + " \(counter)" + SchedulePathExtension),
                FileManager.default.fileExists(atPath: otherURL.path) {
                    counter += 1
            }
            newID = base + " \(counter)"
        }
        
        do {
            let newItem = DocumentBrowseViewController.Item(identifier: newID + SchedulePathExtension, title: newID, description: item.description, image: item.image)
            guard let newURL = urlForSchedule(named: newID + SchedulePathExtension) else {
                completion(nil)
                return
            }
            try FileManager.default.copyItem(at: oldURL, to: newURL)
            completion(newItem)
        } catch {
            let alert = UIAlertController(title: "Could Not Duplicate Schedule", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
            presenter.present(alert, animated: true, completion: nil)
            completion(nil)
        }
    }
    
    func documentBrowser(_ browser: DocumentBrowseViewController, selectedItem item: DocumentBrowseViewController.Item) {
        loadSchedule(named: item.identifier)
        dismiss(animated: true, completion: nil)
    }
    
    func cloudSyncManager(_ manager: CloudSyncManager, modifiedFileNamed name: String) {
        if name == currentSchedule?.fileName {
            try? currentSchedule?.reloadContents()
            updateDisplayedSchedules()
        }
    }
    
    func cloudSyncManager(_ manager: CloudSyncManager, renamedFileNamed name: String, to newName: String) {
        if name == currentSchedule?.fileName {
            currentSchedule?.filePath = manager.urlForUserFile(named: newName)?.path
            try? currentSchedule?.reloadContents()
            updateDisplayedSchedules()
        }
    }
    
    func cloudSyncManager(_ manager: CloudSyncManager, deletedFileNamed name: String) {
        if name == currentSchedule?.fileName {
            currentSchedule = nil
            updateDisplayedSchedules()
        }
    }
}
