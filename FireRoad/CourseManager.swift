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
    
    /**
     - Parameter name: The name of the resource, minus the path extension (assumed
        .txt).
     */
    func pathForCatalogResource(named name: String) -> String? {
        guard let catalogSemester = catalogSemester,
            let base = directory(forSemester: catalogSemester) else {
            return nil
        }
        return URL(fileURLWithPath: base).appendingPathComponent(name + ".txt").path
    }
    
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
        let baseValues: [(s: CGFloat, v: CGFloat)] = [
            (0.7, 0.87),
            (0.52, 0.71),
            (0.88, 0.71)
        ]
        let directive: [String: (h: CGFloat, base: Int)] = [
            "1": (0.0, 0), "2": (20.0, 0),
            "3": (225.0, 0), "4": (128.0, 1),
            "5": (162.0, 0), "6": (210.0, 0),
            "7": (218.0, 2), "8": (267.0, 2),
            "9": (264.0, 0), "10": (0.0, 2),
            "11": (342.0, 1), "12": (125.0, 0),
            "14": (30.0, 0), "15": (3.0, 1),
            "16": (197.0, 0), "17": (315.0, 0),
            "18": (236.0, 1), "20": (135.0, 2),
            "21": (130.0, 2), "21A": (138.0, 2),
            "21W": (146.0, 2), "CMS": (154.0, 2),
            "21G": (162.0, 2), "21H": (170.0, 2),
            "21L": (178.0, 2), "21M": (186.0, 2),
            "WGS": (194.0, 2), "22": (0.0, 1),
            "24": (260.0, 1), "CC": (115.0, 0),
            "CSB": (197.0, 2), "EC": (100.0, 1),
            "EM": (225.0, 1), "ES": (242.0, 1),
            "HST": (218.0, 1), "IDS": (150.0, 1),
            "MAS": (122.0, 2), "SCM": (138.0, 1),
            "STS": (276.0, 2), "SWE": (13.0, 2),
            "SP": (240.0, 0)
        ]
        var ret = directive.mapValues({ UIColor(hue: $0.h / 360.0, saturation: baseValues[$0.base].s, brightness: baseValues[$0.base].v, alpha: 1.0) })
        let saturation = CGFloat(0.7)
        let brightness = CGFloat(0.87)
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
    
    func loadCourses(completion: ((Bool) -> Void)? = nil) {
        
        DispatchQueue.global(qos: .background).async {
            self.courses = []
            self.coursesByID = [:]
            self.coursesByTitle = [:]
            self.loadedDepartments = []
            
            self.dispatch(jobs: [Int](0..<4).map({ num -> DispatchJob in
                return { [weak self] (taskCompletion) in
                    guard let path = self?.pathForCatalogResource(named: "condensed_\(num)") else {
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
                    completion?(false)
                    return
                }
                
                let relatedBlock: DispatchJob = { [weak self] taskCompletion in
                    self?.loadRelatedCourses(taskCompletion: taskCompletion)
                }
                
                self.dispatch(jobs: [relatedBlock], completion: { (success) in
                    self.isLoaded = success
                    if success {
                        NotificationCenter.default.post(name: .CourseManagerFinishedLoading, object: self)
                    }
                    completion?(success)
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
        guard let text = try? String(contentsOfFile: path),
            text.range(of: "<html") == nil else {
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
        guard let enrollPath = self.pathForCatalogResource(named: "enrollment"),
            let text = try? String(contentsOfFile: enrollPath),
            text.range(of: "<html") == nil else {
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
        guard let relatedPath = self.pathForCatalogResource(named: "related"),
            let text = try? String(contentsOfFile: relatedPath),
            text.range(of: "<html") == nil else {
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
    
    func loadCourseDetailsSynchronously(for department: String) {
        if self.loadedDepartments.contains(department) {
            return
        }
        guard let path = self.pathForCatalogResource(named: department) else {
            print("Failed to load details for \(department)")
            return
        }
        self.readSummaryFile(at: path)
        self.loadedDepartments.append(department)
    }
    
    func loadCourseDetailsSynchronously(about course: Course) {
        if self.getCourse(withID: course.subjectID!) == nil {
            return
        }
        if self.loadedDepartments.contains(course.subjectCode!) {
            return
        }
        guard let path = self.pathForCatalogResource(named: course.subjectCode!) else {
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
        guard let path = self.pathForCatalogResource(named: course.subjectCode!) else {
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
    
    func getCourses(forDepartment department: String) -> [Course] {
        return courses.filter({ $0.subjectCode == department }).sorted(by: { $0.subjectID!.lexicographicallyPrecedes($1.subjectID!) })
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
    
    func color(forCourse course: Course, variantNumber: Int = 0) -> UIColor {
        var ret: UIColor?
        if course.subjectCode != nil {
            if let color = CourseManager.colorMapping[course.subjectCode!] {
                ret = color
            }
        }
        if let id = course.subjectID,
            Int(id) == nil,
            let color = CourseManager.colorMapping[id] {
            ret = color
        }
        
        if let color = ret {
            if variantNumber != 0 {
                /* Variants:
                 1 - higher hue, higher saturation, lower brightness
                 2 - lower hue, lower saturation, lower brightness
                 3 - higher saturation
                 4 - higher brightness
                 */
                var h: CGFloat = 0.0
                var s: CGFloat = 0.0
                var b: CGFloat = 0.0
                let delta: CGFloat = 0.15
                color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
                switch variantNumber % 5 {
                case 1:
                    h += delta / 2.0
                    s += delta
                    b -= delta
                case 2:
                    h -= delta / 2.0
                    s -= delta
                    b -= delta
                case 3:
                    s += delta
                case 4:
                    b += delta
                default:
                    break
                }
                return UIColor(hue: h, saturation: s, brightness: b, alpha: 1.0)
            }
            return color
        }
        
        return UIColor.lightGray
    }
    
    func color(forDepartment department: String) -> UIColor {
        return CourseManager.colorMapping[department] ?? UIColor.lightGray
    }
    
    // MARK: - Departments
    
    private var _departments: [(code: String, description: String, shortName: String)] = []
    var departments: [(code: String, description: String, shortName: String)] {
        get {
            if _departments.count == 0 {
                loadDepartments()
            }
            return _departments
        } set {
            _departments = newValue
            _departmentsByCode = [:]
            for (code, desc, short) in _departments {
                _departmentsByCode[code] = (desc, short)
            }
        }
    }
    
    private var _departmentsByCode: [String: (String, String)] = [:]
    private var departmentsByCode: [String: (String, String)] {
        get {
            if _departmentsByCode.count == 0 {
                loadDepartments()
            }
            return _departmentsByCode
        } set {
            _departmentsByCode = newValue
        }
    }
    
    func loadDepartments() {
        guard let filePath = self.pathForCatalogResource(named: "departments"),
            let contents = try? String(contentsOfFile: filePath) else {
                print("Couldn't load departments")
                return
        }
        let comps = contents.components(separatedBy: .newlines)
        departments = comps.flatMap {
            let subcomps = $0.components(separatedBy: "#,#")
            guard subcomps.count == 3 else {
                return nil
            }
            return (subcomps[0], subcomps[1], subcomps[2])
        }
    }
    
    func departmentName(for code: String) -> String? {
        return departmentsByCode[code]?.0
    }

    func shortDepartmentName(for code: String) -> String? {
        return departmentsByCode[code]?.1
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
        if userRatings[course.subjectID!] == nil {
            setUserRatings([course.subjectID!: SubjectRating.baselineFavorites], autoGenerated: true)
        }
    }
    
    func markCourseAsNotFavorite(_ course: Course) {
        if let index = favoriteCourses.index(where: { $0.subjectID == course.subjectID }) {
            favoriteCourses.remove(at: index)
            if userRatings[course.subjectID!] == nil {
                setUserRatings([course.subjectID!: SubjectRating.none], autoGenerated: true)
            }
        }
    }
    
    // MARK: - Ratings

    static let userIDDefaultsKey = "CourseManager.userID"
    static let userRatingsDefaultsKey = "CourseManager.userRatings"
    static let allSubjectRatingsDefaultsKey = "CourseManager.allSubjectRatings"

    private var _recommenderUserID: Int?
    var recommenderUserID: Int? {
        get {
            if _recommenderUserID == nil {
                _recommenderUserID = UserDefaults.standard.integer(forKey: CourseManager.userIDDefaultsKey)
            }
            if _recommenderUserID == 0 {
                _recommenderUserID = nil
            }
            return _recommenderUserID
        } set {
            _recommenderUserID = newValue
            UserDefaults.standard.set(_recommenderUserID, forKey: CourseManager.userIDDefaultsKey)
        }
    }
    
    private var _allSubjectRatings: [String: Int] = [:]
    private(set) var allSubjectRatings: [String: Int] {
        get {
            if _allSubjectRatings.count == 0 {
                _allSubjectRatings = (UserDefaults.standard.dictionary(forKey: CourseManager.allSubjectRatingsDefaultsKey) as? [String: Int]) ?? [:]
            }
            return _allSubjectRatings
        } set {
            _allSubjectRatings = newValue
            UserDefaults.standard.set(_allSubjectRatings, forKey: CourseManager.allSubjectRatingsDefaultsKey)
        }
    }
    
    private var _userRatings: [String: Int] = [:]
    private(set) var userRatings: [String: Int] {
        get {
            if _userRatings.count == 0 {
                _userRatings = (UserDefaults.standard.dictionary(forKey: CourseManager.userRatingsDefaultsKey) as? [String: Int]) ?? [:]
            }
            return _userRatings
        } set {
            _userRatings = newValue
            UserDefaults.standard.set(_userRatings, forKey: CourseManager.userRatingsDefaultsKey)
        }
    }
    
    func setUserRatings(_ newRatings: [String: Int], autoGenerated: Bool) {
        for (course, rating) in newRatings {
            if !autoGenerated {
                userRatings[course] = rating
            }
            allSubjectRatings[course] = rating
        }
        
        submitUserRatings(ratings: newRatings)
    }
    
    static let recommenderVerifyURL = "https://venkats.scripts.mit.edu/fireroad/recommend/verify"
    static let recommenderNewUserURL = "https://venkats.scripts.mit.edu/fireroad/recommend/new_user"
    static let recommenderSubmitURL = "https://venkats.scripts.mit.edu/fireroad/recommend/rate/"
    static let recommenderSignupURL = "https://venkats.scripts.mit.edu/fireroad/recommend/signup/"
    static let recommenderFetchURL = "https://venkats.scripts.mit.edu/fireroad/recommend/get/"

    private func verifyRecommender(completion: @escaping () -> Void) {
        guard AppSettings.shared.allowsRecommendations == true,
            let userID = recommenderUserID,
            var comps = URLComponents(string: CourseManager.recommenderVerifyURL) else {
            return
        }
        comps.queryItems = [URLQueryItem(name: "u", value: "\(userID)")]
        guard let url = comps.url else {
            print("Couldn't get URL")
            return
        }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 10.0)
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard error == nil,
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 else {
                    print("Error retrieving data updates")
                    if error != nil {
                        print("\(error!)")
                    }
                    completion()
                    return
            }
            if let responseURL = httpResponse.url, let headers = httpResponse.allHeaderFields as? [String: String] {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: responseURL)
                HTTPCookieStorage.shared.setCookies(cookies, for: responseURL, mainDocumentURL: nil)
            }
            if let receivedData = data,
                let text = String(data: receivedData, encoding: .utf8),
                let numRatings = Int(text),
                numRatings != self.allSubjectRatings.count {
                self.submitUserRatings(ratings: self.allSubjectRatings)
            }
            completion()
        }
        task.resume()
    }
    
    func getRecommenderUserID(completion: @escaping (Int?) -> Void) {
        guard let url = URL(string: CourseManager.recommenderNewUserURL) else {
            return
        }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 10.0)
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard error == nil, let receivedData = data,
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 else {
                    print("Error retrieving data updates")
                    if error != nil {
                        print("\(error!)")
                    }
                    completion(nil)
                    return
            }
            do {
                guard let result = (try JSONSerialization.jsonObject(with: receivedData, options: [])) as? [String: Int],
                    let id = result["u"] else {
                        return
                }
                completion(id)
            } catch {
                print("Error decoding JSON: \(error)")
            }
        }
        task.resume()
    }
    
    func generateRandomPassword() -> String {
        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-+"
        let len = UInt32(letters.length)
        
        var randomString = ""
        
        for _ in 0..<20 {
            let rand = arc4random_uniform(len)
            var nextChar = letters.character(at: Int(rand))
            randomString += NSString(characters: &nextChar, length: 1) as String
        }
        
        return randomString
    }
    
    func savePassword(_ password: String) {
        let keychain = KeychainItemWrapper(identifier: "FireRoadRecommendationUser", accessGroup: nil)
        keychain["password"] = password as AnyObject?
    }
    
    func loadPassword() -> String? {
        let keychain = KeychainItemWrapper(identifier: "FireRoadRecommendationUser", accessGroup: nil)
        return keychain["password"] as? String
    }
    
    private var userRatingsToSubmit: [String: Int]?
    
    func submitUserRatingsImmediately(ratings: [String: Int], completion: ((Bool) -> Void)? = nil, tryOnce: Bool = false) {
        guard AppSettings.shared.allowsRecommendations == true, ratings.count > 0,
            let url = URL(string: CourseManager.recommenderSubmitURL) else {
            return
        }
        guard let userID = recommenderUserID else {
            getRecommenderUserID { newID in
                if let id = newID {
                    self.recommenderUserID = id
                    self.submitUserRatings(ratings: ratings, completion: completion)
                } else {
                    completion?(false)
                }
            }
            return
        }
        
        let parameters: [[String: Any]] = ratings.map {
            ["u": userID,
             "s": $0.key,
             "v": $0.value]
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print(error.localizedDescription)
        }
        
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        applyBasicAuthentication(to: &request)

        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) in
            guard error == nil, data != nil,
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 else {
                    print("Error retrieving data updates")
                    if error != nil {
                        print("\(error!)")
                    }
                    completion?(false)
                    return
            }
            completion?(true)
        })
        task.resume()
    }
    
    func submitUserRatings(ratings: [String: Int], completion: ((Bool) -> Void)? = nil, tryOnce: Bool = false) {
        guard AppSettings.shared.allowsRecommendations == true, ratings.count > 0 else {
            return
        }
        if userRatingsToSubmit != nil {
            userRatingsToSubmit?.merge(ratings, uniquingKeysWith: { $1 })
        } else {
            userRatingsToSubmit = ratings
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5, execute: {
                guard let toSubmit = self.userRatingsToSubmit else {
                    return
                }
                self.userRatingsToSubmit = nil
                self.submitUserRatingsImmediately(ratings: toSubmit, completion: completion, tryOnce: tryOnce)
            })
        }
    }
    
    func applyBasicAuthentication(to request: inout URLRequest) {
        let username = "\(recommenderUserID ?? 0)"
        guard let password = loadPassword() else {
            print("No password")
            return
        }
        let loginString = "\(username):\(password)"
        guard let loginData = loginString.data(using: .utf8) else {
            return
        }
        let base64LoginString = loginData.base64EncodedString()
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
    }
    
    var subjectRecommendations: [String: [Course: Float]]?
    
    var isLoadingSubjectRecommendations = false
    
    func fetchSubjectRecommendations(completion: (([String: [Course: Float]]?, String?) -> Void)?) {
        guard AppSettings.shared.allowsRecommendations == true, let userID = recommenderUserID, isLoaded else {
            completion?(nil, nil)
            return
        }
        guard var comps = URLComponents(string: CourseManager.recommenderFetchURL) else {
            return
        }
        comps.queryItems = [URLQueryItem(name: "u", value: "\(userID)")]
        guard let url = comps.url else {
            print("Couldn't get URL")
            return
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 10.0)
        applyBasicAuthentication(to: &request)
        isLoadingSubjectRecommendations = true
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            self.isLoadingSubjectRecommendations = false
            guard error == nil, let receivedData = data,
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 else {
                    print("Error retrieving data updates")
                    if error != nil {
                        print("\(error!)")
                    }
                    completion?(nil, nil)
                    return
            }
            do {
                let deserialized = try JSONSerialization.jsonObject(with: receivedData)
                guard let lists = deserialized as? [String: [String: Float]] else {
                    return
                }
                var recs: [String: [Course: Float]] = [:]
                for (key, dict) in lists {
                    recs[key] = [:]
                    for (subject, value) in dict {
                        guard let course = self.getCourse(withID: subject) else {
                            continue
                        }
                        recs[key]?[course] = value
                    }
                }
                self.subjectRecommendations = recs
                completion?(recs, nil)
            } catch {
                if let message = String(data: receivedData, encoding: .utf8), message.count > 0 {
                    completion?(nil, message)
                } else {
                    print("Error decoding JSON: \(error)")
                    completion?(nil, nil)
                }
            }
        }
        task.resume()
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
    
    // MARK: - Catalog Version Management
    
    enum SemesterSeason {
        static let fall = "fall"
        static let spring = "spring"
    }
    struct Semester: Equatable {
        var season: String
        var year: Int
        
        init(season: String, year: Int) {
            self.season = season
            self.year = year
        }
        
        init(path: String) {
            let comps = path.components(separatedBy: "-")
            self.season = comps[0]
            self.year = Int(comps[1])!
        }
        
        var stringValue: String {
            return season + "," + "\(year)"
        }
        
        var pathValue: String {
            return season + "-" + "\(year)"
        }
        
        static func ==(lhs: CourseManager.Semester, rhs: CourseManager.Semester) -> Bool {
            return lhs.season.lowercased() == rhs.season.lowercased() && lhs.year == rhs.year
        }
    }
    
    private static let catalogVersionDefaultsKey = "CourseManager.catalogVersion"
    private static let catalogSemesterDefaultsKey = "CourseManager.catalogSemester"
    private static let availableCatalogSemestersDefaultsKey = "CourseManager.availableCatalogSemesters"

    private var _catalogSemester: Semester?
    var catalogSemester: Semester? {
        get {
            if _catalogSemester == nil,
                let defaultValue = UserDefaults.standard.string(forKey: CourseManager.catalogSemesterDefaultsKey) {
                _catalogSemester = Semester(path: defaultValue)
            }
            return _catalogSemester
        } set {
            _catalogSemester = newValue
            UserDefaults.standard.set(_catalogSemester?.pathValue, forKey: CourseManager.catalogSemesterDefaultsKey)
        }
    }
    
    func directory(forSemester semester: Semester) -> String? {
        guard let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            return nil
        }
        return URL(fileURLWithPath: documents).appendingPathComponent(semester.pathValue).path
    }
    
    func catalogVersion(for semester: Semester) -> Int {
        return UserDefaults.standard.integer(forKey: CourseManager.catalogVersionDefaultsKey + ":" + semester.stringValue)
    }
    
    func setCatalogVersion(_ version: Int, for semester: Semester) {
        UserDefaults.standard.set(version, forKey: CourseManager.catalogVersionDefaultsKey + ":" + semester.stringValue)
    }
    
    private var _availableCatalogSemesters: [Semester] = []
    var availableCatalogSemesters: [Semester] {
        get {
            if _availableCatalogSemesters.count == 0,
                let defaultValue = UserDefaults.standard.stringArray(forKey: CourseManager.availableCatalogSemestersDefaultsKey) {
                _availableCatalogSemesters = defaultValue.map({ Semester(path: $0) })
            }
            return _availableCatalogSemesters
        } set {
            _availableCatalogSemesters = newValue
            UserDefaults.standard.set(_availableCatalogSemesters.map({ $0.pathValue }), forKey: CourseManager.availableCatalogSemestersDefaultsKey)
        }
    }

    // MARK: - Updating Course Database
    
    private let semesterUpdateURL = "http://venkats.scripts.mit.edu/fireroad/courseupdater/semesters/"
    private let baseUpdateURL = "http://venkats.scripts.mit.edu/fireroad/courseupdater/check/"
    private let baseStaticURL = "http://venkats.scripts.mit.edu/catalogs/"

    enum CatalogUpdateState {
        case newVersionAvailable
        case noUpdatesAvailable
        case downloading
        case completed
        case error
    }
    
    typealias CatalogUpdateResultBlock = ((CatalogUpdateState, Float?, Error?, Int?) -> Void)
    
    func checkForCatalogSemesterUpdates(withResult resultBlock: CatalogUpdateResultBlock?) {
        clearTemporaryDownloads()
        guard let url = URL(string: semesterUpdateURL) else {
            return
        }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 10.0)
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard error == nil, let receivedData = data,
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 else {
                    print("Error retrieving data updates")
                    if error != nil {
                        print("\(error!)")
                    }
                    resultBlock?(.error, nil, error, (response as? HTTPURLResponse)?.statusCode)
                    return
            }
            do {
                guard let semesters = (try JSONSerialization.jsonObject(with: receivedData, options: [])) as? [[String: Any]] else {
                    return
                }
                var newSemesters: [Semester] = []
                for sem in semesters {
                    guard let semPath = sem["sem"] as? String else {
                        print("Invalid semester format: \(sem)")
                        continue
                    }
                    newSemesters.append(Semester(path: semPath))
                }
                self.availableCatalogSemesters = newSemesters
                resultBlock?(.completed, nil, nil, nil)
            } catch {
                print("Error decoding JSON: \(error)")
            }
        }
        task.resume()
    }
    
    func checkForCourseCatalogUpdates(withResult resultBlock: CatalogUpdateResultBlock?) {
        clearTemporaryDownloads()
        guard let catalogSemester = catalogSemester else {
            print("No catalog semester set! Did you check for semester updates first?")
            return
        }
        guard var comps = URLComponents(string: baseUpdateURL) else {
            return
        }
        let catalogVersion = self.catalogVersion(for: catalogSemester)
        comps.queryItems = [
            URLQueryItem(name: "sem", value: catalogSemester.stringValue),
            URLQueryItem(name: "v", value: "\(catalogVersion)"),
            URLQueryItem(name: "rv", value: "\(RequirementsListManager.shared.requirementsVersion)")
        ]
        guard let url = comps.url else {
            print("Couldn't get URL")
            return
        }
        let errorBlock: (Error?, Int?) -> Void = { (error, code) in
            resultBlock?(.error, nil, error, code)
        }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 10.0)
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard error == nil, let receivedData = data,
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 else {
                print("Error retrieving data updates")
                if error != nil {
                    print("\(error!)")
                }
                return
            }
            do {
                if let dict = (try JSONSerialization.jsonObject(with: receivedData, options: [])) as? [String: Any],
                    let newVersion = dict["v"] as? Int,
                    let updateFiles = dict["delta"] as? [String] {
                    
                    if updateFiles.count > 0 {
                        resultBlock?(.newVersionAvailable, nil, nil, nil)
                        let updateReqVersion = dict["rv"] as? Int
                        let updateReqFiles = dict["r_delta"] as? [String]

                        self.updateCourseCatalog(with: updateFiles, newVersion: newVersion, updaterBlock: { (progress) in
                            let overallProg = progress * Float(updateFiles.count) / Float(updateFiles.count + (updateReqFiles?.count ?? 0))
                            if overallProg > 1.0 - 0.0001 {
                                resultBlock?(.completed, overallProg, nil, nil)
                            } else {
                                resultBlock?(.downloading, overallProg, nil, nil)
                            }
                        }, errorBlock: errorBlock, completion: {
                            guard let reqVersion = updateReqVersion,
                                let reqFiles = updateReqFiles else {
                                return
                            }
                            self.updateRequirementsCatalog(with: reqFiles, newVersion: reqVersion, updaterBlock: { (progress) in
                                let overallProg = (Float(updateFiles.count) + progress * Float(reqFiles.count)) / Float(updateFiles.count + reqFiles.count)
                                if overallProg > 1.0 - 0.0001 {
                                    resultBlock?(.completed, overallProg, nil, nil)
                                } else {
                                    resultBlock?(.downloading, overallProg, nil, nil)
                                }
                            }, errorBlock: errorBlock)
                        })
                    } else if let reqVersion = dict["rv"] as? Int,
                        let reqFiles = dict["r_delta"] as? [String],
                        reqFiles.count > 0 {
                        resultBlock?(.newVersionAvailable, nil, nil, nil)
                        self.updateRequirementsCatalog(with: reqFiles, newVersion: reqVersion, updaterBlock: { (progress) in
                            if progress > 1.0 - 0.0001 {
                                resultBlock?(.completed, progress, nil, nil)
                            } else {
                                resultBlock?(.downloading, progress, nil, nil)
                            }
                        }, errorBlock: errorBlock)
                    }
                } else {
                    resultBlock?(.noUpdatesAvailable, nil, nil, nil)
                }
            } catch {
                print("Error decoding JSON: \(error)")
            }
        }
        task.resume()
    }
    
    var temporaryDownloadDirectory: String? {
        guard let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            return nil
        }
        let path = URL(fileURLWithPath: docs).appendingPathComponent("temp_dl").path
        if !FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
        }
        return path
    }
    
    func clearTemporaryDownloads() {
        guard let temp = temporaryDownloadDirectory else {
            return
        }
        do {
            try FileManager.default.removeItem(atPath: temp)
        } catch {
            print("Couldn't clear temporary downloads: \(error)")
        }
    }
    
    private func updateCourseCatalog(with updateFiles: [String], newVersion: Int, updaterBlock: ((Float) -> Void)? = nil, errorBlock: ((Error?, Int?) -> Void)? = nil, completion: (() -> Void)? = nil) {
        guard let semester = self.catalogSemester,
            let dest = self.directory(forSemester: semester) else {
            print("Couldn't get destination")
            return
        }
        let destURL = URL(fileURLWithPath: dest)
        self.updateCatalogFiles(with: updateFiles, destinationDirectory: destURL, updaterBlock: { progress in
            if progress == 1.0 {
                self.setCatalogVersion(newVersion, for: semester)
                completion?()
            }
            updaterBlock?(progress)
        }, errorBlock: errorBlock)
    }
    
    private func updateRequirementsCatalog(with updateFiles: [String], newVersion: Int, updaterBlock: ((Float) -> Void)? = nil, errorBlock: ((Error?, Int?) -> Void)? = nil, completion: (() -> Void)? = nil) {
        guard let semester = self.catalogSemester,
            let dest = self.directory(forSemester: semester) else {
            print("Couldn't get destination")
            return
        }
        let destURL = URL(fileURLWithPath: dest).deletingLastPathComponent().appendingPathComponent(RequirementsDirectoryName)
        self.updateCatalogFiles(with: updateFiles, destinationDirectory: destURL, updaterBlock: { reqProgress in
            if reqProgress == 1.0 {
                RequirementsListManager.shared.requirementsVersion = newVersion
                completion?()
            }
            updaterBlock?(reqProgress)
        }, errorBlock: errorBlock)
    }
    
    private func updateCatalogFiles(with fileNames: [String], destinationDirectory: URL, downloadIndex: Int = 0, updaterBlock: ((Float) -> Void)? = nil, errorBlock: ((Error?, Int?) -> Void)? = nil) {
        guard let url = URL(string: baseStaticURL) else {
            return
        }
        guard let temp = temporaryDownloadDirectory else {
            return
        }
        let tempDestination = URL(fileURLWithPath: temp)
        if fileNames.count <= downloadIndex {
            do {
                if FileManager.default.fileExists(atPath: destinationDirectory.path) {
                    for content in try FileManager.default.contentsOfDirectory(atPath: tempDestination.path) {
                        let oldPath = tempDestination.appendingPathComponent(content)
                        let newPath = destinationDirectory.appendingPathComponent(content)
                        if FileManager.default.fileExists(atPath: newPath.path) {
                            _ = try FileManager.default.replaceItemAt(newPath, withItemAt: oldPath)
                        } else {
                            try FileManager.default.moveItem(at: oldPath, to: newPath)
                        }
                    }
                } else {
                    try FileManager.default.moveItem(at: tempDestination, to: destinationDirectory)
                }
                clearTemporaryDownloads()
                updaterBlock?(1.0)
            } catch {
                errorBlock?(error, nil)
            }
            return
        } else {
            let currentFile = fileNames[downloadIndex]
            let request = URLRequest(url: url.appendingPathComponent(currentFile), cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 5.0)
            let task = URLSession.shared.downloadTask(with: request, completionHandler: { (downloadURL, response, error) in
                guard error == nil,
                    let httpResponse = response as? HTTPURLResponse,
                    httpResponse.statusCode == 200 else {
                    if error != nil {
                        print("Error retrieving file: \(error!)")
                    } else if let response = response {
                        print("Error in response: \(response)")
                    }
                    errorBlock?(error, (response as? HTTPURLResponse)?.statusCode)
                    return
                }
                guard let url = downloadURL else {
                    print("No download URL given")
                    return
                }
                do {
                    try FileManager.default.moveItem(at: url, to: tempDestination.appendingPathComponent((currentFile as NSString).lastPathComponent))
                    updaterBlock?(Float(downloadIndex + 1) / Float(fileNames.count + 1))
                    self.updateCatalogFiles(with: fileNames, destinationDirectory: destinationDirectory, downloadIndex: downloadIndex + 1, updaterBlock: updaterBlock, errorBlock: errorBlock)
                } catch {
                    print("Error moving file: \(error)")
                    errorBlock?(error, nil)
                }
            })
            task.resume()
        }
    }
}
