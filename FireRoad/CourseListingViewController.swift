//
//  CourseListingViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 12/16/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class CourseListingViewController: CourseListingDisplayController, UISearchResultsUpdating, UISearchControllerDelegate, UICollectionViewDelegateFlowLayout, CourseFilterDelegate {

    var departmentCode: String = "1"
    var courses: [Course] = []
    
    var currentSearchText: String?
    var searchCourses: [Course]?
    
    let searchBarHeight = CGFloat(60.0)
    
    var searchController: UISearchController?
    
    @IBOutlet var filterItem: UIBarButtonItem?
    @IBOutlet var filterButton: UIButton? // The UIButton inside the filter item
    
    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView?.alwaysBounceVertical = true
        // Do any additional setup after loading the view.
        searchController = UISearchController(searchResultsController: nil)
        searchController?.searchResultsUpdater = self
        searchController?.delegate = self
        searchController?.dimsBackgroundDuringPresentation = false
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
        }
        searchController?.searchBar.placeholder = "Filter subjects…"
        
        NotificationCenter.default.addObserver(self, selector: #selector(CourseListingViewController.courseManagerFinishedLoading(_:)), name: .CourseManagerFinishedLoading, object: nil)
        
        let options = UserDefaults.standard.integer(forKey: searchOptionsDefaultsKey)
        if options > 0 {
            searchOptions = SearchOptions(rawValue: options)
        }
        
        // Make sure button is square
        if let button = filterButton {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalTo: button.heightAnchor, multiplier: 1.0).isActive = true
        }
        updateFilterButton()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var courseLoadingHUD: MBProgressHUD?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !CourseManager.shared.isLoaded || !CourseManager.shared.loadedDepartments.contains(departmentCode) {
            guard courseLoadingHUD == nil else {
                return
            }
            let hud = MBProgressHUD.showAdded(to: self.splitViewController?.view ?? self.view, animated: true)
            if !CourseManager.shared.isLoaded {
                hud.mode = .determinateHorizontalBar
            } else {
                hud.mode = .indeterminate
            }
            hud.label.text = "Loading subjects…"
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
                DispatchQueue.main.async {
                    hud.hide(animated: true)
                    self.setupCollectionViewData()
                }
            }
        } else {
            setupCollectionViewData()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        collectionView?.collectionViewLayout.invalidateLayout()
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        collectionView?.collectionViewLayout.invalidateLayout()
        if popoverNavigationController != nil {
            dismiss(animated: true, completion: nil)
            popoverNavigationController = nil
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setupCollectionViewData() {
        self.courses = CourseManager.shared.getCourses(forDepartment: self.departmentCode)
        self.collectionView?.reloadData()
        if (currentSearchText?.count ?? 0) > 0 || searchOptions.containsCourseFilters {
            self.loadSearchResults(withString: currentSearchText ?? "", options: searchOptions)
        }
    }
    
    @objc func courseManagerFinishedLoading(_ note: Notification) {
        setupCollectionViewData()
    }
    
    // MARK: - State Preservation
    
    static let departmentCodeRestorationKey = "CourseListingVC.departmentCode"
    static let navigationTitleRestorationKey = "CourseListingVC.navTitle"

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(departmentCode, forKey: CourseListingViewController.departmentCodeRestorationKey)
        coder.encode(navigationItem.title, forKey: CourseListingViewController.navigationTitleRestorationKey)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        departmentCode = (coder.decodeObject(forKey: CourseListingViewController.departmentCodeRestorationKey) as? String) ?? ""
        navigationItem.title = (coder.decodeObject(forKey: CourseListingViewController.navigationTitleRestorationKey) as? String) ?? departmentCode
    }
    
    // MARK: - Collection View Data Source
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searchCourses?.count ?? courses.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SearchView", for: indexPath)
        if #available(iOS 11.0, *) {
            // Show the search bar in the navigation bar instead
            view.isHidden = true
            return view
        } else {
            if let searchBar = view.viewWithTag(12) as? UISearchBar, searchBar != searchController?.searchBar,
                let newBar = searchController?.searchBar {
                /*searchBar.delegate = self
                 searchBar.text = currentSearchText ?? ""*/
                searchBar.removeFromSuperview()
                view.addSubview(newBar)
                newBar.tag = 12
                newBar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
                newBar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
                newBar.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
                newBar.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            }
            view.isHidden = (searchCourses?.count ?? courses.count) == 0
            return view
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
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
            var infoText = "\(seasons.joined(separator: ", ").capitalizingFirstLetter()) • "
            if course.isVariableUnits {
                infoText += "units arranged"
            } else {
                infoText += "\(course.totalUnits) units"
            }
            if course.rating > 0.0 {
                infoText += " • " + String(format: "%.1f/7.0", course.rating) + " ★"
            }
            infoLabel.text = infoText
        }
        if let descriptionLabel = cell.viewWithTag(56) as? UILabel {
            descriptionLabel.text = course.subjectDescription ?? "No description available."
        }
        
        if let longPress = cell.gestureRecognizers?.first(where: { $0 is UILongPressGestureRecognizer }) {
            cell.removeGestureRecognizer(longPress)
        }
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(CourseListingViewController.longPressOnListingCell(_:)))
        longPress.minimumPressDuration = 0.5
        cell.addGestureRecognizer(longPress)

        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let course = searchCourses?[indexPath.item] ?? courses[indexPath.item]
        guard let cell = collectionView.cellForItem(at: indexPath) else {
            return
        }
        searchController?.dismiss(animated: true, completion: nil)
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
        if #available(iOS 11.0, *) {
            return .zero
        }
        return CGSize(width: collectionView.frame.size.width, height: searchBarHeight)
    }
    
    // MARK: - Search
    
    var searchOptions: SearchOptions = .noFilter {
        didSet {
            UserDefaults.standard.set(searchOptions.rawValue, forKey: searchOptionsDefaultsKey)
        }
    }
    let searchOptionsDefaultsKey = "CourseListing.searchOptions"
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchBarTextChanged(searchText)
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(false, animated: true)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBarTextChanged(searchBar.text ?? "")
        searchBar.resignFirstResponder()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.loadSearchResults(withString: searchBar.text!, options: searchOptions)
        searchBar.resignFirstResponder()
    }
    
    func clearSearch() {
        currentSearchText = nil
        let oldCourseCount = searchCourses?.count ?? courses.count
        let newCourses = courses
        searchCourses = nil
        collectionView?.performBatchUpdates({
            if newCourses.count > oldCourseCount {
                collectionView?.insertItems(at: (oldCourseCount..<newCourses.count).map({ IndexPath(item: $0, section: 0) }))
            } else if newCourses.count < oldCourseCount {
                collectionView?.deleteItems(at: (newCourses.count..<oldCourseCount).map({ IndexPath(item: $0, section: 0) }))
            }
            collectionView?.reloadItems(at: (0..<min(newCourses.count, oldCourseCount)).map({ IndexPath(item: $0, section: 0) }))
        }, completion: nil)
    }
    
    lazy var searchEngine = CourseSearchEngine()
    lazy var updateQueue = DispatchQueue(label: "BrowseSearchUpdateQueue")
    
    func loadSearchResults(withString searchTerm: String, options: SearchOptions = .noFilter, completion: (() -> Void)? = nil) {
        self.updateQueue.async {
            var newAggregatedSearchResults: Set<Course> = Set<Course>()
            if let rootTab = self.rootParent as? RootTabViewController,
                let schedules = rootTab.currentScheduleOptions {
                self.searchEngine.userSchedules = schedules
            }
            self.searchEngine.loadSearchResults(for: searchTerm, options: options, within: self.courses) { newResults in
                self.updateQueue.async {
                    newAggregatedSearchResults.formUnion(Set<Course>(newResults.keys))
                    if !self.searchEngine.isSearching {
                        // It has stopped the search
                        func sortingFunction(course1: (Course), course2: (Course)) -> Bool {
                            switch self.searchOptions.whichSort {
                                case "Number":
                                    return (course1.subjectID ?? "").localizedStandardCompare(course2.subjectID ?? "") == .orderedAscending
                                case "Rating":
                                    return course1.rating > course2.rating
                                case "Hours":
                                    let course1hours = course1.inClassHours + course1.outOfClassHours
                                    let course2hours = course2.inClassHours + course2.outOfClassHours
                                    if course1hours == 0 && course2hours != 0 {
                                        return false
                                    }
                                    else if course2hours == 0 && course1hours != 0 {
                                        return true
                                    }
                                    else {
                                        return course1hours < course2hours
                                    }
                                    
                                case "Relevance":
                                    return (course1.subjectID ?? "").localizedStandardCompare(course2.subjectID ?? "") == .orderedAscending
                                default:
                                    return (course1.subjectID ?? "").localizedStandardCompare(course2.subjectID ?? "") == .orderedAscending
                            }
                        }
                        let sortedResults = newAggregatedSearchResults.sorted(by: sortingFunction).map { $0 }
                        print(sortedResults)
                        DispatchQueue.main.async {
                            self.updateDisplayAfterSearch(with: sortedResults)
                            completion?()
                        }
                    }
                }
            }
        }
    }
    
    func searchBarTextChanged(_ searchText: String) {
        guard searchText.count > 0 || searchOptions.containsCourseFilters else {
            clearSearch()
            return
        }
        currentSearchText = searchText
        
        if self.searchOptions == .noFilter {
            var updatedAlready = false
            searchEngine.loadFastSearchResults(for: searchText, within: courses) { newResults in
                self.updateQueue.async {
                    guard newResults.count > 0 else {
                        return
                    }
                    func sortingFunction(course1: (key: Course, value: Float), course2: (key: Course, value: Float)) -> Bool {
                        switch self.searchOptions.whichSort {
                            case "Number":
                                return (course1.0.subjectID ?? "").localizedStandardCompare(course2.0.subjectID ?? "") == .orderedAscending
                            case "Rating":
                                return course1.0.rating > course2.0.rating
                            case "Hours":
                                let course1hours = course1.0.inClassHours + course1.0.outOfClassHours
                                let course2hours = course2.0.inClassHours + course2.0.outOfClassHours
                                if course1hours == 0 && course2hours != 0 {
                                    return false
                                }
                                else if course2hours == 0 && course1hours != 0 {
                                    return true
                                }
                                else {
                                    return course1hours < course2hours
                                }
                                
                            case "Relevance":
                                return course1.1 < course2.1
                            default:
                                return course1.1 < course2.1
                        }
                    }
                    let sortedResults = newResults.sorted(by: sortingFunction).map { $0.0 }
                    print(sortedResults)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if !updatedAlready {
                            self.updateDisplayAfterSearch(with: sortedResults)
                        }
                    }
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                guard DispatchQueue.main.sync(execute: { searchText == self.currentSearchText }) else {
                    return
                }
                self.loadSearchResults(withString: searchText, options: self.searchOptions, completion: {
                    updatedAlready = true
                })
            }
        } else {
            self.loadSearchResults(withString: searchText, options: self.searchOptions)
        }
    }
    
    func updateDisplayAfterSearch(with newCourses: [Course]) {
        DispatchQueue.main.async {
            let shouldResumeFirstResponder = self.searchController?.searchBar.isFirstResponder ?? false
            
            let oldCourseCount = self.searchCourses?.count ?? self.courses.count
            self.searchCourses = newCourses
            if self.collectionView?.numberOfItems(inSection: 0) != oldCourseCount || !self.isViewLoaded {
                self.collectionView?.reloadData()
            } else {
                self.collectionView?.performBatchUpdates({
                    if newCourses.count > oldCourseCount {
                        self.collectionView?.insertItems(at: (oldCourseCount..<newCourses.count).map({ IndexPath(item: $0, section: 0) }))
                    } else if newCourses.count < oldCourseCount {
                        self.collectionView?.deleteItems(at: (newCourses.count..<oldCourseCount).map({ IndexPath(item: $0, section: 0) }))
                    }
                    self.collectionView?.reloadItems(at: (0..<min(newCourses.count, oldCourseCount)).map({ IndexPath(item: $0, section: 0) }))
                }, completion: nil)
            }
            if shouldResumeFirstResponder {
                self.searchController?.searchBar.becomeFirstResponder()
            }
        }
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        if searchText.count > 0 || searchOptions.containsCourseFilters {
            loadSearchResults(withString: searchText, options: searchOptions, completion: nil)
        } else {
            clearSearch()
        }
    }
    
    // MARK: - Filtering
    
    func updateFilterButton() {
        if searchOptions == .noFilter {
            // Simple icon, no background
            filterButton?.tintColor = .systemBlue
            filterButton?.backgroundColor = .clear
        } else {
            // Tinted background with corner radius (filters on)
            filterButton?.tintColor = .white
            filterButton?.backgroundColor = .systemBlue
            filterButton?.layer.cornerRadius = 4.0
        }
        filterButton?.setImage(UIImage(named: "filter")?.withRenderingMode(.alwaysTemplate), for: .normal)
    }
    
    @IBAction func filterButtonTapped(_ sender: AnyObject) {
        guard CourseManager.shared.isLoaded else {
            return
        }
        let filter = self.storyboard!.instantiateViewController(withIdentifier: "CourseFilter") as! CourseFilterViewController
        filter.options = searchOptions
        filter.delegate = self
        let nav = UINavigationController(rootViewController: filter)
        if traitCollection.horizontalSizeClass != .compact {
            nav.modalPresentationStyle = .popover
            nav.popoverPresentationController?.barButtonItem = filterItem
        }
        present(nav, animated: true, completion: nil)
    }
    
    func courseFilter(_ filter: CourseFilterViewController, changed options: SearchOptions) {
        searchOptions = options
        updateFilterButton()
        if (currentSearchText?.count ?? 0) > 0 || searchOptions.containsCourseFilters {
            self.loadSearchResults(withString: currentSearchText ?? "", options: searchOptions)
        } else {
            self.clearSearch()
        }
    }
    
    func courseFilterWantsDismissal(_ filter: CourseFilterViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Pop Down Table Menu
    
    @objc func longPressOnListingCell(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began,
            let cell = sender.view as? UICollectionViewCell,
            let indexPath = collectionView?.indexPath(for: cell),
            courses[indexPath.item].subjectID != nil,
            let popDown = self.storyboard?.instantiateViewController(withIdentifier: "PopDownTableMenu") as? PopDownTableMenuController else {
                return
        }
        popDown.course = (searchCourses ?? courses)[indexPath.item]
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
}
