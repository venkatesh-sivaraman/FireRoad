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
    static let slots = [8, 9, 10, 11].flatMap({ [CourseScheduleTime(hour: $0, minute: 0, PM: false), CourseScheduleTime(hour: $0, minute: 30, PM: false)] }) + [12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10].flatMap({ [CourseScheduleTime(hour: $0, minute: 0, PM: true), CourseScheduleTime(hour: $0, minute: 30, PM: true)] })
    
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
    
    typealias ScheduleChronologicalElement = (course: Course, type: String, item: CourseScheduleItem, unit: ScheduleUnit)
    
    func chronologicalItems(for day: CourseScheduleDay) -> [ScheduleChronologicalElement] {
        let allItems = scheduleItems.reduce([], { (list: [ScheduleChronologicalElement], item: ScheduleUnit) -> [ScheduleChronologicalElement] in
            return list + item.scheduleItems.compactMap({
                (item.course, item.sectionType, $0, item)
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
            let sortedUnits = units.sorted(by: { (CourseScheduleType.ordering.firstIndex(of: $0.sectionType) ?? 0) < (CourseScheduleType.ordering.firstIndex(of: $1.sectionType) ?? 0) })
            for unit in sortedUnits {
                ret += "\t" + unit.sectionType + ": " + unit.scheduleItems.map({ $0.stringEquivalent() }).joined(separator: ", ") + "\n"
            }
        }
        return ret.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

class ScheduleDocument: UserDocument {
    
    private(set) var courses: [Course] = []
    var allowedSections: [Course: [String: [Int]]]? {
        didSet {
            setNeedsSave()
        }
    }
    var displayedScheduleIndex = -1 {
        didSet {
            setNeedsSave()
        }
    }
    var selectedSchedule: Schedule?
    /// Defines the selected sections before schedules are loaded
    var preloadSections: [Course: [String: Int]]?
    
    override var isEmpty: Bool {
        return courses.count == 0
    }
    
    convenience init(courses: [Course]) {
        self.init()
        self.courses = courses
    }
    
    @discardableResult
    func add(course: Course) -> Bool {
        guard !courses.contains(course) else {
            return false
        }
        courses.append(course)
        setNeedsSave()
        return true
    }
    
    func setCourses(_ newCourses: [Course]) {
        courses.removeAll()
        courses.append(contentsOf: newCourses)
        setNeedsSave()
    }
    
    func remove(course: Course) {
        guard let index = courses.firstIndex(of: course) else {
            return
        }
        courses.remove(at: index)
        setNeedsSave()
    }
    
    func removeCourses(where test: (Course) -> Bool) {
        courses = courses.filter({ !test($0) })
        setNeedsSave()
    }
    
    override var coursesForThumbnail: [Course] {
        return courses
    }
    
    override func thumbnailCropPath(with bounds: CGRect) -> UIBezierPath {
        return UIBezierPath(ovalIn: bounds)
    }
    
    // Legacy file reading
    let separator = "#,#"
    let sectionSeparator = ";"
    let sectionKeyValueSeparator = ":"
    let sectionValueSeparator = ","
    
    enum ScheduleFile {
        static let selectedSubjects = "selectedSubjects"
        static let subjectIDAlt = "id"
        static let subjectID = "subject_id"
        static let subjectTitle = "title"
        static let allowedSections = "allowedSections"
        static let selectedSections = "selectedSections"
    }
    
    override func readUserCourses(from file: String) throws {
        try super.readUserCourses(from: file)
        
        let data = try Data(contentsOf: URL(fileURLWithPath: file))
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
            print("Trying legacy read")
            try legacyReadCourses(from: file)
            return
        }
        
        try readCourses(fromJSON: json)
    }
    
    override func readCourses(fromJSON json: Any) throws {
        guard let fileDict = json as? [String: Any],
            let selectedSubjectsList = fileDict[ScheduleFile.selectedSubjects] as? [[String: Any]] else {
                print("Malformed JSON: \(json)")
                return
        }
        
        var newSections: [Course: [String: [Int]]]?
        var newCourses: [Course] = []
        for subjectJSON in selectedSubjectsList {
            guard let subjectID = (subjectJSON[ScheduleFile.subjectID] ?? subjectJSON[ScheduleFile.subjectIDAlt]) as? String,
                let title = subjectJSON[ScheduleFile.subjectTitle] as? String else {
                    print("Malformed subject entry: \(subjectJSON)")
                    continue
            }
            let course = CourseManager.shared.getCourse(withID: subjectID) ?? CourseManager.shared.getCustomCourse(with: subjectID, title: title) ?? Course(courseID: subjectID, courseTitle: title, courseDescription: "")
            course.readJSON(subjectJSON)
            if let constraints = subjectJSON[ScheduleFile.allowedSections] as? [String: [Int]] {
                if newSections == nil {
                    newSections = [:]
                }
                newSections?[course] = constraints
            }
            if let selected = subjectJSON[ScheduleFile.selectedSections] as? [String: Int] {
                if preloadSections == nil {
                    preloadSections = [:]
                }
                preloadSections?[course] = selected
            }
            if course.creator != nil {
                CourseManager.shared.setCustomCourse(course)
            }
            newCourses.append(course)
        }
        allowedSections = newSections
        courses = newCourses
    }
    
    private func legacyReadCourses(from file: String) throws {
        let contents = try String(contentsOfFile: file)
        
        var newCourses: [Course] = []
        var newSections: [Course: [String: [Int]]]?
        
        var lines = contents.components(separatedBy: .newlines)
        if lines.count > 0 {
            let header = lines.removeFirst()
            var comps = header.components(separatedBy: separator)
            if comps.count > 0 {
                displayedScheduleIndex = Int(comps.removeFirst()) ?? -1
            }
        }
        
        for line in lines {
            guard line.count > 0 else {
                continue
            }
            var components = line.components(separatedBy: separator)
            guard components.count > 0 else {
                continue
            }
            let id = components.remove(at: 0)
            var title: String?
            if components.count > 0 {
                title = components.remove(at: 0)
            }
            let course = CourseManager.shared.getCourse(withID: id) ?? Course(courseID: id, courseTitle: title ?? "", courseDescription: "")
            if components.count > 0 {
                if newSections == nil {
                    newSections = [:]
                }
                newSections?[course] = [:]
                let sectionsString = components.remove(at: 0)
                let sections = sectionsString.components(separatedBy: sectionSeparator)
                for sectionString in sections {
                    let comps = sectionString.components(separatedBy: sectionKeyValueSeparator)
                    guard comps.count == 2 else {
                        continue
                    }
                    let section = comps[0]
                    newSections?[course]?[section] = comps[1].components(separatedBy: sectionValueSeparator).compactMap({ Int($0) })
                }
            }
            newCourses.append(course)
        }
        courses = newCourses
        allowedSections = newSections
        needsSave = false
    }
    
    override func writeUserCourses(to file: String) throws {
        try super.writeUserCourses(to: file)
        
        guard !readOnly else {
            return
        }
        
        let fileJSON = try writeCoursesToJSON()
        let contentsData = try JSONSerialization.data(withJSONObject: fileJSON, options: .prettyPrinted)
        
        // Save to server as well
        if self.needsSave && self.shouldCloudSync {
            CloudSyncManager.scheduleManager.sync(with: self)
        }
        
        if !FileManager.default.fileExists(atPath: file) {
            let success = FileManager.default.createFile(atPath: file, contents: nil, attributes: nil)
            if !success {
                print("Failed to create file at \(file)")
            }
        }
        try contentsData.write(to: URL(fileURLWithPath: file), options: .atomic)
    }
    
    override func writeCoursesToJSON() throws -> Any {
        var selectedSubjectsJSON: [[String: Any]] = []
        for subject in courses {
            var subjectJSON: [String: Any] = subject.toJSON()
            if let sections = allowedSections?[subject] {
                subjectJSON[ScheduleFile.allowedSections] = sections
            }
            if let courseSections = selectedSchedule?.scheduleItems.filter({ $0.course == subject }) {
                var selectedJSON: [String: Int] = [:]
                for unit in courseSections {
                    guard let sections = subject.schedule?[unit.sectionType],
                        let index = sections.firstIndex(of: unit.scheduleItems) else {
                            continue
                    }
                    selectedJSON[unit.sectionType] = index
                }
                subjectJSON[ScheduleFile.selectedSections] = selectedJSON
            }
            selectedSubjectsJSON.append(subjectJSON)
        }
        let fileJSON: [String: Any] = [
            ScheduleFile.selectedSubjects: selectedSubjectsJSON
        ]
        return fileJSON
    }
}

struct ScheduleMask {
    var bitMask: Int
    
    init(scheduleItems: [CourseScheduleItem], day: CourseScheduleDay) {
        var allTimeSlots: [Bool] = ScheduleSlotManager.slots.map({ _ in false })  // List of indices in sortedItems
        for element in scheduleItems {
            guard element.days.contains(day) else {
                continue
            }
            let startIndex = ScheduleSlotManager.slotIndex(for: element.startTime)
            let endIndex = ScheduleSlotManager.slotIndex(for: element.endTime)
            guard startIndex >= 0, startIndex < allTimeSlots.count,
                endIndex >= 0, endIndex < allTimeSlots.count else {
                    continue
            }
            for index in startIndex..<endIndex {
                allTimeSlots[index] = true
            }
        }
        
        self.bitMask = allTimeSlots.enumerated().reduce(0, { $0 + ($1.element ? (1 << $1.offset) : 0) })
    }
    
    func conflicts(with mask: ScheduleMask) -> Bool {
        return (self.bitMask & mask.bitMask) != 0
    }
}
