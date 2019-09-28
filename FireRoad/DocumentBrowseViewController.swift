//
//  DocumentBrowseViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/2/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol DocumentBrowseDelegate: class {
    func documentBrowserAddedItem(_ browser: DocumentBrowseViewController)
    func documentBrowser(_ browser: DocumentBrowseViewController, deletedItem item: DocumentBrowseViewController.Item)
    func documentBrowser(_ browser: DocumentBrowseViewController, selectedItem item: DocumentBrowseViewController.Item)
    func documentBrowser(_ browser: DocumentBrowseViewController, wantsRename item: DocumentBrowseViewController.Item, completion: @escaping ((DocumentBrowseViewController.Item?) -> Void))
    func documentBrowser(_ browser: DocumentBrowseViewController, wantsDuplicate item: DocumentBrowseViewController.Item, completion: @escaping ((DocumentBrowseViewController.Item?) -> Void))
    func documentBrowserDismissed(_ browser: DocumentBrowseViewController)
}

class DocumentBrowseViewController: UITableViewController {

    struct Item: Equatable {
        var identifier: String
        var title: String
        var description: String
        var image: UIImage?
        
        static func ==(lhs: DocumentBrowseViewController.Item, rhs: DocumentBrowseViewController.Item) -> Bool {
            return lhs.identifier == rhs.identifier
        }
    }
    
    var items: [Item] = [] {
        didSet {
            if isViewLoaded && !isEditingRow {
                tableView.reloadSections(IndexSet(integer: 0), with: .fade)
            }
        }
    }
    var showsCancelButton = false
    var itemToHighlight: Item? = nil
    var isEditingRow = false
    
    weak var delegate: DocumentBrowseDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if showsCancelButton {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(DocumentBrowseViewController.doneButtonTapped(_:)))
        }
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(DocumentBrowseViewController.addButtonTapped(_:)))
        
        preferredContentSize = CGSize(width: 320.0, height: 500.0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let item = itemToHighlight,
            let index = items.index(of: item) {
            self.tableView.selectRow(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: .none)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let item = itemToHighlight,
            let index = items.index(of: item) {
            self.tableView.deselectRow(at: IndexPath(row: index, section: 0), animated: true)
            itemToHighlight = nil
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func doneButtonTapped(_ sender: AnyObject) {
        delegate?.documentBrowserDismissed(self)
    }
    
    @objc func addButtonTapped(_ sender: AnyObject) {
        delegate?.documentBrowserAddedItem(self)
    }
    
    func update(item: Item) {
        guard let index = items.index(where: { $0.identifier == item.identifier }) else {
            return
        }
        let selection = self.tableView.indexPathForSelectedRow
        items[index] = item
        self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: selection?.row == index ? .none : .fade)
        self.tableView.selectRow(at: selection, animated: false, scrollPosition: .none)
    }

    // MARK: - Table View Data Source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath)

        let item = items[indexPath.row]
        
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.description
        cell.imageView?.image = item.image
        cell.imageView?.layer.shadowColor = UIColor.lightGray.cgColor
        cell.imageView?.layer.shadowOffset = CGSize(width: 1.0, height: 3.0)
        cell.imageView?.layer.shadowRadius = 6.0
        cell.imageView?.layer.shadowOpacity = 0.6
        cell.imageView?.layer.masksToBounds = false
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 66.0
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate?.documentBrowser(self, selectedItem: items[indexPath.row])
    }
    
    // MARK: - Editing
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteItem(at: indexPath)
        }
    }
    
    func deleteItem(at indexPath: IndexPath) {
        let item = items[indexPath.row]
        items.remove(at: indexPath.row)
        delegate?.documentBrowser(self, deletedItem: item)
        tableView.deleteRows(at: [indexPath], with: .fade)
        if showsCancelButton {
            navigationItem.leftBarButtonItem?.isEnabled = (items.count > 0)
        }
    }
    
    override func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
        isEditingRow = true
    }
    
    override func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
        isEditingRow = false
    }
    
    @available(iOS 11.0, *)
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { (_, _, completionHandler) in
            self.deleteItem(at: indexPath)
            self.isEditingRow = false
            completionHandler(true)
        }
        let rename = UIContextualAction(style: .normal, title: "Rename") { (_, _, completionHandler) in
            self.delegate?.documentBrowser(self, wantsRename: self.items[indexPath.row], completion: { (newItem) in
                self.isEditingRow = false
                if let item = newItem {
                    self.items[indexPath.row] = item
                    self.tableView.reloadRows(at: [indexPath], with: .fade)
                    completionHandler(true)
                } else {
                    completionHandler(false)
                }
            })
        }
        rename.backgroundColor = self.view.tintColor
        let duplicate = UIContextualAction(style: .normal, title: "Duplicate") { (_, _, completionHandler) in
            self.delegate?.documentBrowser(self, wantsDuplicate: self.items[indexPath.row], completion: { (newItem) in
                self.isEditingRow = false
                if let item = newItem {
                    self.items.insert(item, at: 0)
                    completionHandler(true)
                } else {
                    completionHandler(false)
                }
            })
        }
        duplicate.backgroundColor = UIColor(red: 140.0 / 255.0, green: 0.0, blue: 1.0, alpha: 1.0)
        let swipeAction = UISwipeActionsConfiguration(actions: [delete, duplicate, rename])
        swipeAction.performsFirstActionWithFullSwipe = false
        return swipeAction
    }

}
