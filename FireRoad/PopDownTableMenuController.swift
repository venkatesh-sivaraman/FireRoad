//
//  PopDownTableMenuController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 10/14/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol PopDownTableMenuDelegate: class {
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourseToFavorites course: Course)
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourseToSchedule course: Course)
    func popDownTableMenu(_ tableMenu: PopDownTableMenuController, addedCourse course: Course, to semester: UserSemester)
    func popDownTableMenuCanceled(_ tableMenu: PopDownTableMenuController)
}

class PopDownTableMenuController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet var blurView: UIVisualEffectView?
    @IBOutlet var tableView: UITableView!

    var course: Course?
    weak var delegate: PopDownTableMenuDelegate?
    
    @IBOutlet var topConstraint: NSLayoutConstraint?
    @IBOutlet var heightConstraint: NSLayoutConstraint?
    
    static let oneButtonCellIdentifier = "OneButtonCell"
    static let buttonCellIdentifier = "ButtonCell"
    
    let headings = [
        "Favorites",
        "Schedule",
        "Prior Credit",
        "1st Year",
        "2nd Year",
        "3rd Year",
        "4th Year"
    ]
    
    func semester(forButtonAt indexPath: IndexPath, tag: Int) -> UserSemester? {
        return UserSemester(rawValue: (indexPath.row - 3) * 3 + tag)
    }
    
    let cellHeight: CGFloat = 60.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let height = heightConstraint {
            height.constant = CGFloat(headings.count) * cellHeight
            topConstraint?.constant = -height.constant
        }
        blurView?.effect = nil
    }
    
    @IBAction func touchOnBackgroundView(_ sender: UITapGestureRecognizer) {
        delegate?.popDownTableMenuCanceled(self)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return headings.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row < 3 {
            let cell = tableView.dequeueReusableCell(withIdentifier: PopDownTableMenuController.oneButtonCellIdentifier, for: indexPath)
            if let imageView = cell.viewWithTag(34) as? UIImageView,
                let label = cell.viewWithTag(12) as? UILabel {
                label.alpha = 1.0
                imageView.alpha = 1.0
                cell.selectionStyle = .default
                
                if indexPath.row == 0, let course = course {
                    let isInFavorites = CourseManager.shared.favoriteCourses.contains(course)
                    let image = isInFavorites ? UIImage(named: "heart-filled") : UIImage(named: "heart")
                    imageView.image = image?.withRenderingMode(.alwaysTemplate)
                    label.text = isInFavorites ? "Remove from Favorites" : "Add to Favorites"
                } else if indexPath.row == 1 {
                    imageView.image = UIImage(named: "calendar")?.withRenderingMode(.alwaysTemplate)
                    label.text = "Add to Schedule"
                } else if indexPath.row == 2 {
                    imageView.image = UIImage(named: "prior-credit")?.withRenderingMode(.alwaysTemplate)
                    if let rootTab = rootParent as? RootTabViewController,
                        let currentCourse = course,
                        rootTab.currentUser?.courses(forSemester: .PreviousCredit).contains(currentCourse) == true {
                        label.text = "Added to Prior Credit"
                        label.alpha = 0.3
                        imageView.alpha = 0.3
                        cell.selectionStyle = .none
                    } else {
                        label.text = "Prior Credit"
                    }
                }
            }
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: PopDownTableMenuController.buttonCellIdentifier, for: indexPath)
        if let textLabel = cell.viewWithTag(12) as? UILabel {
            textLabel.text = headings[indexPath.row]
        }
        cell.selectionStyle = .none
        for view in cell.contentView.subviews {
            if let button = view as? UIButton {
                button.removeTarget(nil, action: nil, for: .touchUpInside)
                button.addTarget(self, action: #selector(semesterButtonTapped(_:)), for: .touchUpInside)
                
                var semesterContainsCourse = false
                if let rootTab = rootParent as? RootTabViewController,
                    let currentCourse = course,
                    let semester = semester(forButtonAt: indexPath, tag: button.tag),
                    rootTab.currentUser?.courses(forSemester: semester).contains(currentCourse) == true {
                    semesterContainsCourse = true
                }

                switch button.tag {
                case 1:
                    button.isEnabled = (course?.isOfferedFall == true) && !semesterContainsCourse
                    button.setTitle("Fall", for: .normal)
                case 2:
                    button.isEnabled = (course?.isOfferedIAP == true) && !semesterContainsCourse
                    button.setTitle("IAP", for: .normal)
                case 3:
                    button.isEnabled = (course?.isOfferedSpring == true) && !semesterContainsCourse
                    button.setTitle("Spring", for: .normal)
                default:
                    button.isEnabled = false
                }
                
                if semesterContainsCourse {
                    button.setTitle("Added", for: .normal)
                }
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let course = course else {
            return
        }
        if indexPath.row == 0 {
            delegate?.popDownTableMenu(self, addedCourseToFavorites: course)
        } else if indexPath.row == 1 {
            delegate?.popDownTableMenu(self, addedCourseToSchedule: course)
        } else if indexPath.row == 2 {
            if let rootTab = rootParent as? RootTabViewController,
                rootTab.currentUser?.courses(forSemester: .PreviousCredit).contains(course) == true {
            } else {
                delegate?.popDownTableMenu(self, addedCourse: course, to: .PreviousCredit)
            }
        }
    }
    
    @objc func semesterButtonTapped(_ sender: UIButton) {
        guard let course = course,
            let indexPath = tableView.indexPathsForVisibleRows?.first(where: { (ip) -> Bool in
                if let cell = tableView.cellForRow(at: ip) {
                    return sender.isDescendant(of: cell)
                }
                return false
            }) else {
                print("Couldn't find button in visible cells")
                return
        }
        if let semester = semester(forButtonAt: indexPath, tag: sender.tag) {
            delegate?.popDownTableMenu(self, addedCourse: course, to: semester)
        }
    }
    
    func show(animated: Bool) {
        let effect = UIBlurEffect(style: .light)
        self.topConstraint?.constant = 0.0
        self.view.setNeedsLayout()
        if animated {
            UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                self.blurView?.effect = effect
                self.view.layoutIfNeeded()
            }, completion: nil)
        }
    }
    
    func hide(animated: Bool, completion: (() -> Void)? = nil) {
        if let height = heightConstraint {
            topConstraint?.constant = -height.constant
        }
        self.view.setNeedsLayout()
        if animated {
            UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                self.blurView?.effect = nil
                self.view.layoutIfNeeded()
            }, completion: { completed in
                if completed {
                    completion?()
                }
            })
        } else {
            completion?()
        }
    }
}
