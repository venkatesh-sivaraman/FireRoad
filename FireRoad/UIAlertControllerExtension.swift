//
//  UIAlertControllerExtension.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 8/9/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import Foundation

public extension UIAlertController {
    
    private static var globalPresentationWindow: UIWindow?
    
    func show() {
        DispatchQueue.main.async {
            let win = UIWindow(frame: UIScreen.main.bounds)
            let vc = UIViewController()
            vc.view.backgroundColor = .clear
            win.rootViewController = vc
            win.windowLevel = UIWindowLevelAlert + 1
            win.makeKeyAndVisible()
            vc.present(self, animated: true, completion: nil)
            UIAlertController.globalPresentationWindow = win
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIAlertController.globalPresentationWindow?.isHidden = true
        UIAlertController.globalPresentationWindow = nil
    }
}
