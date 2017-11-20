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
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async {
                self.loadingView?.isHidden = false
                self.loadingIndicator?.startAnimating()
            }
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
        var scheduleItems: [ScheduleItem] = []
        for course in courses {
            guard let scheds = course.schedule else {
                continue
            }
            var item = ScheduleItem(course: course, selectedSections: [:])
            for (type, times) in scheds where times.count > 0 {
                item.selectedSections[type] = times[0]
            }
            scheduleItems.append(item)
        }
        return [Schedule(items: scheduleItems)]
    }

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
