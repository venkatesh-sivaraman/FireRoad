//
//  ScheduleModel.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 11/17/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

struct ScheduleItem: CustomDebugStringConvertible {
    var course: Course
    var selectedSections: [String: [CourseScheduleItem]]
    
    var debugDescription: String {
        return "\(course.subjectID!): \(selectedSections)"
    }
    
    func hasWeekendSession() -> Bool {
        return selectedSections.values.contains(where: { (items) -> Bool in
            return items.contains(where: { $0.days.contains(.saturday) || $0.days.contains(.sunday) })
        })
    }
}

class Schedule: NSObject {
    var scheduleItems: [ScheduleItem]
    
    init(items: [ScheduleItem]) {
        self.scheduleItems = items
    }
    
    override var debugDescription: String {
        return "Schedule:\n\t" + scheduleItems.map({ String(reflecting: $0) }).joined(separator: "\n\t")
    }
    
    typealias ScheduleChronologicalElement = (course: Course, type: String, item: CourseScheduleItem)
    
    func chronologicalItems(for day: CourseScheduleDay) -> [ScheduleChronologicalElement] {
        let allItems = scheduleItems.reduce([], { (list: [ScheduleChronologicalElement], item: ScheduleItem) -> [ScheduleChronologicalElement] in
            return list + item.selectedSections.flatMap({ (key, value) in
                value.map({ (item.course, key, $0) })
            })
        }).filter {
            $0.item.days.contains(day)
        }
        
        return allItems.sorted(by: { $0.item.startTime < $1.item.startTime })
    }
}
