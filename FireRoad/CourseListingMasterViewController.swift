//
//  CourseListingMasterViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 12/16/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class CourseListingDisplayController: UIViewController, CourseListCellDelegate, CourseDetailsDelegate, CourseBrowserDelegate, CourseViewControllerProvider, UIPopoverPresentationControllerDelegate {
    var popoverNavigationController: UINavigationController?

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
    
    func viewDetails(for course: Course) {
        viewCourseDetails(for: course, from: nil)
    }
    
    func viewCourseDetails(for course: Course, from rect: CGRect?) {
        generateDetailsViewController(for: course) { (details, list) in
            if let detailVC = details {
                detailVC.showsSemesterDialog = true
                detailVC.delegate = self
                detailVC.view.backgroundColor = .white
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
            listVC.view.backgroundColor = .white
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
}

class CourseListingMasterViewController: CourseListingDisplayController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    var recommendedCourses: [Course] = []
    
    var departments: [(code: String, description: String)] = []
    
    let headings = [
        "For You",
        "Browse Courses"
    ]
    
    @IBOutlet var collectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()

        loadDepartments()
        recommendedCourses = [
            CourseManager.shared.getCourse(withID: "6.046")!,
            CourseManager.shared.getCourse(withID: "7.03")!,
            CourseManager.shared.getCourse(withID: "18.03")!
        ]
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.sectionHeadersPinToVisibleBounds = true
        }
        
        navigationItem.title = "Browse"
    }
    
    func loadDepartments() {
        guard let filePath = Bundle.main.path(forResource: "departments", ofType: "txt"),
            let contents = try? String(contentsOfFile: filePath) else {
                print("Couldn't load departments")
                return
        }
        let comps = contents.components(separatedBy: .newlines)
        departments = comps.flatMap {
            let subcomps = $0.components(separatedBy: "#,#")
            guard subcomps.count == 2 else {
                return nil
            }
            return (subcomps[0], subcomps[1])
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if isViewLoaded {
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        if isViewLoaded {
            collectionView.collectionViewLayout.invalidateLayout()
        }
        if popoverNavigationController != nil {
            dismiss(animated: true, completion: nil)
            popoverNavigationController = nil
        }
    }
    
    // MARK: - Collection View Data Source
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else if section == 1 {
            return departments.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SectionHeader", for: indexPath)
        if let label = view.viewWithTag(12) as? UILabel {
            label.text = headings[indexPath.section]
        }
        view.isHidden = (kind != UICollectionElementKindSectionHeader)
        return view
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = indexPath.section == 0 ? "CourseListCollectionCell" : "DepartmentCell"
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
        if indexPath.section == 0 {
            guard let listCell = cell as? CourseListCollectionCell else {
                print("Invalid course list cell")
                return cell
            }
            listCell.courses = recommendedCourses
            listCell.delegate = self
        } else {
            if let label = cell.viewWithTag(12) as? UILabel {
                label.font = label.font.withSize(traitCollection.userInterfaceIdiom == .phone ? 17.0 : 20.0)
                label.text = "\(departments[indexPath.item].0) – \(departments[indexPath.item].1)"
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if indexPath.section == 1 {
            guard let detailVC = self.storyboard?.instantiateViewController(withIdentifier: "CourseListingVC") as? CourseListingViewController else {
                return
            }
            detailVC.departmentCode = departments[indexPath.item].0
            navigationController?.pushViewController(detailVC, animated: true)
            detailVC.navigationItem.title = departments[indexPath.item].1
        }
    }
    
    // MARK: - Flow Layout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if indexPath.section == 0 {
            return CGSize(width: collectionView.frame.size.width, height: 124.0)
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
}
