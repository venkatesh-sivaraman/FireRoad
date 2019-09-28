//
//  CustomActivity.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/6/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import UIKit

class CustomActivity: UIActivity {
    
    var customActivityType = ""
    var activityName = ""
    var myActivityImage: UIImage?
    var customActionWhenTapped: ( () -> Void)!
    
    init(title: String, image: UIImage?, performAction: @escaping (() -> Void)) {
        self.activityName = title
        self.myActivityImage = image
        self.customActivityType = "Action \(title)"
        self.customActionWhenTapped = performAction
        super.init()
    }
    
    override var activityType: UIActivityType? {
        return UIActivityType(rawValue: customActivityType)
    }
    
    override var activityTitle: String? {
        return activityName
    }
    
    override var activityImage: UIImage? {
        return myActivityImage
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return true
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        
    }

    override var activityViewController: UIViewController? {
        return nil
    }
    
    override func perform() {
        customActionWhenTapped()
    }
}
