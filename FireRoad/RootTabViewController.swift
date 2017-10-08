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
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            hud.hide(animated: true)
        }
        return ret
    }

    var currentUser: User? {
        guard let courseRoadVC = childViewController(where: { $0 is CourseroadViewController }) as? CourseroadViewController else {
                return nil
        }
        return courseRoadVC.currentUser
    }
}
