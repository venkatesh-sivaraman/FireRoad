//
//  ScheduleModel.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 11/17/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class ScheduleUnit: NSObject {
    var course: Course
    var sectionType: String
    var scheduleItems: [CourseScheduleItem]
    
    init(course: Course, sectionType: String, scheduleItems: [CourseScheduleItem]) {
        self.course = course
        self.sectionType = sectionType
        self.scheduleItems = scheduleItems
    }
    
    override var debugDescription: String {
        return "\(course.subjectID!) \(sectionType): \(scheduleItems)"
    }
    
    func hasWeekendSession() -> Bool {
        return scheduleItems.contains(where: { $0.days.contains(.saturday) || $0.days.contains(.sunday) })
    }
}

class Schedule: NSObject {
    var scheduleItems: [ScheduleUnit]
    var conflictCount = 0
    
    init(items: [ScheduleUnit], conflictCount: Int = 0) {
        self.scheduleItems = items
        self.conflictCount = conflictCount
    }
    
    override var debugDescription: String {
        return "Schedule:\n\t" + scheduleItems.map({ String(reflecting: $0) }).joined(separator: "\n\t")
    }
    
    typealias ScheduleChronologicalElement = (course: Course, type: String, item: CourseScheduleItem)
    
    func chronologicalItems(for day: CourseScheduleDay) -> [ScheduleChronologicalElement] {
        let allItems = scheduleItems.reduce([], { (list: [ScheduleChronologicalElement], item: ScheduleUnit) -> [ScheduleChronologicalElement] in
            return list + item.scheduleItems.flatMap({
                (item.course, item.sectionType, $0)
            })
        }).filter {
            $0.item.days.contains(day)
        }
        
        return allItems.sorted(by: { $0.item.startTime < $1.item.startTime })
    }
}
