//
//  CourseSelectionViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/5/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol CourseBrowserDelegate: class {
    func courseBrowser(added course: Course, to semester: UserSemester?) -> UserSemester?
    func courseBrowserRequestedDetails(about course: Course)
}

struct SearchOptions: OptionSet {
    var rawValue: Int
    
    static let all = SearchOptions(rawValue: 1 << 0)
    static let GIR = SearchOptions(rawValue: 1 << 1)
    static let HASS = SearchOptions(rawValue: 1 << 2)
    static let CI = SearchOptions(rawValue: 1 << 3)
}

class CourseBrowserViewController: UIViewController, UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, CourseBrowserCellDelegate, UINavigationControllerDelegate, PopDownTableMenuDelegate {
    
    @IBOutlet var searchBar: UISearchBar?
    @IBOutlet var tableView: UITableView! = nil
    @IBOutlet var loadingView: UIView?
    @IBOutlet var loadingIndicator: UIActivityIndicatorView?
    
    @IBOutlet var headerBar: UIView?
    @IBOutlet var filterButton: UIButton?
    @IBOutlet var categoryControl: UISegmentedControl?
    
    weak var delegate: CourseBrowserDelegate? = nil
    
    /// An initial search to perform in the browser.
    var searchTerm: String?
    
    var searchOptions: SearchOptions = .all
    
    var panelViewController: PanelViewController? {
        return (self.navigationController?.parent as? PanelViewController)
    }
    
    var searchResults: [Course] = []
    var results: [Course] = []
    var managesNavigation: Bool = true
    
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
        filterButton?.setImage(filterButton?.image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .normal)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if managesNavigation {
            self.navigationController?.setNavigationBarHidden(true, animated: true)
        }
        
        if let searchBar = searchBar,
            searchBar.text?.characters.count == 0 {
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
                    if searchText.characters.count > 0 {
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
        guard let searchBar = searchBar else {
            return
        }
        panelViewController?.collapseView(to: searchBar.frame.size.height + 12.0)
    }
    
    func expandView() {
        panelViewController?.expandView()
    }
    
    func clearSearch() {
        searchResults = []
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
        if searchText.characters.count > 0 && panelViewController?.isExpanded == false {
            self.expandView()
        }
        guard searchText.characters.count > 0 else {
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
    
    func loadSearchResults(withString searchTerm: String, options: SearchOptions = .all) {
        guard CourseManager.shared.isLoaded, !isSearching else {
            return
        }
        isShowingSearchResults = true
        let cacheText = self.searchBar?.text
        DispatchQueue.global(qos: .userInitiated).async {
            self.isSearching = true
            let comps = searchTerm.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines)
            
            var newResults: [Course: Float] = [:]
            for course in CourseManager.shared.courses {
                var relevance: Float = 0.0
                var courseComps: [String?] = []
                if options.contains(.GIR) {
                    courseComps += [course.girAttribute?.rawValue, course.girAttribute?.descriptionText()]
                }
                if options.contains(.HASS) {
                    courseComps += [course.hassAttribute?.rawValue, course.hassAttribute?.descriptionText()]
                }
                if options.contains(.CI) {
                    courseComps += [course.communicationRequirement?.rawValue, course.communicationRequirement?.descriptionText()]
                }
                if options.contains(.all) {
                    courseComps = [String?]([course.subjectID, course.subjectID, course.subjectID, course.subjectTitle, course.communicationRequirement?.rawValue, course.communicationRequirement?.descriptionText(), course.hassAttribute?.rawValue, course.hassAttribute?.descriptionText(), course.girAttribute?.rawValue, course.girAttribute?.descriptionText()])
                }
                
                let courseText = (courseComps.flatMap({ $0 }) + (options.contains(.all) ? course.instructors : [])).joined(separator: "\n").lowercased()
                for comp in comps {
                    if courseText.contains(comp) {
                        let separated = courseText.components(separatedBy: comp)
                        var multiplier: Float = 1.0
                        for (i, sepComp) in separated.enumerated() {
                            if sepComp.characters.count > 0, i < separated.count - 1 {
                                let lastCharacter = sepComp[sepComp.index(before: sepComp.endIndex)..<sepComp.endIndex]
                                if lastCharacter.trimmingCharacters(in: .newlines).characters.count == 0 {
                                    multiplier += 20.0
                                } else if lastCharacter.trimmingCharacters(in: .whitespaces).characters.count == 0 {
                                    multiplier += 10.0
                                }
                            } else {
                                multiplier += 1.0
                            }
                        }
                        relevance += multiplier * Float(comp.characters.count)
                    }
                }
                if relevance > 0.0 {
                    relevance *= log(Float(max(2, course.enrollmentNumber)))
                    print(course.subjectID!, courseText, relevance)
                    newResults[course] = relevance
                }
            }
            let sortedResults = newResults.sorted(by: { $0.1 > $1.1 }).map { $0.0 }
            self.isSearching = false
            DispatchQueue.main.async {
                if cacheText == self.searchBar?.text {
                    self.searchResults = sortedResults
                    print("Reloading with \(self.results.count) results")
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
        self.delegate?.courseBrowserRequestedDetails(about: results[indexPath.row])
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
    }
    
    @IBAction func segmentedControlSelectionChanged(_ sender: UISegmentedControl) {
        guard let viewMode = ViewMode(rawValue: sender.selectedSegmentIndex) else {
            return
        }
        nonSearchViewMode = viewMode
        updateCourseVisibility()
    }
    
    @IBAction func filterButtonTapped(_ sender: UIButton) {
        
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
    
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourse course: Course, to semester: UserSemester) {
        _ = self.delegate?.courseBrowser(added: course, to: semester)
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
}
