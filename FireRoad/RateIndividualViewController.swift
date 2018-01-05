//
//  RateIndividualViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/5/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import UIKit

class RateIndividualViewController: UIViewController {

    @IBOutlet var ratingView: RatingView!
    var course: Course?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        ratingView.course = course
        preferredContentSize = CGSize(width: 140.0, height: 44.0)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
