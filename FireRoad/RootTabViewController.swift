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
        guard let courseRoadVC = childViewController(where: { $0 is CourseroadViewController }) as? CourseroadViewController,
            let containingVC = viewControllers?.first(where: { courseRoadVC.isDescendant(of: $0) }) else {
            return nil
        }
        self.selectedViewController = containingVC
        return courseRoadVC.addCourse(course, to: semester)
    }

    var currentUser: User? {
        guard let courseRoadVC = childViewController(where: { $0 is CourseroadViewController }) as? CourseroadViewController else {
                return nil
        }
        return courseRoadVC.currentUser
    }
}
