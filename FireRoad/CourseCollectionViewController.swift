//
//  CourseCollectionViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/20/19.
//  Copyright © 2019 Base 12 Innovations. All rights reserved.
//

import UIKit

private let reuseIdentifier = "CourseCell"

protocol CourseCollectionViewThumbnailHandler: CourseThumbnailCellDelegate {
    func courseCollectionViewController(wantsFormat cell: CourseThumbnailCell, at indexPath: IndexPath)
}

class CourseCollectionViewController: UICollectionViewController {

    weak var thumbnailHandler: CourseCollectionViewThumbnailHandler?
    
    var courses: [Course] = []
        
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let layout = collectionView?.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.sectionInset = UIEdgeInsets(top: 12.0, left: 12.0, bottom: 12.0, right: 12.0)
            layout.minimumInteritemSpacing = traitCollection.userInterfaceIdiom == .phone ? 8.0 : 12.0
            layout.minimumLineSpacing = 12.0
            layout.itemSize = itemSize
            collectionView?.contentInset = UIEdgeInsets.zero
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */
    
    func titleTextSize(for indexPath: IndexPath) -> CGFloat {
        if traitCollection.userInterfaceIdiom == .phone {
            return 19.0
        }
        return 24.0
    }
    
    func detailTextSize(for indexPath: IndexPath) -> CGFloat {
        if traitCollection.userInterfaceIdiom == .phone {
            return 13.0
        }
        return 15.0
    }

    // MARK: - Collection View
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return courses.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CourseCell", for: indexPath) as! CourseThumbnailCell
        cell.shadowEnabled = true
        cell.delegate = self.thumbnailHandler
        let course = courses[indexPath.item]
        cell.course = course
        if let font = cell.textLabel?.font, font.pointSize != titleTextSize(for: indexPath) {
            cell.textLabel?.font = font.withSize(titleTextSize(for: indexPath))
        }
        if let font = cell.detailTextLabel?.font, font.pointSize != detailTextSize(for: indexPath) {
            cell.detailTextLabel?.font = UIFont.systemFont(ofSize: detailTextSize(for: indexPath))
        }
        cell.textLabel?.text = course.subjectID
        cell.detailTextLabel?.text = course.subjectTitle ?? ""
        cell.backgroundColor = CourseManager.shared.color(forCourse: course)
        thumbnailHandler?.courseCollectionViewController(wantsFormat: cell, at: indexPath)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let layout = collectionViewLayout as! UICollectionViewFlowLayout
        let availableWidth = (collectionView.frame.size.width - layout.sectionInset.left - layout.sectionInset.right)
        let cellCount = floor(availableWidth / (layout.itemSize.width + layout.minimumInteritemSpacing))
        let emptySpace = collectionView.frame.size.width - cellCount * (layout.itemSize.width + layout.minimumInteritemSpacing) + layout.minimumInteritemSpacing
        return UIEdgeInsets(top: 8.0, left: emptySpace / 2.0, bottom: 8.0, right: emptySpace / 2.0)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.size.width, height: 38.0)
    }
    
    var itemSize: CGSize {
        let scaleFactor = CGSize(width: traitCollection.userInterfaceIdiom == .pad ? 1.0 : 0.88, height: traitCollection.userInterfaceIdiom == .pad ? 1.0 : 0.88)
        return CGSize(width: 116.0 * scaleFactor.width, height: 112.0 * scaleFactor.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return itemSize
    }
}
