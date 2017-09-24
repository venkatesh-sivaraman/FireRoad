//
//  SecondViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/2/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class CourseroadViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, CourseBrowserDelegate, CourseDetailsDelegate, CourseThumbnailCellDelegate {

    @IBOutlet var collectionView: UICollectionView! = nil
    var currentUser: User? = nil
    var panelView: PanelViewController? = nil
    var courseBrowser: CourseBrowserViewController? = nil
    
    @IBOutlet var loadingView: UIView?
    @IBOutlet var loadingIndicator: UIActivityIndicatorView?
    
    let viewMenuItemTitle = "View"
    let deleteMenuItemTitle = "Delete"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if CourseManager.shared.courses.count == 0 {
            loadingView?.isHidden = false
            loadingIndicator?.startAnimating()
            CourseManager.shared.loadCourses { [weak self] (success: Bool) in
                if success {
                    self?.currentUser = User()
                }
                self?.collectionView.reloadData()
                if let loadingView = self?.loadingView,
                    let collectionView = self?.collectionView {
                    collectionView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                    collectionView.alpha = 0.0
                    UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                        collectionView.alpha = 1.0
                        collectionView.transform = CGAffineTransform.identity
                        loadingView.alpha = 0.0
                        loadingView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                    }, completion: { (completed) in
                        if completed {
                            loadingView.isHidden = true
                            self?.loadingIndicator?.stopAnimating()
                        }
                    })
                    /*UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseInOut, animations: {
                    }, completion: { (completed) in
                        if completed {
                            loadingView.isHidden = true
                            self?.loadingIndicator?.stopAnimating()
                        }
                    })*/
                }
            }
        }
        
        self.collectionView.collectionViewLayout = UICollectionViewFlowLayout() //CustomCollectionViewFlowLayout() //LeftAlignedCollectionViewFlowLayout()
        self.collectionView.allowsSelection = true
        updateCollectionViewLayout()
        
        self.collectionView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(CourseroadViewController.handleLongGesture(gesture:))))
        
        for child in self.childViewControllers {
            if child is PanelViewController {
                self.panelView = child as? PanelViewController
                for subchild in self.panelView!.childViewControllers[0].childViewControllers {
                    if subchild is CourseBrowserViewController {
                        self.courseBrowser = subchild as? CourseBrowserViewController
                        break
                    }
                }
            }
        }

        self.courseBrowser?.delegate = self
        
        let menu = UIMenuController.shared
        menu.menuItems = [
            UIMenuItem(title: viewMenuItemTitle, action: #selector(CourseThumbnailCell.viewDetails(_:)))
        ]
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        updateCollectionViewLayout(with: newCollection)
    }
    
    func updateCollectionViewLayout(with traits: UITraitCollection? = nil) {
        let collection = traits ?? self.traitCollection
        let layout = self.collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        layout.sectionInset = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
        layout.minimumInteritemSpacing = 12.0
        layout.minimumLineSpacing = 12.0
        layout.itemSize = CGSize(width: 116.0, height: 112.0)// UICollectionViewFlowLayoutAutomaticSize
        //layout.estimatedItemSize = CGSize(width: 116.0, height: 94.0)
        if collection.horizontalSizeClass == .compact {
            collectionView.contentInset = UIEdgeInsets(top: 84.0, left: 0.0, bottom: 0.0, right: 0.0)
        } else {
            collectionView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
        }
    }
    
    func handleLongGesture(gesture: UILongPressGestureRecognizer) {
        
        switch(gesture.state)
        {
        case UIGestureRecognizerState.began:
            guard let selectedIndexPath = self.collectionView!.indexPathForItem(at: gesture.location(in: self.collectionView)) else {
                break
            }
            collectionView!.beginInteractiveMovementForItem(at: selectedIndexPath)
        case UIGestureRecognizerState.changed:
            let loc = gesture.location(in: gesture.view!)
            collectionView!.updateInteractiveMovementTargetPosition(loc)
        case UIGestureRecognizerState.ended:
            collectionView!.endInteractiveMovement()
        default:
            collectionView!.cancelInteractiveMovement()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.collectionView.reloadData()
        self.panelView?.collapseHeight = self.panelView!.view.frame.size.height
    }
    
    override func viewWillLayoutSubviews() {
        self.collectionView.collectionViewLayout.invalidateLayout()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 13
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if self.currentUser == nil {
            return 0
        }
        if self.currentUser!.courses(forSemester: UserSemester(rawValue: section)!).count == 0 {
            return 1
        }
        return self.currentUser!.courses(forSemester: UserSemester(rawValue: section)!).count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CourseCell", for: indexPath) as! CourseThumbnailCell
        if self.currentUser!.courses(forSemester: UserSemester(rawValue: indexPath.section)!).count == 0 {
            cell.alpha = 0.0
            cell.backgroundColor = UIColor.clear
            return cell
        }
        cell.alpha = 1.0
        cell.delegate = self
        let course = self.currentUser!.courses(forSemester: UserSemester(rawValue: indexPath.section)!)[indexPath.item]
        cell.textLabel?.text = course.subjectID
        cell.detailTextLabel?.text = course.subjectTitle
        cell.backgroundColor = CourseManager.shared.color(forCourse: course)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if self.currentUser!.courses(forSemester: UserSemester(rawValue: indexPath.section)!).count == 0 {
            cell.alpha = 0.0
        } else {
            cell.alpha = 1.0
        }
        
        // Fancy scaling animation
        cell.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        cell.alpha = 0.5
        UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseOut, animations: {
            cell.transform = CGAffineTransform.identity
            cell.alpha = 1.0
        }, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SemesterHeader", for: indexPath)
        if kind == UICollectionElementKindSectionHeader {
            if let titleView = view.viewWithTag(10) as? UILabel {
                titleView.text = UserSemester(rawValue: indexPath.section)?.toString()
            }
        }
        return view
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let layout = collectionViewLayout as! UICollectionViewFlowLayout
        let availableWidth = (self.collectionView.frame.size.width - layout.sectionInset.left - layout.sectionInset.right)
        let cellCount = floor(availableWidth / (layout.itemSize.width + layout.minimumInteritemSpacing))
        let emptySpace = self.collectionView.frame.size.width - cellCount * (layout.itemSize.width + layout.minimumInteritemSpacing) + layout.minimumInteritemSpacing
        return UIEdgeInsets(top: 8.0, left: emptySpace / 2.0, bottom: 8.0, right: emptySpace / 2.0)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.size.width, height: 38.0)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 116.0, height: 112.0)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard self.currentUser!.courses(forSemester: UserSemester(rawValue: indexPath.section)!).count > 0,
            //let semester = UserSemester(rawValue: indexPath.section),
            //let course = currentUser?.courses(forSemester: semester)[indexPath.item] else {
            let cell = collectionView.cellForItem(at: indexPath) else {
            return
        }

        // Selected
        //viewDetails(for: course)
        cell.becomeFirstResponder()
        let menu = UIMenuController.shared
        menu.setTargetRect(cell.bounds, in: cell)
        menu.setMenuVisible(true, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        
    }
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        if self.currentUser!.courses(forSemester: UserSemester(rawValue: indexPath.section)!).count == 0 {
            return false
        }
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let originalSemester = UserSemester(rawValue: sourceIndexPath.section)!
        let destSemester = UserSemester(rawValue: destinationIndexPath.section)!
        let course = self.currentUser!.courses(forSemester: originalSemester)[sourceIndexPath.item]
        self.collectionView.performBatchUpdates({ 
            if self.currentUser!.courses(forSemester: UserSemester(rawValue: destinationIndexPath.section)!).count == 0 {
                self.collectionView.deleteItems(at: [IndexPath(item: destinationIndexPath.item == 0 ? 1 : 0, section: destinationIndexPath.section)])
            }
            self.currentUser!.move(course, fromSemester: originalSemester, toSemester: destSemester, atIndex: destinationIndexPath.item)
            if self.currentUser!.courses(forSemester: UserSemester(rawValue: sourceIndexPath.section)!).count == 0 {
                self.collectionView.insertItems(at: [IndexPath(item: 0, section: sourceIndexPath.section)])
            }
        }, completion: nil)
    }
    
    func courseDetails(added course: Course) {
        _ = addCourse(course)
        self.navigationController?.popViewController(animated: true)
    }
    
    func courseBrowser(added course: Course) -> UserSemester? {
        return addCourse(course)
    }
    
    func courseBrowserRequestedDetails(about course: Course) {
        viewDetails(for: course)
    }
    
    func courseDetailsRequestedDetails(about course: Course) {
        viewDetails(for: course)
    }
    
    // MARK: - Menu Actions
    
    /*func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        guard self.currentUser!.courses(forSemester: UserSemester(rawValue: indexPath.section)!).count > 0 else {
            return false
        }
        return true
    }

    func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return canPerformAction(action, withSender: sender)
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(CourseThumbnailCell.viewDetails(_:)) ||
            action == #selector(CourseThumbnailCell.delete(_:)) {
            return true
        }
        return false
    }
    
    func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
        
    }*/

    func courseThumbnailCellWantsViewDetails(_ cell: CourseThumbnailCell) {
        guard let user = currentUser,
            let indexPath = collectionView.indexPath(for: cell),
            let semester = UserSemester(rawValue: indexPath.section) else {
                return
        }
        let course = user.courses(forSemester: semester)[indexPath.item]
        viewDetails(for: course)
    }
    
    func courseThumbnailCellWantsDelete(_ cell: CourseThumbnailCell) {
        guard let user = currentUser,
            let indexPath = collectionView.indexPath(for: cell),
            let semester = UserSemester(rawValue: indexPath.section) else {
                return
        }
        let course = user.courses(forSemester: semester)[indexPath.item]
        deleteCourse(course, from: semester)
    }
    
    // MARK: - Model Interaction
    
    func viewDetails(for course: Course) {
        CourseManager.shared.loadCourseDetails(about: course) { (success) in
            if success {
                guard let panel = self.panelView,
                    let browser = self.courseBrowser else {
                        return
                }
                if !panel.isExpanded {
                    panel.expandView()
                }
                
                let details = self.storyboard!.instantiateViewController(withIdentifier: "CourseDetails") as! CourseDetailsViewController
                details.course = course
                details.delegate = self
                browser.navigationController?.pushViewController(details, animated: true)
                browser.navigationController?.view.setNeedsLayout()
            } else {
                print("Failed to load course details!")
            }
        }
    }
    
    func addCourse(_ course: Course) -> UserSemester? {
        var selectedSemester: UserSemester? = nil
        for semester in UserSemester.allEnrolledSemesters {
            selectedSemester = semester
            if self.currentUser!.courses(forSemester: semester).count >= 4 {
                continue
            }
            if (semester.isFall() && course.isOfferedFall) ||
                (semester.isSpring() && course.isOfferedSpring) ||
                (semester.isIAP() && course.isOfferedIAP) {
                break
            }
        }
        if selectedSemester != nil {
            self.currentUser?.add(course, toSemester: selectedSemester!)
            self.collectionView.reloadSections(IndexSet(integer: selectedSemester!.rawValue))
        }
        self.panelView?.collapseView(to: self.panelView!.collapseHeight)
        return selectedSemester
    }
    
    func deleteCourse(_ course: Course, from semester: UserSemester) {
        guard let user = currentUser,
            let item = user.courses(forSemester: semester).index(of: course) else {
                return
        }
        let indexPath = IndexPath(item: item, section: semester.rawValue)
        user.delete(course, fromSemester: semester)
        if let cell = collectionView.cellForItem(at: indexPath) {
            let blurView = UIVisualEffectView(frame: cell.convert(cell.bounds, to: collectionView))
            collectionView.addSubview(blurView)
            let effect = UIBlurEffect(style: .light)
            UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseIn, animations: {
                cell.alpha = 0.0
                cell.transform = CGAffineTransform(scaleX: 0.001, y: 0.001)
                blurView.effect = effect
            }) { (completed) in
                if completed {
                    blurView.removeFromSuperview()
                    if user.courses(forSemester: semester).count == 0 {
                        // This cell turns into a dummy cell
                        self.collectionView.reloadItems(at: [indexPath])
                    } else {
                        self.collectionView.deleteItems(at: [indexPath])
                    }
                }
            }
        } else {
            if user.courses(forSemester: semester).count == 0 {
                // This cell turns into a dummy cell
                self.collectionView.reloadItems(at: [indexPath])
            } else {
                self.collectionView.deleteItems(at: [indexPath])
            }
        }
    }
}

// MARK: - Flow Layout -

class CustomCollectionViewFlowLayout: UICollectionViewFlowLayout {
    
    var animator: UIDynamicAnimator? = nil
    var visibleIPs: [IndexPath] = []
    
    func addVisibleCell(with indexPath: IndexPath) {
        self.visibleIPs.append(indexPath)
        let attribs = self.layoutAttributesForItem(at: indexPath)!
        let attachment = UIAttachmentBehavior(item: attribs, attachedToAnchor: attribs.center)
        attachment.length = 0.0
        attachment.damping = 0.8
        attachment.frequency = 1.0
        self.animator?.addBehavior(attachment)
    }
    
    func removeVisibleCell(with indexPath: IndexPath) {
        if let idx = self.visibleIPs.index(of: indexPath) {
            self.visibleIPs.remove(at: idx)
            
            if let bIdx = (self.animator!.behaviors as! [UIAttachmentBehavior]).index(where: { ($0.items.first! as! UICollectionViewLayoutAttributes).indexPath == indexPath }) {
                self.animator?.removeBehavior(self.animator!.behaviors[bIdx])
            }
        }
    }
    
    override init() {
        super.init()
        self.animator = UIDynamicAnimator(collectionViewLayout: self)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.animator = UIDynamicAnimator(collectionViewLayout: self)
    }
    
    override func prepare() {
        super.prepare()
        if self.animator != nil && self.animator!.behaviors.count == 0 {
            self.visibleIPs = []
            self.animator?.removeAllBehaviors()
            for ip in self.collectionView!.indexPathsForVisibleItems {
                self.addVisibleCell(with: ip)
            }
            
        }
    }
    
    /*override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return self.animator!.items(in: rect) as? [UICollectionViewLayoutAttributes]
    }*/
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        if let attribs = self.animator!.layoutAttributesForCell(at: indexPath) {
            return attribs
        }
        return super.layoutAttributesForItem(at: indexPath)
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        let delta = newBounds.origin.y - self.collectionView!.bounds.origin.y
        let loc = self.collectionView!.panGestureRecognizer.location(in: self.collectionView!)
        self.animator!.behaviors.forEach { (beh) in
            let behavior = beh as! UIAttachmentBehavior
            let yDist: CGFloat = CGFloat(fabs(loc.y - behavior.anchorPoint.y)),
            xDist: CGFloat = CGFloat(fabs(loc.x - behavior.anchorPoint.x))
            let scrollResistance: CGFloat = (yDist + xDist) / 150.0
            let item = behavior.items.first!
            var center = item.center
            center.y += delta * 10.0 //max(delta, delta * scrollResistance)
            item.center = center
            self.animator?.updateItem(usingCurrentState: item)
        }
        
        return false
    }
    
    
    
    /*override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let attributes = super.layoutAttributesForElements(in: rect)?.map({ $0.copy() as! UICollectionViewLayoutAttributes })
        if attributes != nil && attributes!.count > 0 && (attributes![0].representedElementCategory != UICollectionElementCategory.cell || attributes![0].indexPath.item != 0) {
            attributes?.forEach { layoutAttribute in
                layoutAttribute.frame.origin.x -= sectionInset.left
            }
            return attributes
        }
        
        var leftMargin = sectionInset.left
        var maxY: CGFloat = -1.0
        attributes?.forEach { layoutAttribute in
            if layoutAttribute.representedElementCategory == UICollectionElementCategory.cell {
                if layoutAttribute.frame.origin.y >= maxY {
                    leftMargin = sectionInset.left
                }
                layoutAttribute.frame.origin.x = leftMargin
                
                leftMargin += layoutAttribute.frame.width + minimumInteritemSpacing
                maxY = max(layoutAttribute.frame.maxY, maxY)
            }
        }
        if attributes != nil {
            var row: [UICollectionViewLayoutAttributes] = []
            var x: CGFloat = 10000.0
            var minY: CGFloat = 10000.0
            for layoutAttribute in attributes! {
                if layoutAttribute.representedElementCategory != UICollectionElementCategory.cell {
                    continue
                }
                if layoutAttribute.frame.origin.x < x {
                    for attrib in row {
                        attrib.frame.origin.y = minY
                    }
                    x = layoutAttribute.frame.origin.x
                    row = []
                    minY = 10000.0
                }
                row.append(layoutAttribute)
                if layoutAttribute.frame.origin.y < minY {
                    minY = layoutAttribute.frame.origin.y
                }
                x = layoutAttribute.frame.origin.x + layoutAttribute.frame.size.width
            }
        }
        
        return attributes
    }*/
    
}
