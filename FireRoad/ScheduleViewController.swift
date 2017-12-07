//
//  ScheduleViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 11/17/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class ScheduleViewController: UIViewController, PanelParentViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    var panelView: PanelViewController?
    var courseBrowser: CourseBrowserViewController?
    
    @IBOutlet var loadingView: UIView?
    @IBOutlet var loadingIndicator: UIActivityIndicatorView?
    
    var pageViewController: UIPageViewController?
    
    var scheduleOptions: [Schedule] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        findPanelChildViewController()
        
        pageViewController = childViewControllers.first(where: { $0 is UIPageViewController }) as? UIPageViewController
        pageViewController?.dataSource = self
        pageViewController?.delegate = self
        
        loadScheduleOptions {
            self.pageViewController?.setViewControllers([self.scheduleGrid(for: 0)].flatMap({ $0 }), direction: .forward, animated: false, completion: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updatePanelViewCollapseHeight()
    }
    
    func loadScheduleOptions(completion: @escaping () -> Void) {
        self.pageViewController?.view.alpha = 0.0
        self.loadingView?.isHidden = false
        self.loadingIndicator?.startAnimating()
        DispatchQueue.global(qos: .background).async {
            while !CourseManager.shared.isLoaded {
                usleep(100)
            }
            
            if let courses = (self.rootParent as? RootTabViewController)?.currentUser?.courses(forSemester: .FreshmanSpring) {
                for course in courses {
                    CourseManager.shared.loadCourseDetailsSynchronously(about: course)
                }
                self.scheduleOptions = self.generateSchedules(from: courses)
                print(self.scheduleOptions)
            }
            
            DispatchQueue.main.async {
                completion()
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
            }
        }
    }
    
    // TODO: Add constraints to this method
    private func generateSchedules(from courses: [Course]) -> [Schedule] {
        let scheduleSlots = [9, 10, 11].flatMap({ [CourseScheduleTime(hour: $0, minute: 0, PM: false), CourseScheduleTime(hour: $0, minute: 30, PM: false)] }) + [12, 1, 2, 3, 4, 5, 6, 7, 8, 9].flatMap({ [CourseScheduleTime(hour: $0, minute: 0, PM: true), CourseScheduleTime(hour: $0, minute: 30, PM: true)] })
        let slotIndex: ((CourseScheduleTime) -> Int) = {
            var base = 0
            if $0.PM == false || $0.hour == 12 {
                base = ($0.hour - 9) * 2
            } else {
                base = ($0.hour + 3) * 2
            }
            if $0.minute >= 30 {
                return base + 1
            }
            return base
        }
        
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
        
        var conflictGroups: [[ScheduleUnit]] = scheduleSlots.map({ _ in [] })
        var configurationConflictMapping: [ScheduleUnit: Set<Int>] = [:]
        for unit in scheduleConfigurationsList {
            var slotsOccupied = Set<Int>()
            for item in unit.scheduleItems {
                let startSlot = slotIndex(item.startTime)
                let endSlot = slotIndex(item.endTime)
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
        return results.sorted(by: { $0.conflictCount < $1.conflictCount })
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
    
    /*private func recursivelyGenerateScheduleConfigurations(for course: Course, currentConfiguration: [String: [CourseScheduleItem]] = [:], scheduleTypeIndex: Int = 0) -> [[ScheduleItem]] {
        guard scheduleTypeIndex < CourseScheduleType.ordering.count,
            let sectionsList = course.schedule?[CourseScheduleType.ordering[scheduleTypeIndex]],
            sectionsList.count > 0 else {
                return [ScheduleItem(course: course, selectedSections: currentConfiguration)]
        }
        let currentType = CourseScheduleType.ordering[scheduleTypeIndex]
        
        var prefixConfiguration: [String: [CourseScheduleItem]] = [:]
        for (type, config) in currentConfiguration {
            prefixConfiguration[type] = config
        }
        var ret: [ScheduleItem] = []
        for section in sectionsList {
            prefixConfiguration[currentType] = section
            ret += recursivelyGenerateScheduleConfigurations(for: course, currentConfiguration: prefixConfiguration, scheduleTypeIndex: scheduleTypeIndex + 1)
        }
        
        return ret
    }*/

    func addCourse(_ course: Course, to semester: UserSemester? = nil) -> UserSemester? {
        print("Added \(course)")
        return nil
    }
    
    // MARK: - Page View Controller
    
    func scheduleGrid(for page: Int) -> ScheduleGridViewController? {
        guard let vc = self.storyboard?.instantiateViewController(withIdentifier: "ScheduleGrid") as? ScheduleGridViewController,
            page >= 0,
            page < scheduleOptions.count else {
            return nil
        }
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
}
