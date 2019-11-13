//
//  CourseListingMasterViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 12/16/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class CourseListingDisplayController: UICollectionViewController, CourseListCellDelegate, CourseDetailsDelegate, CourseBrowserDelegate, CourseViewControllerProvider, UIPopoverPresentationControllerDelegate, PopDownTableMenuDelegate {
    var popoverNavigationController: UINavigationController?

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        navigationController?.enumerateChildViewControllers { (vc) in
            if let listVC = vc as? CourseDetailsViewController {
                listVC.delegate = self
            } else if let browserVC = vc as? CourseBrowserViewController {
                browserVC.delegate = self
            }
        }
    }
    // MARK: - Course List Cell Delegate
    
    func courseListCell(_ cell: CourseListCell, selected course: Course) {
        guard let courseIndex = cell.courses.index(of: course),
            let selectedCell = cell.collectionView.cellForItem(at: IndexPath(item: courseIndex, section: 0)) else {
                return
        }
        viewCourseDetails(for: course, from: selectedCell.convert(selectedCell.bounds, to: self.view))
    }
    
    func addCourse(_ course: Course, to semester: UserSemester? = nil) -> UserSemester? {
        guard let tabVC = rootParent as? RootTabViewController else {
            print("Root isn't a tab bar controller!")
            return nil
        }
        if presentedViewController != nil {
            dismiss(animated: true, completion: nil)
            popoverNavigationController = nil
        }
        let ret = tabVC.addCourse(course, to: semester)
        return ret
    }
    
    func addCourseToSchedule(_ course: Course) {
        guard let tabVC = rootParent as? RootTabViewController else {
            print("Root isn't a tab bar controller!")
            return
        }
        if presentedViewController != nil {
            dismiss(animated: true, completion: nil)
            popoverNavigationController = nil
        }
        tabVC.addCourseToSchedule(course)
    }
    
    func courseDetails(added course: Course, to semester: UserSemester?) {
        _ = addCourse(course, to: semester)
    }
    
    func courseDetailsRequestedDetails(about course: Course) {
        viewDetails(for: course)
    }
    
    func viewDetails(for course: Course, showGenericDetails: Bool = true) {
        viewCourseDetails(for: course, from: nil)
    }
    
    func viewCourseDetails(for course: Course, from rect: CGRect?) {
        generateDetailsViewController(for: course, showGenericDetails: true) { (details, list) in
            if let detailVC = details {
                detailVC.displayStandardMode = true
                detailVC.showsSemesterDialog = true
                detailVC.delegate = self
                self.showInformationalViewController(detailVC, from: rect ?? CGRect.zero)
            } else if let listVC = list {
                listVC.delegate = self
                listVC.managesNavigation = false
                listVC.showsSemesterDialog = true
                listVC.view.backgroundColor = .white
                self.showInformationalViewController(listVC, from: rect ?? CGRect.zero)
            }
        }
    }
    
    func courseDetails(addedCourseToSchedule course: Course) {
        addCourseToSchedule(course)
    }
    
    func courseDetailsRequestedPostReqs(for course: Course) {
        generatePostReqsViewController(for: course) { (list) in
            guard let listVC = list else {
                return
            }
            listVC.delegate = self
            listVC.managesNavigation = false
            listVC.showsSemesterDialog = true
            if #available(iOS 13.0, *) {
                listVC.view.backgroundColor = .systemBackground
            } else {
                listVC.view.backgroundColor = .white
            }
            self.showInformationalViewController(listVC)
        }
    }
    
    func courseDetailsRequestedOpen(url: URL) {
        guard let webVC = generateURLViewController(for: url) else {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return
        }
        webVC.view.backgroundColor = .white
        showInformationalViewController(webVC)
    }
    
    /// Shows the view controller in a popover on iPad, and pushes it on iPhone.
    func showInformationalViewController(_ vc: UIViewController, from rect: CGRect = CGRect.zero) {
        if traitCollection.horizontalSizeClass == .regular,
            traitCollection.userInterfaceIdiom == .pad {
            vc.restorationIdentifier = nil
            if let nav = popoverNavigationController {
                nav.pushViewController(vc, animated: true)
            } else {
                let nav = UINavigationController(rootViewController: vc)
                nav.modalPresentationStyle = .popover
                nav.popoverPresentationController?.sourceRect = rect
                nav.popoverPresentationController?.sourceView = self.view
                nav.popoverPresentationController?.delegate = self
                present(nav, animated: true)
                popoverNavigationController = nav
            }
        } else {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        popoverNavigationController = nil
    }
    
    // MARK: - Pop Down Table Menu
    
    var popDownOldNavigationTitle: String?
    
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourseToFavorites course: Course) {
        if CourseManager.shared.favoriteCourses.contains(course) {
            CourseManager.shared.markCourseAsNotFavorite(course)
        } else {
            CourseManager.shared.markCourseAsFavorite(course)
        }
        popDownTableMenuCanceled(tableMenu)
    }
    
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourseToSchedule course: Course) {
        addCourseToSchedule(course)
        popDownTableMenuCanceled(tableMenu)
    }
    
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourse course: Course, to semester: UserSemester) {
        _ = addCourse(course, to: semester)
        popDownTableMenuCanceled(tableMenu)
    }
    
    func popDownTableMenuCanceled(_ tableMenu: PopDownTableMenuController) {
        navigationItem.rightBarButtonItem?.isEnabled = true
        if let oldTitle = popDownOldNavigationTitle {
            navigationItem.title = oldTitle
        }
        tableMenu.hide(animated: true) {
            tableMenu.willMove(toParentViewController: nil)
            tableMenu.view.removeFromSuperview()
            tableMenu.removeFromParentViewController()
            tableMenu.didMove(toParentViewController: nil)
        }
    }
}

class CourseListingMasterViewController: CourseListingDisplayController, UICollectionViewDelegateFlowLayout, AppSettingsViewControllerDelegate {

    var recommendedCourses: [Course] = []
    var recommendationMessage: String?
    
    var additionalRecommendations: [(String, [Course])] = []
    
    let headings = [
        "For You",
        "Departments"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let layout = collectionView?.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.sectionHeadersPinToVisibleBounds = true
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(CourseListingMasterViewController.courseManagerFinishedLoading(_:)), name: .CourseManagerFinishedLoading, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupCollectionViewData()
    }
    
    func setupCollectionViewData() {
        recommendedCourses = []
        additionalRecommendations = []
        if let recs = CourseManager.shared.subjectRecommendations {
            setRecommendedCourses(from: recs)
        } else {
            CourseManager.shared.fetchSubjectRecommendations { (recs, message) in
                DispatchQueue.main.async {
                    if let message = message {
                        self.recommendationMessage = message
                    }
                    if let recs = recs {
                        self.setRecommendedCourses(from: recs)
                    }
                    self.collectionView?.reloadSections(IndexSet(integer: 0))
                }
            }
        }
        collectionView?.reloadData()
    }
    
    func setRecommendedCourses(from subjectRecs: [String: [Course: Float]]) {
        additionalRecommendations = []
        for (recKey, recSet) in subjectRecs {
            var newRecSet = recSet
            if let rootTab = rootParent as? RootTabViewController,
                let user = rootTab.currentUser {
                newRecSet = recSet.filter {
                    !user.allCourses.contains($0.key)
                }
            }

            if recKey == "for-you" {
                self.recommendedCourses = newRecSet.sorted(by: { $0.value > $1.value }).map { $0.key }
            } else if let title = recommendationTitle(for: recKey) {
                additionalRecommendations.append((title, newRecSet.sorted(by: { $0.value > $1.value }).map { $0.key }))
            }
        }
    }
    
    /**
     This function decodes the server's recommendation key names into human-readable
     strings. Add new recommendation types here to ensure that they are presented
     to the user.
     */
    private func recommendationTitle(for key: String) -> String? {
        let components = key.components(separatedBy: ":")
        RequirementsListManager.shared.loadRequirementsLists()
        switch components[0] {
        case "course":
            if components[1] == "girs" {
                return nil
            }
            guard let reqList = RequirementsListManager.shared.requirementList(withID: components[1]),
                let shortTitle = reqList.shortTitle ?? reqList.mediumTitle ?? reqList.title else {
                    return nil
            }
            var category: String
            if components[1].range(of: "major", options: .caseInsensitive) != nil {
                category = "majors"
            } else if components[1].range(of: "minor", options: .caseInsensitive) != nil {
                category = "minors"
            } else if components[1].range(of: "master", options: .caseInsensitive) != nil {
                category = "masters students"
            } else {
                category = "students"
            }
            
            return "\(shortTitle) \(category) may also like…"
        case "subject":
            return "Because you selected \(components[1])…"
        case "top-subjects":
            return "Top rated"
        case "after":
            return "What to take after \(components[1])"
        case "keyword":
            return "If you like \(components[1])…"
        default:
            return nil
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if isViewLoaded {
            collectionView?.collectionViewLayout.invalidateLayout()
        }
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        if isViewLoaded {
            collectionView?.collectionViewLayout.invalidateLayout()
        }
        if popoverNavigationController != nil {
            dismiss(animated: true, completion: nil)
            popoverNavigationController = nil
        }
        if #available(iOS 12.0, *) {
            if traitCollection.userInterfaceStyle != newCollection.userInterfaceStyle {
                collectionView?.reloadData()
            }
        }
    }
    
    @objc func courseManagerFinishedLoading(_ note: Notification) {
        setupCollectionViewData()
    }
    
    // MARK: - Collection View Data Source
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 1 + additionalRecommendations.count * 2
        } else if section == 1 {
            return CourseManager.shared.departments.count
        }
        return 0
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SectionHeader", for: indexPath)
        if let label = view.viewWithTag(12) as? UILabel {
            label.text = headings[indexPath.section]
        }
        view.isHidden = (kind != UICollectionElementKindSectionHeader)
        return view
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            if CourseManager.shared.isLoadingSubjectRecommendations || !CourseManager.shared.isLoaded {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LoadingCoursesCell", for: indexPath)
                (cell.viewWithTag(12) as? UIActivityIndicatorView)?.startAnimating()
                return cell
            } else if recommendedCourses.count == 0 {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ErrorCell", for: indexPath)
                if let label = cell.viewWithTag(12) as? UILabel {
                    if let message = recommendationMessage {
                        label.text = message
                    } else if AppSettings.shared.allowsRecommendations != true {
                        label.text = "Turn on Sync and Recommendations in the settings menu above to receive recommendations."
                    } else if !CourseManager.shared.isConnectedToNetwork {
                        label.text = "Couldn't connect to the server to receive recommendations."
                    } else if !CourseManager.shared.isLoggedIn {
                        label.text = "Log in from the settings menu above to receive recommendations."
                    } else {
                        label.text = "You don't have any recommendations at the moment. Try again later!"
                    }
                }
                return cell
            } else {
                if indexPath.item % 2 == 0 {
                    // List of courses
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CourseListCollectionCell", for: indexPath)
                    guard let listCell = cell as? CourseListCollectionCell else {
                        print("Invalid course list cell")
                        return cell
                    }
                    listCell.courses = indexPath.item == 0 ? recommendedCourses : additionalRecommendations[indexPath.item / 2 - 1].1
                    listCell.delegate = self
                    listCell.longPressTarget = self
                    listCell.longPressAction = #selector(CourseListingMasterViewController.longPressOnListCell(_:))
                    return listCell
                } else {
                    // Recommendation section header
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SubHeaderCell", for: indexPath)
                    if let label = cell.viewWithTag(12) as? UILabel {
                        label.text = additionalRecommendations[(indexPath.item - 1) / 2].0
                    }
                    return cell
                }
            }
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "DepartmentCell", for: indexPath)
            if let label = cell.viewWithTag(12) as? UILabel {
                label.font = label.font.withSize(traitCollection.userInterfaceIdiom == .phone ? 17.0 : 20.0)
                let departments = CourseManager.shared.departments
                label.text = "\(departments[indexPath.item].code) – \(departments[indexPath.item].description)"
            }
            return cell
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if indexPath.section == 1 {
            guard let detailVC = self.storyboard?.instantiateViewController(withIdentifier: "CourseListingVC") as? CourseListingViewController else {
                return
            }
            let departments = CourseManager.shared.departments
            detailVC.departmentCode = departments[indexPath.item].code
            navigationController?.pushViewController(detailVC, animated: true)
            if traitCollection.userInterfaceIdiom == .pad {
                detailVC.navigationItem.title = departments[indexPath.item].description
            } else {
                detailVC.navigationItem.title = departments[indexPath.item].shortName
            }
        }
    }
    
    // MARK: - Flow Layout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if indexPath.section == 0 {
            if indexPath.item % 2 == 0 {
                return CGSize(width: collectionView.frame.size.width, height: 124.0)
            } else {
                return CGSize(width: collectionView.frame.size.width, height: 48.0)
            }
        } else if indexPath.section == 1 {
            if traitCollection.horizontalSizeClass == .regular {
                return CGSize(width: collectionView.frame.size.width / 2.0, height: 48.0)
            } else {
                return CGSize(width: collectionView.frame.size.width, height: 48.0)
            }
        }
        return CGSize.zero
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.size.width, height: 52.0)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize.zero
    }
    
    // MARK: - Pop Down Table Menu
    
    @objc func longPressOnListCell(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began,
            let popDown = self.storyboard?.instantiateViewController(withIdentifier: "PopDownTableMenu") as? PopDownTableMenuController,
            let cell = sender.view as? CourseThumbnailCell,
            let id = cell.course?.subjectID,
            CourseManager.shared.getCourse(withID: id) != nil else {
                return
        }
        popDown.course = cell.course
        popDown.delegate = self
        let containingView: UIView = self.view
        containingView.addSubview(popDown.view)
        popDown.view.translatesAutoresizingMaskIntoConstraints = false
        popDown.view.leftAnchor.constraint(equalTo: containingView.leftAnchor).isActive = true
        popDown.view.rightAnchor.constraint(equalTo: containingView.rightAnchor).isActive = true
        popDown.view.bottomAnchor.constraint(equalTo: containingView.bottomAnchor).isActive = true
        popDown.view.topAnchor.constraint(equalTo: containingView.topAnchor).isActive = true
        popDown.willMove(toParentViewController: self)
        self.addChildViewController(popDown)
        popDown.didMove(toParentViewController: self)
        let generator = UIImpactFeedbackGenerator()
        generator.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            popDown.show(animated: true)
            generator.impactOccurred()
        }
    }
    
    // MARK: - Settings
    
    @IBAction func settingsButtonTapped(_ sender: AnyObject) {
        guard let settings = storyboard?.instantiateViewController(withIdentifier: "AppSettingsVC") as? AppSettingsViewController else {
            return
        }
        settings.delegate = self
        let nav = UINavigationController(rootViewController: settings)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true, completion: nil)
    }
    
    func settingsViewControllerDismissed(_ settings: AppSettingsViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    func settingsViewControllerWantsAuthenticationView(_ settings: AppSettingsViewController) {
        dismiss(animated: true) {
            CourseManager.shared.loginIfNeeded({ _ in })
        }
    }
}
