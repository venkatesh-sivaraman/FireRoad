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
    
    var currentUser: User?
    
    @IBOutlet var topConstraint: NSLayoutConstraint?
    @IBOutlet var heightConstraint: NSLayoutConstraint?
    
    @IBOutlet var hideButton: UIButton?
    
    static let oneButtonCellIdentifier = "OneButtonCell"
    static let buttonCellIdentifier = "ButtonCell"
    
    // If changing number of headings, the height of the pop down menu may need to be changed in the storyboard
    var headings = [
        "Favorites",
        "Schedule",
        "Prior Credit"
    ]
    
    func semester(forButtonAt indexPath: IndexPath, tag: Int) -> UserSemester? {
        return UserSemester(season: Season.values[tag - 1], year: indexPath.row - 2)
    }
    
    let cellHeight: CGFloat = 60.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Update headings based on semesters present in document
        if let user = currentUser {
            headings += (1...user.numYears).map { UserSemester.descriptionForYear($0) }
        }
        
        if let height = heightConstraint {
            height.constant = CGFloat(headings.count) * cellHeight
            topConstraint?.constant = -height.constant
        }
        blurView?.effect = nil
        hideButton?.setImage(hideButton?.image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .normal)
    }
    
    @IBAction func touchOnBackgroundView(_ sender: UITapGestureRecognizer) {
        delegate?.popDownTableMenuCanceled(self)
    }
    
    @IBAction func hideButtonTapped(_ sender: AnyObject) {
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
                        rootTab.currentUser?.courses(forSemester: UserSemester.priorCredit()).contains(currentCourse) == true {
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
            var heading = headings[indexPath.row]
            if tableView.frame.size.width <= 350.0,
                let space = heading.index(of: " ") {
                heading = String(heading[heading.startIndex..<space])
            }
            textLabel.text = heading
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
                    button.alpha = ((course?.isOfferedFall == true) && !semesterContainsCourse) ? 1.0 : 0.3
                    button.setTitle("Fall", for: .normal)
                case 2:
                    button.alpha = ((course?.isOfferedIAP == true) && !semesterContainsCourse) ? 1.0 : 0.3
                    button.setTitle("IAP", for: .normal)
                case 3:
                    button.alpha = ((course?.isOfferedSpring == true) && !semesterContainsCourse) ? 1.0 : 0.3
                    button.setTitle("Spring", for: .normal)
                case 4:
                    button.alpha = ((course?.isOfferedSummer == true) && !semesterContainsCourse) ? 1.0 : 0.3
                    button.setTitle("Summer", for: .normal)
                default:
                    button.isEnabled = false
                }
                button.titleLabel?.minimumScaleFactor = 0.7
                button.titleLabel?.adjustsFontSizeToFitWidth = true
                
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
                rootTab.currentUser?.courses(forSemester: UserSemester.priorCredit()).contains(course) == true {
            } else {
                delegate?.popDownTableMenu(self, addedCourse: course, to: UserSemester.priorCredit())
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
        var effect: UIBlurEffect
        if #available(iOS 13.0, *) {
            effect = UIBlurEffect(style: .systemMaterial)
        } else {
            effect = UIBlurEffect(style: .light)
        }
        hideButton?.alpha = 0.0
        self.topConstraint?.constant = 0.0
        self.view.setNeedsLayout()
        if animated {
            UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                self.blurView?.effect = effect
                self.view.layoutIfNeeded()
                self.hideButton?.alpha = 1.0
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
                self.hideButton?.alpha = 0.0
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
