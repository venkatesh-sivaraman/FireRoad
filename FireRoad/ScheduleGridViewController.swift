//
//  ScheduleGridViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 11/17/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol ScheduleGridDelegate: CourseDisplayManager {
    func deleteCourseFromSchedules(_ course: Course)
    func scheduleGrid(_ gridVC: ScheduleGridViewController, wantsConstraintMenuFor course: Course, sender: UIView?)
}

class ScheduleGridViewController: UIViewController, CourseThumbnailCellDelegate, UIPopoverPresentationControllerDelegate, UIScrollViewDelegate {

    var schedule: Schedule? {
        didSet {
            if isViewLoaded,
                let sched = schedule {
                loadGrid(with: sched)
            }
        }
    }
    
    weak var delegate: ScheduleGridDelegate?
    
    var pageNumber: Int = 0
    
    var topPadding: CGFloat = 0.0
    
    @IBOutlet var scrollView: UIScrollView?
    @IBOutlet var scrollViewContentView: UIView!
    @IBOutlet var gridLinesStackView: UIStackView!
    @IBOutlet var stackView: UIStackView!
    @IBOutlet var stackViewTopConstraint: NSLayoutConstraint?
    
    var cellTitleFontSize: CGFloat {
        if traitCollection.horizontalSizeClass == .regular {
            return 22.0
        }
        return 16.0
    }
    
    var cellDescriptionFontSize: CGFloat {
        if traitCollection.horizontalSizeClass == .regular {
            return 14.0
        }
        return 12.0
    }
    
    var courseColors: [Course: UIColor]?
    
    var justLoaded = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupGridStackView()
        if let sched = schedule {
            loadGrid(with: sched)
        }
        
        scrollView?.contentInset = UIEdgeInsets(top: topPadding, left: 0.0, bottom: 0.0, right: 0.0)
        scrollView?.delegate = self
        
        justLoaded = true
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if justLoaded {
            if traitCollection.horizontalSizeClass == .compact {
                scrollView?.zoomScale = min(1.0, self.view.frame.size.width / scrollViewContentView.frame.size.width)
            }
            justLoaded = false
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass ||
            previousTraitCollection?.verticalSizeClass != traitCollection.verticalSizeClass,
            let schedule = self.schedule {
            setupGridStackView()
            loadGrid(with: schedule)
            recenterScrollView()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.recenterScrollView()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        recenterScrollView()
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
    
    let cellMargin = CGFloat(0.0)
    let stackViewMargin = CGFloat(1.0)
    let hourHeight = CGFloat(60.0)
    let times = ScheduleSlotManager.slots
    
    var courseCells: [ScheduleUnit: [CourseThumbnailCell]] = [:]

    func setupGridStackView() {
        for (i, _) in CourseScheduleDay.ordering.enumerated() {
            guard gridLinesStackView.arrangedSubviews.count > i + 1,
                let gridSubStackView = gridLinesStackView.arrangedSubviews[i + 1] as? UIStackView else {
                    break
            }
            removeAllButFirstView(from: gridSubStackView)
            
            for _ in times {
                let _ = addGridSpace(to: gridSubStackView, height: (hourHeight - stackViewMargin) / 2.0)
            }
        }
    }
    
    func loadGrid(with schedule: Schedule) {
        if !schedule.scheduleItems.contains(where: { $0.hasWeekendSession() }) && stackView.arrangedSubviews.count >= 8 {
            // Remove Saturday and Sunday slots
            removeWeekendColumns(from: stackView)
            removeWeekendColumns(from: gridLinesStackView)
        }
        
        courseCells = [:]
        
        for (i, day) in CourseScheduleDay.ordering.enumerated() {
            guard stackView.arrangedSubviews.count > i + 1,
                let subStackView = stackView.arrangedSubviews[i + 1] as? UIStackView else {
                    break
            }
            removeAllButFirstView(from: subStackView)
            
            let sortedItems = schedule.chronologicalItems(for: day)
            var timeSlots: [[Schedule.ScheduleChronologicalElement]] = times.map({ _ in [] })
            var allTimeSlots: [[Int]] = times.map({ _ in [] })  // List of indices in sortedItems
            for (i, element) in sortedItems.enumerated() {
                let startIndex = ScheduleSlotManager.slotIndex(for: element.item.startTime)
                let endIndex = ScheduleSlotManager.slotIndex(for: element.item.endTime)
                guard startIndex >= 0, startIndex < timeSlots.count,
                    endIndex >= 0, endIndex < timeSlots.count,
                    startIndex < endIndex else {
                        continue
                }
                timeSlots[startIndex].append(element)
                for index in startIndex..<endIndex {
                    allTimeSlots[index].append(i)
                }
            }
            
            // Cluster the time slots so we know how wide to make each cell
            var slotOccupancies: [(Int, Int)] = []   // Number of occupancies in each cluster, and number of time slots occupied by the cluster
            var slotClusterMapping: [Int: Int] = [:]    // Mapping of slot index to cluster in slotOccupiedCounts
            var currentElements: Set<Int> = Set<Int>() // Indices in sortedItems
            for (i, slot) in allTimeSlots.enumerated() {
                currentElements = currentElements.filter { sortedItems[$0].item.endTime > times[i] }
                if currentElements.count == 0 || slotOccupancies.count == 0 {
                    slotOccupancies.append((currentElements.count, 0))
                }
                assert(slot.count > 0 || currentElements.count == 0, "Inconsistency between allTimeSlots and current element list")
                currentElements.formUnion(Set<Int>(slot))
                if let (lastOccupancy, duration) = slotOccupancies.last {
                    slotOccupancies[slotOccupancies.count - 1] = (max(currentElements.count, lastOccupancy), duration + 1)
                }
                slotClusterMapping[i] = slotOccupancies.count - 1
            }
            
            var lastParentView: UIView?
            var lastParentViewStartIndex = 0
            var lastParentViewEndIndex = 0
            // Mapping of column numbers to the indexes at which those columns will end
            var occupiedColumns: [Int: Int] = [:]
            for (i, slot) in timeSlots.enumerated() {
                guard let cluster = slotClusterMapping[i] else {
                    print("Couldn't find current cluster")
                    continue
                }
                occupiedColumns = occupiedColumns.filter({ $1 > i })
                let (occupancy, duration) = slotOccupancies[cluster]
                let widthFraction = 1.0 / CGFloat(occupancy)
                if slot.count > 0 {
                    for (course, type, item, unit) in slot {
                        let classDuration = item.startTime.delta(to: item.endTime)
                        let cellHeight = CGFloat(classDuration.0) * (hourHeight + stackViewMargin) + CGFloat(classDuration.1) * (hourHeight + stackViewMargin) / 60.0 - stackViewMargin
                        if lastParentViewEndIndex <= i || lastParentView == nil {
                            let parentHeight = CGFloat(duration) * (hourHeight + stackViewMargin) / 2.0 - stackViewMargin
                            let parentView = addGridSpace(to: subStackView, height: parentHeight, color: .clear)
                            lastParentView = parentView
                            lastParentViewStartIndex = i
                            lastParentViewEndIndex = i + duration
                        }
                        guard let parentView = lastParentView else {
                            continue
                        }
                        let courseCell = CourseThumbnailCell(frame: .zero)
                        courseCell.translatesAutoresizingMaskIntoConstraints = false
                        parentView.addSubview(courseCell)
                        courseCell.loadThumbnailAppearance()
                        courseCell.backgroundColor = courseColors?[course] ?? CourseManager.shared.color(forCourse: course)
                        courseCell.delegate = self
                        courseCell.course = course
                        courseCell.showsConstraintMenuItem = true
                        
                        courseCell.generateLabels(withDetail: true)
                        courseCell.textLabel?.font = courseCell.textLabel?.font.withSize(cellTitleFontSize)
                        courseCell.textLabel?.text = course.subjectID!
                        courseCell.textLabel?.numberOfLines = 1
                        courseCell.detailTextLabel?.font = UIFont.systemFont(ofSize: cellDescriptionFontSize)
                        courseCell.detailTextLabel?.text = (CourseScheduleType.abbreviation(for: type)?.lowercased() ?? type.lowercased()) + (item.location != nil ?  " (\(item.location!))" : "")
                        
                        if courseCells[unit] == nil {
                            courseCells[unit] = []
                        }
                        courseCells[unit]?.append(courseCell)
                        
                        // Positioning
                        for subcolumn in 0..<occupancy {
                            if occupiedColumns[subcolumn] == nil {
                                occupiedColumns[subcolumn] = ScheduleSlotManager.slotIndex(for: item.endTime)
                                if subcolumn == 0 {
                                    courseCell.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: cellMargin).isActive = true
                                } else {
                                    NSLayoutConstraint(item: courseCell, attribute: .leading, relatedBy: .equal, toItem: parentView, attribute: .trailing, multiplier: widthFraction * CGFloat(subcolumn), constant: cellMargin).isActive = true
                                }
                                break
                            }
                        }
                        courseCell.widthAnchor.constraint(equalTo: parentView.widthAnchor, multiplier: widthFraction).isActive = true
                        if i == lastParentViewStartIndex {
                            courseCell.topAnchor.constraint(equalTo: parentView.topAnchor, constant: cellMargin).isActive = true
                        } else {
                            NSLayoutConstraint(item: courseCell, attribute: .top, relatedBy: .equal, toItem: parentView, attribute: .bottom, multiplier: CGFloat(i - lastParentViewStartIndex) / CGFloat(duration), constant: cellMargin).isActive = true
                        }
                        courseCell.heightAnchor.constraint(equalToConstant: cellHeight).isActive = true
                    }
                } else if lastParentViewEndIndex <= i {
                    let parentView = addGridSpace(to: subStackView, height: (hourHeight - stackViewMargin) / 2.0, color: .clear)
                    occupiedColumns = [:]
                    lastParentView = parentView
                    lastParentViewStartIndex = i
                    lastParentViewEndIndex = i + duration
                }
            }
        }
    }
    
    func scheduleUnits(in schedule: Schedule, notPresentIn newSchedule: Schedule) -> [ScheduleUnit] {
        var ret: [ScheduleUnit] = []
        for unit in schedule.scheduleItems {
            if !newSchedule.scheduleItems.contains(unit) {
                ret.append(unit)
            }
        }
        return ret
    }
    
    func setSchedule(_ newSchedule: Schedule, animated: Bool) {
        if animated {
            let removedUnits: [ScheduleUnit] = schedule != nil ? scheduleUnits(in: schedule!, notPresentIn: newSchedule) : []
            let addedUnits: [ScheduleUnit] = schedule != nil ? scheduleUnits(in: newSchedule, notPresentIn: schedule!) : newSchedule.scheduleItems
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseIn, animations: {
                for unit in removedUnits where self.courseCells[unit] != nil {
                    for cell in self.courseCells[unit]! {
                        cell.transform = CGAffineTransform(scaleX: 0.001, y: 0.001)
                        cell.alpha = 0.0
                    }
                }
            }, completion: { (completed) in
                self.schedule = newSchedule
                for unit in addedUnits where self.courseCells[unit] != nil {
                    for cell in self.courseCells[unit]! {
                        cell.transform = CGAffineTransform(scaleX: 0.001, y: 0.001)
                        cell.alpha = 0.0
                    }
                }
                UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseOut, animations: {
                    for unit in addedUnits where self.courseCells[unit] != nil {
                        for cell in self.courseCells[unit]! {
                            cell.transform = .identity
                            cell.alpha = 1.0
                        }
                    }
                }, completion: nil)
            })
        } else {
            schedule = newSchedule
        }
    }
    
    func courseThumbnailCellWantsDelete(_ cell: CourseThumbnailCell) {
        guard let course = cell.course else {
            return
        }
        delegate?.deleteCourseFromSchedules(course)
    }
    
    func courseThumbnailCellWantsViewDetails(_ cell: CourseThumbnailCell) {
        guard let course = cell.course else {
            return
        }
        delegate?.viewDetails(for: course, showGenericDetails: true)
    }
    
    func courseThumbnailCellWantsConstrain(_ cell: CourseThumbnailCell) {
        guard let course = cell.course else {
            return
        }
        delegate?.scheduleGrid(self, wantsConstraintMenuFor: course, sender: cell)
    }
    
    func courseThumbnailCellWantsRate(_ cell: CourseThumbnailCell) {
        guard let rater = storyboard?.instantiateViewController(withIdentifier: "RatePopover") as? RateIndividualViewController else {
            return
        }
        rater.course = cell.course
        rater.modalPresentationStyle = .popover
        rater.popoverPresentationController?.delegate = self
        rater.popoverPresentationController?.sourceRect = cell.bounds
        rater.popoverPresentationController?.sourceView = cell
        self.present(rater, animated: true, completion: nil)
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
    // MARK: - Scroll View

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollViewContentView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        recenterScrollView()
    }
    
    func recenterScrollView() {
        guard let scrollView = scrollView else {
            return
        }
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        scrollView.contentInset = UIEdgeInsetsMake(topPadding + offsetY, offsetX, 0, 0)
    }
}
