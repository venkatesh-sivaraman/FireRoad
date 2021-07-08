//
//  CourseBrowserCell.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/7/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol CourseBrowserCellDelegate: class {
    func browserCell(added course: Course) -> UserSemester?  // Return the semester to which the course was added
}

class CourseBrowserCell: UITableViewCell {

    @IBOutlet var titleLabel: UILabel! = nil
    @IBOutlet var descriptionLabel: UILabel! = nil
    @IBOutlet var addLabel: UILabel? = nil
    @IBOutlet var colorCoder: UIView? = nil
    
    var sort: SortOption? {
        didSet {
            updateTitle()
        }
    }
    
    func updateTitle() {
        var title = course?.subjectID ?? ""
        if let level = course?.subjectLevel, level != .undergraduate {
            title += " (\(level.rawValue))"
        }
        if course?.isHistorical == true {
            title = "⚠︎ " + title
        }
        
        if self.sort == .rating {
            if course?.rating == 0.0 {
                title += " (no rating available)"
            } else {
                title += " (" + String(format: "%.1f/7.0", course?.rating ?? 0.0) + ")"
            }
            
        }
        else if self.sort == .hours {
            if Double(course?.inClassHours ?? 0.0) + Double(course?.outOfClassHours ?? 0.0) == 0.0 {
                title += " (no hours available)"
            } else {
                title += " (" + String(format: "%.1f/week", (Double(course?.inClassHours ?? 0.0) + Double(course?.outOfClassHours ?? 0.0))) + ")"
            }
        }
        self.titleLabel.text = title
    }
    
    var course: Course? = nil {
        didSet {
            updateTitle()
            
            var descriptionText = course?.subjectTitle ?? ""
            if course?.virtualStatus == .hybrid ||  course?.virtualStatus == .inperson  {
                descriptionText = "(In-Person Available) " + descriptionText
            }
            self.descriptionLabel.text = descriptionText
           
            self.addLabel?.text = ""
            if self.course != nil {
                self.colorCoder?.backgroundColor = CourseManager.shared.color(forCourse: course!)
            }
        }
    }
    
    weak var delegate: CourseBrowserCellDelegate? = nil
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.selectionStyle = .none
        if self.selectedBackgroundView != nil && self.selectedBackgroundView?.superview == nil {
            self.selectedBackgroundView!.frame = self.contentView.bounds
            self.contentView.insertSubview(self.selectedBackgroundView!, at: 0)
            self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[bgv]|", options: .alignAllCenterY, metrics: nil, views: ["bgv": self.selectedBackgroundView!]))
            self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[bgv]|", options: .alignAllCenterX, metrics: nil, views: ["bgv": self.selectedBackgroundView!]))
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        if highlighted {
            self.selectedBackgroundView?.isHidden = false
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .beginFromCurrentState, animations: {
                self.selectedBackgroundView?.alpha = 0.4
            }, completion: nil)
        } else {
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .beginFromCurrentState, animations: {
                self.selectedBackgroundView?.alpha = 0.0
            }, completion: { (completed) in
                if completed {
                    self.selectedBackgroundView?.isHidden = true
                }
            })
        }
    }

    @IBAction func addCourseButtonPressed(sender: UIButton) {
        if self.course != nil {
            if let semester = self.delegate?.browserCell(added: self.course!) {
                self.addLabel?.text = "Added to \(semester.description.lowercased())"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: { 
                    self.addLabel?.text = ""
                })
            }
        }
        
    }
    
    /*override func layoutSubviews() {
        super.layoutSubviews()
        self.descriptionLabel.preferredMaxLayoutWidth = self.descriptionLabel.frame.size.width
        self.layoutIfNeeded()
    }*/
}
