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

    func generateDetailsViewController(for course: Course, completion: @escaping ((CourseDetailsViewController?, CourseBrowserViewController?) -> Void))
    func generatePostReqsViewController(for course: Course, completion: (CourseBrowserViewController?) -> Void)
    func generateURLViewController(for url: URL) -> WebpageViewController?
}

extension CourseViewControllerProvider {
    func generateDetailsViewController(for course: Course, completion: @escaping ((CourseDetailsViewController?, CourseBrowserViewController?) -> Void)) {
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
                    self.generateDetailsViewController(for: course, completion: completion)
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
        } else if course.subjectID == "GIR" {
            let listVC = self.storyboard!.instantiateViewController(withIdentifier: "CourseListVC") as! CourseBrowserViewController
            listVC.searchTerm = GIRAttribute(rawValue: course.subjectDescription ?? (course.subjectTitle ?? ""))?.rawValue
            listVC.searchOptions = [.offeredAnySemester, .containsSearchTerm, .fulfillsGIR, .searchRequirements]
            listVC.showsHeaderBar = false
            completion(nil, listVC)
        }
    }
    
    func generatePostReqsViewController(for course: Course, completion: (CourseBrowserViewController?) -> Void) {
        let listVC = self.storyboard!.instantiateViewController(withIdentifier: "CourseListVC") as! CourseBrowserViewController
        listVC.searchTerm = (course.subjectID ?? "")
        if let gir = course.girAttribute, gir != .lab, gir != .rest {
            listVC.searchTerm = (listVC.searchTerm ?? "") + " " + gir.descriptionText()
        }
        listVC.searchOptions = [.offeredAnySemester, .containsSearchTerm, .anyRequirement, .searchPrereqs]
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
        viewDetails(for: course)
    }
    
    func viewDetails(for course: Course) {
        generateDetailsViewController(for: course) { (details, list) in
            guard let panel = self.panelView,
                let browser = self.courseBrowser else {
                    return
            }
            if !panel.isExpanded {
                panel.expandView()
            }
            if let detailVC = details {
                detailVC.showsSemesterDialog = self.showsSemesterDialogs
                detailVC.delegate = self
                if let vcs = browser.navigationController?.viewControllers {
                    detailVC.restorationIdentifier? += "\(vcs.count)"
                }
                browser.navigationController?.pushViewController(detailVC, animated: true)
                browser.navigationController?.view.setNeedsLayout()
            } else if let listVC = list {
                listVC.delegate = self
                listVC.managesNavigation = false
                listVC.showsSemesterDialog = self.showsSemesterDialogs
                listVC.view.backgroundColor = UIColor.clear
                if let vcs = browser.navigationController?.viewControllers {
                    listVC.restorationIdentifier? += "\(vcs.count)"
                }
                browser.navigationController?.pushViewController(listVC, animated: true)
                browser.navigationController?.view.setNeedsLayout()
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
            guard let panel = self.panelView,
                let browser = self.courseBrowser,
                let listVC = list else {
                    return
            }
            if !panel.isExpanded {
                panel.expandView()
            }
            
            listVC.delegate = self
            listVC.managesNavigation = false
            listVC.showsSemesterDialog = self.showsSemesterDialogs
            listVC.view.backgroundColor = UIColor.clear
            if let vcs = browser.navigationController?.viewControllers {
                listVC.restorationIdentifier? += "\(vcs.count)"
            }
            browser.navigationController?.pushViewController(listVC, animated: true)
            browser.navigationController?.view.setNeedsLayout()
        }
    }
    
    func courseDetailsRequestedOpen(url: URL) {
        guard let panel = self.panelView,
            let browser = self.courseBrowser,
            let webVC = generateURLViewController(for: url) else {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return
        }
        if !panel.isExpanded {
            panel.expandView()
        }
        
        webVC.view.backgroundColor = UIColor.clear
        browser.navigationController?.pushViewController(webVC, animated: true)
        browser.navigationController?.view.setNeedsLayout()
    }
}
