//
//  ScheduleConstraintViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 12/13/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol ScheduleConstraintDelegate: class {
    func scheduleConstraintViewController(_ vc: ScheduleConstraintViewController, updatedAllowedSections newSections: [String: [Int]]?)
    func scheduleConstraintViewControllerDismissed(_ vc: ScheduleConstraintViewController)
}

class ScheduleConstraintViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var course: Course?
    var allowedSections: [String: [Int]]?
    
    @IBOutlet var tableView: UITableView!
    
    weak var delegate: ScheduleConstraintDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Constrain" + (course?.subjectID != nil ? " \(course!.subjectID!)" : "")
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(ScheduleConstraintViewController.doneButtonTapped(_:)))
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func doneButtonTapped(_ sender: AnyObject) {
        delegate?.scheduleConstraintViewControllerDismissed(self)
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    func allowedScheduleItems(for section: Int) -> [Int]? {
        guard let schedule = course?.schedule else {
            return nil
        }
        let ordering = CourseScheduleType.ordering.filter({ schedule[$0] != nil })
        if ordering.count <= section {
            return allowedSections?[schedule.keys.filter({ !ordering.contains($0) }).sorted()[section - ordering.count]]
        }
        return allowedSections?[ordering[section]]
    }
    
    func setAllowedScheduleItems(_ scheduleItems: [Int]?, for section: Int) {
        guard let schedule = course?.schedule else {
            return
        }
        let ordering = CourseScheduleType.ordering.filter({ schedule[$0] != nil })
        if allowedSections == nil {
            allowedSections = [:]
        }
        if ordering.count <= section {
            allowedSections?[schedule.keys.filter({ !ordering.contains($0) }).sorted()[section - ordering.count]] = scheduleItems
        }
        allowedSections?[ordering[section]] = scheduleItems
    }
    
    func scheduleItemSet(for section: Int) -> [[CourseScheduleItem]]? {
        guard let schedule = course?.schedule else {
            return nil
        }
        let ordering = CourseScheduleType.ordering.filter({ schedule[$0] != nil })
        if ordering.count <= section {
            return schedule[schedule.keys.filter({ !ordering.contains($0) }).sorted()[section - ordering.count]]
        }
        return schedule[ordering[section]]!
    }
    
    func scheduleItemIndex(for indexPath: IndexPath) -> Int {
        return (scheduleItemSet(for: indexPath.section)?.count ?? 0) == 1 ? indexPath.row : (indexPath.row - 1)
    }
    
    func isScheduleItemAllowed(at indexPath: IndexPath) -> Bool {
        let itemIndex = scheduleItemIndex(for: indexPath)
        guard let scheduleSet = allowedScheduleItems(for: indexPath.section) else {
            return true
        }
        return scheduleSet.contains(itemIndex)
    }
    
    // MARK: - Table View

    func numberOfSections(in tableView: UITableView) -> Int {
        return course?.schedule?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let numItems = scheduleItemSet(for: section)?.count ?? 0
        return numItems == 1 ? 1 : (numItems + 1)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let schedule = course?.schedule else {
            return nil
        }
        let ordering = CourseScheduleType.ordering.filter({ schedule[$0] != nil })
        if ordering.count <= section {
            return schedule.keys.filter({ !ordering.contains($0) }).sorted()[section - ordering.count]
        }
        return ordering[section]
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ConstraintCell", for: indexPath)
        guard let itemSet = scheduleItemSet(for: indexPath.section) else {
            cell.textLabel?.text = ""
            cell.detailTextLabel?.text = ""
            return cell
        }
        if itemSet.count > 1, indexPath.row == 0 {
            if #available(iOS 13.0, *) {
                cell.textLabel?.textColor = .label
            } else {
                cell.textLabel?.textColor = .black
            }
            cell.textLabel?.text = "All Sections"
            cell.detailTextLabel?.text = ""
            let allowedItems = allowedScheduleItems(for: indexPath.section)
            cell.accessoryType = (allowedItems == nil || allowedItems!.count == itemSet.count) ? .checkmark : .none
        } else {
            if #available(iOS 13.0, *) {
                if itemSet.count == 1 {
                    cell.textLabel?.textColor = .placeholderText
                } else {
                    cell.textLabel?.textColor = .label
                }
            } else {
                if itemSet.count == 1 {
                    cell.textLabel?.textColor = .lightGray
                } else {
                    cell.textLabel?.textColor = .black
                }
            }
            let item = itemSet[scheduleItemIndex(for: indexPath)]
            cell.textLabel?.text = item.map({ $0.stringEquivalent(withLocation: false) }).joined(separator: ", ")
            let locations = Set<String>(item.compactMap({ $0.location }))
            cell.detailTextLabel?.text = locations.count == 1 ? (locations.first ?? "") : (item.compactMap({ $0.location }).joined(separator: ", "))
            
            cell.accessoryType = isScheduleItemAllowed(at: indexPath) ? .checkmark : .none
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return (scheduleItemSet(for: indexPath.section)?.count ?? 0) > 1
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let itemSet = scheduleItemSet(for: indexPath.section) else {
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        if itemSet.count > 1, indexPath.row == 0 {
            let allowedItems = allowedScheduleItems(for: indexPath.section)
            if allowedItems == nil || allowedItems!.count == itemSet.count {
                // Select none - don't do anything, we need at least one selected
            } else if let scheduleSet = scheduleItemSet(for: indexPath.section) {
                // Select all
                setAllowedScheduleItems([Int](0..<scheduleSet.count), for: indexPath.section)
            }
        } else if let scheduleSet = scheduleItemSet(for: indexPath.section) {
            let itemIndex = scheduleItemIndex(for: indexPath)
            var allowedItems = allowedScheduleItems(for: indexPath.section) ?? [Int](0..<scheduleSet.count)
            if let index = allowedItems.index(of: itemIndex) {
                // Deselect - only do so if at least one in the section is selected
                if allowedItems.count > 1 {
                    allowedItems.remove(at: index)
                }
            } else {
                allowedItems.append(itemIndex)
            }
            setAllowedScheduleItems(allowedItems, for: indexPath.section)
        }
        tableView.reloadData()
        delegate?.scheduleConstraintViewController(self, updatedAllowedSections: allowedSections)
    }
}
