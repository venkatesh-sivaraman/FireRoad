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
        case .PreviousCredit: return "Prior Credit"
        case .FreshmanFall: return "1st Year Fall"
        case .FreshmanIAP: return "1st Year IAP"
        case .FreshmanSpring: return "1st Year Spring"
        case .SophomoreFall: return "2nd Year Fall"
        case .SophomoreIAP: return "2nd Year IAP"
        case .SophomoreSpring: return "2nd Year Spring"
        case .JuniorFall: return "3rd Year Fall"
        case .JuniorIAP: return "3rd Year IAP"
        case .JuniorSpring: return "3rd Year Spring"
        case .SeniorFall: return "4th Year Fall"
        case .SeniorIAP: return "4th Year IAP"
        case .SeniorSpring: return "4th Year Spring"
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
    
    static let allSemesters: [UserSemester] = [
        .PreviousCredit, .FreshmanFall, .FreshmanIAP, .FreshmanSpring,
        .SophomoreFall, .SophomoreIAP, .SophomoreSpring,
        .JuniorFall, .JuniorIAP, .JuniorSpring,
        .SeniorFall, .SeniorIAP, .SeniorSpring
    ]
}

class User: NSObject {
    
    private var selectedSubjects: [UserSemester: [Course]] = [:]
    
    var name: String = "No Name"
    /// Courses of study correspond to the filenames of .reql files.
    var coursesOfStudy: [String] = []
    
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
        NotificationCenter.default.removeObserver(self)
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
        setNeedsSave()
    }
    
    func add(_ course: Course, toSemester destSemester: UserSemester) {
        var semesterCourses = self.courses(forSemester: destSemester)
        if !semesterCourses.contains(course) {
            semesterCourses.append(course)
        }
        self.selectedSubjects[destSemester] = semesterCourses
        setNeedsSave()
        
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
        setNeedsSave()
        
        // Index the new department for Spotlight
        if let code = course.subjectCode {
            CourseManager.shared.indexSearchableItems(forDepartment: code)
        }
    }
    
    func move(_ course: Course, fromSemester semester: UserSemester, toSemester destSemester: UserSemester, atIndex idx: Int) {
        self.delete(course, fromSemester: semester)
        self.insert(course, toSemester: destSemester, atIndex: idx)
        setNeedsSave()
    }
    
    @objc func courseManagerFinishedLoading() {
        for (semester, courses) in selectedSubjects {
            selectedSubjects[semester] = courses.map({ CourseManager.shared.getCourse(withID: $0.subjectID!) ?? $0 })
        }
        warningsCache.removeAll()
    }
    
    // MARK: - Courses of Study
    
    func addCourseOfStudy(_ listID: String) {
        coursesOfStudy.append(listID)
        setNeedsSave()
    }
    
    func removeCourseOfStudy(_ listID: String) {
        if let index = coursesOfStudy.index(of: listID) {
            coursesOfStudy.remove(at: index)
            setNeedsSave()
        }
    }
    
    // MARK: - Courseroad Error Checking
    
    enum CourseWarningType {
        case unsatisfiedPrerequisites
        case unsatisfiedCorequisites
    }
    
    struct CourseWarning {
        var type: CourseWarningType
        var message: String?
    }
    
    var warningsCache: [Course: [CourseWarning]] = [:]
    
    func warningsForCourse(_ course: Course, in semester: UserSemester) -> [CourseWarning] {
        guard semester != .PreviousCredit else {
            return []
        }
        if let warnings = warningsCache[course] {
            return warnings
        }
        var unsatisfiedPrereqs: [String] = []
        for prereqList in course.prerequisites {
            var satisfied = false
            for prereq in prereqList {
                for otherSemester in UserSemester.allSemesters where otherSemester.rawValue < semester.rawValue {
                    for course in courses(forSemester: otherSemester) {
                        if course.satisfies(requirement: prereq) {
                            satisfied = true
                            break
                        }
                    }
                    if satisfied {
                        break
                    }
                }
                if satisfied {
                    break
                }
            }
            if !satisfied {
                unsatisfiedPrereqs += prereqList
            }
        }
        var unsatisfiedCoreqs: [String] = []
        for coreqList in course.corequisites {
            var satisfied = false
            for coreq in coreqList {
                for otherSemester in UserSemester.allSemesters where otherSemester.rawValue <= semester.rawValue {
                    for course in courses(forSemester: otherSemester) {
                        if course.satisfies(requirement: coreq) {
                            satisfied = true
                            break
                        }
                    }
                    if satisfied {
                        break
                    }
                }
                if satisfied {
                    break
                }
            }
            if !satisfied {
                unsatisfiedCoreqs += coreqList
            }
        }
        var warnings: [CourseWarning] = []
        if unsatisfiedPrereqs.count > 0 {
            warnings.append(CourseWarning(type: .unsatisfiedPrerequisites, message: nil))
        }
        if unsatisfiedCoreqs.count > 0 {
            warnings.append(CourseWarning(type: .unsatisfiedCorequisites, message: nil))
        }
        warningsCache[course] = warnings
        return warnings
    }
    
    // MARK: - Global Relevance Calculation
    
    private enum RelevanceCacheType: Int {
        case plannedSubjects
        case majorSubjects
        case nonMajorSubjects
        case primaryRelatedSubjects
    }
    private var relevanceCache: [RelevanceCacheType: [Course: Float]] = [:]
    
    private static let relevanceCacheWeights: [RelevanceCacheType: Float] = [
        .plannedSubjects: 2.0,
        .majorSubjects: 4.0,
        .nonMajorSubjects: 3.0,
        .primaryRelatedSubjects: 0.1   //Because it is going to be additionally weighted by relevance
    ]
    
    private func addCourse(_ course: Course, toRelevanceCache cache: RelevanceCacheType, weight: Float = 1.0) {
        if let oldValue = relevanceCache[cache]?[course] {
            relevanceCache[cache]?[course]? = max(oldValue, User.relevanceCacheWeights[cache]! * weight)
        } else {
            relevanceCache[cache]?[course] = User.relevanceCacheWeights[cache]! * weight
        }
    }
    
    func updateRelevanceCache() {
        print("Updating relevance cache...")
        relevanceCache = [
            .plannedSubjects: [:],
            .majorSubjects: [:],
            .nonMajorSubjects: [:],
            .primaryRelatedSubjects: [:]
        ]
        
        for course in allCourses + CourseManager.shared.favoriteCourses {
            addCourse(course, toRelevanceCache: .plannedSubjects)
            for (relatedOne, relevance) in course.relatedSubjects {
                guard let relatedCourse = CourseManager.shared.getCourse(withID: relatedOne) else {
                    continue
                }
                addCourse(relatedCourse, toRelevanceCache: .primaryRelatedSubjects, weight: relevance)
            }
        }
        
        for courseOfStudy in coursesOfStudy {
            guard let reqList = RequirementsListManager.shared.requirementList(withID: courseOfStudy) else {
                continue
            }
            for reqCourse in reqList.requiredCourses {
                if reqList.listID.contains("major") {
                    addCourse(reqCourse, toRelevanceCache: .majorSubjects)
                } else {
                    addCourse(reqCourse, toRelevanceCache: .nonMajorSubjects)
                }
                for (relatedOne, relevance) in reqCourse.relatedSubjects {
                    guard let relatedCourse = CourseManager.shared.getCourse(withID: relatedOne) else {
                        continue
                    }
                    addCourse(relatedCourse, toRelevanceCache: .primaryRelatedSubjects, weight: relevance)
                }
            }
        }
        print("Finished updating relevance cache.")
    }
    
    /**
     Returns a multiplier indicating the relevance of the given course to the user.
     If the course has no relevant connections to the user, this function returns
     1.0. Otherwise, the return value is doubled for every connection to the user
     (contained within CourseRoad, related to such a course, within major, and
     within minor).
     */
    func userRelevance(for course: Course) -> Float {
        var relevance: Float = 1.0
        if relevanceCache.count == 0 {
            updateRelevanceCache()
        }
        for (_, courseSet) in relevanceCache {
            if let weight = courseSet[course] {
                relevance *= weight
            }
        }
        return relevance
    }
    
    // MARK: - File Handling
    
    func setNeedsSave() {
        needsSave = true
        warningsCache.removeAll()
        relevanceCache = [:]
    }
    
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
        coursesOfStudy = firstLineComps[1].components(separatedBy: ",")
        
        // Do nothing with the second line for now
        lines.removeFirst()
        
        selectedSubjects = [:]
        for subjectLine in lines where subjectLine.count > 0 {
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
        
        if !CourseManager.shared.isLoaded {
            NotificationCenter.default.addObserver(self, selector: #selector(courseManagerFinishedLoading), name: .CourseManagerFinishedLoading, object: nil)
        }
    }
    
    private var currentlyWriting = false
    
    func writeUserCourses(to file: String) throws {
        currentlyWriting = true
        
        var contentsString = ""
        // First line, header information
        contentsString += "\(name);\(coursesOfStudy.joined(separator: ","))\n"
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
