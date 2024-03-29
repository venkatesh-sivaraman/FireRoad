//
//  SecondViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/2/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class CourseroadViewController: UIViewController, PanelParentViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, CourseDetailsDelegate, CourseThumbnailCellDelegate, CourseroadWarningsDelegate, UIBarPositioningDelegate, DocumentBrowseDelegate, UIPopoverPresentationControllerDelegate, UIDocumentInteractionControllerDelegate, CustomCoursesViewControllerDelegate, CustomCourseEditDelegate {

    @IBOutlet var collectionView: UICollectionView! = nil
    var currentUser: User? {
        guard let rootTab = rootParent as? RootTabViewController else {
            return nil
        }
        return rootTab.currentUser
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
    @IBOutlet var warningsButton: UIButton?
    @IBOutlet var openButton: UIButton?
    @IBOutlet var shareButton: UIButton?
    @IBOutlet var customActivityButton: UIButton?

    @IBOutlet var layoutToggleItem: UIBarButtonItem?
    @IBOutlet var warningsItem: UIBarButtonItem?
    @IBOutlet var openItem: UIBarButtonItem?
    @IBOutlet var shareItem: UIBarButtonItem?
    @IBOutlet var customActivityItem: UIBarButtonItem?
    @IBOutlet var toolbarTitleLabel: UILabel?
    
    @IBOutlet var placeholderView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(courseManagerFinishedLoading(_:)), name: .CourseManagerFinishedLoading, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(cloudSyncManagerFinishedSyncing(_:)), name: .CloudSyncManagerFinishedSyncing, object: CloudSyncManager.roadManager)

        self.collectionView.collectionViewLayout = UICollectionViewFlowLayout() //CustomCollectionViewFlowLayout() //LeftAlignedCollectionViewFlowLayout()
        self.collectionView.allowsSelection = true
        updateCollectionViewLayout()
        
        self.collectionView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(CourseroadViewController.handleLongGesture(gesture:))))
        
        findPanelChildViewController()
        
        updateLayoutToggleButton()
                
        updateNavigationBar(animated: false)        
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        guard isViewLoaded else {
            return
        }
        updateCollectionViewLayout(with: newCollection)
        updateNavigationBar(newTraits: newCollection)
        if #available(iOS 12.0, *) {
            if newCollection.userInterfaceStyle != traitCollection.userInterfaceStyle {
                collectionView.reloadData()
            }
        }
    }
    
    func updateNavigationBar(animated: Bool = true, newTraits: UITraitCollection? = nil) {
        /*let traits = newTraits ?? traitCollection
         navigationItem.title = "FireRoad"
         let newHiddenValue = traits.horizontalSizeClass != .regular || traits.verticalSizeClass != .regular || traits.userInterfaceIdiom != .pad
         if newHiddenValue != navigationController?.isNavigationBarHidden {
         navigationController?.setNavigationBarHidden(newHiddenValue, animated: animated)
         }*/
    }
    
    func updateCollectionViewLayout(with traits: UITraitCollection? = nil) {
        let collection = traits ?? traitCollection
        guard isViewLoaded,
            let layout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }
        layout.sectionInset = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
        layout.minimumInteritemSpacing = collection.userInterfaceIdiom == .phone ? 8.0 : 12.0
        layout.minimumLineSpacing = 12.0
        layout.itemSize = itemSize
        //layout.estimatedItemSize = CGSize(width: 116.0, height: 94.0)
        let top: CGFloat = 84.0 + (collection.horizontalSizeClass == .regular && collection.verticalSizeClass == .regular ? 44.0 : 0.0)
        collectionView.contentInset = UIEdgeInsets(top: top, left: 0.0, bottom: 0.0, right: 0.0)
    }
    
    @objc func handleLongGesture(gesture: UILongPressGestureRecognizer) {
        
        switch(gesture.state)
        {
        case UIGestureRecognizerState.began:
            guard let selectedIndexPath = self.collectionView!.indexPathForItem(at: gesture.location(in: self.collectionView)) else {
                break
            }
            if UIMenuController.shared.isMenuVisible {
                UIMenuController.shared.setMenuVisible(false, animated: true)
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
        currentUser?.clearWarningsCache()
        reloadViewAfterCollectionViewUpdate()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reloadCollectionView()
        if let offset = collectionViewOffsetWhenLoaded {
            collectionView.setContentOffset(offset, animated: false)
            collectionViewOffsetWhenLoaded = nil
        }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.updateCourseWarningStatus()
            self.currentUser?.setBaselineRatings()
        }
        updateLayoutToggleButton()
    }
    
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        guard traitCollection.horizontalSizeClass == .regular,
            traitCollection.verticalSizeClass == .regular else {
                return .any
        }
        return .topAttached
    }
    
    func reloadCollectionView() {
        guard isViewLoaded else {
            return
        }
        collectionView.reloadData()
        reloadViewAfterCollectionViewUpdate()
    }
    
    func reloadViewAfterCollectionViewUpdate() {
        placeholderView?.isHidden = !(currentUser == nil || currentUser?.allCourses.count == 0)
        updateCourseWarningStatus()
    }
    
    // MARK: - Handling Courseroads
    
    func loadCourseroad(named name: String) {
        guard let rootTab = rootParent as? RootTabViewController else {
            return
        }
        rootTab.loadCourseroad(named: name)
        reloadCollectionView()
        collectionView.scrollRectToVisible(CGRect(x: 0.0, y: 0.0, width: 4.0, height: 4.0), animated: true)
    }
    
    func loadNewCourseroad(named name: String) {
        guard let rootTab = rootParent as? RootTabViewController else {
            return
        }
        rootTab.loadNewCourseroad(named: name)
        reloadCollectionView()
        collectionView.scrollRectToVisible(CGRect(x: 0.0, y: 0.0, width: 4.0, height: 4.0), animated: true)
    }
    
    func waitForUser() {
        guard let rootTab = rootParent as? RootTabViewController else {
            return
        }
        if !rootTab.isLoadingUser {
            reloadCollectionView()
            collectionView.scrollRectToVisible(CGRect(x: 0.0, y: 0.0, width: 4.0, height: 4.0), animated: true)
        } else {
            if !CourseManager.shared.isLoaded {
                loadingView?.isHidden = false
                loadingIndicator?.startAnimating()
            }
            DispatchQueue.global().async {
                while rootTab.isLoadingUser {
                    usleep(100)
                }
                DispatchQueue.main.async {
                    self.reloadCollectionView()
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
    
    var documentInteractionController: UIDocumentInteractionController?
    var temporaryFileURL: URL?
    
    @IBAction func shareItemTapped(_ sender: AnyObject) {
        guard let path = currentUser?.filePath else {
            return
        }
        let actionSheet = UIAlertController(title: nil, message: "Choose a format to share:", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "PDF", style: .default, handler: { _ in
            var activityItems: [Any] = []
            self.collectionView.renderToPDF({ (data) in
                if let data = data {
                    let url = URL(fileURLWithPath: path).deletingPathExtension().appendingPathExtension("pdf")
                    do {
                        try data.write(to: url)
                        self.temporaryFileURL = url
                        activityItems.append(url)
                    } catch {
                        print("Error writing data: \(data)")
                    }
                } else {
                    let provider = ScheduleItemProvider(placeholderItem: UIImage(), renderingBlock: { () -> Any in
                        return self.collectionView.renderToImage()
                    })
                    activityItems.append(provider)
                }
                let actionVC = UIActivityViewController(activityItems: activityItems, applicationActivities: [])
                actionVC.completionWithItemsHandler = { (_, _, _, _) in
                    if let url = self.temporaryFileURL {
                        try? FileManager.default.removeItem(at: url)
                    }
                }
                if self.traitCollection.userInterfaceIdiom == .pad,
                    let barItem = sender as? UIBarButtonItem {
                    actionVC.modalPresentationStyle = .popover
                    actionVC.popoverPresentationController?.barButtonItem = barItem
                }
                self.present(actionVC, animated: true, completion: nil)
            })
        }))
        actionSheet.addAction(UIAlertAction(title: "FireRoad Document", style: .default, handler: { _ in
            let url = URL(fileURLWithPath: path)
            let actionVC = UIDocumentInteractionController(url: url)
            actionVC.uti = "com.base12innovations.FireRoad.road"
            actionVC.delegate = self
            if self.traitCollection.userInterfaceIdiom == .pad,
                let barItem = sender as? UIBarButtonItem {
                actionVC.presentOptionsMenu(from: barItem, animated: true)
            } else if let view = sender as? UIView {
                actionVC.presentOptionsMenu(from: view.bounds, in: view, animated: true)
            }
            self.documentInteractionController = actionVC
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        if self.traitCollection.userInterfaceIdiom == .pad,
            let barItem = sender as? UIBarButtonItem {
            actionSheet.modalPresentationStyle = .popover
            actionSheet.popoverPresentationController?.barButtonItem = barItem
        }
        present(actionSheet, animated: true, completion: nil)
    }
    
    func documentInteractionControllerDidDismissOptionsMenu(_ controller: UIDocumentInteractionController) {
        documentInteractionController = nil
    }
        
    // MARK: - State Restoration
    
    var collectionViewOffsetWhenLoaded: CGPoint?
    
    static let panelVCRestorationKey = "CourseroadVC.panelVC"
    static let collectionViewOffsetRestorationKey = "CourseroadVC.collectionViewOffset"

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(panelView, forKey: CourseroadViewController.panelVCRestorationKey)
        if isViewLoaded, collectionView.contentOffset.y >= collectionView.contentInset.top {
            coder.encode(collectionView.contentOffset, forKey: CourseroadViewController.collectionViewOffsetRestorationKey)
        }
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        collectionViewOffsetWhenLoaded = coder.decodeCGPoint(forKey: CourseroadViewController.collectionViewOffsetRestorationKey)
    }
    
    // MARK: - Collection View

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return UserSemester.allSemesters.count
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
        if (self.currentUser?.courses(forSemester: UserSemester(rawValue: indexPath.section)!).count ?? 0) <= indexPath.item {
            cell.alpha = 0.0
            if #available(iOS 13.0, *) {
                cell.backgroundColor = .systemBackground
            } else {
                cell.backgroundColor = .white
            }
            cell.shadowEnabled = false
            cell.textLabel?.text = ""
            cell.detailTextLabel?.text = ""
            cell.showsWarningIcon = false
            cell.showsViewMenuItem = false
            cell.showsRateMenuItem = false
            cell.showsMarkMenuItem = false
            return cell
        }
        cell.shadowEnabled = true
        cell.delegate = self
        let semester = UserSemester(rawValue: indexPath.section)!
        let course = self.currentUser!.courses(forSemester: semester)[indexPath.item]
        cell.course = course
        cell.generateMarkerImageView()
        cell.marker = self.currentUser!.subjectMarker(for: course, in: semester)
        cell.textLabel?.text = course.subjectID
        if traitCollection.userInterfaceIdiom == .phone {
            if let font = cell.textLabel?.font, font.pointSize != 19.0 {
                cell.textLabel?.font = font.withSize(19.0)
            }
            if let font = cell.detailTextLabel?.font, font.pointSize != 13.0 {
                cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 13.0)
            }
        }
        cell.detailTextLabel?.text = course.subjectTitle ?? ""
        cell.backgroundColor = CourseManager.shared.color(forCourse: course)
        if CourseManager.shared.isLoaded,
            !AppSettings.shared.hidesAllWarnings,
            (currentUser?.warningsForCourse(course, in: semester).count ?? 0) > 0 {
            if currentUser?.overridesWarnings(for: course) == false {
                cell.showsWarningIcon = true
            } else {
                cell.showsWarningIcon = false
            }
            cell.showsWarningsMenuItem = true
        } else {
            cell.showsWarningIcon = false
            cell.showsWarningsMenuItem = false
        }
        cell.showsRateMenuItem = !course.isGeneric && course.creator == nil
        cell.showsEditMenuItem = course.creator != nil
        cell.showsViewMenuItem = course.creator == nil
        cell.showsMarkMenuItem = true
        
        return cell
    }
    
    /// Used to prevent a ghost cell from appearing beneath the destination of the moving cell.
    var indexPathOfMovedCell: IndexPath?
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if self.currentUser?.courses(forSemester: UserSemester(rawValue: indexPath.section)!).count == 0 {
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
            initializeSectionHeaderView(view, for: indexPath)
        }
        return view
    }
    
    func initializeSectionHeaderView(_ view: UIView, for indexPath: IndexPath) {
        if let titleView = view.viewWithTag(10) as? UILabel {
            titleView.text = UserSemester(rawValue: indexPath.section)?.toString()
        }
        if let button = view.viewWithTag(20) as? UIButton {
            button.setImage(UIImage(named: "ellipsis")?.withRenderingMode(.alwaysTemplate), for: .normal)
            button.removeTarget(nil, action: nil, for: .touchUpInside)
            button.addTarget(self, action: #selector(showActionMenuForSection(_:)), for: .touchUpInside)
        }
        if let unitsLabel = view.viewWithTag(30) as? UILabel,
            let semester = UserSemester(rawValue: indexPath.section),
            let semesterCourses = currentUser?.courses(forSemester: semester) {
            let totalUnits = semesterCourses.reduce(0, { $0 + $1.totalUnits })
            var unitsText = "\(totalUnits) units"
            var totalHours: Float = 0.0
            if semester != .PreviousCredit, CourseManager.shared.isLoaded {
                totalHours = semesterCourses.reduce(0.0, { $0 + ($1.inClassHours + $1.outOfClassHours) / ($1.quarterOffered != .wholeSemester ? 2.0 : 1.0) })
                unitsText += " • " + String(format: "%.1f hours", totalHours)
            }
            unitsLabel.text = unitsText
            unitsLabel.isHidden = (totalUnits == 0 && totalHours == 0.0)
        }
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
        if self.currentUser?.courses(forSemester: UserSemester(rawValue: indexPath.section)!).count == 0 {
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
        if originalSemester != destSemester && self.currentUser!.courses(forSemester: destSemester).contains(course) {
            // Don't allow
            self.reloadCollectionView()
        } else {
            self.collectionView.performBatchUpdates({
                if self.currentUser!.courses(forSemester: UserSemester(rawValue: destinationIndexPath.section)!).count == 0 {
                    self.collectionView.deleteItems(at: [IndexPath(item: destinationIndexPath.item == 0 ? 1 : 0, section: destinationIndexPath.section)])
                }
                self.currentUser!.move(course, fromSemester: originalSemester, toSemester: destSemester, atIndex: destinationIndexPath.item)
                if self.currentUser!.courses(forSemester: UserSemester(rawValue: sourceIndexPath.section)!).count == 0 {
                    self.collectionView.insertItems(at: [IndexPath(item: 0, section: sourceIndexPath.section)])
                }
            }, completion: { _ in
                self.reloadViewAfterCollectionViewUpdate()
            })
        }
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
        let courses = user.courses(forSemester: semester)
        guard indexPath.item < courses.count else {
            return
        }
        viewDetails(for: courses[indexPath.item])
    }
    
    func courseThumbnailCellWantsEdit(_ cell: CourseThumbnailCell) {
        guard let user = currentUser,
            let indexPath = collectionView.indexPath(for: cell),
            let semester = UserSemester(rawValue: indexPath.section) else {
                return
        }
        let courses = user.courses(forSemester: semester)
        guard indexPath.item < courses.count,
            courses[indexPath.item].creator != nil else {
            return
        }
        
        guard let editVC = storyboard?.instantiateViewController(withIdentifier: "CustomCourseEditVC") as? CustomCourseEditViewController else {
            return
        }
        editVC.delegate = self
        editVC.course = courses[indexPath.item]
        editVC.showsCancelButton = true
        editVC.doneButtonMode = .save
        let nav = UINavigationController(rootViewController: editVC)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true, completion: nil)
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
    
    func courseThumbnailCellWantsShowWarnings(_ cell: CourseThumbnailCell) {
        showWarningsViewController(with: cell.course)
    }
    
    func courseThumbnailCellWantsRate(_ cell: CourseThumbnailCell) {
        guard let rater = storyboard?.instantiateViewController(withIdentifier: "RatePopover") as? RateIndividualViewController else {
            return
        }
        rater.course = cell.course
        rater.modalPresentationStyle = .popover
        rater.popoverPresentationController?.delegate = self
        rater.popoverPresentationController?.sourceRect = cell.bounds
        rater.popoverPresentationController?.sourceView = cell
        self.present(rater, animated: true, completion: nil)
    }
    
    func courseThumbnailCellWantsMark(_ cell: CourseThumbnailCell) {
        guard let user = currentUser,
            let course = cell.course,
            let indexPath = collectionView.indexPath(for: cell),
            let semester = UserSemester(rawValue: indexPath.section) else {
                return
        }
        let marker = user.subjectMarker(for: course, in: semester)
        let tableMenu = TableMenuViewController()
        tableMenu.items = [TableMenuItem(identifier: "none", title: "None")] + SubjectMarker.allMarkers.map({ TableMenuItem(identifier: $0.rawValue, title: $0.readableName(), image: UIImage(named: $0.imageName())) })
        tableMenu.selectedItemIndex = tableMenu.items.index(where: { $0.identifier == marker?.rawValue ?? "none"}) ?? -1
        tableMenu.action = { item in
            user.setSubjectMarker(SubjectMarker(rawValue: item.identifier), for: course, in: semester)
            self.reloadCollectionView()
        }
        tableMenu.modalPresentationStyle = .popover
        tableMenu.popoverPresentationController?.delegate = self
        tableMenu.popoverPresentationController?.sourceView = cell
        tableMenu.popoverPresentationController?.sourceRect = cell.bounds
        present(tableMenu, animated: true, completion: nil)
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
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
            tabVC.displaySchedule(with: courses, name: semester.toString())
        }))
        actionMenu.addAction(UIAlertAction(title: "Add Custom Activity", style: .default, handler: { (action) in
            self.showCustomCourseMenu(from: semester)
        }))
        actionMenu.addAction(UIAlertAction(title: "Clear", style: .destructive, handler: { (action) in
            for course in courses {
                user.delete(course, fromSemester: semester)
            }
            UIView.transition(with: self.collectionView, duration: 0.2, options: .transitionCrossDissolve, animations: {
                self.reloadCollectionView()
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
        guard currentUser != nil else {
            return nil
        }
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
                let reloadWholeView = (currentUser == nil || currentUser?.allCourses.count == 0)
                self.currentUser?.add(course, toSemester: selectedSemester!)
                if self.isViewLoaded {
                    if reloadWholeView {
                        self.collectionView.reloadData()
                    } else {
                        self.collectionView.reloadSections(IndexSet(integer: selectedSemester!.rawValue))
                    }
                }
            }
            if self.isViewLoaded,
                let courseItem = self.currentUser?.courses(forSemester: selectedSemester!).index(of: course) {
                self.collectionView.scrollToItem(at: IndexPath(item: courseItem, section: selectedSemester!.rawValue), at: .centeredVertically, animated: true)
            }
        }
        self.panelView?.collapseView(to: self.panelView!.collapseHeight)
        self.reloadViewAfterCollectionViewUpdate()
        return selectedSemester
    }
    
    func deleteCourse(_ course: Course, from semester: UserSemester) {
        guard let user = currentUser,
            let item = user.courses(forSemester: semester).index(of: course) else {
                return
        }
        print("Current user is \(user)")
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
        reloadViewAfterCollectionViewUpdate()
    }
    
    func updateCourseWarningStatus() {
        guard isViewLoaded else {
            return
        }
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let cell = collectionView.cellForItem(at: indexPath) as? CourseThumbnailCell,
                let semester = UserSemester(rawValue: indexPath.section),
                let courses = self.currentUser?.courses(forSemester: semester),
                indexPath.item < courses.count else {
                    continue
            }
            let course = courses[indexPath.item]
            if CourseManager.shared.isLoaded,
                !AppSettings.shared.hidesAllWarnings,
                (currentUser?.warningsForCourse(course, in: semester).count ?? 0) > 0 {
                if currentUser?.overridesWarnings(for: course) == false {
                    cell.showsWarningIcon = true
                } else {
                    cell.showsWarningIcon = false
                }
                cell.showsWarningsMenuItem = true
            } else {
                cell.showsWarningIcon = false
                cell.showsWarningsMenuItem = false
            }
            cell.showsRateMenuItem = !course.isGeneric
        }
        
        // Update headers
        for indexPath in collectionView.indexPathsForVisibleSupplementaryElements(ofKind: UICollectionElementKindSectionHeader) {
            guard let view = collectionView.supplementaryView(forElementKind: UICollectionElementKindSectionHeader, at: indexPath) else {
                continue
            }
            initializeSectionHeaderView(view, for: indexPath)
        }
    }
    
    // MARK: - View
    
    func updateLayoutToggleButton() {
        layoutToggleButton?.imageView?.contentMode = .center
        let toggleImage = UIImage(named: isSmallLayoutMode ? "large-grid" : "small-grid")
        layoutToggleButton?.setImage(toggleImage?.withRenderingMode(.alwaysTemplate), for: .normal)
        layoutToggleItem?.image = toggleImage
        
        warningsButton?.setImage(warningsButton?.image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .normal)
        warningsButton?.isEnabled = CourseManager.shared.isLoaded
        warningsItem?.isEnabled = CourseManager.shared.isLoaded
        
        openButton?.setImage(openButton?.image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .normal)
        shareButton?.setImage(shareButton?.image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .normal)
        customActivityButton?.setImage(customActivityButton?.image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .normal)
    }
    
    @IBAction func toggleViewLayoutMode(_ sender: AnyObject) {
        isSmallLayoutMode = !isSmallLayoutMode
        for cell in collectionView.visibleCells {
            updateCellForLayoutSizeMode(cell)
        }
        collectionView.collectionViewLayout.invalidateLayout()
        updateLayoutToggleButton()
    }
    
    // MARK: - Loading Different Roads
    
    var documentBrowser: DocumentBrowseViewController?
    lazy var thumbnailImageComputeQueue = ComputeQueue(label: "CourseroadVC.thumbnailImage")
    
    @IBAction func openButtonPressed(_ sender: AnyObject) {
        guard let browser = storyboard?.instantiateViewController(withIdentifier: "DocumentBrowser") as? DocumentBrowseViewController,
            let rootTab = rootParent as? RootTabViewController else {
                return
        }
        documentBrowser = browser
        browser.delegate = self
        // Generate items
        browser.items = loadDocumentBrowserItems()
        if browser.items.count > 1 {
            browser.itemToHighlight = browser.items.first(where: { $0.identifier == (rootTab.currentUser?.filePath as NSString?)?.lastPathComponent })
        }
        
        let nav = UINavigationController(rootViewController: browser)
        browser.navigationItem.title = "My Roads"
        if let barItem = sender as? UIBarButtonItem {
            browser.showsCancelButton = false
            nav.modalPresentationStyle = .popover
            nav.popoverPresentationController?.barButtonItem = barItem
            present(nav, animated: true, completion: nil)
        } else {
            browser.navigationItem.prompt = "Select an existing road or add a new one."
            browser.showsCancelButton = true
            present(nav, animated: true, completion: nil)
        }
    }
    
    @objc func cloudSyncManagerFinishedSyncing(_ note: Notification) {
        if let browser = documentBrowser,
            (note.object as? CloudSyncManager)?.lastSyncHadChange == true {
            browser.items = loadDocumentBrowserItems()
        }
    }
    
    func loadDocumentBrowserItems() -> [DocumentBrowseViewController.Item] {
        guard let roadDir = CloudSyncManager.roadManager.filesDirectory,
            let dirContents = try? FileManager.default.contentsOfDirectory(atPath: roadDir) else {
                return []
        }
        
        var items: [(DocumentBrowseViewController.Item, Date?)] = []
        let todayFormatter = DateFormatter()
        todayFormatter.dateStyle = .none
        todayFormatter.timeStyle = .short
        let otherFormatter = DateFormatter()
        otherFormatter.dateStyle = .medium
        otherFormatter.timeStyle = .none
        for path in dirContents {
            let fullPath = (roadDir as NSString).appendingPathComponent(path)
            guard path.range(of: ".road")?.upperBound == path.endIndex,
                path[path.startIndex] != Character("."),
                let tempUser = try? User(contentsOfFile: fullPath, readOnly: true) else {
                    continue
            }
            let courses = tempUser.coursesOfStudy.compactMap({ RequirementsListManager.shared.requirementList(withID: $0)?.mediumTitle }).joined(separator: ", ")
            let attr = try? FileManager.default.attributesOfItem(atPath: fullPath)
            let modDate = attr?[FileAttributeKey.modificationDate] as? Date
            var components: [String] = []
            if let date = modDate {
                if Calendar.current.isDateInToday(date) {
                    components.append(todayFormatter.string(from: date))
                } else {
                    components.append(otherFormatter.string(from: date))
                }
            }
            components.append(courses)
            var item = DocumentBrowseViewController.Item(identifier: path, title: (path as NSString).deletingPathExtension, description: components.joined(separator: " • "), image: tempUser.emptyThumbnailImage())
            thumbnailImageComputeQueue.async {
                item.image = tempUser.generateThumbnailImage()
                DispatchQueue.main.async {
                    self.documentBrowser?.update(item: item)
                }
            }
            items.append((item, modDate))
        }
        return items.sorted(by: {
            if $1.1 == nil && $0.1 == nil {
                return false
            } else if $1.1 == nil {
                return true
            } else if $0.1 == nil {
                return false
            }
            return $0.1!.compare($1.1!) == .orderedDescending
        }).map({ $0.0 })
    }
    
    func documentBrowserDismissed(_ browser: DocumentBrowseViewController) {
        dismiss(animated: true, completion: nil)
        documentBrowser = nil
    }
    
    func documentBrowserAddedItem(_ browser: DocumentBrowseViewController) {
        let alert = UIAlertController(title: "New Road", message: "Choose a title for your new road:", preferredStyle: .alert)
        let presenter = self.presentedViewController ?? self
        alert.addTextField { (tf) in
            tf.placeholder = "Title"
            tf.enablesReturnKeyAutomatically = true
            tf.clearButtonMode = .always
            tf.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { _ in
            guard let text = alert.textFields?.first?.text,
                text.count > 0 else {
                    let errorAlert = UIAlertController(title: "No Title", message: "You must choose a title in order to create the new road.", preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                    presenter.present(errorAlert, animated: true, completion: nil)
                    return
            }
            
            let newID = text + ".road"
            guard let rootTab = self.rootParent as? RootTabViewController,
                let newURL = rootTab.urlForCourseroad(named: newID),
                !FileManager.default.fileExists(atPath: newURL.path) else {
                    let errorAlert = UIAlertController(title: "Road Already Exists", message: "Please choose another title.", preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                    presenter.present(errorAlert, animated: true, completion: nil)
                    return
            }

            self.dismiss(animated: true, completion: nil)
            self.documentBrowser = nil
            self.loadNewCourseroad(named: newID)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        presenter.present(alert, animated: true, completion: nil)
    }
    
    func documentBrowser(_ browser: DocumentBrowseViewController, deletedItem item: DocumentBrowseViewController.Item) {
        guard let rootTab = rootParent as? RootTabViewController,
            let url = rootTab.urlForCourseroad(named: item.identifier) else {
            return
        }
        CloudSyncManager.roadManager.deleteFile(with: (item.identifier as NSString).deletingPathExtension) { _ in
            if self.currentUser?.filePath == url.path {
                if let firstItem = browser.items.first {
                    self.loadCourseroad(named: firstItem.identifier)
                } else {
                    self.loadNewCourseroad(named: InitialDocumentTitle + CloudSyncManager.roadManager.pathExtension)
                    self.dismiss(animated: true, completion: nil)
                    self.documentBrowser = nil
                }
            }
        }
    }
    
    func documentBrowser(_ browser: DocumentBrowseViewController, wantsRename item: DocumentBrowseViewController.Item, completion: @escaping ((DocumentBrowseViewController.Item?) -> Void)) {
        let alert = UIAlertController(title: "Rename Road", message: "Choose a new title:", preferredStyle: .alert)
        let presenter = self.presentedViewController ?? self
        alert.addTextField { (tf) in
            tf.placeholder = "Title"
            tf.text = item.title
            tf.enablesReturnKeyAutomatically = true
            tf.clearButtonMode = .always
            tf.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Rename", style: .default, handler: { _ in
            guard let text = alert.textFields?.first?.text,
                text.count > 0,
                let rootTab = self.rootParent as? RootTabViewController else {
                    completion(nil)
                    return
            }
            
            CloudSyncManager.roadManager.renameFile(at: item.identifier, to: text, completion: { newURL in
                if let destURL = newURL {
                    let newItem = DocumentBrowseViewController.Item(identifier: destURL.lastPathComponent, title: text, description: item.description, image: item.image)
                    var shouldOpenNewRoad = false
                    if (self.currentUser?.filePath as NSString?)?.lastPathComponent == item.identifier {
                        rootTab.currentUser = nil
                        shouldOpenNewRoad = true
                    }
                    if shouldOpenNewRoad {
                        self.loadCourseroad(named: newItem.identifier)
                    }
                    completion(newItem)
                } else {
                    print("Failed to rename road")
                }
            })
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        presenter.present(alert, animated: true, completion: nil)
    }
    
    func documentBrowser(_ browser: DocumentBrowseViewController, wantsDuplicate item: DocumentBrowseViewController.Item, completion: @escaping ((DocumentBrowseViewController.Item?) -> Void)) {
        guard let rootTab = self.rootParent as? RootTabViewController,
            let oldURL = rootTab.urlForCourseroad(named: item.identifier) else {
                return
        }
        let presenter = self.presentedViewController ?? self

        let base = (item.identifier as NSString).deletingPathExtension
        var newID = base + " 2"
        if let newURL = rootTab.urlForCourseroad(named: newID + ".road"),
            FileManager.default.fileExists(atPath: newURL.path) {
            var counter = 3
            while let otherURL = rootTab.urlForCourseroad(named: base + " \(counter).road"),
                FileManager.default.fileExists(atPath: otherURL.path) {
                    counter += 1
            }
            newID = base + " \(counter)"
        }
        
        do {
            let newItem = DocumentBrowseViewController.Item(identifier: newID + ".road", title: newID, description: item.description, image: item.image)
            guard let newURL = rootTab.urlForCourseroad(named: newID + ".road") else {
                completion(nil)
                return
            }
            try FileManager.default.copyItem(at: oldURL, to: newURL)
            completion(newItem)
        } catch {
            let alert = UIAlertController(title: "Could Not Duplicate Road", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
            presenter.present(alert, animated: true, completion: nil)
            completion(nil)
        }
    }
    
    func documentBrowser(_ browser: DocumentBrowseViewController, selectedItem item: DocumentBrowseViewController.Item) {
        loadCourseroad(named: item.identifier)
        dismiss(animated: true, completion: nil)
        documentBrowser = nil
    }
    
    // MARK: - Warnings
    
    func showWarningsViewController(with focusedCourse: Course? = nil) {
        guard let warningVC = self.storyboard?.instantiateViewController(withIdentifier: "WarningsVC") as? CourseroadWarningsViewController else {
            return
        }
        warningVC.delegate = self
        warningVC.focusedCourse = focusedCourse
        if let user = currentUser {
            var warnings: [(Course, [User.CourseWarning], Bool)] = []
            // Make sure there aren't duplicate sets of warnings in the warnings list
            var addedCourses: [Course: Int] = [:]
            for semester in UserSemester.allEnrolledSemesters {
                let courses = user.courses(forSemester: semester)
                for course in courses {
                    let courseWarnings = user.warningsForCourse(course, in: semester)
                    if courseWarnings.count > 0 {
                        if let existing = addedCourses[course],
                            warnings[existing].1 == courseWarnings {
                            continue
                        }
                        warnings.append((course, courseWarnings, user.overridesWarnings(for: course)))
                        addedCourses[course] = warnings.count - 1
                    }
                }
            }
            warningVC.allWarnings = warnings
        }
        let nav = UINavigationController(rootViewController: warningVC)
        nav.modalPresentationStyle = .formSheet
        self.present(nav, animated: true, completion: nil)
    }
    
    @IBAction func showWarningsFromButton(_ sender: AnyObject?) {
        showWarningsViewController()
    }
    
    func warningsControllerDismissed(_ warningsController: CourseroadWarningsViewController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func warningsController(_ warningsController: CourseroadWarningsViewController, requestedDetailsAbout course: Course) {
        generateDetailsViewController(for: course, showGenericDetails: true) { (details, list) in
            if let detailVC = details {
                detailVC.displayStandardMode = true
                detailVC.showsSemesterDialog = true
                detailVC.delegate = self
                warningsController.navigationController?.pushViewController(detailVC, animated: true)
            } else if let listVC = list {
                listVC.delegate = self
                listVC.managesNavigation = false
                listVC.showsSemesterDialog = true
                if #available(iOS 13.0, *) {
                    listVC.view.backgroundColor = .systemBackground
                } else {
                    listVC.view.backgroundColor = .white
                }
                warningsController.navigationController?.pushViewController(listVC, animated: true)
            }
        }
    }
    
    func warningsController(_ warningsController: CourseroadWarningsViewController, setOverride override: Bool, for course: Course) {
        currentUser?.setOverridesWarnings(override, for: course)
        reloadCollectionView()
    }
    
    // MARK: - Custom Courses
    
    @IBAction func customActivityItemTapped(_ sender: Any) {
        showCustomCourseMenu()
    }
    
    func showCustomCourseMenu(from semester: UserSemester? = nil) {
        guard let customCourseVC = storyboard?.instantiateViewController(withIdentifier: "CustomCourseVC") as? CustomCoursesViewController else {
            return
        }
        customCourseVC.delegate = self
        customCourseVC.semester = semester
        
        let nav = UINavigationController(rootViewController: customCourseVC)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true, completion: nil)
    }
    
    func customCoursesViewController(_ controller: CustomCoursesViewController, addedCourseToSchedule course: Course) {
        dismiss(animated: true, completion: nil)
        addCourseToSchedule(course)
    }
    
    func customCoursesViewController(_ controller: CustomCoursesViewController, added course: Course, to semester: UserSemester) {
        dismiss(animated: true, completion: nil)
        _ = addCourse(course, to: semester)
    }
    
    func customCoursesViewControllerDismissed(_ controller: CustomCoursesViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    func customCourseEditViewController(_ controller: CustomCourseEditViewController, finishedEditing course: Course) {
        CourseManager.shared.setCustomCourse(course)
        if let user = currentUser {
            user.setNeedsSave()
        }
        reloadCollectionView()
        dismiss(animated: true, completion: nil)
    }
    
    func customCourseEditViewControllerDismissed(_ controller: CustomCourseEditViewController) {
        dismiss(animated: true, completion: nil)
    }
}
