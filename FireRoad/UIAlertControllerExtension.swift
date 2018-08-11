//
//  UIAlertControllerExtension.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 8/9/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import Foundation

public extension UIAlertController {
    func show() {
        let win = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        win.rootViewController = vc
        win.windowLevel = UIWindowLevelAlert + 1
        win.makeKeyAndVisible()
        vc.present(self, animated: true, completion: nil)
    }
}
