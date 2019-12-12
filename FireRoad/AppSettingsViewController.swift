//
//  AppSettingsViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/28/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol AppSettingsViewControllerDelegate: class {
    func settingsViewControllerDismissed(_ settings: AppSettingsViewController)
    func settingsViewControllerWantsAuthenticationView(_ settings: AppSettingsViewController)
}

class AppSettingsViewController: UITableViewController, AppSettingsDelegate {

    weak var delegate: AppSettingsViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        navigationItem.title = "Settings"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped(_:)))
        
        AppSettings.shared.presentationDelegate = self
        tableView.allowsSelection = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func doneButtonTapped(_ sender: AnyObject) {
        delegate?.settingsViewControllerDismissed(self)
    }
    
    // MARK: - Table view data source

    func cellIdentifier(for setting: AppSettingsItem) -> String {
        switch setting.type {
        case .boolean:
            return "SwitchCell"
        case .button:
            return "ButtonCell"
        case .readOnlyText:
            return "TextCell"
        case .checkmark:
            return "CheckmarkCell"
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return AppSettings.shared.settings.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AppSettings.shared.settings[section].items.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return AppSettings.shared.settings[section].header
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return AppSettings.shared.settings[section].footer
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let setting = AppSettings.shared.settings[indexPath.section].items[indexPath.row]
        switch setting.type {
        case .boolean, .button, .checkmark:
            return 44.0
        default:
            return UITableViewAutomaticDimension
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let setting = AppSettings.shared.settings[indexPath.section].items[indexPath.row]
        let identifier = cellIdentifier(for: setting)
        
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        let textLabel = (cell.viewWithTag(12) as? UILabel) ?? cell.textLabel
        let detailTextLabel = (cell.viewWithTag(34) as? UILabel) ?? cell.detailTextLabel
        textLabel?.text = setting.title
        detailTextLabel?.text = ""
        
        switch setting.type {
        case .boolean:
            if let cellSwitch = cell.viewWithTag(34) as? UISwitch {
                cellSwitch.isOn = (setting.currentValue as? Bool) ?? false
                cellSwitch.removeTarget(nil, action: nil, for: .valueChanged)
                cellSwitch.addTarget(self, action: #selector(switchActivated(_:)), for: .valueChanged)
            }
        case .readOnlyText, .button:
            if let value = setting.currentValue as? String {
                detailTextLabel?.text = value
            }
        case .checkmark:
            cell.accessoryType = (setting.currentValue as? Bool) == true ? .checkmark : .none
            var labelColor: UIColor
            if #available(iOS 13.0, *) {
                labelColor = .label
            } else {
                labelColor = .black
            }
            textLabel?.textColor = (setting.currentValue as? Bool) == true ? cell.tintColor : labelColor
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let group = AppSettings.shared.settings[indexPath.section]
        let setting = group.items[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        if setting.type == .button {
            setting.setter?(nil)
        } else if setting.type == .checkmark {
            setting.setter?(true)
        }
        if group.reloadOnSelect {
            tableView.reloadSections(IndexSet(integer: indexPath.section), with: .fade)
        }
    }
    
    @objc func switchActivated(_ sender: UISwitch) {
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
        let group = AppSettings.shared.settings[selectedIndexPath.section]
        var setting = group.items[selectedIndexPath.row]
        setting.currentValue = sender.isOn
        if group.reloadOnSelect {
            tableView.reloadSections(IndexSet(integer: selectedIndexPath.section), with: .fade)
        }
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

    func showAuthenticationView() {
        delegate?.settingsViewControllerWantsAuthenticationView(self)
    }
}
