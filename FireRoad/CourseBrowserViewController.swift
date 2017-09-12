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
    
    @IBOutlet var searchBar: UISearchBar! = nil
    @IBOutlet var tableView: UITableView! = nil
    
    weak var delegate: CourseBrowserDelegate? = nil
    
    var results: [Course] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.searchBar.tintColor = self.view.tintColor
        self.navigationController?.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
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
    
    func collapseView() {
        (self.navigationController!.parent as? PanelViewController)?.collapseView(to: self.searchBar.frame.size.height + 12.0)
    }
    
    func expandView() {
        (self.navigationController!.parent as? PanelViewController)?.expandView()
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
        if searchText.characters.count > 0 && self.view.frame.size.height < 100.0 {
            //self.expandView()
        }
        self.loadSearchResults(withString: searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        self.loadSearchResults(withString: searchBar.text!)
    }
    
    func loadSearchResults(withString searchTerm: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let comps = searchTerm.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines)
            
            var newResults: [Course: Float] = [:]
            for course in CourseManager.shared.courses {
                var relevance: Float = 0.0
                for comp in comps {
                    if course.subjectID != nil {
                        let id = course.subjectID!.lowercased()
                        if id.contains(comp) {
                            if id == comp.lowercased() {
                                relevance += 30.0 * Float(comp.characters.count)
                            } else if let range = id.range(of: comp) {
                                if range.lowerBound == id.startIndex {
                                    relevance += 20.0 * Float(comp.characters.count)
                                }
                            }
                        }
                    }
                    if course.subjectTitle != nil {
                        let id = course.subjectTitle!.lowercased()
                        if id.contains(comp) {
                            if id == comp.lowercased() {
                                relevance += 10.0 * Float(comp.characters.count)
                            } else if let range = id.range(of: comp) {
                                if range.lowerBound == id.startIndex || id.characters[id.index(range.lowerBound, offsetBy: -1, limitedBy: id.startIndex)!] == Character(" ") {
                                    relevance += Float(comp.characters.count)
                                }
                            }
                        }
                    }
                }
                if relevance > 0.0 {
                    relevance += Float(course.enrollmentNumber)
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
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CourseCell", for: indexPath) as! CourseBrowserCell
        cell.course = results[indexPath.row]
        cell.delegate = self
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.searchBar.resignFirstResponder()
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
        return self.delegate?.courseBrowser(added: course)
    }
}
