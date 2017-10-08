//
//  User.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/2/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

enum UserSemester: Int {
    case PreviousCredit = 0
    case FreshmanFall = 1
    case FreshmanIAP = 2
    case FreshmanSpring = 3
    case SophomoreFall = 4
    case SophomoreIAP = 5
    case SophomoreSpring = 6
    case JuniorFall = 7
    case JuniorIAP = 8
    case JuniorSpring = 9
    case SeniorFall = 10
    case SeniorIAP = 11
    case SeniorSpring = 12
    
    func toString() -> String {
        switch self {
        case .PreviousCredit: return "Previous Credit"
        case .FreshmanFall: return "Freshman Fall"
        case .FreshmanIAP: return "Freshman IAP"
        case .FreshmanSpring: return "Freshman Spring"
        case .SophomoreFall: return "Sophomore Fall"
        case .SophomoreIAP: return "Sophomore IAP"
        case .SophomoreSpring: return "Sophomore Spring"
        case .JuniorFall: return "Junior Fall"
        case .JuniorIAP: return "Junior IAP"
        case .JuniorSpring: return "Junior Spring"
        case .SeniorFall: return "Senior Fall"
        case .SeniorIAP: return "Senior IAP"
        case .SeniorSpring: return "Senior Spring"
        }
    }
    
    func isIAP() -> Bool {
        return (self == .FreshmanIAP || self == .SophomoreIAP || self == .JuniorIAP || self == .SeniorIAP)
    }
    
    func isFall() -> Bool {
        return (self == .FreshmanFall || self == .SophomoreFall || self == .JuniorFall || self == .SeniorFall)
    }
    
    func isSpring() -> Bool {
        return (self == .FreshmanSpring || self == .SophomoreSpring || self == .JuniorSpring || self == .SeniorSpring)
    }
    
    static let allEnrolledSemesters: [UserSemester] = [
        .FreshmanFall, .FreshmanIAP, .FreshmanSpring,
        .SophomoreFall, .SophomoreIAP, .SophomoreSpring,
        .JuniorFall, .JuniorIAP, .JuniorSpring,
        .SeniorFall, .SeniorIAP, .SeniorSpring
    ]
}

class User: NSObject {
    
    private var selectedSubjects: [UserSemester: [Course]] = [:]
    
    var name: String = "No Name"
    var coursesOfStudy: [CourseOfStudy] = []
    
    var filePath: String? {
        didSet {
            if saveTimer?.isValid == true {
                saveTimer?.invalidate()
            }
            saveTimer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: true, block: { _ in
                self.autosave()
            })
        }
    }
    var needsSave: Bool = false
    private var saveInterval = 2.0
    private var saveTimer: Timer?
    
    var allCourses: [Course] {
        var ret: [Course] = []
        for (_, subjects) in selectedSubjects.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            ret += subjects
        }
        return ret
    }
    
    init(contentsOfFile path: String) throws {
        super.init()
        try readUserCourses(from: path)
    }
    
    deinit {
        if saveTimer?.isValid == true {
            saveTimer?.invalidate()
        }
    }
    
    override init() {
        super.init()
    }
    
    func courses(forSemester semester: UserSemester) -> [Course] {
        if selectedSubjects.contains(where: { $0.0 == semester }) {
            return selectedSubjects[semester]!
        }
        return []
    }
    
    func delete(_ course: Course, fromSemester semester: UserSemester) {
        var semesterCourses = self.courses(forSemester: semester)
        if let delIdx = semesterCourses.index(of: course) {
            semesterCourses.remove(at: delIdx)
        }
        self.selectedSubjects[semester] = semesterCourses
        needsSave = true
    }
    
    func add(_ course: Course, toSemester destSemester: UserSemester) {
        var semesterCourses = self.courses(forSemester: destSemester)
        if !semesterCourses.contains(course) {
            semesterCourses.append(course)
        }
        self.selectedSubjects[destSemester] = semesterCourses
        needsSave = true
        
        // Index the new department for Spotlight
        if let code = course.subjectCode {
            CourseManager.shared.indexSearchableItems(forDepartment: code)
        }
    }
    
    func insert(_ course: Course, toSemester destSemester: UserSemester, atIndex idx: Int) {
        var semesterCourses = self.courses(forSemester: destSemester)
        if !semesterCourses.contains(course) {
            semesterCourses.insert(course, at: min(idx, semesterCourses.count))
        }
        self.selectedSubjects[destSemester] = semesterCourses
        needsSave = true
        
        // Index the new department for Spotlight
        if let code = course.subjectCode {
            CourseManager.shared.indexSearchableItems(forDepartment: code)
        }
    }
    
    func move(_ course: Course, fromSemester semester: UserSemester, toSemester destSemester: UserSemester, atIndex idx: Int) {
        self.delete(course, fromSemester: semester)
        self.insert(course, toSemester: destSemester, atIndex: idx)
        needsSave = true
    }
    
    // MARK: - File Handling
    
    var subjectComponentSeparator = "#,#"
    
    func readUserCourses(from file: String) throws {
        self.filePath = file
        let contents = try String(contentsOfFile: file)
        var lines = contents.components(separatedBy: "\n")
        guard lines.count >= 2 else {
            print("No information in this file to read")
            return
        }
        
        // First line, header information
        let firstLine = lines.removeFirst()
        let firstLineComps = firstLine.components(separatedBy: ";")
        guard firstLineComps.count >= 2 else {
            print("First line doesn't have enough information")
            return
        }
        name = firstLineComps[0].trimmingCharacters(in: .whitespacesAndNewlines)
        coursesOfStudy = firstLineComps[1].components(separatedBy: ",").flatMap({ CourseOfStudy(rawValue: $0) })
        
        // Do nothing with the second line for now
        lines.removeFirst()
        
        selectedSubjects = [:]
        for subjectLine in lines where subjectLine.characters.count > 0 {
            let comps = subjectLine.components(separatedBy: subjectComponentSeparator)
            guard comps.count >= 4 else {
                print("Not enough components in subject line \(subjectLine)")
                continue
            }
            guard let semesterRaw = Int(comps[0]),
                let semester = UserSemester(rawValue: semesterRaw),
                let units = Int(comps[3]) else {
                    print("Invalid integer format in subject line \(subjectLine)")
                    continue
            }
            let subjectID = comps[1]
            
            if CourseManager.shared.getCourse(withID: subjectID) == nil {
                CourseManager.shared.addCourse(withID: subjectID, title: comps[2], units: units)
            }
            guard let course = CourseManager.shared.getCourse(withID: subjectID) else {
                print("Unable to add course with ID \(subjectID) to course manager")
                continue
            }
            
            add(course, toSemester: semester)
        }
    }
    
    private var currentlyWriting = false
    
    func writeUserCourses(to file: String) throws {
        currentlyWriting = true
        
        var contentsString = ""
        // First line, header information
        contentsString += "\(name);\(coursesOfStudy.map({ $0.rawValue }).joined(separator: ","))\n"
        // Second line, future header information
        contentsString += "\n"
        // Subsequent lines, selected subjects
        for (semester, subjects) in selectedSubjects.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            for subject in subjects {
                guard let id = subject.subjectID,
                    let title = subject.subjectTitle else {
                        print("No information to write for \(subject)")
                        continue
                }
                let units = subject.totalUnits
                contentsString += ["\(semester.rawValue)", id, title, "\(units)"].joined(separator: subjectComponentSeparator) + "\n"
            }
        }
        
        if !FileManager.default.fileExists(atPath: file) {
            let success = FileManager.default.createFile(atPath: file, contents: nil, attributes: nil)
            if !success {
                print("Failed to create file at \(file)")
            }
        }
        try contentsString.write(toFile: file, atomically: true, encoding: .utf8)
        currentlyWriting = false
    }
    
    func autosave() {
        guard needsSave, let path = filePath else {
            return
        }
        
        DispatchQueue.global().async { [weak self] in
            guard let `self` = self,
                !self.currentlyWriting else {
                return
            }
            do {
                try self.writeUserCourses(to: path)
            } catch {
                print("Error writing file: \(error)")
            }
            self.needsSave = false
        }
    }
}
