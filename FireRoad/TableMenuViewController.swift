//
//  TableMenuViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/26/19.
//  Copyright © 2019 Base 12 Innovations. All rights reserved.
//

import UIKit

struct TableMenuItem {
    var identifier: String
    var title: String
    var image: UIImage?
    
    init(identifier: String, title: String, image: UIImage? = nil) {
        self.identifier = identifier
        self.title = title
        self.image = image
    }
}

class TableMenuViewController: UITableViewController {

    var items: [TableMenuItem] = []
    var selectedItemIndex: Int = -1
    
    /// Action to be performed when a given item is selected
    var action: ((TableMenuItem) -> Void)?
    
    init() {
        super.init(style: .plain)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell") ?? UITableViewCell(style: .default, reuseIdentifier: "ItemCell")
        let item = items[indexPath.row]
        cell.textLabel?.text = item.title
        cell.textLabel?.textColor = indexPath.row == selectedItemIndex ? view.tintColor : UIColor.black
        cell.accessoryType = indexPath.row == selectedItemIndex ? .checkmark : .none
        cell.imageView?.image = item.image

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        selectedItemIndex = indexPath.row
        tableView.deselectRow(at: indexPath, animated: true)
        action?(item)
        tableView.reloadData()
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
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
