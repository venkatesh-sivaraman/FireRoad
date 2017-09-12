//
//  CourseListCell.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/14/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol CourseListCellDelegate: class {
    func courseListCellSelected(_ course: Course)
}

class CourseListCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {

    var courses: [Course] = []
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
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.delegate?.courseListCellSelected(self.courses[indexPath.row])
    }
}
