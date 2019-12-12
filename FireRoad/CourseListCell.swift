//
//  CourseListCell.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/14/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol CourseListCellDelegate: class {
    func courseListCell(_ cell: CourseListCell, selected course: Course)
}

protocol CourseListCell: UICollectionViewDataSource, UICollectionViewDelegate {
    var courses: [Course] { get set }
    var collectionView: UICollectionView! { get set }
    var delegate: CourseListCellDelegate? { get set }
    var longPressTarget: Any? { get set }
    var longPressAction: Selector? { get set }
}

class CourseListTableCell: UITableViewCell, CourseListCell {

    var courses: [Course] = [] {
        didSet {
            collectionView.reloadData()
        }
    }
    /// Array of (current fulfillment, max fulfillment, uses bar) tuples corresponding to courses.
    var fulfillmentIndications: [(Int, Int, Bool)] = []
    
    @IBOutlet var collectionView: UICollectionView! = nil
    weak var delegate: CourseListCellDelegate? = nil
    
    var longPressTarget: Any?
    var longPressAction: Selector?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.courses.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CourseListItem", for: indexPath) as! CourseThumbnailCell
        let course = self.courses[indexPath.item]
        cell.course = course
        cell.textLabel?.text = course.subjectID
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.hyphenationFactor = 0.7
        paraStyle.alignment = .center
        if let title = course.subjectTitle {
            cell.detailTextLabel?.attributedText = NSAttributedString(string: title, attributes: [.paragraphStyle: paraStyle])
        }
        cell.backgroundColor = CourseManager.shared.color(forCourse: course)
        if indexPath.item < fulfillmentIndications.count {
            cell.usesFulfillmentProgressBar = fulfillmentIndications[indexPath.item].2
            cell.fulfillmentLevel = fulfillmentIndications[indexPath.item].0
            cell.fulfillmentThreshold = fulfillmentIndications[indexPath.item].1
        }
        cell.longPressTarget = longPressTarget
        cell.longPressAction = longPressAction
        cell.shadowEnabled = true
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        cell.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        cell.alpha = 0.5
        UIView.animate(withDuration: 0.3, delay: 0.0, options: [.curveEaseOut, .allowUserInteraction], animations: {
            cell.transform = CGAffineTransform.identity
            cell.alpha = 1.0
        }, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.delegate?.courseListCell(self, selected: self.courses[indexPath.row])
    }
}

class CourseListCollectionCell: UICollectionViewCell, CourseListCell {
    var courses: [Course] = [] {
        didSet {
            collectionView.reloadData()
        }
    }

    @IBOutlet var collectionView: UICollectionView! = nil
    weak var delegate: CourseListCellDelegate? = nil
    
    var longPressTarget: Any?
    var longPressAction: Selector?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.courses.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CourseListItem", for: indexPath) as! CourseThumbnailCell
        let course = self.courses[indexPath.item]
        cell.course = course
        cell.textLabel?.text = course.subjectID
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.hyphenationFactor = 0.7
        paraStyle.alignment = .center
        if let title = course.subjectTitle {
            cell.detailTextLabel?.attributedText = NSAttributedString(string: title, attributes: [.paragraphStyle: paraStyle])
        }
        cell.backgroundColor = CourseManager.shared.color(forCourse: course)
        cell.longPressTarget = longPressTarget
        cell.longPressAction = longPressAction
        return cell
        
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        cell.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        cell.alpha = 0.5
        UIView.animate(withDuration: 0.3, delay: 0.0, options: [.curveEaseOut, .allowUserInteraction], animations: {
            cell.transform = CGAffineTransform.identity
            cell.alpha = 1.0
        }, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.delegate?.courseListCell(self, selected: self.courses[indexPath.item])
    }
}
