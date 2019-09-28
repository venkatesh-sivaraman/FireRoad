//
//  User.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/2/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

enum SubjectRating {
    static let baselineInCourseroad = 2
    static let baselineFavorites = 3
    static let baselineInCourseOfStudy = 1
    static let none = 0
}

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
    case SuperSeniorFall = 13
    case SuperSeniorIAP = 14
    case SuperSeniorSpring = 15

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
        case .SuperSeniorFall: return "5th Year Fall"
        case .SuperSeniorIAP: return "5th Year IAP"
        case .SuperSeniorSpring: return "5th Year Spring"
        }
    }
    
    func isIAP() -> Bool {
        return (self == .FreshmanIAP || self == .SophomoreIAP || self == .JuniorIAP || self == .SeniorIAP || self == .SuperSeniorIAP)
    }
    
    func isFall() -> Bool {
        return (self == .FreshmanFall || self == .SophomoreFall || self == .JuniorFall || self == .SeniorFall || self == .SuperSeniorFall)
    }
    
    func isSpring() -> Bool {
        return (self == .FreshmanSpring || self == .SophomoreSpring || self == .JuniorSpring || self == .SeniorSpring || self == .SuperSeniorSpring)
    }
    
    func yearNumber() -> Int {
        return UserSemester.yearMapping[self] ?? 0
    }
    
    private static let yearMapping: [UserSemester: Int] = [
        .FreshmanFall: 1,
        .FreshmanIAP: 1,
        .FreshmanSpring: 1,
        .SophomoreFall: 2,
        .SophomoreIAP: 2,
        .SophomoreSpring: 2,
        .JuniorFall: 3,
        .JuniorIAP: 3,
        .JuniorSpring: 3,
        .SeniorFall: 4,
        .SeniorIAP: 4,
        .SeniorSpring: 4,
        .SuperSeniorFall: 5,
        .SuperSeniorIAP: 5,
        .SuperSeniorSpring: 5,
    ]
    
    static let allEnrolledSemesters: [UserSemester] = [
        .FreshmanFall, .FreshmanIAP, .FreshmanSpring,
        .SophomoreFall, .SophomoreIAP, .SophomoreSpring,
        .JuniorFall, .JuniorIAP, .JuniorSpring,
        .SeniorFall, .SeniorIAP, .SeniorSpring,
        .SuperSeniorFall, .SuperSeniorIAP, .SuperSeniorSpring
    ]
    
    static let allSemesters: [UserSemester] = [
        .PreviousCredit, .FreshmanFall, .FreshmanIAP, .FreshmanSpring,
        .SophomoreFall, .SophomoreIAP, .SophomoreSpring,
        .JuniorFall, .JuniorIAP, .JuniorSpring,
        .SeniorFall, .SeniorIAP, .SeniorSpring,
        .SuperSeniorFall, .SuperSeniorIAP, .SuperSeniorSpring
    ]
}

class User: UserDocument {
    
    private var selectedSubjects: [UserSemester: [Course]] = [:]
    
    override var isEmpty: Bool {
        return allCourses.count == 0
    }
    
    var name: String = "No Name"
    /// Courses of study correspond to the filenames of .reql files.
    var coursesOfStudy: [String] = []
    private var markers: [UserSemester: [Course: SubjectMarker]] = [:]
    
    /// Dictionary from requirement key paths to manual progress override values
    private var progressOverrides: [String: Int] = [:]
    
    var allCourses: [Course] {
        var ret: [Course] = []
        for (_, subjects) in selectedSubjects.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            ret += subjects
        }
        return ret
    }
    
    var creditCourses: [Course] {
        // Only courses that aren't marked as listener
        return selectedSubjects.flatMap({ (semester, courses) in courses.filter({ subjectMarker(for: $0, in: semester) != .listener }) })
    }
    
    func courses(forSemester semester: UserSemester) -> [Course] {
        if selectedSubjects.contains(where: { $0.0 == semester }) {
            return selectedSubjects[semester]!
        }
        return []
    }
    
    func delete(_ course: Course, fromSemester semester: UserSemester, removingOverrides: Bool = true) {
        var semesterCourses = self.courses(forSemester: semester)
        if let delIdx = semesterCourses.index(of: course) {
            semesterCourses.remove(at: delIdx)
        }
        self.selectedSubjects[semester] = semesterCourses
        if removingOverrides {
            overrides[course] = nil
        }
        setSubjectMarker(nil, for: course, in: semester)
        setNeedsSave()
        
        if CourseManager.shared.userRatings[course.subjectID!] == nil {
            CourseManager.shared.setUserRatings([course.subjectID!: SubjectRating.none], autoGenerated: true)
        }
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
        // Update location of subject marker
        let optMarker = subjectMarker(for: course, in: semester)
        if let marker = optMarker, semester != destSemester {
            setSubjectMarker(nil, for: course, in: semester)
            setSubjectMarker(marker, for: course, in: destSemester)
        }
        self.delete(course, fromSemester: semester, removingOverrides: false)
        self.insert(course, toSemester: destSemester, atIndex: idx)
        setSubjectMarker(optMarker, for: course, in: destSemester)
        setNeedsSave()
    }
    
    @objc func courseManagerFinishedLoading() {
        for (semester, courses) in selectedSubjects {
            selectedSubjects[semester] = courses.map({ CourseManager.shared.getCourse(withID: $0.subjectID!) ?? $0 })
        }
        for (semester, markerSet) in markers {
            var newMarkers: [Course: SubjectMarker] = [:]
            for (course, marker) in markerSet {
                newMarkers[CourseManager.shared.getCourse(withID: course.subjectID!) ?? course] = marker
            }
            markers[semester] = newMarkers
        }
        clearWarningsCache()
        var newOverrides: [Course: Bool] = [:]
        for (course, over) in overrides {
            guard let newCourse = CourseManager.shared.getCourse(withID: course.subjectID!) else {
                continue
            }
            newOverrides[newCourse] = over
        }
        overrides = newOverrides
    }
    
    // MARK: - Courses of Study
    
    func addCourseOfStudy(_ listID: String) {
        coursesOfStudy.append(listID)
        if let reqList = RequirementsListManager.shared.requirementList(withID: listID) {
            var newRatings: [String: Int] = [:]
            for course in reqList.requiredCourses where course.subjectID != nil {
                if CourseManager.shared.userRatings[course.subjectID!] == nil {
                    newRatings[course.subjectID!] = SubjectRating.baselineInCourseOfStudy
                }
            }
            CourseManager.shared.setUserRatings(newRatings, autoGenerated: true)
        }
        setNeedsSave()
    }
    
    func removeCourseOfStudy(_ listID: String) {
        if let index = coursesOfStudy.index(of: listID) {
            coursesOfStudy.remove(at: index)
            if let reqList = RequirementsListManager.shared.requirementList(withID: listID) {
                var newRatings: [String: Int] = [:]
                for course in reqList.requiredCourses where course.subjectID != nil {
                    if CourseManager.shared.userRatings[course.subjectID!] == nil {
                        newRatings[course.subjectID!] = SubjectRating.none
                    }
                }
                CourseManager.shared.setUserRatings(newRatings, autoGenerated: true)
            }
            setNeedsSave()
        }
    }
    
    // MARK: - Courseroad Error Checking
    
    enum CourseWarningType: String {
        case unsatisfiedPrerequisites = "Unsatisfied Prerequisite"
        case unsatisfiedCorequisites = "Unsatisfied Corequisite"
        case notOffered = "Not Offered"
    }
    
    struct CourseWarning: Equatable {
        var type: CourseWarningType
        var message: String?
        
        static func ==(lhs: CourseWarning, rhs: CourseWarning) -> Bool {
            return lhs.type == rhs.type && lhs.message == rhs.message
        }
    }
    
    var warningsCache: [Course: [CourseWarning]] = [:]
    
    var overrides: [Course: Bool] = [:]
    
    func clearWarningsCache() {
        warningsCache.removeAll()
    }
    
    /**
     Evaluates the prerequisites and corequisites for the user taking the course
     in the given semester. If semester is nil, uses the first occurrence of
     the course in the user's road that is not in Prior Credit.
    */
    func evaluateRequirements(for course: Course, in semester: UserSemester? = nil) {
        guard let evalSemester = semester ?? UserSemester.allEnrolledSemesters.first(where: { courses(forSemester: $0).contains(course) }) else {
            return
        }
        
        var priorCourses: [Course] = []
        
        for otherSemester in UserSemester.allSemesters where otherSemester.rawValue <= evalSemester.rawValue {
            for otherCourse in courses(forSemester: otherSemester) {
                if otherSemester.rawValue < evalSemester.rawValue || (course.quarterOffered != .beginningOnly && otherCourse.quarterOffered == .beginningOnly) {
                    priorCourses.append(otherCourse)
                }
            }
        }

        if let prereqs = course.prerequisites {
            prereqs.computeRequirementStatus(with: priorCourses)
        }
        
        for otherSemester in UserSemester.allSemesters where otherSemester.rawValue <= evalSemester.rawValue {
            for otherSemester in UserSemester.allSemesters where (AppSettings.shared.allowsCorequisitesTogether && otherSemester.rawValue <= evalSemester.rawValue) || (!AppSettings.shared.allowsCorequisitesTogether && otherSemester.rawValue < evalSemester.rawValue) {
                priorCourses += courses(forSemester: otherSemester)
            }
        }
        
        if let coreqs = course.corequisites {
            coreqs.computeRequirementStatus(with: priorCourses)
        }
    }
    
    func warningsForCourse(_ course: Course, in semester: UserSemester) -> [CourseWarning] {
        guard semester != .PreviousCredit else {
            return []
        }
        if let warnings = warningsCache[course] {
            return warnings
        }
        
        
        var unsatisfiedPrereqs = false
        var unsatisfiedCoreqs = false

        if course.prerequisites != nil || course.corequisites != nil {
            evaluateRequirements(for: course, in: semester)
            unsatisfiedPrereqs = !(course.prerequisites?.isFulfilled ?? true)
            unsatisfiedCoreqs = !(course.corequisites?.isFulfilled ?? true)
        }

        var warnings: [CourseWarning] = []
        if semester.isFall(), !course.isOfferedFall {
            warnings.append(CourseWarning(type: .notOffered, message: "According to the course catalog, \(course.subjectID!) is not offered in the fall."))
        } else if semester.isIAP(), !course.isOfferedIAP {
            warnings.append(CourseWarning(type: .notOffered, message: "According to the course catalog, \(course.subjectID!) is not offered over IAP."))
        } else if semester.isSpring(), !course.isOfferedSpring {
            warnings.append(CourseWarning(type: .notOffered, message: "According to the course catalog, \(course.subjectID!) is not offered in the spring."))
        }
        if !course.eitherPrereqOrCoreq || (unsatisfiedPrereqs && unsatisfiedCoreqs) {
            if unsatisfiedPrereqs, let prereqs = course.prerequisites {
                warnings.append(CourseWarning(type: .unsatisfiedPrerequisites, message: formatUnsatisfiedRequirements(label: "prerequisites", requirements: prereqs)))
            }
            if unsatisfiedCoreqs, let coreqs = course.corequisites {
                warnings.append(CourseWarning(type: .unsatisfiedCorequisites, message: formatUnsatisfiedRequirements(label: "corequisites", requirements: coreqs)))
            }
        }
        warningsCache[course] = warnings
        return warnings
    }
    
    private func formatUnsatisfiedRequirements(label: String, requirements: RequirementsListStatement) -> String {
        return "One or more \(label) may not be satisfied."
    }
    
    func overridesWarnings(for course: Course) -> Bool {
        return overrides[course] ?? false
    }
    
    func setOverridesWarnings(_ override: Bool, for course: Course) {
        overrides[course] = override
        setNeedsSave()
    }
    
    // MARK: - Subject Markers
    
    func setSubjectMarker(_ marker: SubjectMarker?, for course: Course, in semester: UserSemester, save: Bool = true) {
        if markers[semester] == nil {
            markers[semester] = [:]
        }
        markers[semester]?[course] = marker
        if save {
            setNeedsSave()
        }
    }
    
    func subjectMarker(for course: Course, in semester: UserSemester) -> SubjectMarker? {
        return markers[semester]?[course]
    }
    
    // MARK: - Requirement Overrides
    
    func progressOverride(for keyPath: String) -> Int? {
        return progressOverrides[keyPath]
    }
    
    func setProgressOverride(for keyPath: String, to value: Int, save: Bool = true) {
        progressOverrides[keyPath] = value
        if save {
            setNeedsSave()
        }
    }
    
    // MARK: - Global Relevance Calculation
    
    private enum RelevanceCacheType: Int {
        case plannedSubjects
        case ratedSubjects
        case majorSubjects
        case nonMajorSubjects
        case primaryRelatedSubjects
    }
    private var relevanceCache: [RelevanceCacheType: [Course: Float]] = [:]
    
    private static let relevanceCacheWeights: [RelevanceCacheType: Float] = [
        .plannedSubjects: 2.0,
        .ratedSubjects: 2.0,    //In the future, weight this by rating
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
            .ratedSubjects: [:],
            .majorSubjects: [:],
            .nonMajorSubjects: [:],
            .primaryRelatedSubjects: [:]
        ]
        
        for course in allCourses {
            addCourse(course, toRelevanceCache: .plannedSubjects)
            for (relatedOne, relevance) in course.relatedSubjects {
                guard let relatedCourse = CourseManager.shared.getCourse(withID: relatedOne) else {
                    continue
                }
                addCourse(relatedCourse, toRelevanceCache: .primaryRelatedSubjects, weight: relevance)
            }
        }
        
        for course in CourseManager.shared.favoriteCourses {
            addCourse(course, toRelevanceCache: .ratedSubjects)
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
    
    func userRecommendedCourses() -> [Course] {
        updateRelevanceCache()
        var courseRelevances: [Course: Float] = [:]
        for (_, courseSet) in relevanceCache {
            for (course, relevance) in courseSet {
                guard !allCourses.contains(course) else {
                    continue
                }
                if courseRelevances[course] != nil {
                    courseRelevances[course]? += relevance
                } else {
                    courseRelevances[course] = relevance
                }
            }
        }
        return courseRelevances.sorted(by: { $0.value > $1.value })[0..<min(courseRelevances.count, 15)].map({ $0.key })
    }
    
    // MARK: - Ratings
    
    func setBaselineRatings() {
        var newRatings: [String: Int] = [:]
        for course in allCourses {
            if CourseManager.shared.userRatings[course.subjectID!] == nil {
                newRatings[course.subjectID!] = SubjectRating.baselineInCourseroad
            }
        }
        for listID in coursesOfStudy {
            guard let reqList = RequirementsListManager.shared.requirementList(withID: listID) else {
                continue
            }
            for course in reqList.requiredCourses where course.subjectID != nil {
                if CourseManager.shared.userRatings[course.subjectID!] == nil, newRatings[course.subjectID!] == nil {
                    newRatings[course.subjectID!] = SubjectRating.baselineInCourseOfStudy
                }
            }
        }
        CourseManager.shared.setUserRatings(newRatings, autoGenerated: true)
    }
    
    // MARK: - File Handling
    
    enum RoadFile {
        static let coursesOfStudy = "coursesOfStudy"
        static let selectedSubjects = "selectedSubjects"
        static let progressOverrides = "progressOverrides"
        static let subjectIDAlt = "id"
        static let subjectID = "subject_id"
        static let subjectTitle = "title"
        static let semesterNumber = "semester"
        static let units = "units"
        static let overrideWarnings = "overrideWarnings"
        static let marker = "marker"
    }
    
    override func setNeedsSave() {
        super.setNeedsSave()
        clearWarningsCache()
        relevanceCache = [:]
    }
    
    var subjectComponentSeparator = "#,#"
    
    override func readUserCourses(from file: String) throws {
        try super.readUserCourses(from: file)
        
        defer {
            if !CourseManager.shared.isLoaded {
                NotificationCenter.default.addObserver(self, selector: #selector(courseManagerFinishedLoading), name: .CourseManagerFinishedLoading, object: nil)
            }
        }
        
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
            let courses = fileDict[RoadFile.coursesOfStudy] as? [String],
            let selectedSubjectsList = fileDict[RoadFile.selectedSubjects] as? [[String: Any]] else {
                print("Malformed JSON: \(json)")
                return
        }
        coursesOfStudy = courses
        selectedSubjects = [:]
        overrides = [:]
        progressOverrides = [:]
        markers = [:]
        
        for subjectJSON in selectedSubjectsList {
            guard let subjectID = (subjectJSON[RoadFile.subjectID] ?? subjectJSON[RoadFile.subjectIDAlt]) as? String,
                let title = subjectJSON[RoadFile.subjectTitle] as? String,
                let units = subjectJSON[RoadFile.units] as? Int,
                let semesterNumber = subjectJSON[RoadFile.semesterNumber] as? Int,
                let override = subjectJSON[RoadFile.overrideWarnings] as? Bool else {
                    print("Malformed subject entry: \(subjectJSON)")
                    continue
            }
            guard let semester = UserSemester(rawValue: semesterNumber) else {
                print("No semester number \(semesterNumber)")
                continue
            }
            if subjectJSON[CourseAttribute.creator.jsonKey()] != nil,
                CourseManager.shared.getCustomCourse(with: subjectID, title: title) == nil {
                let course = Course(json: subjectJSON)
                CourseManager.shared.setCustomCourse(course)
            } else if subjectJSON[CourseAttribute.creator.jsonKey()] == nil,
                CourseManager.shared.getCourse(withID: subjectID) == nil,
                Course.genericCourses[subjectID] == nil {
                CourseManager.shared.addCourse(withID: subjectID, title: title, units: units)
            }
            guard let course = CourseManager.shared.getCourse(withID: subjectID) ?? Course.genericCourses[subjectID] ?? CourseManager.shared.getCustomCourse(with: subjectID, title: title) else {
                print("Unable to add course with ID \(subjectID) to course manager")
                continue
            }
            // Add additional keys from JSON
            course.readJSON(subjectJSON)
            if course.creator != nil {
                // Save course if it's custom
                CourseManager.shared.setCustomCourse(course)
            }
            
            // Subject marker
            if let markerString = subjectJSON[RoadFile.marker] as? String,
                let marker = SubjectMarker(rawValue: markerString) {
                setSubjectMarker(marker, for: course, in: semester, save: false)
            }
            
            add(course, toSemester: semester)
            overrides[course] = override
        }
        
        // Read requirement overrides
        if let reqOverrides = fileDict[RoadFile.progressOverrides] as? [String: Any] {
            for (keyPath, val) in reqOverrides {
                guard let intVal = val as? Int else {
                    continue
                }
                setProgressOverride(for: keyPath, to: intVal, save: false)
            }
        } else if progressOverrides.count == 0,
            let savedOverrides = CourseManager.shared.getAllProgressOverrides(),
            savedOverrides.count > 0 {
            print("Adding courses from saved defaults")
            for (keyPath, val) in savedOverrides {
                setProgressOverride(for: keyPath, to: val, save: false)
            }
        }
        needsSave = false
    }
    
    private func legacyReadCourses(from file: String) throws {
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
        overrides = [:]
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
            
            if CourseManager.shared.getCourse(withID: subjectID) == nil, Course.genericCourses[subjectID] == nil {
                CourseManager.shared.addCourse(withID: subjectID, title: comps[2], units: units)
            }
            guard let course = CourseManager.shared.getCourse(withID: subjectID) ?? Course.genericCourses[subjectID] else {
                print("Unable to add course with ID \(subjectID) to course manager")
                continue
            }
            
            add(course, toSemester: semester)
            
            if comps.count >= 5,
                let override = Int(comps[4]) {
                overrides[course] = (override >= 1)
            }
        }
    }
    
    override func writeUserCourses(to file: String) throws {
        try super.writeUserCourses(to: file)
        
        guard !readOnly else {
            return
        }
        
        setBaselineRatings()

        let fileJSON = try writeCoursesToJSON()
        let contentsData = try JSONSerialization.data(withJSONObject: fileJSON, options: .prettyPrinted)
        
        // Save to server as well
        if self.needsSave && self.shouldCloudSync {
            CloudSyncManager.roadManager.sync(with: self)
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
        for (semester, subjects) in selectedSubjects.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            for subject in subjects {
                var json = subject.toJSON()
                json[RoadFile.semesterNumber] = semester.rawValue
                json[RoadFile.overrideWarnings] = overridesWarnings(for: subject)
                if let marker = subjectMarker(for: subject, in: semester) {
                    json[RoadFile.marker] = marker.rawValue
                }
                selectedSubjectsJSON.append(json)
            }
        }
        let fileJSON: [String: Any] = [
            RoadFile.coursesOfStudy: coursesOfStudy,
            RoadFile.selectedSubjects: selectedSubjectsJSON,
            RoadFile.progressOverrides: progressOverrides
        ]
        return fileJSON
    }
    
    // MARK: - Thumbnails
    
    override var coursesForThumbnail: [Course] {
        return allCourses
    }
}
