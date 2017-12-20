//
//  CourseListingViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 12/16/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class CourseListingViewController: CourseListingDisplayController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UISearchBarDelegate {

    @IBOutlet var collectionView: UICollectionView!
    
    var departmentCode: String = "1"
    var courses: [Course] = []
    
    var currentSearchText: String?
    var searchCourses: [Course]?
    
    let searchBarHeight = CGFloat(60.0)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        } else {
            // Fallback on earlier versions
        }
    }
    
    var courseLoadingHUD: MBProgressHUD?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !CourseManager.shared.isLoaded || !CourseManager.shared.loadedDepartments.contains(departmentCode) {
            guard courseLoadingHUD == nil else {
                return
            }
            let hud = MBProgressHUD.showAdded(to: self.splitViewController?.view ?? self.view, animated: true)
            hud.mode = .determinateHorizontalBar
            hud.label.text = "Loading courses…"
            courseLoadingHUD = hud
            DispatchQueue.global(qos: .background).async {
                let initialProgress = CourseManager.shared.loadingProgress
                while !CourseManager.shared.isLoaded {
                    DispatchQueue.main.async {
                        hud.progress = (CourseManager.shared.loadingProgress - initialProgress) / (1.0 - initialProgress)
                    }
                    usleep(100)
                }
                CourseManager.shared.loadCourseDetailsSynchronously(for: self.departmentCode)
                self.courses = CourseManager.shared.getCourses(forDepartment: self.departmentCode)
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                    hud.hide(animated: true)
                }
            }
        } else {
            self.courses = CourseManager.shared.getCourses(forDepartment: self.departmentCode)
            self.collectionView.reloadData()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        collectionView.collectionViewLayout.invalidateLayout()
        if popoverNavigationController != nil {
            dismiss(animated: true, completion: nil)
            popoverNavigationController = nil
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Collection View Data Source
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searchCourses?.count ?? courses.count
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SearchView", for: indexPath)
        if let searchBar = view.viewWithTag(12) as? UISearchBar {
            searchBar.delegate = self
            searchBar.text = currentSearchText ?? ""
        }
        view.isHidden = (searchCourses?.count ?? courses.count) == 0
        return view
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = "CourseListingCell"
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
        let course = searchCourses?[indexPath.item] ?? courses[indexPath.item]
        if let thumbnail = cell.viewWithTag(7) as? CourseThumbnailCell {
            if thumbnail.textLabel == nil {
                thumbnail.generateLabels(withDetail: false)
            }
            thumbnail.loadThumbnailAppearance()
            thumbnail.course = course
            thumbnail.textLabel?.text = course.subjectID ?? ""
            thumbnail.backgroundColor = CourseManager.shared.color(forCourse: course)
            thumbnail.isUserInteractionEnabled = false
        }
        if let label = cell.viewWithTag(12) as? UILabel {
            label.text = (course.subjectTitle ?? "") + (course.subjectLevel == .graduate ? " (G)" : "")
        }
        if let infoLabel = cell.viewWithTag(34) as? UILabel {
            var seasons: [String] = []
            if course.isOfferedFall {
                seasons.append("fall")
            }
            if course.isOfferedIAP {
                seasons.append("IAP")
            }
            if course.isOfferedSpring {
                seasons.append("spring")
            }
            if course.isOfferedSummer {
                seasons.append("summer")
            }
            infoLabel.text = "\(seasons.joined(separator: ", ").capitalizingFirstLetter()) • \(course.totalUnits) units"
        }
        if let descriptionLabel = cell.viewWithTag(56) as? UILabel {
            descriptionLabel.text = course.subjectDescription ?? "No description available."
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let course = searchCourses?[indexPath.item] ?? courses[indexPath.item]
        guard let cell = collectionView.cellForItem(at: indexPath) else {
            return
        }
        viewCourseDetails(for: course, from: cell.convert(cell.bounds, to: self.view))
    }
    
    // MARK: - Flow Layout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if traitCollection.horizontalSizeClass == .regular {
            return CGSize(width: collectionView.frame.size.width / 2.0, height: 190.0)
        } else {
            return CGSize(width: collectionView.frame.size.width, height: 190.0)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return .zero
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.size.width, height: searchBarHeight)
    }
    
    // MARK: - Search
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.count > 0 {
            filterCourses(with: searchBar)
        } else {
            clearSearch()
        }
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(false, animated: true)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        clearSearch()
        searchBar.resignFirstResponder()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        filterCourses(with: searchBar)
        searchBar.resignFirstResponder()
    }
    
    func clearSearch() {
        currentSearchText = nil
        let oldCourseCount = searchCourses?.count ?? courses.count
        let newCourses = courses
        searchCourses = nil
        collectionView.performBatchUpdates({
            if newCourses.count > oldCourseCount {
                collectionView.insertItems(at: (oldCourseCount..<newCourses.count).map({ IndexPath(item: $0, section: 0) }))
            } else if newCourses.count < oldCourseCount {
                collectionView.deleteItems(at: (newCourses.count..<oldCourseCount).map({ IndexPath(item: $0, section: 0) }))
            }
            collectionView.reloadItems(at: (0..<min(newCourses.count, oldCourseCount)).map({ IndexPath(item: $0, section: 0) }))
        }, completion: nil)
    }
    
    func filterCourses(with searchBar: UISearchBar) {
        let searchTerm = searchBar.text ?? ""
        currentSearchText = searchTerm
        let oldCourseCount = searchCourses?.count ?? courses.count
        let newCourses = self.courses.filter({ $0.subjectID?.contains(searchTerm) == true || $0.subjectTitle?.contains(searchTerm) == true })
        searchCourses = newCourses
        collectionView.performBatchUpdates({
            if newCourses.count > oldCourseCount {
                collectionView.insertItems(at: (oldCourseCount..<newCourses.count).map({ IndexPath(item: $0, section: 0) }))
            } else if newCourses.count < oldCourseCount {
                collectionView.deleteItems(at: (newCourses.count..<oldCourseCount).map({ IndexPath(item: $0, section: 0) }))
            }
            collectionView.reloadItems(at: (0..<min(newCourses.count, oldCourseCount)).map({ IndexPath(item: $0, section: 0) }))
        }, completion: nil)
        searchBar.becomeFirstResponder()
    }
}
