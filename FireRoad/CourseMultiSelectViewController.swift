//
//  CourseMultiSelectViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/29/20.
//  Copyright © 2020 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol CourseMultiSelectDelegate: class {
    func courseMultiSelect(_ controller: CourseMultiSelectViewController, finishedWith courses: [Course])
    func courseMultiSelectCanceled(_ controller: CourseMultiSelectViewController)
    func courseMultiSelect(_ controller: CourseMultiSelectViewController, selectionChanged courses: [Course])
}

class CourseMultiSelectViewController: UITableViewController {

    weak var delegate: CourseMultiSelectDelegate?
    
    /// The user/road to show items for
    var currentUser: User?
    
    /// Courses to be shown in another category
    var additionalCourses: [Course] = []
    
    /// Courses initially selected
    var selectedCourses: [Course] = []
    
    private var coursesBySection: [(String, [Course])] = []
    
    private var doneButton: UIBarButtonItem?
    var doneButtonTitle = "Done" {
        didSet {
            doneButton?.title = doneButtonTitle
        }
    }
    var doneButtonEnabled = false {
        didSet {
            doneButton?.isEnabled = doneButtonEnabled
        }
    }
    private var cancelButton: UIBarButtonItem?
    var cancelButtonTitle = "Cancel" {
        didSet {
            cancelButton?.title = cancelButtonTitle
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.doneButton = UIBarButtonItem(title: doneButtonTitle, style: .done, target: self, action: #selector(doneButtonTapped(_:)))
        self.navigationItem.rightBarButtonItem = self.doneButton
        self.cancelButton = UIBarButtonItem(title: cancelButtonTitle, style: .plain, target: self, action: #selector(cancelButtonTapped(_:)))
        self.navigationItem.leftBarButtonItem = self.cancelButton
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateData()
    }

    @objc func doneButtonTapped(_ sender: UIBarButtonItem) {
        delegate?.courseMultiSelect(self, finishedWith: selectedCourses)
    }
    
    @objc func cancelButtonTapped(_ sender: UIBarButtonItem) {
        delegate?.courseMultiSelectCanceled(self)
    }
    
    func updateData() {
        coursesBySection = []
        guard let user = currentUser else {
            return
        }
        for semester in UserSemester.allSemesters {
            let courses = user.courses(forSemester: semester)
            if courses.count > 0 {
                coursesBySection.append((semester.toString(), courses))
            }
        }
        if additionalCourses.count > 0 {
            coursesBySection.append(("Other Courses", additionalCourses))
        }
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return coursesBySection.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return coursesBySection[section].1.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CourseCell", for: indexPath)

        let course = coursesBySection[indexPath.section].1[indexPath.row]
        if let cell = cell as? CourseBrowserCell {
            cell.course = course
        }

        cell.accessoryType = selectedCourses.contains(course) ? .checkmark : .none
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let course = coursesBySection[indexPath.section].1[indexPath.row]
        cell.backgroundColor = selectedCourses.contains(course) ? cell.tintColor.withAlphaComponent(0.1) : .clear
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return coursesBySection[section].0
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let course = coursesBySection[indexPath.section].1[indexPath.row]
        if let idx = selectedCourses.index(of: course) {
            selectedCourses.remove(at: idx)
        } else {
            selectedCourses.append(course)
        }
        delegate?.courseMultiSelect(self, selectionChanged: selectedCourses)
        tableView.reloadRows(at: [indexPath], with: .fade)
    }

}
