//
//  SecondViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/2/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class CourseroadViewController: UIViewController, PanelParentViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, CourseDetailsDelegate, CourseThumbnailCellDelegate {

    @IBOutlet var collectionView: UICollectionView! = nil
    var currentUser: User? {
        didSet {
            collectionView.reloadData()
        }
    }
    var panelView: PanelViewController? = nil
    var courseBrowser: CourseBrowserViewController? = nil
    var showsSemesterDialogs: Bool {
        return true
    }
    
    @IBOutlet var loadingView: UIView?
    @IBOutlet var loadingIndicator: UIActivityIndicatorView?
    
    @IBOutlet var bigLayoutConstraints: [NSLayoutConstraint]!
    @IBOutlet var smallLayoutConstraints: [NSLayoutConstraint]!
    
    @IBOutlet var layoutToggleButton: UIButton?
    var isSmallLayoutMode = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(courseManagerFinishedLoading(_:)), name: .CourseManagerFinishedLoading, object: nil)
        
        self.collectionView.collectionViewLayout = UICollectionViewFlowLayout() //CustomCollectionViewFlowLayout() //LeftAlignedCollectionViewFlowLayout()
        self.collectionView.allowsSelection = true
        updateCollectionViewLayout()
        
        self.collectionView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(CourseroadViewController.handleLongGesture(gesture:))))
        
        findPanelChildViewController()
        
        let menu = UIMenuController.shared
        menu.menuItems = [
            UIMenuItem(title: MenuItemStrings.view, action: #selector(CourseThumbnailCell.viewDetails(_:)))
        ]
        
        updateLayoutToggleButton()
        
        loadRecentCourseroad()
        
        updateNavigationBar(animated: false)
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
                    self.currentUser?.coursesOfStudy = [ "girs" ]
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
        updateNavigationBar(newTraits: newCollection)
    }
    
    func updateNavigationBar(animated: Bool = true, newTraits: UITraitCollection? = nil) {
        let traits = newTraits ?? traitCollection
        navigationItem.title = "FireRoad"
        let newHiddenValue = traits.horizontalSizeClass != .regular || traits.verticalSizeClass != .regular || traits.userInterfaceIdiom != .pad
        if newHiddenValue != navigationController?.isNavigationBarHidden {
            navigationController?.setNavigationBarHidden(newHiddenValue, animated: animated)
        }
    }
    
    func updateCollectionViewLayout(with traits: UITraitCollection? = nil) {
        let collection = traits ?? traitCollection
        let layout = self.collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        layout.sectionInset = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
        layout.minimumInteritemSpacing = collection.userInterfaceIdiom == .phone ? 8.0 : 12.0
        layout.minimumLineSpacing = 12.0
        layout.itemSize = itemSize
        //layout.estimatedItemSize = CGSize(width: 116.0, height: 94.0)
        collectionView.contentInset = UIEdgeInsets(top: 84.0, left: 0.0, bottom: 0.0, right: 0.0)
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
        updateNavigationBar()

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.collectionView.reloadData()
        updatePanelViewCollapseHeight()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillLayoutSubviews() {
        self.collectionView.collectionViewLayout.invalidateLayout()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func courseManagerFinishedLoading(_ note: Notification) {
        updateCourseWarningStatus()
    }
    
    // MARK: - State Restoration
    
    static let panelVCRestorationKey = "CourseroadVC.panelVC"
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(panelView, forKey: CourseroadViewController.panelVCRestorationKey)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
    }
    
    // MARK: - Collection View

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
            cell.showsWarningIcon = false
            return cell
        }
        cell.shadowEnabled = true
        cell.delegate = self
        let semester = UserSemester(rawValue: indexPath.section)!
        let course = self.currentUser!.courses(forSemester: semester)[indexPath.item]
        cell.textLabel?.text = course.subjectID
        if traitCollection.userInterfaceIdiom == .phone {
            if let font = cell.textLabel?.font {
                cell.textLabel?.font = font.withSize(19.0)
            }
            cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 14.0)
        }
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.hyphenationFactor = 0.7
        paraStyle.alignment = .center
        if let title = course.subjectTitle {
            cell.detailTextLabel?.attributedText = NSAttributedString(string: title, attributes: [.paragraphStyle: paraStyle])
        }
        cell.backgroundColor = CourseManager.shared.color(forCourse: course)
        cell.showsWarningIcon = (currentUser?.warningsForCourse(course, in: semester).count ?? 0) > 0
        
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
            if let button = view.viewWithTag(20) as? UIButton {
                button.setImage(UIImage(named: "ellipsis")?.withRenderingMode(.alwaysTemplate), for: .normal)
                button.removeTarget(nil, action: nil, for: .touchUpInside)
                button.addTarget(self, action: #selector(showActionMenuForSection(_:)), for: .touchUpInside)
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
    
    var itemSize: CGSize {
        let scaleFactor = CGSize(width: traitCollection.userInterfaceIdiom == .pad ? 1.0 : 0.88, height: traitCollection.userInterfaceIdiom == .pad ? 1.0 : 0.88)
        if isSmallLayoutMode {
            return CGSize(width: 116.0 * scaleFactor.width, height: 48.0 * scaleFactor.height)
        }
        return CGSize(width: 116.0 * scaleFactor.width, height: 112.0 * scaleFactor.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return itemSize
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
        }, completion: { _ in
            self.updateCourseWarningStatus()
        })
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
    
    // MARK: - Section Actions
    
    @objc func showActionMenuForSection(_ sender: UIButton) {
        guard let user = currentUser else {
            return
        }
        var tappedSection: Int = -1
        for ip in collectionView.indexPathsForVisibleSupplementaryElements(ofKind: UICollectionElementKindSectionHeader) {
            guard let headerView = collectionView.supplementaryView(forElementKind: UICollectionElementKindSectionHeader, at: ip) else {
                continue
            }
            if sender.isDescendant(of: headerView) {
                tappedSection = ip.section
                break
            }
        }
        
        guard tappedSection != -1,
            let semester = UserSemester(rawValue: tappedSection),
            let tabVC = rootParent as? RootTabViewController else {
            return
        }
        
        let actionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let courses = user.courses(forSemester: semester)
        actionMenu.addAction(UIAlertAction(title: "View Schedule", style: .default, handler: { (action) in
            tabVC.displaySchedule(with: courses)
        }))
        actionMenu.addAction(UIAlertAction(title: "Clear", style: .destructive, handler: { (action) in
            for course in courses {
                user.delete(course, fromSemester: semester)
            }
            UIView.transition(with: self.collectionView, duration: 0.2, options: .transitionCrossDissolve, animations: {
                self.collectionView.reloadData()
            }, completion: nil)
        }))
        actionMenu.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        actionMenu.modalPresentationStyle = .popover
        actionMenu.popoverPresentationController?.sourceView = sender
        actionMenu.popoverPresentationController?.sourceRect = sender.bounds
        present(actionMenu, animated: true, completion: nil)
    }
    
    // MARK: - Model Interaction
        
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
        updateCourseWarningStatus()
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
        updateCourseWarningStatus()
    }
    
    func updateCourseWarningStatus() {
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let cell = collectionView.cellForItem(at: indexPath) as? CourseThumbnailCell,
                let semester = UserSemester(rawValue: indexPath.section),
                let courses = self.currentUser?.courses(forSemester: semester),
                indexPath.item < courses.count else {
                    continue
            }
            let course = courses[indexPath.item]
            cell.showsWarningIcon = (currentUser?.warningsForCourse(course, in: semester).count ?? 0) > 0
        }
    }
    
    // MARK: - View
    
    func updateLayoutToggleButton() {
        layoutToggleButton?.imageView?.contentMode = .center
        layoutToggleButton?.setImage(UIImage(named: isSmallLayoutMode ? "large-grid" : "small-grid")?.withRenderingMode(.alwaysTemplate), for: .normal)
    }
    
    @IBAction func toggleViewLayoutMode(_ sender: AnyObject) {
        isSmallLayoutMode = !isSmallLayoutMode
        for cell in collectionView.visibleCells {
            updateCellForLayoutSizeMode(cell)
        }
        collectionView.collectionViewLayout.invalidateLayout()
        updateLayoutToggleButton()
    }
}
