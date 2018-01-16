//
//  CourseroadWarningsViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 12/25/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol CourseroadWarningsDelegate: class {
    func warningsController(_ warningsController: CourseroadWarningsViewController, setOverride override: Bool, for course: Course)
    func warningsController(_ warningsController: CourseroadWarningsViewController, requestedDetailsAbout course: Course)
    func warningsControllerDismissed(_ warningsController: CourseroadWarningsViewController)
}

class CourseroadWarningsViewController: UITableViewController {

    var allWarnings: [(course: Course, warnings: [User.CourseWarning], overridden: Bool)] = []
    
    var focusedCourse: Course?
    
    weak var delegate: CourseroadWarningsDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let course = focusedCourse,
            let index = allWarnings.index(where: { $0.course == course }) {
            tableView.scrollToRow(at: IndexPath(row: 0, section: index), at: .middle, animated: true)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func doneButtonPressed(_ sender: AnyObject) {
        delegate?.warningsControllerDismissed(self)
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return allWarnings.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allWarnings[section].warnings.count + 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return allWarnings[section].course.subjectID
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: indexPath.row == 0 ? "OverrideCell" : "WarningCell", for: indexPath)

        if indexPath.row == 0 {
            if let overrideSwitch = cell.viewWithTag(12) as? UISwitch {
                overrideSwitch.isOn = allWarnings[indexPath.section].overridden
                overrideSwitch.removeTarget(nil, action: nil, for: .valueChanged)
                overrideSwitch.addTarget(self, action: #selector(CourseroadWarningsViewController.overrideSwitchChanged(_:)), for: .valueChanged)
            }
        } else {
            let warning = allWarnings[indexPath.section].warnings[indexPath.row - 1]
            let textLabel = (cell.viewWithTag(12) as? UILabel) ?? cell.textLabel
            let detail = (cell.viewWithTag(34) as? UILabel) ?? cell.detailTextLabel
            textLabel?.text = warning.type.rawValue
            detail?.text = warning.message ?? ""
            cell.contentView.alpha = allWarnings[indexPath.section].overridden ? 0.3 : 1.0
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row > 0
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate?.warningsController(self, requestedDetailsAbout: allWarnings[indexPath.section].course)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 {
            return 44.0
        }
        return 72.0
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    @objc func overrideSwitchChanged(_ sender: UISwitch) {
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
        let newItem = (allWarnings[selectedIndexPath.section].course, allWarnings[selectedIndexPath.section].warnings, sender.isOn)
        allWarnings[selectedIndexPath.section] = newItem
        delegate?.warningsController(self, setOverride: sender.isOn, for: allWarnings[selectedIndexPath.section].course)
        tableView.reloadSections(IndexSet(integer: selectedIndexPath.section), with: .fade)
    }
}
