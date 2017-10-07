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

class CourseListCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {

    var courses: [Course] = [] {
        didSet {
            collectionView.reloadData()
        }
    }
    @IBOutlet var collectionView: UICollectionView! = nil
    weak var delegate: CourseListCellDelegate? = nil
    
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
        cell.textLabel?.text = course.subjectID
        cell.detailTextLabel?.text = course.subjectTitle
        cell.backgroundColor = CourseManager.shared.color(forCourse: course)
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
