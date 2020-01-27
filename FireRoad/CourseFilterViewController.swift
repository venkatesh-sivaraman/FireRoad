//
//  CourseFilterViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 11/11/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol CourseFilterDelegate: class {
    func courseFilter(_ filter: CourseFilterViewController, changed options: SearchOptions)
    func courseFilterWantsDismissal(_ filter: CourseFilterViewController)
}

class CourseFilterViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var options: SearchOptions = .noFilter
    
    struct FilterTableItem {
        enum FilterTableItemType {
            case checkmark
            case segmentedControl
        }
        var type: FilterTableItemType
        var title: String
        var items: [(String, SearchOptions)]
        var tintColor: UIColor?
        var firstOptionOverridesOthers: Bool
    }
    
    let tableItems = [
        FilterTableItem(type: .segmentedControl,
                        title: "Offered",
                        items: [
                            ("Any", .offeredAnySemester),
                            ("Fall", .offeredFall),
                            ("Spring", .offeredSpring),
                            ("IAP", .offeredIAP)],
                        tintColor: nil,
                        firstOptionOverridesOthers: false),
        FilterTableItem(type: .segmentedControl,
                        title: "Schedule Conflicts",
                        items: [
                            ("Off", .conflictsAllowed),
                            ("Lectures", .noLectureConflicts),
                            ("No Conflict", .noConflicts)],
                        tintColor: nil,
                        firstOptionOverridesOthers: false),
        FilterTableItem(type: .segmentedControl,
                        title: "HASS",
                        items: [
                            ("Off", .noHASSFilter),
                            ("Any", .fulfillsHASS),
                            ("A", .fulfillsHASSA),
                            ("S", .fulfillsHASSS),
                            ("H", .fulfillsHASSH)],
                        tintColor: CourseManager.shared.color(forDepartment: "HASS"),
                        firstOptionOverridesOthers: false),
        FilterTableItem(type: .segmentedControl,
                        title: "Communication",
                        items: [
                            ("Off", .noCIFilter),
                            ("CI-H", .fulfillsCIH),
                            ("CI-HW", .fulfillsCIHW),
                            ("Not CI", .notCI)],
                        tintColor: CourseManager.shared.color(forDepartment: "CI-H"),
                        firstOptionOverridesOthers: false),
        FilterTableItem(type: .segmentedControl,
                        title: "GIR",
                        items: [
                            ("Off", .noGIRFilter),
                            ("Any GIR", .fulfillsGIR),
                            ("Lab", .fulfillsLabGIR),
                            ("REST", .fulfillsRestGIR)],
                        tintColor: CourseManager.shared.color(forDepartment: "GIR"),
                        firstOptionOverridesOthers: false),
        FilterTableItem(type: .segmentedControl,
                        title: "Level",
                        items: [
                            ("Any", .noLevelFilter),
                            ("Undergrad", .undergradOnly),
                            ("Grad", .graduateOnly)],
                        tintColor: nil,
                        firstOptionOverridesOthers: false),
        FilterTableItem(type: .segmentedControl,
                        title: "Sort By",
                        items: [
                            ("Number", .sortByNumber),
                            ("Rating", .sortByRating),
                            ("Hours", .sortByHours),
                            ("Relevance", .sortByRelevance)],
                        tintColor: nil,
                        firstOptionOverridesOthers: false),
        FilterTableItem(type: .segmentedControl,
                        title: "Search Behavior",
                        items: [
                            ("Contains", .containsSearchTerm),
                            ("Matches", .matchesSearchTerm),
                            ("Starts With", .startsWithSearchTerm),
                            ("Ends With", .endsWithSearchTerm)],
                        tintColor: nil,
                        firstOptionOverridesOthers: false),
        FilterTableItem(type: .checkmark,
                        title: "Search Fields",
                        items: [
                            ("All", .searchAllFields),
                            ("Subject Number", .searchID),
                            ("Subject Title", .searchTitle),
                            ("Prerequisites", .searchPrereqs),
                            ("Corequisites", .searchCoreqs),
                            ("Instructors", .searchInstructors)],
                        tintColor: nil,
                        firstOptionOverridesOthers: true),
    ]
    
    let buttonCellIdentifier = "ButtonCell"
    let segmentedControlCellIdentifier = "SegmentedControlCell"
    let checkmarkCellIdentifier = "CheckmarkCell"
    
    @IBOutlet var tableView: UITableView!
    weak var delegate: CourseFilterDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if navigationController?.viewControllers.count == 1 {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(CourseFilterViewController.doneButtonTapped(_:)))
        }
    }
    
    @objc func doneButtonTapped(_ sender: AnyObject) {
        delegate?.courseFilterWantsDismissal(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return tableItems.count + 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        let item = tableItems[section - 1]
        switch item.type {
        case .checkmark:
            return item.items.count
        case .segmentedControl:
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return nil
        }
        let item = tableItems[section - 1]
        return item.title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: buttonCellIdentifier, for: indexPath)
            if let textLabel = cell.viewWithTag(12) {
                textLabel.alpha = options == .noFilter ? 0.4 : 1.0
            }
            cell.selectionStyle = options == .noFilter ? .none : .default
            return cell
        }
        let item = tableItems[indexPath.section - 1]
        switch item.type {
        case .checkmark:
            let cell = tableView.dequeueReusableCell(withIdentifier: checkmarkCellIdentifier, for: indexPath)
            let option = item.items[indexPath.row]
            cell.textLabel?.text = option.0
            if item.firstOptionOverridesOthers, indexPath.row > 0, options.contains(item.items[0].1) {
                cell.accessoryType = .none
            } else {
                cell.accessoryType = options.contains(option.1) ? .checkmark : .none
            }
            return cell
        case .segmentedControl:
            let cell = tableView.dequeueReusableCell(withIdentifier: segmentedControlCellIdentifier, for: indexPath)
            guard let segmentedControl = cell.viewWithTag(12) as? UISegmentedControl else {
                return cell
            }
            segmentedControl.removeAllSegments()
            var selectedIndex = 0
            for (i, option) in item.items.enumerated() {
                segmentedControl.insertSegment(withTitle: option.0, at: segmentedControl.numberOfSegments, animated: false)
                if options.contains(option.1) {
                    selectedIndex = i
                }
            }
            segmentedControl.selectedSegmentIndex = selectedIndex
            if let tint = item.tintColor {
                if #available(iOS 13.0, *) {
                    segmentedControl.selectedSegmentTintColor = tint
                } else {
                    segmentedControl.tintColor = tint
                }
            } else {
                if #available(iOS 13.0, *) {
                    segmentedControl.selectedSegmentTintColor = self.view.tintColor
                } else {
                    segmentedControl.tintColor = self.view.tintColor
                }
            }
            segmentedControl.setTitleTextAttributes([NSAttributedStringKey.foregroundColor: UIColor.white], for: .selected)
            segmentedControl.removeTarget(nil, action: nil, for: .valueChanged)
            segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged(_:)), for: .valueChanged)
            return cell
        }
    }

    @objc func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        var indexPath: IndexPath?
        guard let ips = tableView.indexPathsForVisibleRows else {
            return
        }
        for ip in ips {
            guard let cell = tableView.cellForRow(at: ip) else {
                continue
            }
            if sender.isDescendant(of: cell) {
                indexPath = ip
                break
            }
        }
        guard let selectedIndexPath = indexPath else {
            return
        }
        updateTableItem(at: selectedIndexPath.section - 1, withSelectionOfOptionAt: sender.selectedSegmentIndex)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            if options != .noFilter {
                options = .noFilter
                delegate?.courseFilter(self, changed: options)
                tableView.deselectRow(at: indexPath, animated: true)
                tableView.reloadSections(IndexSet(1..<(tableItems.count + 1)), with: .fade)
            }
            delegate?.courseFilterWantsDismissal(self)
        } else if tableItems[indexPath.section - 1].type == .checkmark {
            updateTableItem(at: indexPath.section - 1, withSelectionOfOptionAt: indexPath.row)
            tableView.deselectRow(at: indexPath, animated: true)
            tableView.reloadSections(IndexSet([0, indexPath.section]), with: .fade)
        }
    }
    
    func updateTableItem(at index: Int, withSelectionOfOptionAt optionIndex: Int) {
        let item = tableItems[index]
        let togglingOption = item.items[optionIndex].1
        if optionIndex == 0, item.firstOptionOverridesOthers {
            if options.contains(togglingOption) {
                var containsAnotherOption = false
                for (i, otherOption) in item.items.enumerated() where i != optionIndex {
                    if options.contains(otherOption.1) {
                        containsAnotherOption = true
                        break
                    }
                }
                if containsAnotherOption {
                    options.remove(togglingOption)
                }
            } else {
                for (i, otherOption) in item.items.enumerated() where i > 0 {
                    options.remove(otherOption.1)
                }
                options.insert(togglingOption)
            }
        } else {
            if item.type == .segmentedControl {
                for otherOption in item.items {
                    options.remove(otherOption.1)
                }
                options.insert(togglingOption)
            } else {
                if item.firstOptionOverridesOthers, options.contains(item.items[0].1) {
                    options.remove(item.items[0].1)
                }
                if options.contains(togglingOption) {
                    var containsAnotherOption = false
                    for (i, otherOption) in item.items.enumerated() where i != optionIndex {
                        if options.contains(otherOption.1) {
                            containsAnotherOption = true
                            break
                        }
                    }
                    if containsAnotherOption {
                        options.remove(togglingOption)
                    }
                } else {
                    options.insert(togglingOption)
                }
            }
        }
        delegate?.courseFilter(self, changed: options)
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
