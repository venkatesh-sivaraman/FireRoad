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
        static let addScheduleItemCell = "AddScheduleItemCell"
        static let timeCell = "TimeCell"
        static let daysCell = "DaysCell"
        static let pickerCell = "PickerCell"
        static let deleteCell = "DeleteScheduleItemCell"
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
        case scheduleItem
    }
    
    enum CourseEditField {
        static let subjectID = "Short Code"
        static let title = "Title"
        static let units = "Units"
        static let inClassHours = "In-Class Hours"
        static let outOfClassHours = "Out-of-Class Hours"
        static let color = "Color"
        static let addScheduleItem = "Add schedule item…"
        static let scheduleDays = "Days of Week"
        static let scheduleStart = "Start Time"
        static let scheduleEnd = "End Time"
        static let schedulePicker = "Picker"
        static let deleteScheduleItem = "Delete Item"
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
    
    var scheduleSectionIndex: Int {
        return editItems.count - 2
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Edit Activity"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: doneButtonMode == .save ? "Save" : "Add", style: .done, target: self, action: #selector(CustomCourseEditViewController.doneButtonPressed(_:)))
        if showsCancelButton {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(CustomCourseEditViewController.cancelButtonPressed(_:)))
        }
        
        if course == nil {
            let newCourse = Course(courseID: "", courseTitle: "", courseDescription: "")
            newCourse.creator = CourseManager.shared.recommenderUserID ?? UIDevice.current.name
            newCourse.isPublic = false
            newCourse.isOfferedFall = true
            newCourse.isOfferedIAP = true
            newCourse.isOfferedSpring = true
            newCourse.isOfferedSummer = true
            newCourse.totalUnits = 0
            newCourse.inClassHours = 0.0
            newCourse.outOfClassHours = 0.0
            course = newCourse
        }
        
        editItems = [
            ("Activity Name", nil, [[.title: CourseEditField.subjectID,
              .identifier: CellIdentifier.textFieldCell,
              .currentValue: course?.subjectID ?? "",
              .textMaxLength: 8,
              .placeholder: "(Max 8 characters)"],
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
            ("Schedule", nil, [[.title: CourseEditField.addScheduleItem,
                                .identifier: CellIdentifier.addScheduleItemCell]]),
            ("Color", nil, [[.title: CourseEditField.color,
              .currentValue: course?.customColor ?? "",
              .identifier: CellIdentifier.colorCell]])
        ]
        
        insertScheduleEditItems()
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
        
        if let oldCourse = CourseManager.shared.getCourse(withID: id) ?? CourseManager.shared.getCustomCourse(with: id, title: title),
            oldCourse != course {
            let alert = UIAlertController(title: "Short Code Exists", message: "Please choose another short code for this activity.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        if let schedule = courseCopy.schedule {
            var hasInverted = false
            var hasNoDays = false
            outer:
            for (_, val) in schedule {
                for itemSet in val {
                    for item in itemSet {
                        if item.days.isEmpty {
                            hasNoDays = true
                            break outer
                        } else if item.startTime >= item.endTime {
                            hasInverted = true
                            break outer
                        }
                    }
                }
            }
            
            if hasInverted {
                let alert = UIAlertController(title: "Invalid Schedule", message: "One or more schedule items has zero or negative duration.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                present(alert, animated: true, completion: nil)
                return
            } else if hasNoDays {
                let alert = UIAlertController(title: "Invalid Schedule", message: "One or more schedule items has no days associated with it.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                present(alert, animated: true, completion: nil)
                return
            }
        }
        
        course.readJSON(courseCopy.toJSON())
        delegate?.customCourseEditViewController(self, finishedEditing: course)
    }

    // MARK: - Table view data source
    
    var currentPickerIndexPath: IndexPath?

    override func numberOfSections(in tableView: UITableView) -> Int {
        return editItems.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return editItems[section].items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = editItems[indexPath.section].items[indexPath.row]
        let id = item[.identifier] as! String
        let cell = tableView.dequeueReusableCell(withIdentifier: id, for: indexPath)
        
        guard let title = item[.title] as? String else {
            return cell
        }
        (cell.viewWithTag(12) as? UILabel)?.text = title
        
        if id == CellIdentifier.pickerCell,
            let picker = cell.viewWithTag(34) as? UIDatePicker,
            let currentDate = item[.currentValue] as? Date {
            
            let calendar = Calendar(identifier: .gregorian)
            var dateComps = calendar.dateComponents([.month, .day, .year], from: Date())
            // Min date
            dateComps.hour = ScheduleSlotManager.slots[0].hour24
            dateComps.minute = 0
            picker.minimumDate = calendar.date(from: dateComps)
            // Max date
            dateComps.hour = ScheduleSlotManager.slots[ScheduleSlotManager.slots.count - 1].hour24
            dateComps.minute = 0
            picker.maximumDate = calendar.date(from: dateComps)
            picker.date = currentDate
            
            picker.addTarget(self, action: #selector(CustomCourseEditViewController.datePickerChanged(_:)), for: .valueChanged)
        } else if id == CellIdentifier.timeCell {
            cell.textLabel?.text = item[.title] as? String
            cell.detailTextLabel?.text = item[.currentValue] as? String
        } else if id == CellIdentifier.daysCell,
            let currentVal = item[.currentValue] as? CourseScheduleDay {
            // String like "MTW", "MRF", etc.
            for (i, day) in CourseScheduleDay.ordering.enumerated() {
                guard let btn = cell.viewWithTag(i + 100) as? UIButton else {
                    continue
                }
                btn.setTitleColor(.white, for: .selected)
                btn.addTarget(self, action: #selector(CustomCourseEditViewController.dayOfWeekButtonPressed(_:)), for: .touchUpInside)
                btn.layer.cornerRadius = 6.0
                btn.isSelected = currentVal.contains(day)
                //btn.backgroundColor = btn.isSelected ? btn.tintColor : UIColor.clear
            }
        }

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
        guard let ip = tableView.indexPathForRow(at: textField.convert(textField.bounds.origin, to: tableView)),
            let text = textField.text,
            let textRange = Range(range, in: text) else {
                print("Couldn't find row for text field")
                return true
        }
        
        var item = editItems[ip.section].items[ip.row]
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
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        hidePickerView()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
    @objc func sliderValueChanged(_ slider: UISlider) {
        hidePickerView()
        
        guard let ip = tableView.indexPathForRow(at: slider.convert(slider.bounds.origin, to: tableView)) else {
            print("Couldn't find row for text field")
            return
        }
        
        var item = editItems[ip.section].items[ip.row]
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
        editItems[ip.section].items[ip.row] = item
        if let cell = tableView.cellForRow(at: ip) {
            (cell.viewWithTag(56) as? UILabel)?.text = "\(item[.currentValue] ?? 0)"
        }
    }
    
    func colorSelectCell(_ cell: CourseColorSelectCell, selected colorLabel: String) {
        hidePickerView()
        
        guard let ip = tableView.indexPath(for: cell) else {
            return
        }
        var item = editItems[ip.section].items[ip.row]
        item[.currentValue] = colorLabel
        courseCopy?.customColor = colorLabel
        editItems[ip.section].items[ip.row] = item
    }
    
    @objc func dayOfWeekButtonPressed(_ sender: UIButton) {
        guard let ip = tableView.indexPathForRow(at: sender.convert(sender.bounds.origin, to: tableView)) else {
            print("Couldn't find row for text field")
            return
        }
        
        var item = editItems[ip.section].items[ip.row]
        guard let scheduleItem = item[.scheduleItem] as? CourseScheduleItem else {
            return
        }
        let day = CourseScheduleDay.ordering[sender.tag - 100]
        if (scheduleItem.days.contains(day)) {
            scheduleItem.days.remove(day)
        } else {
            scheduleItem.days = scheduleItem.days.union(day)
        }
        item[.currentValue] = scheduleItem.days
        editItems[ip.section].items[ip.row] = item
        
        sender.isSelected = !sender.isSelected
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = editItems[indexPath.section].items[indexPath.row]
        if item[.identifier] as? String == CellIdentifier.timeCell {
            // Open the picker, noting that the index path of this cell might change
            var newIndexPath = indexPath
            if let pickerIP = currentPickerIndexPath {
                var done = false
                if pickerIP.row == indexPath.row + 1 {
                    // We are deselecting, get out after hiding the picker
                    tableView.deselectRow(at: indexPath, animated: true)
                    done = true
                }
                if indexPath.row > pickerIP.row, indexPath.section == pickerIP.section {
                    newIndexPath = IndexPath(row: indexPath.row - 1, section: indexPath.section)
                }
                hidePickerView()
                if done {
                    return
                }
            }
            
            guard let scheduleItem = item[.scheduleItem] as? CourseScheduleItem else {
                return
            }
            let time = item[.title] as? String == CourseEditField.scheduleStart ? scheduleItem.startTime : scheduleItem.endTime
            tableView.selectRow(at: newIndexPath, animated: false, scrollPosition: .middle)
            showPicker(for: time, in: scheduleItem, from: newIndexPath)
        } else if item[.identifier] as? String == CellIdentifier.addScheduleItemCell {
            hidePickerView()
            let newItem = CourseScheduleItem(days: "", startTime: "12", endTime: "1")
            addScheduleEditItem(newItem, addToCourse: true)
        } else if item[.identifier] as? String == CellIdentifier.deleteCell,
            let currentSched = item[.scheduleItem] as? CourseScheduleItem {
            if let currentPickerIP = currentPickerIndexPath {
                let pickerItem = editItems[currentPickerIP.section].items[currentPickerIP.row]
                if let pickerSched = pickerItem[.scheduleItem] as? CourseScheduleItem,
                    pickerSched != currentSched {
                    // Out of this section - we won't hide it below, so hide it now
                    hidePickerView()
                }
            }
            
            editItems[indexPath.section].items.removeAll(where: { $0[.scheduleItem] as? CourseScheduleItem == currentSched})
            if let firstItems = courseCopy?.schedule?[CourseScheduleType.custom]?.first,
                let index = firstItems.firstIndex(of: currentSched) {
                courseCopy?.schedule?[CourseScheduleType.custom]?[0].remove(at: index)
            }
            tableView.reloadSections(IndexSet(integer: scheduleSectionIndex), with: .fade)
        }
    }
    
    // MARK: Schedule Items
    
    private func insertScheduleEditItems() {
        // Custom items should only have one section type, "custom", with at most one set of options.
        guard let items = courseCopy?.schedule?[CourseScheduleType.custom],
            items.count == 1 else {
            return
        }
        
        for item in items[0] {
            addScheduleEditItem(item, updateTable: false)
        }
    }
    
    private func addScheduleEditItem(_ item: CourseScheduleItem, addToCourse: Bool = false, updateTable: Bool = true) {
        let scheduleSection = editItems[scheduleSectionIndex]
        var scheduleItems = scheduleSection.items
        scheduleItems.insert([.title: CourseEditField.scheduleDays,
                              .identifier: CellIdentifier.daysCell,
                              .currentValue: item.days,
                              .scheduleItem: item], at: scheduleItems.count - 1)
        scheduleItems.insert([.title: CourseEditField.scheduleStart,
                              .identifier: CellIdentifier.timeCell,
                              .currentValue: item.startTime.stringEquivalent(withTimeOfDay: true),
                              .scheduleItem: item], at: scheduleItems.count - 1)
        scheduleItems.insert([.title: CourseEditField.scheduleEnd,
                              .identifier: CellIdentifier.timeCell,
                              .currentValue: item.endTime.stringEquivalent(withTimeOfDay: true),
                              .scheduleItem: item], at: scheduleItems.count - 1)
        scheduleItems.insert([.title: CourseEditField.deleteScheduleItem,
                              .identifier: CellIdentifier.deleteCell,
                              .scheduleItem: item], at: scheduleItems.count - 1)

        editItems[scheduleSectionIndex] = (scheduleSection.header, scheduleSection.footer, scheduleItems)
        
        if addToCourse, let courseCopy = courseCopy {
            if courseCopy.schedule == nil {
                courseCopy.schedule = [:]
            }
            var schedule = courseCopy.schedule!
            if schedule[CourseScheduleType.custom] == nil {
                schedule[CourseScheduleType.custom] = []
            }
            if schedule[CourseScheduleType.custom]?.count == 0 {
                schedule[CourseScheduleType.custom]?.append([])
            }
            schedule[CourseScheduleType.custom]?[0].append(item)
            courseCopy.schedule = schedule
        }
        
        if updateTable {
            tableView.reloadSections(IndexSet(integer: scheduleSectionIndex), with: .fade)
        }
    }
    
    // MARK: Picker View
    
    private func showPicker(for time: CourseScheduleTime, in scheduleItem: CourseScheduleItem, from clickedIndexPath: IndexPath) {
        let newIndexPath = IndexPath(row: clickedIndexPath.row + 1, section: clickedIndexPath.section)
        
        let calendar = Calendar(identifier: .gregorian)
        var dateComps = calendar.dateComponents([.month, .day, .year], from: Date())
        dateComps.hour = time.hour24
        dateComps.minute = time.minute
        guard let date = calendar.date(from: dateComps) else {
            return
        }
        
        editItems[clickedIndexPath.section].items.insert([.title: CourseEditField.schedulePicker, .identifier: CellIdentifier.pickerCell, .currentValue: date, .scheduleItem: scheduleItem], at: newIndexPath.row)
        tableView.insertRows(at: [newIndexPath], with: .fade)
        currentPickerIndexPath = newIndexPath

    }
    
    private func hidePickerView() {
        guard let indexPath = currentPickerIndexPath else {
            return
        }
        
        editItems[indexPath.section].items.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .fade)
        currentPickerIndexPath = nil
    }
    
    @IBAction func datePickerChanged(_ sender: UIDatePicker) {
        guard let indexPath = currentPickerIndexPath else {
            return
        }
        
        let components = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: sender.date)
        guard let hour = components.hour, let min = components.minute else {
            return
        }
        
        // Edit both the picker item, and the time it represents
        var item = editItems[indexPath.section].items[indexPath.row]
        var timeItem = editItems[indexPath.section].items[indexPath.row - 1]

        item[.currentValue] = sender.date
        if let scheduleItem = item[.scheduleItem] as? CourseScheduleItem {
            let newTime = CourseScheduleTime.fromString("\(hour % 12):\(min)", evening: hour >= 19)
            if timeItem[.title] as? String == CourseEditField.scheduleStart {
                scheduleItem.startTime = newTime
            } else {
                scheduleItem.endTime = newTime
            }
            scheduleItem.isEvening = (hour >= 19)
            timeItem[.currentValue] = newTime.stringEquivalent(withTimeOfDay: true)
        }
        editItems[indexPath.section].items[indexPath.row] = item
        editItems[indexPath.section].items[indexPath.row - 1] = timeItem
        
        // Select the above row, and set its detail text label
        let timeIndexPath = IndexPath(row: indexPath.row - 1, section: indexPath.section)
        if let label = tableView.cellForRow(at: timeIndexPath)?.detailTextLabel {
            label.text = timeItem[.currentValue] as? String
        }
    }
}
