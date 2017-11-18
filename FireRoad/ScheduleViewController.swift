//
//  ScheduleViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 11/17/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class ScheduleViewController: UIViewController, PanelParentViewController {
    var panelView: PanelViewController?
    var courseBrowser: CourseBrowserViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        findPanelChildViewController()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updatePanelViewCollapseHeight()
    }

    func addCourse(_ course: Course, to semester: UserSemester? = nil) -> UserSemester? {
        print("Added \(course)")
        return nil
    }
}
