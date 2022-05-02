//
//  UIViewControllerExtension.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 10/7/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

extension UIViewController {
    
    var rootParent: UIViewController? {
        guard self.parent != nil else {
            return nil
        }
        var currentParent: UIViewController = self
        while let newParent = currentParent.parent {
            currentParent = newParent
        }
        return currentParent
    }
    
    func childViewController(where test: ((UIViewController) -> Bool)) -> UIViewController? {
        for child in children {
            if test(child) {
                return child
            } else if let matchedChild = child.childViewController(where: test) {
                return matchedChild
            }
        }
        return nil
    }
    
    func isDescendant(of viewController: UIViewController) -> Bool {
        var currentParent: UIViewController = self
        while let newParent = currentParent.parent {
            currentParent = newParent
            if currentParent == viewController {
                return true
            }
        }
        return false
    }
    
    func enumerateChildViewControllers(with action: (UIViewController) -> Void) {
        for child in children {
            action(child)
            child.enumerateChildViewControllers(with: action)
        }
    }
}
