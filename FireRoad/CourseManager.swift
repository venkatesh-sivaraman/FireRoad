//
//  CourseManager.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/2/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit
import CoreSpotlight
import MobileCoreServices

extension Notification.Name {
    static let CourseManagerFinishedLoading = Notification.Name(rawValue: "CourseManagerFinishedLoadingNotification")
}

class CourseManager: NSObject {
    
    var courses: [Course] = []
    var coursesByID: [String: Course] = [:]
    var coursesByTitle: [String: Course] = [:]
    static let shared: CourseManager = CourseManager()
    var loadedDepartments: [String] = []
    
    var isLoaded = false
    var loadingProgress: Float = 0.0
    
    private var loadingCompletionBlock: ((Bool) -> Void)? = nil

    /*
 Academic Year,Effective Term Code,Subject Id,Subject Code,Subject Number,Source Subject Id,Print Subject Id,Department Code,Department Name,Subject Short Title,Subject Title,Is Variable Units,Lecture Units,Lab Units,Preparation Units,Total Units,Gir Attribute,Gir Attribute Desc,Comm Req Attribute,Comm Req Attribute Desc,Write Req Attribute,Write Req Attribute Desc,Supervisor Attribute Desc,Prerequisites,Subject Description,Joint Subjects,School Wide Electives,Meets With Subjects,Equivalent Subjects,Is Offered This Year,Is Offered Fall Term,Is Offered Iap,Is Offered Spring Term,Is Offered Summer Term,Fall Instructors,Spring Instructors,Status Change,Last Activity Date,Warehouse Load Date,Master Subject Id,Hass Attribute,Hass Attribute Desc,Term Duration,On Line Page Number
*/
    
    static let departmentNumbers = [
        /*"3", "1", "4", "2", "22",
        "16", "8", "18", "14", "17",
        "24", "21", "21A", "21W", "CMS",
        "MAS", "21G", "21H", "21L", "21M",
        "WGS", "CC", "EC", "EM", "ES",
        "IDS", "STS", "SWE", "SP", "SCM",
        "15", "11", "12", "10", "5",
        "20", "6", "7", "CSB", "HST", "9"*/
        "1", "2", "3", "4",
        "5", "6", "7", "8",
        "9", "10", "11", "12",
        "14", "15", "16", "17",
        "18", "20", "21", "21A",
        "21W", "CMS", "21G", "21H",
        "21L", "21M", "WGS", "22",
        "24", "CC", "CSB", "EC",
        "EM", "ES", "HST", "IDS",
        "MAS", "SCM", "STS", "SWE", "SP"
    ]
    static let colorMapping: [String: UIColor] = {
        let saturation = CGFloat(0.7)
        let brightness = CGFloat(0.87)
        let stepSize = CGFloat(4.0)  // (Department numbers % step size) should be non-zero
        let startPoint = 1.0 / CGFloat(CourseManager.departmentNumbers.count)
        
        var ret: [String: UIColor] = [:]
        var currentHue = startPoint
        for number in CourseManager.departmentNumbers {
            ret[number] = UIColor(hue: currentHue, saturation: saturation, brightness: brightness, alpha: 1.0)
            currentHue += fmod(stepSize / CGFloat(CourseManager.departmentNumbers.count), 1.0)
        }
        ret["GIR"] = UIColor(hue: 0.05, saturation: saturation * 0.75, brightness: brightness, alpha: 1.0)
        ret["HASS"] = UIColor(hue: 0.45, saturation: saturation * 0.75, brightness: brightness, alpha: 1.0)
        ret["HASS-A"] = UIColor(hue: 0.55, saturation: saturation * 0.75, brightness: brightness, alpha: 1.0)
        ret["HASS-H"] = UIColor(hue: 0.65, saturation: saturation * 0.75, brightness: brightness, alpha: 1.0)
        ret["HASS-S"] = UIColor(hue: 0.75, saturation: saturation * 0.75, brightness: brightness, alpha: 1.0)
        ret["CI-H"] = UIColor(hue: 0.85, saturation: saturation * 0.75, brightness: brightness, alpha: 1.0)
        ret["CI-HW"] = UIColor(hue: 0.95, saturation: saturation * 0.75, brightness: brightness, alpha: 1.0)
        return ret
    }()
    
    typealias DispatchJob = ((Bool) -> Void) -> Void
    
    func loadCourses(completion: @escaping ((Bool) -> Void)) {
        
        DispatchQueue.global(qos: .background).async {
            self.courses = []
            self.coursesByID = [:]
            self.coursesByTitle = [:]
            self.loadedDepartments = []
            
            self.dispatch(jobs: [Int](0..<4).map({ num -> DispatchJob in
                return { [weak self] (taskCompletion) in
                    guard let path = Bundle.main.path(forResource: "condensed_\(num)", ofType: "txt") else {
                        print("Failed")
                        taskCompletion(false)
                        return
                    }
                    self?.readSummaryFile(at: path) { progress in
                        self?.loadingProgress += progress * 0.9 / 4.0
                    }
                    taskCompletion(true)
                }
            }), completion: { (summarySuccess) in
                guard summarySuccess else {
                    completion(false)
                    return
                }
                
                let enrollmentBlock: DispatchJob = { [weak self] taskCompletion in
                    self?.loadEnrollment(taskCompletion: taskCompletion)
                }
                let relatedBlock: DispatchJob = { [weak self] taskCompletion in
                    self?.loadRelatedCourses(taskCompletion: taskCompletion)
                }
                
                self.dispatch(jobs: [enrollmentBlock, relatedBlock], completion: { (success) in
                    self.isLoaded = success
                    if success {
                        NotificationCenter.default.post(name: .CourseManagerFinishedLoading, object: self)
                    }
                    completion(success)
                }, totalProgress: 0.1)
            }, totalProgress: 0.0)
        }
    }
    
    private func dispatch(jobs: [DispatchJob], completion: @escaping (Bool) -> Void, totalProgress: Float = 0.1) {
        var completionCount: Int = 0
        let groupCompletionBlock: ((Bool) -> Void) = { (success) in
            if success {
                completionCount += 1
                self.loadingProgress += totalProgress / Float(jobs.count)
                if completionCount == jobs.count {
                    DispatchQueue.main.async {
                        completion(success)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoaded = success
                    completion(success)
                }
            }
        }
        
        for job in jobs {
            DispatchQueue.global(qos: .background).async {
                job(groupCompletionBlock)
            }
        }
    }
    
    func readSummaryFile(at path: String, updateBlock: ((Float) -> Void)? = nil) {
        guard let text = try? String(contentsOfFile: path) else {
            print("Error loading summary file")
            return
        }
        let lines = text.components(separatedBy: .newlines)
        var csvHeaders: [String]? = nil
        
        for line in lines {
            let comps = line.components(separatedBy: ",")
            if comps.contains("Subject Id") {
                csvHeaders = comps
            } else if csvHeaders != nil {
                var i = 0
                var quotedLine = ""
                var currentID: String?
                for comp in comps {
                    var trimmed: String = quotedLine + (quotedLine.count > 0 ? "," : "") + comp
                    if (trimmed.count - trimmed.replacingOccurrences(of: "\"", with: "").count) % 2 == 1 {
                        quotedLine = trimmed
                    } else {
                        quotedLine = ""
                        trimmed = trimmed.first == Character("\"") ? String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 1)..<trimmed.index(trimmed.endIndex, offsetBy: -1)]) : trimmed
                        trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
                        if i >= csvHeaders!.count {
                            print("Beyond bounds")
                        } else if let key = CourseAttribute(csvHeader: csvHeaders![i]) {
                            if key == .subjectID {
                                currentID = trimmed.replacingOccurrences(of: "[J]", with: "")
                            }
                            if let id = currentID {
                                let course = getOrInitializeCourse(withID: id)
                                if key == .subjectTitle {
                                    updateSubjectTitle(for: course, to: trimmed)
                                } else {
                                    course.setValue(trimmed, forKey: key.rawValue)
                                }
                            } else {
                                print("No subject ID for line \(line)!")
                            }
                        }
                        i += 1
                    }
                }
            } else {
                print("No CSV headers found, so this file can't be read.")
                return
            }
            updateBlock?(1.0 / Float(lines.count))
        }
    }
    
    func loadEnrollment(taskCompletion: (Bool) -> Void) {
        guard let enrollPath = Bundle.main.path(forResource: "enrollment", ofType: "txt"),
            let text = try? String(contentsOfFile: enrollPath) else {
                print("Failed with enrollment")
                taskCompletion(false)
                return
        }
        let lines = text.components(separatedBy: .newlines)
        var csvHeaders: [String]? = nil
        for line in lines {
            let comps = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).components(separatedBy: ",")
            if comps.contains("Subject Id") {
                csvHeaders = comps
            } else if csvHeaders != nil {
                var currentID: String?
                for (i, comp) in comps.enumerated() {
                    if csvHeaders![i] == "Subject Id" {
                        currentID = comp.replacingOccurrences(of: "[J]", with: "")
                    } else if csvHeaders![i] == "Subject Enrollment Number",
                        let id = currentID,
                        let course = self.getCourse(withID: id) {
                        course.enrollmentNumber = max(course.enrollmentNumber, Int(Float(comp)!))
                    }
                }
            } else {
                print("No CSV headers found, so this file can't be read.")
                taskCompletion(false)
                return
            }
        }
        taskCompletion(true)
    }
    
    func loadRelatedCourses(taskCompletion: (Bool) -> Void) {
        guard let relatedPath = Bundle.main.path(forResource: "related", ofType: "txt"),
            let text = try? String(contentsOfFile: relatedPath) else {
                print("Failed with related")
                taskCompletion(false)
                return
        }
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let comps = line.components(separatedBy: ",")
            var related: [(String, Float)] = []
            for compIdx in stride(from: 1, to: comps.count, by: 2) {
                related.append((comps[compIdx], Float(comps[compIdx + 1])!))
            }
            let course = getOrInitializeCourse(withID: comps[0].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).replacingOccurrences(of: "[J]", with: ""))
            course.relatedSubjects = related.sorted(by: { $0.1 > $1.1 })
        }
        taskCompletion(true)
    }
    
    func loadCourseDetailsSynchronously(about course: Course) {
        if self.getCourse(withID: course.subjectID!) == nil {
            return
        }
        if self.loadedDepartments.contains(course.subjectCode!) {
            return
        }
        guard let path = Bundle.main.path(forResource: course.subjectCode!, ofType: "txt") else {
            print("Failed to load details for \(course.subjectID!)")
            return
        }
        self.readSummaryFile(at: path)
        self.loadedDepartments.append(course.subjectCode!)
    }
    
    func loadCourseDetails(about course: Course, _ completion: @escaping ((Bool) -> Void)) {
        if self.getCourse(withID: course.subjectID!) == nil {
            completion(false)
            return
        }
        if self.loadedDepartments.contains(course.subjectCode!) {
            completion(true)
            return
        }
        guard let path = Bundle.main.path(forResource: course.subjectCode!, ofType: "txt") else {
            print("Failed")
            completion(false)
            return
        }
        DispatchQueue.global().async {
            self.readSummaryFile(at: path)
            self.loadedDepartments.append(course.subjectCode!)
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }
    
    // MARK: - Course Object Management
    
    let courseEditingQueueID = "FireRoadCourseManagerEditingQueue"
    lazy var courseEditingQueue = DispatchQueue(label: courseEditingQueueID)
    
    private func getOrInitializeCourse(withID subjectID: String) -> Course {
        return courseEditingQueue.sync {
            if let course = getCourse(withID: subjectID) {
                return course
            }
            let newCourse = Course()
            courses.append(newCourse)
            updateSubjectID(for: newCourse, to: subjectID)
            return newCourse
        }
    }
    
    private func updateSubjectID(for course: Course, to newValue: String) {
        if let oldID = course.subjectID, coursesByID[oldID] == course {
            coursesByID[oldID] = nil
        }
        course.subjectID = newValue
        coursesByID[newValue] = course
    }
    
    private func updateSubjectTitle(for course: Course, to newValue: String) {
        courseEditingQueue.sync {
            if let oldTitle = course.subjectTitle, coursesByTitle[oldTitle] == course {
                coursesByTitle[oldTitle] = nil
            }
            course.subjectTitle = newValue
            coursesByTitle[newValue] = course
        }
    }
    
    func getCourse(withID subjectID: String) -> Course? {
        if let course = self.coursesByID[subjectID] {
            return course
        }
        return nil
    }
    
    func getCourse(withTitle subjectTitle: String) -> Course? {
        if subjectTitle.count == 0 {
            return nil
        }
        if let course = self.coursesByTitle[subjectTitle] {
            return course
        }
        return nil
    }
    
    func addCourse(_ course: Course) {
        courseEditingQueue.sync {
            guard let processedID = course.subjectID else {
                print("Tried to add course \(course) with no ID")
                return
            }
            coursesByID[processedID] = course
            if let title = course.subjectTitle {
                coursesByTitle[title] = course
            }
            courses.append(course)
        }
    }
    
    func addCourse(withID subjectID: String, title: String, units: Int) {
        let newCourse = Course()
        newCourse.subjectID = subjectID
        newCourse.subjectTitle = title
        newCourse.totalUnits = units
        addCourse(newCourse)
    }
    
    func color(forCourse course: Course) -> UIColor {
        if course.subjectCode != nil {
            if let color = CourseManager.colorMapping[course.subjectCode!] {
                return color
            }
        }
        if let id = course.subjectID,
            let color = CourseManager.colorMapping[id] {
            return color
        }
        return UIColor.lightGray
    }
    
    // MARK: - Centralized Recents List
    
    let recentlyViewedCoursesDefaultsKey = "RecentlyViewedCourses"
    
    var _recentlyViewedCourses: [Course]?
    private(set) var recentlyViewedCourses: [Course] {
        get {
            if _recentlyViewedCourses == nil {
                _recentlyViewedCourses = (UserDefaults.standard.array(forKey: recentlyViewedCoursesDefaultsKey) as? [String])?.flatMap({
                    getCourse(withID: $0)
                }) ?? []
                _recentlyViewedCourses = [Course](_recentlyViewedCourses![0..<min(_recentlyViewedCourses!.count, 15)])
            }
            return _recentlyViewedCourses!
        } set {
            _recentlyViewedCourses = [Course](newValue[0..<min(newValue.count, 15)])
            UserDefaults.standard.set(_recentlyViewedCourses?.flatMap({ $0.subjectID }), forKey: recentlyViewedCoursesDefaultsKey)
        }
    }
    
    func markCourseAsRecentlyViewed(_ course: Course) {
        if let index = recentlyViewedCourses.index(of: course) {
            recentlyViewedCourses.remove(at: index)
        }
        recentlyViewedCourses.insert(course, at: 0)
    }
    
    func removeCourseFromRecentlyViewed(_ course: Course) {
        if let index = recentlyViewedCourses.index(of: course) {
            recentlyViewedCourses.remove(at: index)
        }
    }
    
    // MARK: - Favorites List
    
    let favoriteCoursesDefaultsKey = "FavoriteCourses"
    
    var _favoriteCourses: [Course]?
    private(set) var favoriteCourses: [Course] {
        get {
            if _favoriteCourses == nil {
                _favoriteCourses = (UserDefaults.standard.array(forKey: favoriteCoursesDefaultsKey) as? [String])?.flatMap({
                    getCourse(withID: $0)
                }) ?? []
            }
            return _favoriteCourses!
        } set {
            _favoriteCourses = newValue
            UserDefaults.standard.set(_favoriteCourses?.flatMap({ $0.subjectID }), forKey: favoriteCoursesDefaultsKey)
        }
    }
    
    func markCourseAsFavorite(_ course: Course) {
        if favoriteCourses.index(of: course) != nil {
            return
        }
        favoriteCourses.append(course)
    }
    
    func markCourseAsNotFavorite(_ course: Course) {
        if let index = favoriteCourses.index(where: { $0.subjectID == course.subjectID }) {
            favoriteCourses.remove(at: index)
        }
    }
    
    // MARK: - Course Notes
    
    private let subjectNotesKey = "CourseManager.subjectNotes"
    
    /// Dictionary keyed by subject IDs and whose values are the notes for the subject.
    private var notesCache: [String: String] = [:]
    
    func notes(for subject: String) -> String? {
        if notesCache.count == 0 {
            loadNotesCache()
        }
        return notesCache[subject]
    }
    
    func setNotes(_ notesString: String, for subject: String) {
        notesCache[subject] = notesString
        saveNotes()
    }
    
    func loadNotesCache() {
        notesCache = (UserDefaults.standard.dictionary(forKey: subjectNotesKey) as? [String: String]) ?? [:]
    }
    
    func saveNotes() {
        UserDefaults.standard.set(notesCache, forKey: subjectNotesKey)
    }
    
    // MARK: - Spotlight
    
    static let spotlightDomainIdentifier = (Bundle.main.bundleIdentifier ?? "FireRoadNoBundleID") + ".course"
    
    var indexedDepartments: [String] = []
    
    private func indexSearchableItems(for department: String? = nil) {
        var allItems: [CSSearchableItem] = []
        let separatorSet = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        for course in courses {
            guard let id = course.subjectID, let title = course.subjectTitle else {
                continue
            }
            guard department == nil || course.subjectCode == department else {
                continue
            }
            let attributeSet = CSSearchableItemAttributeSet()
            attributeSet.title = id + " – " + title
            
            let infoItems: [String] = [course.girAttribute?.rawValue, course.hassAttribute?.rawValue, course.communicationRequirement?.rawValue].flatMap({ $0 }).filter({ $0.count > 0 })
            var infoString = infoItems.joined(separator: ", ")
            if course.instructors.count > 0 {
                infoString += "\nTaught by \(course.instructors.joined(separator: ", "))"
            }
            attributeSet.contentDescription = infoString
            
            attributeSet.keywords = [id] + [title, infoString].joined(separator: "\n").components(separatedBy: separatorSet).filter { (word) -> Bool in
                ((word.count >= 4) || word == id) && word != "Taught"
                
                } as [String]
            let item = CSSearchableItem(uniqueIdentifier: CourseManager.spotlightDomainIdentifier + "." + id, domainIdentifier: CourseManager.spotlightDomainIdentifier, attributeSet: attributeSet)
            allItems.append(item)
        }
        
        CSSearchableIndex.default().indexSearchableItems(allItems) { (error) -> Void in
            if error != nil {
                print("An error occurred: \(String(describing: error))")
            } else if let dept = department {
                self.indexedDepartments.append(dept)
            }
        }
    }
    
    func indexSearchableItemsInBackground() {
        /*DispatchQueue.global(qos: .utility).async {
            self.indexSearchableItems()
        }*/
    }
    
    func indexSearchableItems(forDepartment department: String) {
        guard !indexedDepartments.contains(department) else {
            return
        }
        /*DispatchQueue.global(qos: .utility).async {
            self.indexSearchableItems(for: department)
        }*/
    }
}
