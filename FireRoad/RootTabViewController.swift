//
//  RootTabViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 10/7/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class RootTabViewController: UITabBarController {
    
    var blurView: UIVisualEffectView?
    var courseUpdatingHUD: MBProgressHUD?
    
    func hideHUD() {
        self.courseUpdatingHUD?.hide(animated: true)
        UIView.animate(withDuration: 0.3, animations: {
            self.blurView?.effect = nil
        }, completion: { completed in
            if completed {
                self.blurView?.removeFromSuperview()
            }
        })
    }
    
    var justLoaded = false
    override func viewDidLoad() {
        updateSemesters()
        justLoaded = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if justLoaded, !CourseManager.shared.isLoaded {
            CourseManager.shared.loadCourses()
        }
        justLoaded = false
    }
    
    func updateSemesters() {
        let oldAvailableSemesters = CourseManager.shared.availableCatalogSemesters
        CourseManager.shared.checkForCatalogSemesterUpdates { (state, _, error, code) in
            DispatchQueue.main.async {
                switch state {
                case .completed:
                    if (CourseManager.shared.catalogSemester == nil ||
                        CourseManager.shared.catalogSemester?.pathValue == oldAvailableSemesters.last?.pathValue),
                        let currentSemester = CourseManager.shared.availableCatalogSemesters.last {
                        print("Setting current semester to \(currentSemester.stringValue)")
                        CourseManager.shared.catalogSemester = currentSemester
                        self.updateCourseCatalog()
                    } else if let newVersion = CourseManager.shared.availableCatalogSemesters.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                            // Prompt the user about updating the course catalog to the new semester
                            let alert = UIAlertController(title: "\(newVersion.season.capitalized) \(newVersion.year) Catalog Available", message: "Would you like to switch to the new catalog?", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { _ in
                                CourseManager.shared.catalogSemester = newVersion
                                self.updateCourseCatalog()
                            }))
                            alert.addAction(UIAlertAction(title: "Not Now", style: .cancel, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        })
                    }
                case .error:
                    if CourseManager.shared.catalogSemester == nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                            var message = ""
                            if let codeNum = code {
                                message = "The request received error code \(codeNum). Please try again later."
                            } else if let error = error {
                                message = error.localizedDescription
                            } else {
                                message = "Couldn't load initial course catalog. Please try again later."
                            }
                            let alert = UIAlertController(title: "Error Loading Catalog", message: message, preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                            alert.addAction(UIAlertAction(title: "Retry", style: .default, handler: { _ in
                                self.updateSemesters()
                            }))
                            self.present(alert, animated: true, completion: nil)
                        })
                    }
                    break
                default:
                    print("Shouldn't have gotten \(state) from catalog semester updater")
                }
            }
        }
    }
    
    func updateCourseCatalog() {
        CourseManager.shared.checkForCourseCatalogUpdates { (state, progressOpt, error, code) in
            DispatchQueue.main.async {
                switch state {
                case .newVersionAvailable:
                    guard self.courseUpdatingHUD == nil else {
                        break
                    }
                    let blur = UIVisualEffectView(effect: nil)
                    blur.frame = self.view.bounds
                    self.blurView = blur
                    self.view.addSubview(blur)
                    blur.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
                    blur.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
                    blur.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
                    blur.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
                    
                    let hud = MBProgressHUD.showAdded(to: blur.contentView, animated: true)
                    hud.mode = .determinateHorizontalBar
                    hud.label.text = "Updating subject catalog…"
                    self.courseUpdatingHUD = hud
                    
                    UIView.animate(withDuration: 0.3, animations: {
                        blur.effect = UIBlurEffect(style: .light)
                    })
                case .noUpdatesAvailable:
                    if !CourseManager.shared.isLoaded {
                        CourseManager.shared.loadCourses()
                    }
                    break
                case .downloading:
                    guard let progress = progressOpt else {
                        break
                    }
                    self.courseUpdatingHUD?.progress = progress
                case .completed:
                    self.hideHUD()
                    print("Loading courses")
                    CourseManager.shared.loadCourses()
                    self.reloadRequirementsView()
                case .error:
                    self.hideHUD()
                    var errorMessage = ""
                    if let err = error {
                        errorMessage += err.localizedDescription + "\n\n"
                    } else if let errorCode = code {
                        errorMessage += "Received HTTP error code \(errorCode).\n\n"
                    }
                    errorMessage += "Update will try again on the next launch."
                    let alert = UIAlertController(title: "Error Updating Subjects", message: errorMessage, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                    CourseManager.shared.loadCourses()
                    self.reloadRequirementsView()
                }
            }
        }
    }
    
    func addCourse(_ course: Course, to semester: UserSemester? = nil) -> UserSemester? {
        guard currentUser?.allCourses.contains(course) == false else {
            let alert = UIAlertController(title: "Course Already Added", message: "\(course.subjectID!) is already in your course list.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
            return nil
        }

        guard let courseRoadVC = childViewController(where: { $0 is CourseroadViewController }) as? CourseroadViewController else {
            return nil
        }
        //self.selectedViewController = containingVC
        let ret = courseRoadVC.addCourse(course, to: semester)
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud.mode = .customView
        let imageView = UIImageView(image: UIImage(named: "Checkmark"))
        imageView.frame = CGRect(x: 0.0, y: 0.0, width: 72.0, height: 72.0)
        hud.customView = imageView
        hud.label.text = "Added \(course.subjectID!)"
        hud.isSquare = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            hud.hide(animated: true)
        }
        return ret
    }
    
    func addCourseToSchedule(_ course: Course) {
        guard let scheduleVC = childViewController(where: { $0 is ScheduleViewController }) as? ScheduleViewController else {
            print("Couldn't get schedule view controller")
            return
        }
        if !scheduleVC.displayedCourses.contains(course) {
            scheduleVC.displayedCourses.append(course)
        }
        if let tab = viewControllers?.first(where: { scheduleVC.isDescendant(of: $0) }) {
            selectedViewController = tab
        }
    }

    var currentUser: User? {
        guard let courseRoadVC = childViewController(where: { $0 is CourseroadViewController }) as? CourseroadViewController else {
                return nil
        }
        return courseRoadVC.currentUser
    }
    
    func displaySchedule(with courses: [Course]) {
        guard let scheduleVC = childViewController(where: { $0 is ScheduleViewController }) as? ScheduleViewController else {
            print("Couldn't get schedule view controller")
            return
        }
        scheduleVC.displayedCourses = courses
        if let tab = viewControllers?.first(where: { scheduleVC.isDescendant(of: $0) }) {
            selectedViewController = tab
        }
    }
    
    func reloadRequirementsView() {
        RequirementsListManager.shared.clearRequirementsLists()
        guard let browserVC = childViewController(where: { $0 is RequirementsBrowserViewController }) as? RequirementsBrowserViewController else {
            print("Couldn't get requirements view controller")
            return
        }
        browserVC.reloadRequirements()
    }
}
