//
//  CourseListingMasterViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 12/16/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class CourseListingMasterViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, CourseListCellDelegate {

    var recommendedCourses: [Course] = []
    
    var departments: [(code: String, description: String)] = []
    
    let headings = [
        "For You",
        "Browse Courses"
    ]
    
    @IBOutlet var collectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        loadDepartments()
        recommendedCourses = [
            CourseManager.shared.getCourse(withID: "6.046")!,
            CourseManager.shared.getCourse(withID: "7.03")!,
            CourseManager.shared.getCourse(withID: "18.03")!
        ]
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.sectionHeadersPinToVisibleBounds = true
        }
        
        navigationItem.title = "Browse"
    }
    
    func loadDepartments() {
        guard let filePath = Bundle.main.path(forResource: "departments", ofType: "txt"),
            let contents = try? String(contentsOfFile: filePath) else {
                print("Couldn't load departments")
                return
        }
        let comps = contents.components(separatedBy: .newlines)
        departments = comps.flatMap {
            let subcomps = $0.components(separatedBy: "#,#")
            guard subcomps.count == 2 else {
                return nil
            }
            return (subcomps[0], subcomps[1])
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    // MARK: - Collection View Data Source
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else if section == 1 {
            return departments.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SectionHeader", for: indexPath)
        if let label = view.viewWithTag(12) as? UILabel {
            label.text = headings[indexPath.section]
        }
        view.isHidden = (kind != UICollectionElementKindSectionHeader)
        return view
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = indexPath.section == 0 ? "CourseListCollectionCell" : "DepartmentCell"
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
        if indexPath.section == 0 {
            guard let listCell = cell as? CourseListCollectionCell else {
                print("Invalid course list cell")
                return cell
            }
            listCell.courses = recommendedCourses
            listCell.delegate = self
        } else {
            if let label = cell.viewWithTag(12) as? UILabel {
                label.font = label.font.withSize(traitCollection.userInterfaceIdiom == .phone ? 17.0 : 20.0)
                label.text = "\(departments[indexPath.item].0) – \(departments[indexPath.item].1)"
            }
        }
        return cell
    }
    
    // MARK: - Flow Layout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if indexPath.section == 0 {
            return CGSize(width: collectionView.frame.size.width, height: 124.0)
        } else if indexPath.section == 1 {
            if traitCollection.horizontalSizeClass == .regular {
                return CGSize(width: collectionView.frame.size.width / 3.0, height: 48.0)
            } else {
                return CGSize(width: collectionView.frame.size.width, height: 48.0)
            }
        }
        return CGSize.zero
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.size.width, height: 52.0)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize.zero
    }
    
    // MARK: - Course List Cell Delegate
    
    func courseListCell(_ cell: CourseListCell, selected course: Course) {
        
    }
}
