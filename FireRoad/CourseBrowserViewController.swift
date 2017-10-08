//
//  CourseSelectionViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/5/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol CourseBrowserDelegate: class {
    func courseBrowser(added course: Course) -> UserSemester?
    func courseBrowserRequestedDetails(about course: Course)
}

class CourseBrowserViewController: UIViewController, UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, CourseBrowserCellDelegate, UINavigationControllerDelegate {
    
    @IBOutlet var searchBar: UISearchBar?
    @IBOutlet var tableView: UITableView! = nil
    @IBOutlet var loadingView: UIView?
    @IBOutlet var loadingIndicator: UIActivityIndicatorView?
    
    weak var delegate: CourseBrowserDelegate? = nil
    
    /// An initial search to perform in the browser.
    var searchTerm: String?
    
    var searchOptions: SearchOptions = .all
    
    var panelViewController: PanelViewController? {
        return (self.navigationController?.parent as? PanelViewController)
    }
    
    var results: [Course] = []
    var managesNavigation: Bool = true
    
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if managesNavigation {
            self.navigationController?.setNavigationBarHidden(true, animated: true)
        }
        
        if let searchBar = searchBar,
            searchBar.text?.characters.count == 0 {
            showRecentlyViewedCourses()
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
                    loadingView.alpha = 1.0
                }, completion: { (completed) in
                    if completed {
                        self.tableView.isHidden = true
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
                if let loadingView = self.loadingView {
                    UIView.animate(withDuration: 0.2, animations: {
                        self.tableView.alpha = 1.0
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
                        self.showRecentlyViewedCourses()
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
    
    func showRecentlyViewedCourses() {
        guard CourseManager.shared.isLoaded else {
            return
        }
        var recentlyViewed = CourseManager.shared.recentlyViewedCourses
        results = [Course](recentlyViewed[0..<min(recentlyViewed.count, 15)])
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
            showRecentlyViewedCourses()
            return
        }
        loadSearchResults(withString: searchText, options: searchOptions)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        self.loadSearchResults(withString: searchBar.text!, options: searchOptions)
    }
    
    struct SearchOptions: OptionSet {
        var rawValue: Int
        
        static let all = SearchOptions(rawValue: 1 << 0)
        static let GIR = SearchOptions(rawValue: 1 << 1)
        static let HASS = SearchOptions(rawValue: 1 << 2)
        static let CI = SearchOptions(rawValue: 1 << 3)
    }
    
    func loadSearchResults(withString searchTerm: String, options: SearchOptions = .all) {
        guard CourseManager.shared.isLoaded else {
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let comps = searchTerm.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines)
            
            var newResults: [Course: Float] = [:]
            for course in CourseManager.shared.courses {
                var relevance: Float = 0.0
                var courseComps: [String?] = []
                if options.contains(.GIR) {
                    courseComps += [course.GIRAttribute, course.GIRAttributeDescription]
                }
                if options.contains(.HASS) {
                    courseComps += [course.hassAttribute, course.hassAttributeDescription]
                }
                if options.contains(.CI) {
                    courseComps += [course.communicationRequirement, course.communicationReqDescription]
                }
                if options.contains(.all) {
                    courseComps = [String?]([course.subjectID, course.subjectID, course.subjectID, course.subjectTitle, course.communicationRequirement, course.communicationReqDescription, course.hassAttribute, course.hassAttributeDescription, course.GIRAttribute, course.GIRAttributeDescription])
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
            self.results = newResults.sorted(by: { $0.1 > $1.1 }).map { $0.0 }
            DispatchQueue.main.async {
                print("Reloading with \(self.results.count) results")
                self.tableView.reloadData()
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
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let searchBar = searchBar,
            searchBar.text?.characters.count == 0, results.count > 0 {
            return "Recents"
        }
        return nil
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
    
    func browserCell(added course: Course) -> UserSemester? {
        self.searchBar?.resignFirstResponder()
        return self.delegate?.courseBrowser(added: course)
    }
}
