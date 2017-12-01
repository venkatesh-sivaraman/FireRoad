//
//  ScheduleGridViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 11/17/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class ScheduleGridViewController: UIViewController {

    var schedule: Schedule? {
        didSet {
            if isViewLoaded,
                let sched = schedule {
                loadGrid(with: sched)
            }
        }
    }
    
    var pageNumber: Int = 0
    
    var topPadding: CGFloat = 0.0
    
    @IBOutlet var scrollView: UIScrollView?
    @IBOutlet var gridLinesStackView: UIStackView!
    @IBOutlet var stackView: UIStackView!
    @IBOutlet var stackViewTopConstraint: NSLayoutConstraint?
    
    var cellTitleFontSize: CGFloat {
        if traitCollection.horizontalSizeClass == .regular {
            return 24.0
        }
        return 18.0
    }
    
    var cellDescriptionFontSize: CGFloat {
        if traitCollection.horizontalSizeClass == .regular {
            return 16.0
        }
        return 13.0
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let sched = schedule {
            loadGrid(with: sched)
        }
        
        scrollView?.contentInset = UIEdgeInsets(top: topPadding, left: 0.0, bottom: 0.0, right: 0.0)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func removeWeekendColumns(from sv: UIStackView) {
        if let last = sv.arrangedSubviews.last {
            sv.removeArrangedSubview(last)
            last.removeFromSuperview()
        }
        if let last = sv.arrangedSubviews.last {
            sv.removeArrangedSubview(last)
            last.removeFromSuperview()
        }
    }
    
    func removeAllButFirstView(from sv: UIStackView) {
        while sv.arrangedSubviews.count > 1 {
            if let last = sv.arrangedSubviews.last {
                sv.removeArrangedSubview(last)
                last.removeFromSuperview()
            }
        }
    }
    
    func addGridSpace(to sv: UIStackView, height: CGFloat, color: UIColor = .white) -> UIView {
        let parentView = UIView(frame: .zero)
        parentView.backgroundColor = color
        parentView.translatesAutoresizingMaskIntoConstraints = false
        parentView.clipsToBounds = false
        sv.addArrangedSubview(parentView)
        parentView.heightAnchor.constraint(equalToConstant: height).isActive = true
        return parentView
    }
    
    func loadGrid(with schedule: Schedule) {
        if !schedule.scheduleItems.contains(where: { $0.hasWeekendSession() }) && stackView.arrangedSubviews.count >= 8 {
            // Remove Saturday and Sunday slots
            removeWeekendColumns(from: stackView)
            removeWeekendColumns(from: gridLinesStackView)
        }
        
        let cellMargin = CGFloat(1.0)
        let stackViewMargin = CGFloat(1.0)
        let hourHeight = CGFloat(60.0)
        // These times match the ones listed in the storyboard
        let times = [9, 10, 11].flatMap({ [CourseScheduleTime(hour: $0, minute: 0, PM: false), CourseScheduleTime(hour: $0, minute: 30, PM: false)] }) + [12, 1, 2, 3, 4, 5, 6, 7, 8, 9].flatMap({ [CourseScheduleTime(hour: $0, minute: 0, PM: true), CourseScheduleTime(hour: $0, minute: 30, PM: true)] })
        
        for (i, day) in CourseScheduleDay.ordering.enumerated() {
            guard stackView.arrangedSubviews.count > i + 1,
                let subStackView = stackView.arrangedSubviews[i + 1] as? UIStackView,
                gridLinesStackView.arrangedSubviews.count > i + 1,
                let gridSubStackView = gridLinesStackView.arrangedSubviews[i + 1] as? UIStackView else {
                    break
            }
            removeAllButFirstView(from: subStackView)
            removeAllButFirstView(from: gridSubStackView)
            
            for _ in times {
                let _ = addGridSpace(to: gridSubStackView, height: (hourHeight - stackViewMargin) / 2.0)
            }
            
            let sortedItems = schedule.chronologicalItems(for: day)
            var timeSlots: [[Schedule.ScheduleChronologicalElement]] = times.map({ _ in [] })
            for element in sortedItems {
                guard let timeIndex = times.index(where: { $0 == element.item.startTime }) else {
                    continue
                }
                timeSlots[timeIndex].append(element)
            }
            
            var lastTimeFilled: CourseScheduleTime?
            for (i, slot) in timeSlots.enumerated() {
                if let lastTime = lastTimeFilled,
                    times[i] < lastTime {
                    continue
                }
                if let (course, type, item) = slot.first {
                    let classDuration = item.startTime.delta(to: item.endTime)
                    var cellHeight = CGFloat(classDuration.0) * hourHeight + CGFloat(classDuration.1) * hourHeight / 60.0
                    var currentHour = item.startTime.hour24 + 1
                    while currentHour < item.endTime.hour24 {
                        cellHeight += stackViewMargin
                        currentHour += 1
                    }
                    let parentView = addGridSpace(to: subStackView, height: cellHeight, color: .clear)
                    let courseCell = CourseThumbnailCell(frame: .zero)
                    courseCell.translatesAutoresizingMaskIntoConstraints = false
                    parentView.addSubview(courseCell)
                    courseCell.loadThumbnailAppearance()
                    courseCell.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: cellMargin).isActive = true
                    courseCell.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -cellMargin).isActive = true
                    courseCell.topAnchor.constraint(equalTo: parentView.topAnchor, constant: cellMargin).isActive = true
                    courseCell.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -cellMargin).isActive = true
                    courseCell.backgroundColor = CourseManager.shared.color(forCourse: course)
                    courseCell.generateLabels(withDetail: traitCollection.horizontalSizeClass != .compact || UIDevice.current.orientation.isLandscape)
                    courseCell.textLabel?.font = courseCell.textLabel?.font.withSize(cellTitleFontSize)
                    courseCell.textLabel?.text = course.subjectID!
                    courseCell.detailTextLabel?.font = courseCell.detailTextLabel?.font.withSize(cellDescriptionFontSize)
                    courseCell.detailTextLabel?.text = (CourseScheduleType.abbreviation(for: type)?.lowercased() ?? type.lowercased()) + (item.location != nil ?  " (\(item.location!))" : "")
                    lastTimeFilled = item.endTime
                } else {
                    let _ = addGridSpace(to: subStackView, height: (hourHeight - stackViewMargin) / 2.0, color: .clear)
                    lastTimeFilled = i + 1 < times.count ? times[i + 1] : nil
                }
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass ||
            previousTraitCollection?.verticalSizeClass != traitCollection.verticalSizeClass,
            let schedule = self.schedule {
            loadGrid(with: schedule)
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
