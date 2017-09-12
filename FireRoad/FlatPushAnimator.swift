//
//  FlatPushAnimator.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/13/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class FlatPushAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    var reversed: Bool = false
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.4
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let sourceView = transitionContext.view(forKey: .from)!,
        destView = transitionContext.view(forKey: .to)!
        
        transitionContext.containerView.addSubview(destView)
        if reversed {
            destView.frame = transitionContext.initialFrame(for: transitionContext.viewController(forKey: .from)!).offsetBy(dx: -destView.frame.size.width, dy: 0.0)
            UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 10.0, options: [], animations: {
                destView.frame = transitionContext.finalFrame(for: transitionContext.viewController(forKey: .to)!)
                sourceView.frame = sourceView.frame.offsetBy(dx: sourceView.frame.size.width, dy: 0.0)

            }, completion: { (completed) in
                if completed {
                    transitionContext.completeTransition(true)
                }
            })
        } else {
            destView.frame = transitionContext.initialFrame(for: transitionContext.viewController(forKey: .from)!).offsetBy(dx: sourceView.frame.size.width, dy: 0.0)
            UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 10.0, options: [], animations: {
                destView.frame = transitionContext.finalFrame(for: transitionContext.viewController(forKey: .to)!)
                sourceView.frame = sourceView.frame.offsetBy(dx: -sourceView.frame.size.width, dy: 0.0)
            }, completion: { (completed) in
                if completed {
                    transitionContext.completeTransition(true)
                }
            })
        }
    }
}
