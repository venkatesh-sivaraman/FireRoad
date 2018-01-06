//
//  ScheduleModel.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 11/17/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

enum ScheduleSlotManager {
    // These times match the ones listed in the storyboard
    static let slots = [8, 9, 10, 11].flatMap({ [CourseScheduleTime(hour: $0, minute: 0, PM: false), CourseScheduleTime(hour: $0, minute: 30, PM: false)] }) + [12, 1, 2, 3, 4, 5, 6, 7, 8, 9].flatMap({ [CourseScheduleTime(hour: $0, minute: 0, PM: true), CourseScheduleTime(hour: $0, minute: 30, PM: true)] })
    
    static func slotIndex(for time: CourseScheduleTime) -> Int {
        var base = 0
        if time.PM == false || time.hour == 12 {
            base = (time.hour - 8) * 2
        } else {
            base = (time.hour + 4) * 2
        }
        if time.minute >= 30 {
            return base + 1
        }
        return base
    }
}

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
    
    func userStringRepresentation() -> String {
        var courses: [Course: [ScheduleUnit]] = [:]
        for item in scheduleItems {
            if courses[item.course] != nil {
                courses[item.course]?.append(item)
            } else {
                courses[item.course] = [item]
            }
        }
        var ret = ""
        let sortedCourses = courses.sorted(by: { ($0.key.subjectID ?? "").localizedStandardCompare($1.key.subjectID ?? "") == .orderedAscending })
        for (course, units) in sortedCourses {
            ret += course.subjectID ?? ""
            ret += "\n"
            let sortedUnits = units.sorted(by: { (CourseScheduleType.ordering.index(of: $0.sectionType) ?? 0) < (CourseScheduleType.ordering.index(of: $1.sectionType) ?? 0) })
            for unit in sortedUnits {
                ret += "\t" + unit.sectionType + ": " + unit.scheduleItems.map({ $0.stringEquivalent() }).joined(separator: ", ") + "\n"
            }
        }
        return ret.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
