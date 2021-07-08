//
//  CustomCoursesViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/20/19.
//  Copyright © 2019 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol CustomCoursesViewControllerDelegate: class {
    func customCoursesViewController(_ controller: CustomCoursesViewController, added course: Course, to semester: UserSemester)
    func customCoursesViewController(_ controller: CustomCoursesViewController, addedCourseToSchedule course: Course)
    func customCoursesViewControllerDismissed(_ controller: CustomCoursesViewController)
}

class CustomCoursesViewController: CourseCollectionViewController, CourseCollectionViewThumbnailHandler, PopDownTableMenuDelegate, CustomCourseEditDelegate {

    /// If present, the course will be added directly to this semester. Otherwise, a pop down menu will be shown.
    var semester: UserSemester?
    /// If true, add directly to schedule.
    var addToSchedule = false
    weak var delegate: CustomCoursesViewControllerDelegate?
    private let addCoursePlaceholder = Course(courseID: "+", courseTitle: "Create new activity…", courseDescription: "")

    override func viewDidLoad() {
        super.viewDidLoad()
        thumbnailHandler = self
        loadCourses()
        navigationItem.title = "Custom Activities"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(CustomCoursesViewController.closeButtonPressed(_:)))
        navigationController?.navigationBar.isTranslucent = true
        NotificationCenter.default.addObserver(self, selector: #selector(CustomCoursesViewController.courseManagerSyncedPreferences(_:)), name: .CourseManagerPreferenceSynced, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func loadCourses() {
        courses = CourseManager.shared.customCourses().sorted(by: { ($0.subjectID ?? "").lexicographicallyPrecedes($1.subjectID ?? "") }) + [addCoursePlaceholder]
        collectionView?.reloadData()
    }
    
    @objc func courseManagerSyncedPreferences(_ note: Notification) {
        loadCourses()
    }
    
    func courseCollectionViewController(wantsFormat cell: CourseThumbnailCell, at indexPath: IndexPath) {
        cell.showsWarningIcon = false
        cell.showsWarningsMenuItem = false
        if indexPath.item == courses.count - 1 {
            cell.backgroundColor = UIColor(red: 0.6, green: 0.12, blue: 0.13, alpha: 1.0)
            cell.action = {
                // Add a course here
                self.editCourse(nil)
            }
        } else {
            cell.action = nil
            cell.showsViewMenuItem = false
            cell.showsAddMenuItem = true
            cell.showsEditMenuItem = true
            cell.showsRateMenuItem = false
            cell.showsConstraintMenuItem = false
        }
    }
    
    override func titleTextSize(for indexPath: IndexPath) -> CGFloat {
        if indexPath.item == courses.count - 1 {
            return super.titleTextSize(for: indexPath) * 1.75
        }
        return super.titleTextSize(for: indexPath)
    }
    
    func courseThumbnailCellWantsEdit(_ cell: CourseThumbnailCell) {
        guard let course = cell.course else {
            return
        }
        editCourse(course)
    }
    
    func courseThumbnailCellWantsDelete(_ cell: CourseThumbnailCell) {
        guard let course = cell.course else {
            return
        }
        
        CourseManager.shared.removeCustomCourse(course)
        loadCourses()
    }
    
    func courseThumbnailCellWantsAdd(_ cell: CourseThumbnailCell) {
        guard let course = cell.course else {
            return
        }
        if let semester = semester {
            delegate?.customCoursesViewController(self, added: course, to: semester)
        } else if addToSchedule {
            delegate?.customCoursesViewController(self, addedCourseToSchedule: course)
        } else {
            addCourse(course)
        }
    }
    
    @objc func closeButtonPressed(_ sender: UIBarButtonItem) {
        delegate?.customCoursesViewControllerDismissed(self)
    }
    
    // MARK: - Pop Down Table Menu
    
    func addCourse(_ course: Course) {
        guard let popDown = self.storyboard?.instantiateViewController(withIdentifier: "PopDownTableMenu") as? PopDownTableMenuController,
            let rootTab = rootParent as? RootTabViewController else {
            return
        }
        popDown.course = course
        popDown.currentUser = rootTab.currentUser
        popDown.delegate = self
        let containingView: UIView = self.view
        containingView.addSubview(popDown.view)
        popDown.view.translatesAutoresizingMaskIntoConstraints = false
        popDown.view.leftAnchor.constraint(equalTo: containingView.leftAnchor).isActive = true
        popDown.view.rightAnchor.constraint(equalTo: containingView.rightAnchor).isActive = true
        popDown.view.bottomAnchor.constraint(equalTo: containingView.bottomAnchor).isActive = true
        popDown.view.topAnchor.constraint(equalTo: containingView.topAnchor).isActive = true
        popDown.willMove(toParentViewController: self)
        self.addChildViewController(popDown)
        popDown.didMove(toParentViewController: self)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            popDown.show(animated: true)
        }
        popDownOldNavigationTitle = navigationItem.title
        navigationItem.title = "(\(course.subjectID ?? ""))"
        navigationItem.leftBarButtonItem?.isEnabled = false
    }
    
    var popDownOldNavigationTitle: String?
    
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourseToFavorites course: Course) {
        if CourseManager.shared.favoriteCourses.contains(course) {
            CourseManager.shared.markCourseAsNotFavorite(course)
        } else {
            CourseManager.shared.markCourseAsFavorite(course)
        }
        popDownTableMenuCanceled(tableMenu)
    }
    
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourseToSchedule course: Course) {
        delegate?.customCoursesViewController(self, addedCourseToSchedule: course)
        popDownTableMenuCanceled(tableMenu)
    }
    
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourse course: Course, to semester: UserSemester) {
        delegate?.customCoursesViewController(self, added: course, to: semester)
        popDownTableMenuCanceled(tableMenu)
    }
    
    func popDownTableMenuCanceled(_ tableMenu: PopDownTableMenuController) {
        navigationItem.rightBarButtonItem?.isEnabled = true
        if let oldTitle = popDownOldNavigationTitle {
            navigationItem.title = oldTitle
        }
        navigationItem.leftBarButtonItem?.isEnabled = true
        tableMenu.hide(animated: true) {
            tableMenu.willMove(toParentViewController: nil)
            tableMenu.view.removeFromSuperview()
            tableMenu.removeFromParentViewController()
            tableMenu.didMove(toParentViewController: nil)
        }
    }

    // MARK: Editor
    
    /**
     Edit the given course, or if nil, create a new course.
     */
    func editCourse(_ course: Course?) {
        guard let editVC = self.storyboard?.instantiateViewController(withIdentifier: "CustomCourseEditVC") as? CustomCourseEditViewController else {
            return
        }
        editVC.course = course
        editVC.delegate = self
        editVC.doneButtonMode = course != nil ? .save : .add
        self.navigationController?.pushViewController(editVC, animated: true)
    }
    
    func customCourseEditViewControllerDismissed(_ controller: CustomCourseEditViewController) {
        // Do nothing
    }
    
    func customCourseEditViewController(_ controller: CustomCourseEditViewController, finishedEditing course: Course) {
        CourseManager.shared.setCustomCourse(course)

        if controller.doneButtonMode == .add, let semester = semester {
            // Add the course directly to the selected semester
            delegate?.customCoursesViewController(self, added: course, to: semester)
        } else if controller.doneButtonMode == .add, addToSchedule {
            delegate?.customCoursesViewController(self, addedCourseToSchedule: course)
        } else {
            navigationController?.popViewController(animated: true)
            loadCourses()
            
            if controller.doneButtonMode == .add {
                // Add the course directly
                addCourse(course)
            }
        }
    }
}
