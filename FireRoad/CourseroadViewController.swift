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
    var currentUser: User? {
        didSet {
            collectionView.reloadData()
        }
    }
    var panelView: PanelViewController? = nil
    var courseBrowser: CourseBrowserViewController? = nil
    
    @IBOutlet var loadingView: UIView?
    @IBOutlet var loadingIndicator: UIActivityIndicatorView?
    
    @IBOutlet var bigLayoutConstraints: [NSLayoutConstraint]!
    @IBOutlet var smallLayoutConstraints: [NSLayoutConstraint]!
    var isSmallLayoutMode = false
    
    let viewMenuItemTitle = "View"
    let deleteMenuItemTitle = "Delete"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if !CourseManager.shared.isLoaded {
            CourseManager.shared.loadCourses { (success: Bool) in
                print("Success: \(success)")
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
        
        loadRecentCourseroad()
    }
    
    let recentCourseroadPathDefaultsKey = "recent-courseroad-filepath"
    
    func loadRecentCourseroad() {
        var loaded = false
        if let recentPath = UserDefaults.standard.string(forKey: recentCourseroadPathDefaultsKey),
            let dirPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            let url = URL(fileURLWithPath: dirPath)
            do {
                currentUser = try User(contentsOfFile: url.appendingPathComponent(recentPath).path)
                loaded = true
            } catch {
                print("Error loading user: \(error)")
            }
        }
        if !loaded {
            if !CourseManager.shared.isLoaded {
                loadingView?.isHidden = false
                loadingIndicator?.startAnimating()
            }
            DispatchQueue.global().async {
                while !CourseManager.shared.isLoaded {
                    usleep(100)
                }
                DispatchQueue.main.async {
                    self.currentUser = User()
                    if let dirPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
                        let url = URL(fileURLWithPath: dirPath)
                        self.currentUser?.filePath = url.appendingPathComponent("first_steps.road").path
                    }
                    self.currentUser?.coursesOfStudy = [ .major67, .minor9, .minor21M ]
                    self.currentUser?.add(CourseManager.shared.getCourse(withID: "8.02")!, toSemester: .FreshmanFall)
                    self.currentUser?.add(CourseManager.shared.getCourse(withID: "5.112")!, toSemester: .FreshmanFall)
                    self.currentUser?.add(CourseManager.shared.getCourse(withID: "6.006")!, toSemester: .FreshmanFall)
                    self.currentUser?.add(CourseManager.shared.getCourse(withID: "17.55")!, toSemester: .FreshmanFall)
                    self.currentUser?.add(CourseManager.shared.getCourse(withID: "18.03")!, toSemester: .FreshmanSpring)
                    self.currentUser?.add(CourseManager.shared.getCourse(withID: "7.013")!, toSemester: .FreshmanSpring)
                    self.currentUser?.add(CourseManager.shared.getCourse(withID: "21M.284")!, toSemester: .FreshmanSpring)
                    self.currentUser?.add(CourseManager.shared.getCourse(withID: "6.046")!, toSemester: .FreshmanSpring)
                    self.currentUser?.autosave()
                    if let path = self.currentUser?.filePath {
                        UserDefaults.standard.set((path as NSString).lastPathComponent, forKey: self.recentCourseroadPathDefaultsKey)
                    }
                    if let loadingView = self.loadingView,
                        let collectionView = self.collectionView {
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
                                self.loadingIndicator?.stopAnimating()
                            }
                        })
                    }
                }
            }
        }

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
    
    @objc func handleLongGesture(gesture: UILongPressGestureRecognizer) {
        
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
            cell.backgroundColor = UIColor.white
            cell.shadowEnabled = false
            cell.textLabel?.text = ""
            cell.detailTextLabel?.text = ""
            return cell
        }
        cell.shadowEnabled = true
        cell.delegate = self
        let course = self.currentUser!.courses(forSemester: UserSemester(rawValue: indexPath.section)!)[indexPath.item]
        cell.textLabel?.text = course.subjectID
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.hyphenationFactor = 0.7
        paraStyle.alignment = .center
        if let title = course.subjectTitle {
            cell.detailTextLabel?.attributedText = NSAttributedString(string: title, attributes: [.paragraphStyle: paraStyle])
        }
        cell.backgroundColor = CourseManager.shared.color(forCourse: course)
        
        if let user = currentUser {
            var unsatisfiedPrereqs: [String] = []
            for prereq in course.prerequisites.flatMap({ $0 }) {
                var satisfied = false
                for semester in UserSemester.allSemesters where semester.rawValue < indexPath.section {
                    for course in user.courses(forSemester: semester) {
                        if course.satisfies(requirement: prereq) {
                            satisfied = true
                            break
                        }
                    }
                    if satisfied {
                        break
                    }
                }
                if !satisfied {
                    unsatisfiedPrereqs.append(prereq)
                }
            }
            var unsatisfiedCoreqs: [String] = []
            for coreq in course.corequisites.flatMap({ $0 }) {
                var satisfied = false
                for semester in UserSemester.allSemesters where semester.rawValue <= indexPath.section {
                    for course in user.courses(forSemester: semester) {
                        if course.satisfies(requirement: coreq) {
                            satisfied = true
                            break
                        }
                    }
                    if satisfied {
                        break
                    }
                }
                if !satisfied {
                    unsatisfiedCoreqs.append(coreq)
                }
            }
            if unsatisfiedPrereqs.count > 0 {
                print("Unsatisfied prereqs for \(course.subjectID!): \(unsatisfiedPrereqs)")
            }
            if unsatisfiedCoreqs.count > 0 {
                print("Unsatisfied coreqs for \(course.subjectID!): \(unsatisfiedCoreqs)")
            }
        }
        
        return cell
    }
    
    /// Used to prevent a ghost cell from appearing beneath the destination of the moving cell.
    var indexPathOfMovedCell: IndexPath?
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if self.currentUser!.courses(forSemester: UserSemester(rawValue: indexPath.section)!).count == 0 {
            cell.alpha = 0.0
            cell.layer.opacity = 0.0
        } else {
            cell.alpha = 1.0
            cell.layer.opacity = 1.0
        }
        
        updateCellForLayoutSizeMode(cell)
        
        if indexPath == indexPathOfMovedCell {
            cell.isHidden = true
            indexPathOfMovedCell = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                cell.isHidden = false
            }
        }
    }
    
    func updateCellForLayoutSizeMode(_ cell: UICollectionViewCell) {
        if let smallLayout = (cell as? CourseThumbnailCell)?.smallLayoutConstraints,
        let bigLayout = (cell as? CourseThumbnailCell)?.bigLayoutConstraints {
            if !isSmallLayoutMode {
                NSLayoutConstraint.deactivate(smallLayout)
                NSLayoutConstraint.activate(bigLayout)
            } else {
                NSLayoutConstraint.deactivate(bigLayout)
                NSLayoutConstraint.activate(smallLayout)
            }
        }
        (cell as? CourseThumbnailCell)?.detailTextLabel?.isHidden = isSmallLayoutMode
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
        if isSmallLayoutMode {
            return CGSize(width: 116.0, height: 48.0)
        }
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
        if menu.isMenuVisible {
            menu.setMenuVisible(false, animated: true)
        } else {
            menu.setTargetRect(cell.bounds, in: cell)
            menu.setMenuVisible(true, animated: true)
        }
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
        if destinationIndexPath != sourceIndexPath {
            indexPathOfMovedCell = destinationIndexPath
        }
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
    
    func courseDetails(added course: Course, to semester: UserSemester?) {
        _ = addCourse(course, to: semester)
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
        if !CourseManager.shared.isLoaded {
            let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            hud.mode = .determinateHorizontalBar
            hud.label.text = "Loading courses…"
            DispatchQueue.global(qos: .background).async {
                let initialProgress = CourseManager.shared.loadingProgress
                while !CourseManager.shared.isLoaded {
                    DispatchQueue.main.async {
                        hud.progress = (CourseManager.shared.loadingProgress - initialProgress) / (1.0 - initialProgress)
                    }
                    usleep(100)
                }
                DispatchQueue.main.async {
                    hud.hide(animated: true)
                    self.viewDetails(for: course)
                }
            }
            return
        }
        if let id = course.subjectID,
            let realCourse = CourseManager.shared.getCourse(withID: id) {
            CourseManager.shared.loadCourseDetails(about: realCourse) { (success) in
                if success {
                    guard let panel = self.panelView,
                        let browser = self.courseBrowser else {
                            return
                    }
                    if !panel.isExpanded {
                        panel.expandView()
                    }
                    
                    let details = self.storyboard!.instantiateViewController(withIdentifier: "CourseDetails") as! CourseDetailsViewController
                    details.course = realCourse
                    details.delegate = self
                    browser.navigationController?.pushViewController(details, animated: true)
                    browser.navigationController?.view.setNeedsLayout()
                } else {
                    print("Failed to load course details!")
                }
            }
        } else if course.subjectID == "GIR" {
            guard let panel = self.panelView,
                let browser = self.courseBrowser else {
                    return
            }
            if !panel.isExpanded {
                panel.expandView()
            }
            
            let listVC = self.storyboard!.instantiateViewController(withIdentifier: "CourseListVC") as! CourseBrowserViewController
            listVC.searchTerm = GIRAttribute(rawValue: course.subjectDescription ?? (course.subjectTitle ?? ""))?.rawValue
            listVC.searchOptions = [.GIR, .HASS, .CI]
            listVC.delegate = self
            listVC.managesNavigation = false
            listVC.view.backgroundColor = UIColor.clear
            browser.navigationController?.pushViewController(listVC, animated: true)
            browser.navigationController?.view.setNeedsLayout()
        }
    }
    
    func addCourse(_ course: Course, to semester: UserSemester? = nil) -> UserSemester? {
        var selectedSemester: UserSemester? = semester
        if selectedSemester == nil {
            for sem in UserSemester.allEnrolledSemesters {
                selectedSemester = sem
                if self.currentUser!.courses(forSemester: sem).contains(course) {
                    break
                }
                if self.currentUser!.courses(forSemester: sem).count >= 4 {
                    continue
                }
                if (sem.isFall() && course.isOfferedFall) ||
                    (sem.isSpring() && course.isOfferedSpring) ||
                    (sem.isIAP() && course.isOfferedIAP) {
                    break
                }
            }
        }
        if selectedSemester != nil {
            if !self.currentUser!.courses(forSemester: selectedSemester!).contains(course) {
                self.currentUser?.add(course, toSemester: selectedSemester!)
                self.collectionView.reloadSections(IndexSet(integer: selectedSemester!.rawValue))
            }
            if let courseItem = self.currentUser?.courses(forSemester: selectedSemester!).index(of: course) {
                self.collectionView.scrollToItem(at: IndexPath(item: courseItem, section: selectedSemester!.rawValue), at: .centeredVertically, animated: true)
            }
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
    
    // MARK: - View
    
    @IBAction func toggleViewLayoutMode(_ sender: AnyObject) {
        isSmallLayoutMode = !isSmallLayoutMode
        for cell in collectionView.visibleCells {
            updateCellForLayoutSizeMode(cell)
        }
        collectionView.collectionViewLayout.invalidateLayout()
    }
}
