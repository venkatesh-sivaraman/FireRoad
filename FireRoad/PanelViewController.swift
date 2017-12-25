//
//  PanelViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/13/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

extension Notification.Name {
    static let PanelViewControllerWillExpand = Notification.Name("PanelViewControllerWillExpandNotification")
    static let PanelViewControllerWillCollapse = Notification.Name("PanelViewControllerWillCollapseNotification")
}

class PanelViewController: UIViewController, UIGestureRecognizerDelegate {

    private var _heightConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint? {
        get {
            if _heightConstraint == nil {
                if self.parent != nil {
                    let container = self.view.superview!
                    for constraint in container.constraints {
                        if constraint.firstItem as! NSObject == container && constraint.firstAttribute == .height {
                            _heightConstraint = constraint
                            break
                        }
                    }
                }
            }
            return _heightConstraint
        }
    }
    var collapseHeight: CGFloat = 0.0
    var expandedHeight: CGFloat {
        get {
            return self.parent!.view.frame.size.height - self.parent!.bottomLayoutGuide.length - self.view.superview!.convert(CGPoint.zero, to: self.parent!.view).y - 12.0
        }
    }
    
    public private(set) var isExpanded: Bool = false
    
    private var bottomConstraint: NSLayoutConstraint?
    
    private var childNavigationController: UINavigationController? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        let handleView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 36.0, height: 3.0))
        handleView.backgroundColor = UIColor.darkGray.withAlphaComponent(0.4)
        handleView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(handleView)
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[handleView(3)]-6-|", options: .alignAllCenterX, metrics: nil, views: ["handleView": handleView]))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:[handleView(36)]", options: [], metrics: nil, views: ["handleView": handleView]))
        self.view.addConstraint(NSLayoutConstraint(item: handleView, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1.0, constant: 0.0))
        handleView.layer.cornerRadius = 2.0
        /*self.view.layer.shadowRadius = 10.0
         self.view.layer.shadowOpacity = 0.4
         self.view.layer.shadowOffset = CGSize(width: 0.0, height: -0.5)*/
        
        NotificationCenter.default.addObserver(self, selector: #selector(PanelViewController.keyboardWillChangeFrame(sender:)), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(PanelViewController.handlePanGesture(sender:)))
        pan.delegate = self
        self.view.addGestureRecognizer(pan)
        
        for vc in self.childViewControllers {
            if vc is UINavigationController {
                self.childNavigationController = vc as? UINavigationController
                break
            }
        }
    }
        
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.view.frame.size.height > 0.0, collapseHeight == 0.0 {
            collapseHeight = self.view.frame.size.height
        }
        if shouldExpandOnAppear {
            expandView()
        }
        shouldExpandOnAppear = false
    }
    
    // MARK: - State Restoration
    
    var shouldExpandOnAppear = false
    
    static let isExpandedRestorationKey = "PanelView.isExpanded"
    static let childNavRestorationKey = "PanelView.childNav"

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(isExpanded, forKey: PanelViewController.isExpandedRestorationKey)
        coder.encode(childNavigationController, forKey: PanelViewController.childNavRestorationKey)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        shouldExpandOnAppear = coder.decodeBool(forKey: PanelViewController.isExpandedRestorationKey)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.location(in: self.view).y >= self.view.frame.size.height - 30.0
    }
    
    private var panAnchor: CGFloat = 0.0
    
    @objc func handlePanGesture(sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .began:
            panAnchor = self.view.frame.size.height - sender.location(in: self.view).y
        case .changed:
            if self.heightConstraint != nil {
                UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseInOut, animations: {
                    self.heightConstraint?.constant = max(self.collapseHeight - 12.0, min(self.expandedHeight + 12.0, sender.location(in: self.view).y + self.panAnchor))
                    self.parent!.view.setNeedsLayout()
                    self.parent!.view.layoutIfNeeded()
                }, completion: nil)
            }
        case .ended, .cancelled:
            let yVelocity = sender.velocity(in: self.view).y
            if yVelocity > 5.0 || (fabs(yVelocity) < 5.0 && self.heightConstraint != nil && fabs(self.heightConstraint!.constant - self.expandedHeight) < fabs(self.heightConstraint!.constant - self.collapseHeight)) {
                self.expandView()
            } else {
                self.collapseView(to: self.collapseHeight)
            }
            break
        default:
            break
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private var _dimView: UIView? = nil
    var dimView: UIView? {
        get {
            if _dimView == nil {
                let vcForBounds = self.parent ?? self
                _dimView = UIView(frame: self.view.convert(vcForBounds.view.bounds, from: vcForBounds.view))
                _dimView?.isUserInteractionEnabled = true
                _dimView?.translatesAutoresizingMaskIntoConstraints = false
                _dimView?.backgroundColor = UIColor.black.withAlphaComponent(0.6)
                if let containingSubview = vcForBounds.view.subviews.first(where: { self.view.isDescendant(of: $0) }) {
                    vcForBounds.view.insertSubview(_dimView!, belowSubview: containingSubview)
                }
                _dimView?.leftAnchor.constraint(equalTo: vcForBounds.view.leftAnchor).isActive = true
                _dimView?.rightAnchor.constraint(equalTo: vcForBounds.view.rightAnchor).isActive = true
                _dimView?.topAnchor.constraint(equalTo: vcForBounds.view.topAnchor).isActive = true
                _dimView?.bottomAnchor.constraint(equalTo: vcForBounds.view.bottomAnchor).isActive = true
                _dimView?.alpha = 0.0
                
                let tapper = UITapGestureRecognizer(target: self, action: #selector(PanelViewController.collapseViewFromDimViewTap(_:)))
                _dimView?.addGestureRecognizer(tapper)
            }
            return _dimView
        }
        set {
            _dimView = newValue
        }
    }
    
    func hideDimView() {
        dimView?.alpha = 0.0
        dimView?.isUserInteractionEnabled = false
    }
    
    func showDimView() {
        dimView?.alpha = 1.0
        dimView?.isUserInteractionEnabled = true
    }
    
    @objc func collapseViewFromDimViewTap(_ sender: UITapGestureRecognizer) {
        guard !self.view.bounds.insetBy(dx: -10.0, dy: -10.0).contains(sender.location(in: self.view)) else {
            return
        }
        collapseView()
    }
    
    func collapseView(to height: CGFloat? = nil) {
        let newHeight = height ?? self.collapseHeight
        guard parent != nil,
            let container = self.view.superview else {
            return
        }
        guard newHeight != 0.0 else {
            print("Can't collapse PanelViewController to height zero. Did you forget to set the collapse height by calling collapseView(to:) with a height value initially?")
            return
        }
        NotificationCenter.default.post(name: .PanelViewControllerWillCollapse, object: self)
        if self.childNavigationController != nil && self.childNavigationController!.viewControllers.count > 1 {
            self.childNavigationController?.popToRootViewController(animated: true)
        }
        self.collapseHeight = newHeight
        bottomConstraint?.constant = 12.0
        for constraint in container.constraints {
            if constraint.firstItem as! NSObject == container && constraint.firstAttribute == .height {
                constraint.isActive = true
                isExpanded = false
                UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseInOut, animations: {
                    constraint.constant = newHeight
                    self.parent!.view.setNeedsLayout()
                    self.parent!.view.layoutIfNeeded()
                    self.hideDimView()
                }, completion: nil)
                break
            }
        }
    }
    
    func expandView() {
        guard !isExpanded,
            parent != nil,
            let container = self.view.superview else {
            return
        }
        NotificationCenter.default.post(name: .PanelViewControllerWillExpand, object: self)
        for constraint in container.constraints {
            if constraint.firstItem as! NSObject == container && constraint.firstAttribute == .height {
                isExpanded = true
                UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseInOut, animations: {
                    constraint.constant = 10000.0
                    self.parent!.view.setNeedsLayout()
                    self.parent!.view.layoutIfNeeded()
                    self.showDimView()
                }, completion: nil)
                break
            }
        }
    }
    
    @objc func keyboardWillChangeFrame(sender: Notification) {
        if self.parent != nil, isExpanded || (UIResponder.first as? UIView)?.isDescendant(of: self.view) == true {
            let deltaY = (sender.userInfo![UIKeyboardFrameBeginUserInfoKey]! as! CGRect).origin.y - (sender.userInfo![UIKeyboardFrameEndUserInfoKey]! as! CGRect).origin.y
            if bottomConstraint == nil, let container = self.view.superview, let sview = container.superview {
                for constraint in sview.constraints {
                    if (constraint.firstItem as? UIView == container && constraint.firstAttribute == .bottom && constraint.secondItem as? UIView == sview) ||
                        (constraint.firstItem as? UIView == sview && constraint.secondAttribute == .bottom && constraint.secondItem as? UIView == container) {
                        bottomConstraint = constraint
                        break
                    }
                }
            }
            if let bottomConstraint = bottomConstraint {
                let newConstant: CGFloat = bottomConstraint.constant + deltaY
                if newConstant < 12.0 {
                    // A junk update value
                    return
                }
                var isExpanding: Bool = false
                if !isExpanded {
                    isExpanding = true
                    heightConstraint?.constant = 10000.0
                    isExpanded = true
                    NotificationCenter.default.post(name: .PanelViewControllerWillExpand, object: self)
                }
                
                let curve: UIViewAnimationOptions = UIViewAnimationOptions(rawValue: (sender.userInfo![UIKeyboardAnimationCurveUserInfoKey] as! NSNumber).uintValue)
                self.parent!.view.setNeedsLayout()
                UIView.animate(withDuration: sender.userInfo![UIKeyboardAnimationDurationUserInfoKey] as! TimeInterval, delay: 0.0, options: [curve, .beginFromCurrentState], animations: {
                    bottomConstraint.constant = newConstant
                    self.parent!.view.layoutIfNeeded()
                    self.childNavigationController?.view.setNeedsLayout()
                    self.childNavigationController?.view.layoutIfNeeded()
                    if isExpanding {
                        self.showDimView()
                    }
                }, completion: nil)
            }
        }
    }
}
