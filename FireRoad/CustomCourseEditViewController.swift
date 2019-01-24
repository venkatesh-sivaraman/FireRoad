//
//  CustomCourseEditViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/20/19.
//  Copyright © 2019 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol CustomCourseEditDelegate: class {
    func customCourseEditViewControllerDismissed(_ controller: CustomCourseEditViewController)
    func customCourseEditViewController(_ controller: CustomCourseEditViewController, finishedEditing course: Course)
}

class CustomCourseEditViewController: UITableViewController, UITextFieldDelegate, CourseColorSelectDelegate {

    weak var delegate: CustomCourseEditDelegate?
    var showsCancelButton = false
    
    enum DoneButtonMode {
        case save
        case add
    }
    
    var doneButtonMode: DoneButtonMode = .save
    
    enum CellIdentifier {
        static let textFieldCell = "TextFieldCell"
        static let switchCell = "SwitchCell"
        static let sliderCell = "SliderCell"
        static let colorCell = "ColorCell"
    }
    
    enum CourseEditItem {
        case title
        case currentValue
        case placeholder
        case textMaxLength
        case sliderMin
        case sliderMax
        case sliderStep
        case identifier
    }
    
    enum CourseEditField {
        static let subjectID = "Short Code"
        static let title = "Title"
        static let units = "Units"
        static let inClassHours = "In-Class Hours"
        static let outOfClassHours = "Out-of-Class Hours"
        static let color = "Color"
    }
    
    var editItems: [(header: String?, footer: String?, items: [[CourseEditItem: Any]])] = []
    
    var course: Course? {
        didSet {
            if let json = course?.toJSON() {
                courseCopy = Course(json: json)
            }
        }
    }
    var courseCopy: Course?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Edit Activity"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: doneButtonMode == .save ? "Save" : "Add", style: .done, target: self, action: #selector(CustomCourseEditViewController.doneButtonPressed(_:)))
        if showsCancelButton {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(CustomCourseEditViewController.cancelButtonPressed(_:)))
        }
        
        if course == nil {
            course = Course(courseID: "", courseTitle: "", courseDescription: "")
            course?.creator = CourseManager.shared.recommenderUserID ?? UIDevice.current.name
            course?.isPublic = false
            course?.isOfferedFall = true
            course?.isOfferedIAP = true
            course?.isOfferedSpring = true
            course?.isOfferedSummer = true
            course?.totalUnits = 0
            course?.inClassHours = 0.0
            course?.outOfClassHours = 0.0
        }
        
        editItems = [
            ("Activity Name", nil, [[.title: CourseEditField.subjectID,
              .identifier: CellIdentifier.textFieldCell,
              .currentValue: course?.subjectID ?? "",
              .textMaxLength: 6,
              .placeholder: "(Max 6 characters)"],
             [.title: CourseEditField.title,
              .identifier: CellIdentifier.textFieldCell,
              .currentValue: course?.subjectTitle ?? "",
              .placeholder: "Enter a title"]
            ]),
            ("Units/Hours", nil, [[.title: CourseEditField.units,
              .identifier: CellIdentifier.sliderCell,
              .currentValue: course?.totalUnits ?? 0,
              .sliderMin: Float(0.0),
              .sliderMax: Float(18.0),
              .sliderStep: Float(1.0)],
             [.title: CourseEditField.inClassHours,
              .identifier: CellIdentifier.sliderCell,
              .currentValue: course?.inClassHours ?? 0.0,
              .sliderMin: Float(0.0),
              .sliderMax: Float(18.0),
              .sliderStep: Float(0.5)],
             [.title: CourseEditField.outOfClassHours,
              .identifier: CellIdentifier.sliderCell,
              .currentValue: course?.outOfClassHours ?? 0.0,
              .sliderMin: Float(0.0),
              .sliderMax: Float(18.0),
              .sliderStep: Float(0.5)]]),
            ("Color", nil, [[.title: CourseEditField.color,
              .currentValue: course?.customColor ?? "",
              .identifier: CellIdentifier.colorCell]])
        ]
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
    
    @objc func cancelButtonPressed(_ sender: UIBarButtonItem) {
        delegate?.customCourseEditViewControllerDismissed(self)
    }
    
    @objc func doneButtonPressed(_ sender: UIBarButtonItem) {
        guard let course = course,
            let courseCopy = courseCopy else {
            return
        }
        
        guard let id = courseCopy.subjectID, id.count > 0,
            let title = courseCopy.subjectTitle, title.count > 0 else {
                let alert = UIAlertController(title: "Missing Information", message: "Please fill in both the Short Code and Title fields.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                present(alert, animated: true, completion: nil)
                return
        }
        
        if let oldCourse = CourseManager.shared.getCourse(withID: id) ?? CourseManager.shared.customCourses()[id],
            oldCourse != course {
            let alert = UIAlertController(title: "Short Code Exists", message: "Please choose another short code for this activity.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        course.readJSON(courseCopy.toJSON())
        delegate?.customCourseEditViewController(self, finishedEditing: course)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return editItems.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return editItems[section].items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = editItems[indexPath.section].items[indexPath.item]
        let id = item[.identifier] as! String
        let cell = tableView.dequeueReusableCell(withIdentifier: id, for: indexPath)
        cell.selectionStyle = .none
        
        guard let title = item[.title] as? String else {
            return cell
        }
        (cell.viewWithTag(12) as? UILabel)?.text = title

        let textField: UITextField? = cell.viewWithTag(34) as? UITextField
        let slider: UISlider? = cell.viewWithTag(34) as? UISlider
        if title == CourseEditField.subjectID {
            textField?.autocapitalizationType = .allCharacters
        } else if title == CourseEditField.title {
            textField?.adjustsFontSizeToFitWidth = true
            textField?.autocapitalizationType = .words
        } else if id == CellIdentifier.sliderCell {
            slider?.minimumValue = item[.sliderMin] as! Float
            slider?.maximumValue = item[.sliderMax] as! Float
            slider?.isContinuous = true
        }
        textField?.placeholder = item[.placeholder] as? String
        textField?.text = item[.currentValue] as? String
        textField?.adjustsFontSizeToFitWidth = true
        textField?.clearButtonMode = .whileEditing
        textField?.returnKeyType = .done
        textField?.delegate = self
        if let val = item[.currentValue] as? Float {
            slider?.value = val
        } else if let val = item[.currentValue] as? Int {
            slider?.value = Float(val)
        }
        (cell.viewWithTag(56) as? UILabel)?.text = "\(item[.currentValue] ?? 0)"
        slider?.addTarget(self, action: #selector(CustomCourseEditViewController.sliderValueChanged(_:)), for: .valueChanged)
        
        if let colorCell = cell as? CourseColorSelectCell {
            colorCell.delegate = self
            colorCell.selectedColor = item[.currentValue] as? String
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return editItems[section].header
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return editItems[section].footer
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let ip = tableView.indexPathForRow(at: textField.convert(textField.frame.origin, to: tableView)),
            let text = textField.text,
            let textRange = Range(range, in: text) else {
                print("Couldn't find row for text field")
                return true
        }
        
        var item = editItems[ip.section].items[ip.item]
        var allow = true
        let newText = text.replacingCharacters(in: textRange, with: string)
        if item[.title] as? String == CourseEditField.subjectID {
            allow = newText.count <= item[.textMaxLength] as! Int
        }
        
        if allow {
            switch item[.title] as! String {
            case CourseEditField.subjectID:
                item[.currentValue] = newText
                courseCopy?.subjectID = newText
            case CourseEditField.title:
                item[.currentValue] = newText
                courseCopy?.subjectTitle = newText
            default:
                break
            }
            editItems[ip.section].items[ip.item] = item
        }
            
        return allow
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
    @objc func sliderValueChanged(_ slider: UISlider) {
        guard let ip = tableView.indexPathForRow(at: slider.convert(slider.frame.origin, to: tableView)) else {
            print("Couldn't find row for text field")
            return
        }
        
        var item = editItems[ip.section].items[ip.item]
        var newValue = slider.value
        if let step = item[.sliderStep] as? Float {
            newValue = round(newValue / step) * step
            slider.value = newValue
        }
        
        switch item[.title] as! String {
        case CourseEditField.units:
            item[.currentValue] = Int(newValue)
            courseCopy?.totalUnits = Int(newValue)
        case CourseEditField.inClassHours:
            item[.currentValue] = newValue
            courseCopy?.inClassHours = newValue
        case CourseEditField.outOfClassHours:
            item[.currentValue] = newValue
            courseCopy?.outOfClassHours = newValue
        default:
            break
        }
        editItems[ip.section].items[ip.item] = item
        if let cell = tableView.cellForRow(at: ip) {
            (cell.viewWithTag(56) as? UILabel)?.text = "\(item[.currentValue] ?? 0)"
        }
    }
    
    func colorSelectCell(_ cell: CourseColorSelectCell, selected colorLabel: String) {
        guard let ip = tableView.indexPath(for: cell) else {
            return
        }
        var item = editItems[ip.section].items[ip.item]
        item[.currentValue] = colorLabel
        courseCopy?.customColor = colorLabel
        editItems[ip.section].items[ip.item] = item
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
