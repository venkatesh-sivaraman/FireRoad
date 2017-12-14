//
//  RootTabViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 10/7/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class RootTabViewController: UITabBarController {
    
    func addCourse(_ course: Course, to semester: UserSemester? = nil) -> UserSemester? {
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
        scheduleVC.displayedCourses.append(course)
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
}
