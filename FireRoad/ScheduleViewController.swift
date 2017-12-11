//
//  ScheduleViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 11/17/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class ScheduleViewController: UIViewController, PanelParentViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, ScheduleGridDelegate {
    var panelView: PanelViewController?
    var courseBrowser: CourseBrowserViewController?
    var showsSemesterDialogs: Bool {
        return false
    }
    
    private var _displayedCourses: [Course] = []
    var displayedCourses: [Course] {
        get {
            return _displayedCourses
        } set {
            if _displayedCourses != newValue {
                _displayedCourses = newValue
                let beforeUpdate = _displayedCourses
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
                        alert = UIAlertController(title: "No Schedule for \(noSchedCourses.count) Courses", message: "No schedule available at this time for the following courses: \(noSchedCourses.flatMap({ $0.subjectID }).joined(separator: ", ")).", preferredStyle: .alert)
                    }
                    if let alertController = alert {
                        alertController.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                        self.present(alertController, animated: true, completion: nil)
                    }
                })
            }
        }
    }
    
    @IBOutlet var loadingView: UIView?
    @IBOutlet var loadingIndicator: UIActivityIndicatorView?
    @IBOutlet var loadingBackgroundView: UIView?
    
    @IBOutlet var scheduleNumberLabel: UILabel?
    
    var pageViewController: UIPageViewController?
    
    var scheduleOptions: [Schedule] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        if self.displayedCourses.count == 0,
            let courses = (self.rootParent as? RootTabViewController)?.currentUser?.courses(forSemester: .FreshmanFall) {
            self.displayedCourses = courses
        }

        loadingBackgroundView?.layer.cornerRadius = 5.0
        
        // Do any additional setup after loading the view.
        findPanelChildViewController()
        
        pageViewController = childViewControllers.first(where: { $0 is UIPageViewController }) as? UIPageViewController
        pageViewController?.dataSource = self
        pageViewController?.delegate = self
        
        updateDisplayedSchedules()
        
        updateNavigationBar(animated: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updatePanelViewCollapseHeight()
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
    
    func updateDisplayedSchedules(completion: (() -> Void)? = nil) {
        loadScheduleOptions {
            if self.scheduleOptions.count > 0 {
                self.pageViewController?.setViewControllers([self.scheduleGrid(for: 0)].flatMap({ $0 }), direction: .forward, animated: false, completion: nil)
                self.scheduleNumberLabel?.text = "\(1) of \(self.scheduleOptions.count)"
            } else if let noSchedulesView = self.storyboard?.instantiateViewController(withIdentifier: "NoSchedulesView") {
                self.pageViewController?.setViewControllers([noSchedulesView], direction: .forward, animated: false, completion: nil)
                self.scheduleNumberLabel?.text = "--"
            }
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
                self.pageViewController?.view.alpha = 0.0
            }
            self.loadingView?.alpha = 1.0
            self.loadingView?.isHidden = false
            self.loadingIndicator?.startAnimating()
        }
        DispatchQueue.global(qos: .background).async {
            while !CourseManager.shared.isLoaded {
                usleep(100)
            }
            
            for course in self.displayedCourses {
                CourseManager.shared.loadCourseDetailsSynchronously(about: course)
            }
            self._displayedCourses = self.displayedCourses.filter({ $0.schedule != nil && $0.schedule!.count > 0 })
            if self.displayedCourses.count > 0 {
                self.scheduleOptions = self.generateSchedules(from: self.displayedCourses)
                print(self.scheduleOptions)
            } else {
                self.scheduleOptions = []
            }

            self.loadingScheduleOptions = false
            DispatchQueue.main.async {
                completion()
                if !peripheralLoad {
                    if let loadingView = self.loadingView,
                        let pageView = self.pageViewController?.view {
                        pageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                        pageView.alpha = 0.0
                        UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                            pageView.alpha = 1.0
                            pageView.transform = CGAffineTransform.identity
                            loadingView.alpha = 0.0
                            loadingView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                        }, completion: { (completed) in
                            if completed {
                                loadingView.isHidden = true
                                self.loadingIndicator?.stopAnimating()
                            }
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
                let allOptions = sectionOptions.map({ ScheduleUnit(course: course, sectionType: section, scheduleItems: $0) })
                guard allOptions.count > 0 else {
                    print("No options for \(course.subjectID!) \(section)")
                    continue
                }
                scheduleConfigurations.append(allOptions)
                scheduleConfigurationsList += allOptions
            }
        }
        
        var conflictGroups: [[ScheduleUnit]] = ScheduleSlotManager.slots.map({ _ in [] })
        var configurationConflictMapping: [ScheduleUnit: Set<Int>] = [:]
        for unit in scheduleConfigurationsList {
            var slotsOccupied = Set<Int>()
            for item in unit.scheduleItems {
                let startSlot = ScheduleSlotManager.slotIndex(for: item.startTime)
                let endSlot = ScheduleSlotManager.slotIndex(for: item.endTime)
                for slot in startSlot..<endSlot {
                    conflictGroups[slot].append(unit)
                    slotsOccupied.insert(slot)
                }
            }
            configurationConflictMapping[unit] = slotsOccupied
        }

        print("Schedule configurations: \(scheduleConfigurations)")
        print("Conflict groups: \(conflictGroups)")
        
        let results = recursivelyGenerateScheduleConfigurations(with: scheduleConfigurations, conflictMapping: configurationConflictMapping)
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
        * conflictMapping: The numbers of the slots occupied by each schedule unit.
        * prefixSchedule: The list of schedule units generated so far.
        * conflictCount: The current number of conflicts in the schedule.
        * conflictingSlots: The slots which, if occupied by the next added configuration,
            will create an additional conflict.
     
     - Returns: A list of schedules generated.
     */
    private func recursivelyGenerateScheduleConfigurations(with configurations: [[ScheduleUnit]], conflictMapping: [ScheduleUnit: Set<Int>], prefixSchedule: [ScheduleUnit] = [], conflictCount: Int = 0, conflictingSlots: Set<Int> = Set<Int>()) -> [Schedule] {
        if prefixSchedule.count == configurations.count {
            return [Schedule(items: prefixSchedule, conflictCount: conflictCount)]
        }
        // Vary the next configuration in the list
        let changingConfigurationSet = configurations[prefixSchedule.count]
        var results: [Schedule] = []
        for configuration in changingConfigurationSet {
            guard let slots = conflictMapping[configuration] else {
                print("Couldn't find schedule unit in conflict mapping")
                continue
            }
            let newConflictCount = slots.intersection(conflictingSlots).count
            results += recursivelyGenerateScheduleConfigurations(with: configurations, conflictMapping: conflictMapping, prefixSchedule: prefixSchedule + [configuration], conflictCount: conflictCount + newConflictCount, conflictingSlots: conflictingSlots.union(slots))
        }
        return results
    }
    
    // MARK: - Page View Controller
    
    func scheduleGrid(for page: Int) -> ScheduleGridViewController? {
        guard let vc = self.storyboard?.instantiateViewController(withIdentifier: "ScheduleGrid") as? ScheduleGridViewController,
            page >= 0,
            page < scheduleOptions.count else {
            return nil
        }
        vc.delegate = self
        vc.pageNumber = page
        vc.schedule = scheduleOptions[page]
        vc.topPadding = (panelView?.collapseHeight ?? 0.0) + (panelView?.view.convert(.zero, to: self.view).y ?? 0.0) + 12.0
        return vc
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let currentVC = viewController as? ScheduleGridViewController else {
            return nil
        }
        return scheduleGrid(for: currentVC.pageNumber + 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let currentVC = viewController as? ScheduleGridViewController else {
            return nil
        }
        return scheduleGrid(for: currentVC.pageNumber - 1)
    }
    
    var pendingPage = -1
    
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        pendingPage = (pendingViewControllers.first as? ScheduleGridViewController)?.pageNumber ?? 0
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if pendingPage != -1 {
            scheduleNumberLabel?.text = "\(pendingPage + 1) of \(scheduleOptions.count)"
        }
    }
    
    // MARK: Grid Delegate
    
    func addCourse(_ course: Course, to semester: UserSemester? = nil) -> UserSemester? {
        displayedCourses.append(course)
        if traitCollection.horizontalSizeClass == .compact {
            self.panelView?.collapseView(to: self.panelView!.collapseHeight)
        }
        return nil
    }

    func deleteCourseFromSchedules(_ course: Course) {
        guard let index = displayedCourses.index(of: course) else {
            return
        }
        displayedCourses.remove(at: index)
    }
}
