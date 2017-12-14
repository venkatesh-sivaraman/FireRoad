//
//  CourseSelectionViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/5/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol CourseBrowserDelegate: CourseDisplayManager {
    // Nothing here yet
}

struct SearchOptions: OptionSet {
    var rawValue: Int
    
    static let anyRequirement = SearchOptions(rawValue: 1 << 0)
    static let fulfillsGIR = SearchOptions(rawValue: 1 << 1)
    static let fulfillsHASS = SearchOptions(rawValue: 1 << 2)
    static let fulfillsCIH = SearchOptions(rawValue: 1 << 3)
    static let fulfillsCIHW = SearchOptions(rawValue: 1 << 4)

    static let offeredAnySemester = SearchOptions(rawValue: 1 << 10)
    static let offeredFall = SearchOptions(rawValue: 1 << 11)
    static let offeredSpring = SearchOptions(rawValue: 1 << 12)
    static let offeredIAP = SearchOptions(rawValue: 1 << 13)

    static let containsSearchTerm = SearchOptions(rawValue: 1 << 14)
    static let matchesSearchTerm = SearchOptions(rawValue: 1 << 15)
    static let startsWithSearchTerm = SearchOptions(rawValue: 1 << 16)
    static let endsWithSearchTerm = SearchOptions(rawValue: 1 << 17)
    
    static let searchID = SearchOptions(rawValue: 1 << 20)
    static let searchTitle = SearchOptions(rawValue: 1 << 21)
    static let searchPrereqs = SearchOptions(rawValue: 1 << 23)
    static let searchCoreqs = SearchOptions(rawValue: 1 << 24)
    static let searchInstructors = SearchOptions(rawValue: 1 << 25)
    static let searchRequirements = SearchOptions(rawValue: 1 << 26)
    static let searchAllFields: SearchOptions = [
        .searchID,
        .searchTitle,
        .searchPrereqs,
        .searchCoreqs,
        .searchInstructors,
        .searchRequirements
    ]

    static let noFilter: SearchOptions = [
        .anyRequirement,
        .offeredAnySemester,
        .containsSearchTerm,
        .searchAllFields
    ]
}

class CourseBrowserViewController: UIViewController, UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, CourseBrowserCellDelegate, UINavigationControllerDelegate, PopDownTableMenuDelegate, CourseFilterDelegate {
    
    @IBOutlet var searchBar: UISearchBar?
    @IBOutlet var tableView: UITableView! = nil
    @IBOutlet var loadingView: UIView?
    @IBOutlet var loadingIndicator: UIActivityIndicatorView?
    
    @IBOutlet var headerBar: UIView?
    @IBOutlet var filterButton: UIButton?
    @IBOutlet var categoryControl: UISegmentedControl?
    
    @IBOutlet var headerBarHeightConstraint: NSLayoutConstraint?
    let headerBarHeight = CGFloat(44.0)
    
    var showsHeaderBar = true {
        didSet {
            headerBarHeightConstraint?.constant = showsHeaderBar ? headerBarHeight : 0.0
        }
    }
    
    weak var delegate: CourseBrowserDelegate? = nil
    
    /// An initial search to perform in the browser.
    var searchTerm: String?
    
    var searchOptions: SearchOptions = .noFilter
    
    var panelViewController: PanelViewController? {
        return (self.navigationController?.parent as? PanelViewController)
    }
    
    var searchResults: [Course] = []
    var results: [Course] = []
    var managesNavigation = true
    
    var showsSemesterDialog = true
    
    enum ViewMode: Int {
        case recents = 0
        case favorites = 1
        case search = 2
    }
    
    var isShowingSearchResults = false {
        didSet {
            DispatchQueue.main.async {
                if self.isShowingSearchResults {
                    self.nonSearchViewMode = .search
                    self.categoryControl?.setEnabled(true, forSegmentAt: ViewMode.search.rawValue)
                    self.categoryControl?.selectedSegmentIndex = ViewMode.search.rawValue
                    self.updateCourseVisibility()
                } else {
                    self.categoryControl?.setEnabled(false, forSegmentAt: ViewMode.search.rawValue)
                }
            }
        }
    }
    var lastViewMode: ViewMode = .recents
    var nonSearchViewMode: ViewMode = .recents {
        didSet {
            if categoryControl?.selectedSegmentIndex != nonSearchViewMode.rawValue {
                categoryControl?.selectedSegmentIndex = nonSearchViewMode.rawValue
            }
            if nonSearchViewMode != .search {
                UserDefaults.standard.set(nonSearchViewMode.rawValue, forKey: nonSearchViewModeDefaultsKey)
                lastViewMode = nonSearchViewMode
            }
        }
    }
    
    let nonSearchViewModeDefaultsKey = "CourseBrowserNonSearchViewMode"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.searchBar?.tintColor = self.view.tintColor
        if managesNavigation {
            self.navigationController?.delegate = self
        }
        navigationItem.title = searchTerm ?? ""
        
        if let panel = panelViewController {
            NotificationCenter.default.addObserver(self, selector: #selector(panelViewControllerWillCollapse(_:)), name: .PanelViewControllerWillCollapse, object: panel)
        }
        
        nonSearchViewMode = ViewMode(rawValue: UserDefaults.standard.integer(forKey: nonSearchViewModeDefaultsKey)) ?? .recents
        
        categoryControl?.selectedSegmentIndex = nonSearchViewMode.rawValue
        updateFilterButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if managesNavigation {
            self.navigationController?.setNavigationBarHidden(true, animated: true)
        }
        
        if let searchBar = searchBar,
            searchBar.text?.count == 0 {
            clearSearch()
        } else if let initialSearch = searchTerm {
            loadSearchResults(withString: initialSearch, options: searchOptions)
        }
        
        // Show the loading view if necessary
        if !CourseManager.shared.isLoaded {
            if let loadingView = self.loadingView {
                loadingView.alpha = 0.0
                loadingView.isHidden = false
                self.loadingIndicator?.startAnimating()
                UIView.animate(withDuration: 0.2, animations: {
                    self.tableView.alpha = 0.0
                    self.headerBar?.alpha = 0.0
                    loadingView.alpha = 1.0
                }, completion: { (completed) in
                    if completed {
                        self.tableView.isHidden = true
                        self.headerBar?.isHidden = true
                    }
                })
            }
            loadingIndicator?.startAnimating()
        }
        DispatchQueue.global().async {
            while !CourseManager.shared.isLoaded {
                usleep(100)
            }
            DispatchQueue.main.async {
                self.tableView.isHidden = false
                self.headerBar?.isHidden = false
                if let loadingView = self.loadingView {
                    UIView.animate(withDuration: 0.2, animations: {
                        self.tableView.alpha = 1.0
                        self.headerBar?.alpha = 1.0
                        loadingView.alpha = 0.0
                    }, completion: { (completed) in
                        if completed {
                            loadingView.isHidden = true
                            self.loadingIndicator?.stopAnimating()
                        }
                    })
                }
                
                if let searchText = self.searchBar?.text {
                    if searchText.count > 0 {
                        self.loadSearchResults(withString: searchText, options: self.searchOptions)
                    } else {
                        self.clearSearch()
                    }
                } else if let initialSearch = self.searchTerm {
                    self.loadSearchResults(withString: initialSearch, options: self.searchOptions)
                }
            }
        }
    }
    
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationControllerOperation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if operation == .push {
            return FlatPushAnimator()
        } else if operation == .pop {
            let animator = FlatPushAnimator()
            animator.reversed = true
            return animator
        }
        return nil
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func panelViewControllerWillCollapse(_ note: Notification) {
        searchBar?.resignFirstResponder()
        searchBar?.setShowsCancelButton(false, animated: true)
    }
    
    func collapseView() {
        panelViewController?.collapseView()
    }
    
    func expandView() {
        panelViewController?.expandView()
    }
    
    func clearSearch() {
        searchResults = []
        isSearching = false
        isShowingSearchResults = false
        if nonSearchViewMode == .search {
            nonSearchViewMode = lastViewMode
        }
        updateCourseVisibility()
    }
    
    func updateCourseVisibility() {
        guard CourseManager.shared.isLoaded else {
            return
        }
        switch nonSearchViewMode {
        case .search:
            results = searchResults
        case .recents:
            results = CourseManager.shared.recentlyViewedCourses
        case .favorites:
            results = CourseManager.shared.favoriteCourses
        }
        tableView.reloadData()
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(false, animated: true)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        self.collapseView()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.count > 0 && panelViewController?.isExpanded == false {
            self.expandView()
        }
        guard searchText.count > 0 else {
            clearSearch()
            return
        }
        loadSearchResults(withString: searchText, options: searchOptions)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        self.loadSearchResults(withString: searchBar.text!, options: searchOptions)
    }
    
    var isSearching = false
    
    private func courseSatisfiesSearchOptions(_ course: Course, searchTerm: String, options: SearchOptions) -> Bool {
        var fulfillsRequirement = false
        if options.contains(.anyRequirement) {
            fulfillsRequirement = true
        } else if options.contains(.fulfillsGIR), course.girAttribute != nil {
            fulfillsRequirement = true
        } else if options.contains(.fulfillsHASS), course.hassAttribute != nil {
            fulfillsRequirement = true
        } else if options.contains(.fulfillsCIH), course.communicationRequirement == .ciH {
            fulfillsRequirement = true
        } else if options.contains(.fulfillsCIHW), course.communicationRequirement == .ciHW {
            fulfillsRequirement = true
        }
        
        var fulfillsOffered = false
        if options.contains(.offeredAnySemester) {
            fulfillsOffered = true
        } else if options.contains(.offeredFall), course.isOfferedFall {
            fulfillsOffered = true
        } else if options.contains(.offeredSpring), course.isOfferedSpring {
            fulfillsOffered = true
        } else if options.contains(.offeredIAP), course.isOfferedIAP {
            fulfillsOffered = true
        }
        
        return fulfillsRequirement && fulfillsOffered
    }
    
    private func searchText(for course: Course, options: SearchOptions) -> String {
        var courseComps: [String?] = []
        if options.contains(.searchID) {
            courseComps += [course.subjectID, course.subjectID, course.subjectID]
        }
        if options.contains(.searchTitle) {
            courseComps.append(course.subjectTitle)
        }
        if options.contains(.searchRequirements) {
            courseComps += [course.communicationRequirement?.rawValue, course.communicationRequirement?.descriptionText(), course.hassAttribute?.rawValue, course.hassAttribute?.descriptionText(), course.girAttribute?.rawValue, course.girAttribute?.descriptionText()]
        }
        if options.contains(.searchPrereqs) {
            let prereqs: [String?] = course.prerequisites.flatMap({ $0 })
            courseComps += prereqs
        }
        if options.contains(.searchCoreqs) {
            let coreqs: [String?] = course.corequisites.flatMap({ $0 })
            courseComps += coreqs
        }
        
        let courseText = (courseComps.flatMap({ $0 }) + (options.contains(.searchAllFields) ? course.instructors : [])).joined(separator: "\n").lowercased()
        return courseText
    }
    
    private func searchRegex(for searchTerm: String, options: SearchOptions = .noFilter) -> NSRegularExpression {
        let pattern = NSRegularExpression.escapedPattern(for: searchTerm)
        if options.contains(.matchesSearchTerm) {
            return try! NSRegularExpression(pattern: "(?:^|[^A-z\\d])\(pattern)(?:$|[^A-z\\d])", options: .caseInsensitive)
        } else if options.contains(.startsWithSearchTerm) {
            return try! NSRegularExpression(pattern: "(?:^|[^A-z\\d])\(pattern)(\\w*)(?:$|[^A-z\\d])", options: .caseInsensitive)
        } else if options.contains(.endsWithSearchTerm) {
            return try! NSRegularExpression(pattern: "(?:^|[^A-z\\d])(\\w*)\(pattern)(?:$|[^A-z\\d])", options: .caseInsensitive)
        }
        return try! NSRegularExpression(pattern: "(?:^|[^A-z\\d])(\\w*)\(pattern)(\\w*)(?:$|[^A-z\\d])", options: .caseInsensitive)
    }
    
    internal func searchResults(for searchTerm: String, options: SearchOptions = .noFilter) -> [Course] {
        let comps = searchTerm.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines)
        
        var newResults: [Course: Float] = [:]
        for course in CourseManager.shared.courses {
            guard courseSatisfiesSearchOptions(course, searchTerm: searchTerm, options: options) else {
                continue
            }
            
            var relevance: Float = 0.0
            let courseText = searchText(for: course, options: options)
            for comp in comps {
                let regex = searchRegex(for: comp, options: options)
                for match in regex.matches(in: courseText, options: [], range: NSRange(location: 0, length: courseText.count)) {
                    var multiplier: Float = 1.0
                    if match.numberOfRanges > 1 {
                        for i in 1..<match.numberOfRanges where match.range(at: i).length > 0 {
                            multiplier += 10.0
                        }
                    }
                    relevance *= 1.1
                    relevance += multiplier * Float(comp.count)
                }
            }
            if relevance > 0.0 {
                relevance *= log(Float(max(2, course.enrollmentNumber)))
                if let user = (self.rootParent as? RootTabViewController)?.currentUser {
                    relevance *= user.userRelevance(for: course)
                }
                newResults[course] = relevance
            }
        }
        let sortedResults = newResults.sorted(by: { $0.1 > $1.1 }).map { $0.0 }
        return sortedResults
    }
    
    func loadSearchResults(withString searchTerm: String, options: SearchOptions = .noFilter) {
        guard CourseManager.shared.isLoaded, !isSearching else {
            return
        }
        isShowingSearchResults = true
        let cacheText = self.searchBar?.text
        DispatchQueue.global(qos: .userInitiated).async {
            self.isSearching = true
            let sortedResults = self.searchResults(for: searchTerm, options: options)
            self.isSearching = false
            DispatchQueue.main.async {
                if cacheText == self.searchBar?.text {
                    self.searchResults = sortedResults
                    self.updateCourseVisibility()
                } else {
                    print("Searching again")
                    self.loadSearchResults(withString: self.searchBar?.text ?? searchTerm, options: options)
                }
            }
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CourseCell", for: indexPath) as! CourseBrowserCell
        cell.course = results[indexPath.row]
        cell.delegate = self
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.searchBar?.resignFirstResponder()
        self.delegate?.viewDetails(for: results[indexPath.row])
        self.tableView.deselectRow(at: indexPath, animated: false)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.textLabel?.tintColor = UIColor.black
        cell.detailTextLabel?.tintColor = UIColor.black
        cell.textLabel?.textColor = UIColor.black.withAlphaComponent(0.7)
        cell.detailTextLabel?.textColor = UIColor.darkGray.withAlphaComponent(0.7)
    }
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        guard !isShowingSearchResults else {
            return nil
        }
        return "Remove"
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        guard !isShowingSearchResults, editingStyle == .delete else {
            return
        }
        let course = results[indexPath.row]
        if nonSearchViewMode == .recents {
            CourseManager.shared.removeCourseFromRecentlyViewed(course)
        } else {
            CourseManager.shared.markCourseAsNotFavorite(course)
        }
        results.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .fade)
    }
    
    func browserCell(added course: Course) -> UserSemester? {
        self.searchBar?.resignFirstResponder()
        if showsSemesterDialog {
            guard let popDown = self.storyboard?.instantiateViewController(withIdentifier: "PopDownTableMenu") as? PopDownTableMenuController else {
                print("No pop down table menu in storyboard!")
                return nil
            }
            popDown.course = course
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                popDown.show(animated: true)
            }
            return nil
        } else {
            return delegate?.addCourse(course, to: nil)
        }
    }
    
    @IBAction func segmentedControlSelectionChanged(_ sender: UISegmentedControl) {
        guard let viewMode = ViewMode(rawValue: sender.selectedSegmentIndex) else {
            return
        }
        nonSearchViewMode = viewMode
        updateCourseVisibility()
    }
    
    // MARK: - Pop Down Table Menu
    
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourseToFavorites course: Course) {
        if CourseManager.shared.favoriteCourses.contains(course) {
            CourseManager.shared.markCourseAsNotFavorite(course)
        } else {
            CourseManager.shared.markCourseAsFavorite(course)
        }
        popDownTableMenuCanceled(tableMenu)
    }
    
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourseToSchedule course: Course) {
        delegate?.addCourseToSchedule(course)
        popDownTableMenuCanceled(tableMenu)
    }
    
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourse course: Course, to semester: UserSemester) {
        _ = self.delegate?.addCourse(course, to: semester)
        popDownTableMenuCanceled(tableMenu)
    }
    
    func popDownTableMenuCanceled(_ tableMenu: PopDownTableMenuController) {
        navigationItem.rightBarButtonItem?.isEnabled = true
        if !isShowingSearchResults {
            // Refresh favorites if necessary
            updateCourseVisibility()
        }
        tableMenu.hide(animated: true) {
            tableMenu.willMove(toParentViewController: nil)
            tableMenu.view.removeFromSuperview()
            tableMenu.removeFromParentViewController()
            tableMenu.didMove(toParentViewController: nil)
        }
    }
    
    // MARK: - Filter Controller
    
    func updateFilterButton() {
        let image = (searchOptions == .noFilter ? UIImage(named: "filter") : UIImage(named: "filter-on"))
        filterButton?.setImage(image?.withRenderingMode(.alwaysTemplate), for: .normal)
    }
    
    @IBAction func filterButtonTapped(_ sender: UIButton) {
        let filter = self.storyboard!.instantiateViewController(withIdentifier: "CourseFilter") as! CourseFilterViewController
        filter.options = searchOptions
        filter.delegate = self
        navigationController?.pushViewController(filter, animated: true)
        navigationController?.view.setNeedsLayout()
    }
    
    func courseFilter(_ filter: CourseFilterViewController, changed options: SearchOptions) {
        searchOptions = options
        updateFilterButton()
        if isShowingSearchResults, let searchText = searchBar?.text {
            self.loadSearchResults(withString: searchText, options: searchOptions)
        }
    }
    
    func courseFilterWantsDismissal(_ filter: CourseFilterViewController) {
        navigationController?.popViewController(animated: true)
    }
}
