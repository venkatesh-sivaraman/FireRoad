//
//  PanelParentViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 11/17/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol CourseViewControllerProvider {
    var view: UIView! { get }
    var storyboard: UIStoryboard? { get }
    var presentedViewController: UIViewController? { get }
    
    func generateDetailsViewController(for course: Course, showGenericDetails: Bool, completion: @escaping ((CourseDetailsViewController?, CourseBrowserViewController?) -> Void))
    func generatePostReqsViewController(for course: Course, completion: (CourseBrowserViewController?) -> Void)
    func generateURLViewController(for url: URL) -> WebpageViewController?
}

extension CourseViewControllerProvider {
    func generateDetailsViewController(for course: Course, showGenericDetails: Bool, completion: @escaping ((CourseDetailsViewController?, CourseBrowserViewController?) -> Void)) {
        if !CourseManager.shared.isLoaded {
            let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            hud.mode = .determinateHorizontalBar
            hud.label.text = "Loading subjects…"
            DispatchQueue.global(qos: .background).async {
                let initialProgress = CourseManager.shared.loadingProgress
                while !CourseManager.shared.isLoaded {
                    DispatchQueue.main.async {
                        hud.progress = (CourseManager.shared.loadingProgress - initialProgress) / (1.0 - initialProgress)
                    }
                    usleep(100)
                }
                DispatchQueue.main.async {
                    hud.hide(animated: true)
                    self.generateDetailsViewController(for: course, showGenericDetails: showGenericDetails, completion: completion)
                }
            }
            return
        }
        if let id = course.subjectID,
            let realCourse = CourseManager.shared.getCourse(withID: id) {
            CourseManager.shared.loadCourseDetails(about: realCourse) { (success) in
                if success {
                    let details = self.storyboard!.instantiateViewController(withIdentifier: "CourseDetails") as! CourseDetailsViewController
                    details.course = realCourse
                    completion(details, nil)
                } else {
                    print("Failed to load course details!")
                }
            }
        } else if course.subjectID == "GIR" || (course.subjectID != nil && Course.genericCourses[course.subjectID!] != nil) {
            if showGenericDetails {
                let details = self.storyboard!.instantiateViewController(withIdentifier: "CourseDetails") as! CourseDetailsViewController
                details.course = course
                completion(details, nil)
            } else {
                let listVC = self.storyboard!.instantiateViewController(withIdentifier: "CourseListVC") as! CourseBrowserViewController
                if course.subjectID == "GIR" {
                    listVC.searchTerm = GIRAttribute(rawValue: course.subjectDescription ?? (course.subjectTitle ?? ""))?.rawValue
                    listVC.searchOptions = SearchOptions.noFilter.filterGIR(.fulfillsGIR).filterSearchFields(.searchRequirements)
                } else if let id = course.subjectID,
                    let generic = Course.genericCourses[id] {
                    if let attr = generic.girAttribute {
                        listVC.searchTerm = attr.rawValue
                    } else {
                        listVC.searchTerm = ""
                    }
                    listVC.searchOptions = searchOptionsForRequirements(from: generic)
                }
                listVC.showsHeaderBar = false
                completion(nil, listVC)
            }
        }
    }
    
    func searchOptionsForRequirements(from course: Course) -> SearchOptions {
        var base = SearchOptions.noFilter.filterSearchFields(.searchRequirements)
        if let ciAttribute = course.communicationRequirement {
            base = base.filterCI(ciAttribute == .ciH ? .fulfillsCIH : .fulfillsCIHW)
        }
        
        if let hass = course.hassAttribute?.first {
            var option: SearchOptions
            switch hass {
            case .any, .elective: option = .fulfillsHASS
            case .arts: option = .fulfillsHASSA
            case .socialSciences: option = .fulfillsHASSS
            case .humanities: option = .fulfillsHASSH
            }
            base = base.filterHASS(option)
        }
        
        if course.girAttribute != nil {
            base = base.filterGIR(.fulfillsGIR)
        }
        
        return base
    }
    
    func generatePostReqsViewController(for course: Course, completion: (CourseBrowserViewController?) -> Void) {
        let listVC = self.storyboard!.instantiateViewController(withIdentifier: "CourseListVC") as! CourseBrowserViewController
        listVC.searchTerm = (course.subjectID ?? "")
        if let gir = course.girAttribute, gir != .lab, gir != .rest {
            listVC.searchTerm = gir.rawValue
        }
        listVC.searchOptions = SearchOptions.noFilter.filterSearchFields(.searchPrereqs).replace(oldValue: .containsSearchTerm, with: .matchesSearchTerm)
        listVC.showsHeaderBar = false
        completion(listVC)
    }
    
    func generateURLViewController(for url: URL) -> WebpageViewController? {
        return nil
    }
}

protocol PanelParentViewController: CourseViewControllerProvider, CourseBrowserDelegate, CourseDetailsDelegate {
    var panelView: PanelViewController? { get set }
    var courseBrowser: CourseBrowserViewController? { get set }
    var childViewControllers: [UIViewController] { get }
    var rootParent: UIViewController? { get }
    
    var showsSemesterDialogs: Bool { get }
    
    func findPanelChildViewController()
    func updatePanelViewCollapseHeight()    
}

extension PanelParentViewController {
    
    func findPanelChildViewController() {
        for child in self.childViewControllers {
            if child is PanelViewController {
                self.panelView = child as? PanelViewController
                for subchild in self.panelView!.childViewControllers[0].childViewControllers {
                    if subchild is CourseBrowserViewController {
                        self.courseBrowser = subchild as? CourseBrowserViewController
                        self.courseBrowser?.showsSemesterDialog = self.showsSemesterDialogs
                        break
                    }
                }
            }
        }
        
        self.courseBrowser?.delegate = self
    }
    
    func updatePanelViewCollapseHeight() {
        guard self.panelView?.collapseHeight == 0.0 else {
            return
        }
        self.panelView?.collapseHeight = self.panelView!.view.frame.size.height
    }
    
    func courseDetails(added course: Course, to semester: UserSemester?) {
        _ = addCourse(course, to: semester)
        courseBrowser?.navigationController?.popViewController(animated: true)
    }
    
    func courseDetailsRequestedDetails(about course: Course) {
        viewDetails(for: course, showGenericDetails: false)
    }
    
    /// Returns the appropriate background color object depending on the system version.
    private var detailBackgroundColor: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.systemBackground
        } else {
            return UIColor.white
        }
    }
    
    func viewDetails(for course: Course, showGenericDetails: Bool = true) {
        generateDetailsViewController(for: course, showGenericDetails: showGenericDetails) { (details, list) in
            if self.panelView?.isExpanded == false, self.presentedViewController == nil {
                self.panelView?.expandView()
            }
            if let detailVC = details {
                detailVC.showsSemesterDialog = self.showsSemesterDialogs
                detailVC.delegate = self
                if let presented = self.presentedViewController as? UINavigationController {
                    detailVC.view.backgroundColor = self.detailBackgroundColor
                    presented.pushViewController(detailVC, animated: true)
                } else if let browser = self.courseBrowser {
                    detailVC.view.backgroundColor = UIColor.clear
                    if let vcs = browser.navigationController?.viewControllers {
                        detailVC.restorationIdentifier? += "\(vcs.count)"
                    }
                    browser.navigationController?.pushViewController(detailVC, animated: true)
                    browser.navigationController?.view.setNeedsLayout()
                }
            } else if let listVC = list {
                listVC.delegate = self
                listVC.managesNavigation = false
                listVC.showsSemesterDialog = self.showsSemesterDialogs
                if let presented = self.presentedViewController as? UINavigationController {
                    listVC.view.backgroundColor = self.detailBackgroundColor
                    presented.pushViewController(listVC, animated: true)
                } else if let browser = self.courseBrowser {
                    listVC.view.backgroundColor = UIColor.clear
                    if let vcs = browser.navigationController?.viewControllers {
                        listVC.restorationIdentifier? += "\(vcs.count)"
                    }
                    browser.navigationController?.pushViewController(listVC, animated: true)
                    browser.navigationController?.view.setNeedsLayout()
                }
            }
        }
    }
    
    func addCourseToSchedule(_ course: Course) {
        guard let rootTab = self.rootParent as? RootTabViewController else {
            return
        }
        rootTab.addCourseToSchedule(course)
    }
    
    func courseDetails(addedCourseToSchedule course: Course) {
        addCourseToSchedule(course)
    }
    
    func courseDetailsRequestedPostReqs(for course: Course) {
        generatePostReqsViewController(for: course) { (list) in
            guard let listVC = list else {
                return
            }
            if self.panelView?.isExpanded == false {
                self.panelView?.expandView()
            }

            listVC.delegate = self
            listVC.managesNavigation = false
            listVC.showsSemesterDialog = self.showsSemesterDialogs
            if let presented = self.presentedViewController as? UINavigationController {
                listVC.view.backgroundColor = self.detailBackgroundColor
                presented.pushViewController(listVC, animated: true)
            } else if let browser = self.courseBrowser {
                listVC.view.backgroundColor = UIColor.clear
                if let vcs = browser.navigationController?.viewControllers {
                    listVC.restorationIdentifier? += "\(vcs.count)"
                }
                browser.navigationController?.pushViewController(listVC, animated: true)
                browser.navigationController?.view.setNeedsLayout()
            }
        }
    }
    
    func courseDetailsRequestedOpen(url: URL) {
        guard let webVC = generateURLViewController(for: url) else {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return
        }
        if self.panelView?.isExpanded == false {
            self.panelView?.expandView()
        }

        if let presented = self.presentedViewController as? UINavigationController {
            webVC.view.backgroundColor = self.detailBackgroundColor
            presented.pushViewController(webVC, animated: true)
        } else if let browser = self.courseBrowser {
            webVC.view.backgroundColor = UIColor.clear
            browser.navigationController?.pushViewController(webVC, animated: true)
            browser.navigationController?.view.setNeedsLayout()
        }
    }
}
