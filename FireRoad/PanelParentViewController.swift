//
//  PanelParentViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 11/17/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol PanelParentViewController: CourseBrowserDelegate, CourseDetailsDelegate {
    var panelView: PanelViewController? { get set }
    var courseBrowser: CourseBrowserViewController? { get set }
    var childViewControllers: [UIViewController] { get }
    var view: UIView! { get }
    var storyboard: UIStoryboard? { get }
    
    func findPanelChildViewController()
    func updatePanelViewCollapseHeight()
    
    func addCourse(_ course: Course, to semester: UserSemester?) -> UserSemester?
    func viewDetails(for course: Course)
}

extension PanelParentViewController {
    
    func findPanelChildViewController() {
        for child in self.childViewControllers {
            if child is PanelViewController {
                self.panelView = child as? PanelViewController
                for subchild in self.panelView!.childViewControllers[0].childViewControllers {
                    if subchild is CourseBrowserViewController {
                        self.courseBrowser = subchild as? CourseBrowserViewController
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
    
    func courseBrowser(added course: Course, to semester: UserSemester?) -> UserSemester? {
        return addCourse(course, to: semester)
    }
    
    func courseBrowserRequestedDetails(about course: Course) {
        viewDetails(for: course)
    }
    
    func courseDetailsRequestedDetails(about course: Course) {
        viewDetails(for: course)
    }
    
    func viewDetails(for course: Course) {
        if !CourseManager.shared.isLoaded {
            let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            hud.mode = .determinateHorizontalBar
            hud.label.text = "Loading courses…"
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
                    self.viewDetails(for: course)
                }
            }
            return
        }
        if let id = course.subjectID,
            let realCourse = CourseManager.shared.getCourse(withID: id) {
            CourseManager.shared.loadCourseDetails(about: realCourse) { (success) in
                if success {
                    guard let panel = self.panelView,
                        let browser = self.courseBrowser else {
                            return
                    }
                    if !panel.isExpanded {
                        panel.expandView()
                    }
                    
                    let details = self.storyboard!.instantiateViewController(withIdentifier: "CourseDetails") as! CourseDetailsViewController
                    details.course = realCourse
                    details.delegate = self
                    browser.navigationController?.pushViewController(details, animated: true)
                    browser.navigationController?.view.setNeedsLayout()
                } else {
                    print("Failed to load course details!")
                }
            }
        } else if course.subjectID == "GIR" {
            guard let panel = self.panelView,
                let browser = self.courseBrowser else {
                    return
            }
            if !panel.isExpanded {
                panel.expandView()
            }
            
            let listVC = self.storyboard!.instantiateViewController(withIdentifier: "CourseListVC") as! CourseBrowserViewController
            listVC.searchTerm = GIRAttribute(rawValue: course.subjectDescription ?? (course.subjectTitle ?? ""))?.rawValue
            listVC.searchOptions = [.offeredAnySemester, .containsSearchTerm, .fulfillsGIR, .searchRequirements]
            listVC.showsHeaderBar = false
            listVC.delegate = self
            listVC.managesNavigation = false
            listVC.view.backgroundColor = UIColor.clear
            browser.navigationController?.pushViewController(listVC, animated: true)
            browser.navigationController?.view.setNeedsLayout()
        }
    }
    
    func courseDetailsRequestedPostReqs(for course: Course) {
        guard let panel = self.panelView,
            let browser = self.courseBrowser else {
                return
        }
        if !panel.isExpanded {
            panel.expandView()
        }

        let listVC = self.storyboard!.instantiateViewController(withIdentifier: "CourseListVC") as! CourseBrowserViewController
        listVC.searchTerm = (course.subjectID ?? "") + " " + (course.girAttribute?.descriptionText() ?? "")
        listVC.searchOptions = [.offeredAnySemester, .containsSearchTerm, .fulfillsGIR, .anyRequirement, .searchPrereqs]
        listVC.showsHeaderBar = false
        listVC.delegate = self
        listVC.managesNavigation = false
        listVC.view.backgroundColor = UIColor.clear
        browser.navigationController?.pushViewController(listVC, animated: true)
        browser.navigationController?.view.setNeedsLayout()
    }
}
