//
//  CourseSearchEngine.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/15/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import UIKit

struct SearchOptions: OptionSet {
    var rawValue: Int
    
    static let noGIRFilter = SearchOptions(rawValue: 1 << 0)
    static let fulfillsGIR = SearchOptions(rawValue: 1 << 1)
    static let fulfillsLabGIR = SearchOptions(rawValue: 1 << 2)
    static let fulfillsRestGIR = SearchOptions(rawValue: 1 << 3)
    private static let allGIRFilters: SearchOptions = [.noGIRFilter, .fulfillsGIR, .fulfillsLabGIR, .fulfillsRestGIR]
    
    static let noHASSFilter = SearchOptions(rawValue: 1 << 4)
    static let fulfillsHASS = SearchOptions(rawValue: 1 << 5)
    static let fulfillsHASSA = SearchOptions(rawValue: 1 << 6)
    static let fulfillsHASSS = SearchOptions(rawValue: 1 << 7)
    static let fulfillsHASSH = SearchOptions(rawValue: 1 << 8)
    private static let allHASSFilters: SearchOptions = [.noHASSFilter, .fulfillsHASS, .fulfillsHASSA, .fulfillsHASSS, .fulfillsHASSH]

    static let noCIFilter = SearchOptions(rawValue: 1 << 9)
    static let fulfillsCIH = SearchOptions(rawValue: 1 << 10)
    static let fulfillsCIHW = SearchOptions(rawValue: 1 << 11)
    static let notCI = SearchOptions(rawValue: 1 << 12)
    private static let allCIFilters: SearchOptions = [.noCIFilter, .fulfillsCIH, .fulfillsCIHW, .notCI]

    static let offeredAnySemester = SearchOptions(rawValue: 1 << 13)
    static let offeredFall = SearchOptions(rawValue: 1 << 14)
    static let offeredSpring = SearchOptions(rawValue: 1 << 15)
    static let offeredIAP = SearchOptions(rawValue: 1 << 16)
    private static let allOfferedFilters: SearchOptions = [.offeredAnySemester, .offeredFall, .offeredSpring, .offeredIAP]
    
    static let noLevelFilter = SearchOptions(rawValue: 1 << 27)
    static let undergradOnly = SearchOptions(rawValue: 1 << 28)
    static let graduateOnly = SearchOptions(rawValue: 1 << 29)
    private static let allLevelFilters: SearchOptions = [.noLevelFilter, .undergradOnly, .graduateOnly]

    static let containsSearchTerm = SearchOptions(rawValue: 1 << 17)
    static let matchesSearchTerm = SearchOptions(rawValue: 1 << 18)
    static let startsWithSearchTerm = SearchOptions(rawValue: 1 << 19)
    static let endsWithSearchTerm = SearchOptions(rawValue: 1 << 20)
    private static let allSearchTermFilters: SearchOptions = [.containsSearchTerm, .matchesSearchTerm, .startsWithSearchTerm, .endsWithSearchTerm]
    
    static let searchID = SearchOptions(rawValue: 1 << 21)
    static let searchTitle = SearchOptions(rawValue: 1 << 22)
    static let searchPrereqs = SearchOptions(rawValue: 1 << 23)
    static let searchCoreqs = SearchOptions(rawValue: 1 << 24)
    static let searchInstructors = SearchOptions(rawValue: 1 << 25)
    static let searchRequirements = SearchOptions(rawValue: 1 << 26)
    
    static let conflictsAllowed = SearchOptions(rawValue: 1 << 30)
    static let noLectureConflicts = SearchOptions(rawValue: 1 << 31)
    static let noConflicts = SearchOptions(rawValue: 1 << 32)
    
    static let sortByRelevance = SearchOptions(rawValue: 1 << 33)
    static let sortByRating = SearchOptions(rawValue: 1 << 34)
    static let sortByHours = SearchOptions(rawValue: 1 << 35)
    static let sortByNumber = SearchOptions(rawValue: 1 << 36)
    private static let allSortingFilters: SearchOptions = [.sortByRelevance, .sortByRating, .sortByHours, .sortByNumber]

    static let searchAllFields: SearchOptions = [
        .searchID,
        .searchTitle,
        .searchPrereqs,
        .searchCoreqs,
        .searchInstructors,
        .searchRequirements,
    ]
    
    static let noFilter: SearchOptions = [
        .noGIRFilter,
        .noHASSFilter,
        .noCIFilter,
        .noLevelFilter,
        .offeredAnySemester,
        .containsSearchTerm,
        .searchAllFields,
        .conflictsAllowed,
        .sortByRelevance
    ]
    
    var shouldAutoSearch: Bool {
        if contains(.noGIRFilter), contains(.noHASSFilter), contains(.noCIFilter) {
            return false
        }
        return true
    }
    
    var whichSort: String {
        if contains(.sortByRelevance) {
            return "Relevance"
        }
        else if contains(.sortByRating) {
            return "Rating"
        }
        else if contains(.sortByHours) {
            return "Hours"
        }
        else {
            return "Number"
        }
    }
    
    /// A broader criterion than shouldAutoSearch
    var containsCourseFilters: Bool {
        if union([.searchAllFields, .containsSearchTerm]).contains(.noFilter) {
            return false
        }
        return true
    }
    
    // Convenience functions to replace certain axes of filter options
    
    func replace(oldValue: SearchOptions, with newValue: SearchOptions) -> SearchOptions {
        var new = self
        new.remove(oldValue)
        new.formUnion(newValue)
        return new
    }
    
    func filterGIR(_ value: SearchOptions) -> SearchOptions {
        return replace(oldValue: .allGIRFilters, with: value)
    }
    
    func filterHASS(_ value: SearchOptions) -> SearchOptions {
        return replace(oldValue: .allHASSFilters, with: value)
    }

    func filterCI(_ value: SearchOptions) -> SearchOptions {
        return replace(oldValue: .allCIFilters, with: value)
    }

    func filterLevel(_ value: SearchOptions) -> SearchOptions {
        return replace(oldValue: .allLevelFilters, with: value)
    }
    
    func filterOffered(_ value: SearchOptions) -> SearchOptions {
        return replace(oldValue: .allOfferedFilters, with: value)
    }

    func filterSearchFields(_ value: SearchOptions) -> SearchOptions {
        return replace(oldValue: .searchAllFields, with: value)
    }
    
    func filterSort(_ value: SearchOptions) -> SearchOptions {
        return replace(oldValue: .allSortingFilters, with: value)
    }

}

class CourseSearchEngine: NSObject {
    
    var isSearching = false
    var shouldAbortSearch = false
    var showsGenericCourses = true
    
    var userSchedules: [Schedule]? {
        didSet {
            guard let scheds = userSchedules else {
                userScheduleMasks = nil
                return
            }
            userScheduleMasks = scheds.map { sched -> [ScheduleMask] in
                CourseScheduleDay.ordering.map {
                    ScheduleMask(scheduleItems: sched.scheduleItems.map({ $0.scheduleItems }).flatMap({ $0 }), day: $0)
                }
            }
        }
    }
    private var userScheduleMasks: [[ScheduleMask]]?
    
    private func courseSatisfiesSearchOptions(_ course: Course, searchTerm: String, options: SearchOptions) -> Bool {
        var fulfillsGIR = false
        if options.contains(.noGIRFilter) {
            fulfillsGIR = true
        } else if options.contains(.fulfillsGIR), course.girAttribute != nil {
            fulfillsGIR = true
        } else if options.contains(.fulfillsLabGIR), course.girAttribute == .lab {
            fulfillsGIR = true
        } else if options.contains(.fulfillsRestGIR), course.girAttribute == .rest {
            fulfillsGIR = true
        }
        
        var fulfillsHASS = false
        if options.contains(.noHASSFilter) {
            fulfillsHASS = true
        } else if options.contains(.fulfillsHASS), course.hassAttribute?.count != 0 {
            fulfillsHASS = true
        } else if options.contains(.fulfillsHASSA), course.hassAttribute?.contains(.arts) == true {
            fulfillsHASS = true
        } else if options.contains(.fulfillsHASSS), course.hassAttribute?.contains(.socialSciences) == true {
            fulfillsHASS = true
        } else if options.contains(.fulfillsHASSH), course.hassAttribute?.contains(.humanities) == true {
            fulfillsHASS = true
        }
        
        var fulfillsCI = false
        if options.contains(.noCIFilter) {
            fulfillsCI = true
        } else if options.contains(.fulfillsCIH), course.communicationRequirement == .ciH {
            fulfillsCI = true
        } else if options.contains(.notCI), course.communicationRequirement == nil {
            fulfillsCI = true
        } else if options.contains(.fulfillsCIHW), course.communicationRequirement == .ciHW {
            fulfillsCI = true
        }
        
        var fulfillsOffered = false
        if options.contains(.offeredAnySemester) {
            fulfillsOffered = true
        } else if options.contains(.offeredFall), course.isOfferedFall {
            fulfillsOffered = true
        } else if options.contains(.offeredSpring), course.isOfferedSpring {
            fulfillsOffered = true
        } else if options.contains(.offeredIAP), course.isOfferedIAP {
            fulfillsOffered = true
        }
        
        var fulfillsLevel = false
        if options.contains(.noLevelFilter) {
            fulfillsLevel = true
        } else if options.contains(.undergradOnly), course.subjectLevel == .undergraduate {
            fulfillsLevel = true
        } else if options.contains(.graduateOnly), course.subjectLevel == .graduate {
            fulfillsLevel = true
        }
        
        return fulfillsGIR && fulfillsHASS && fulfillsCI && fulfillsOffered && fulfillsLevel
    }
    
    private func courseSchedule(_ courseSched: [String: [[CourseScheduleItem]]], satisfies schedule: [ScheduleMask], options: SearchOptions) -> Bool {
        var fulfillsConflicts = true
        for (type, units) in courseSched {
            guard !options.contains(.noLectureConflicts) || type == CourseScheduleType.lecture else {
                continue
            }
            
            // Find a section that doesn't conflict with the user schedule on any day
            if !units.contains(where: { section -> Bool in
                for (i, day) in CourseScheduleDay.ordering.enumerated() {
                    if ScheduleMask(scheduleItems: section, day: day).conflicts(with: schedule[i]) {
                        return false
                    }
                }
                return true
            }) {
                fulfillsConflicts = false
            }
        }
        return fulfillsConflicts
    }
    
    private func courseSatisfiesTimeIntensiveSearchOptions(_ course: Course, searchTerm: String, options: SearchOptions) -> Bool {
        var fulfillsConflicts = false
        if let masks = userScheduleMasks, !options.contains(.conflictsAllowed) {
            if let department = course.subjectCode {
                CourseManager.shared.loadCourseDetailsSynchronously(for: department)
            }
            if let courseSched = course.schedule, courseSched.count > 0 {
                for sched in masks {
                    if courseSchedule(courseSched, satisfies: sched, options: options) {
                        fulfillsConflicts = true
                    }
                }
            }
        } else {
            fulfillsConflicts = true
        }
        return fulfillsConflicts
    }
    
    private func searchText(for course: Course, options: SearchOptions) -> [String: Float] {
        var ret: [String: Float] = [:]
        if let id = course.subjectID, options.contains(.searchID) {
            ret[id.lowercased()] = 100.0
        }
        if let title = course.subjectTitle, options.contains(.searchTitle) {
            ret[title.lowercased()] = 80.0
        }
        var courseComps: [String?] = []
        if options.contains(.searchRequirements) {
            courseComps += [course.communicationRequirement?.rawValue, course.communicationRequirement?.descriptionText(), course.girAttribute?.rawValue, course.girAttribute?.descriptionText()]
            if let hasses = course.hassAttribute {
                courseComps += hasses.map({ hass -> String? in hass.rawValue })
                courseComps += hasses.map({ hass -> String? in hass.descriptionText() })
            }
        }
        if options.contains(.searchPrereqs),
            let prereqs = course.prerequisites?.requiredCourses.map({ $0.subjectID }) {
            courseComps += prereqs
        }
        if options.contains(.searchCoreqs),
            let coreqs = course.corequisites?.requiredCourses.map({ $0.subjectID }) {
            courseComps += coreqs
        }
        
        let courseText = (courseComps.compactMap({ $0 }) + (options.contains(.searchAllFields) ? course.instructors : [])).joined(separator: " ").lowercased()
        ret[courseText] = 1.0
        return ret
    }
    
    private func searchRegex(for searchTerm: String, options: SearchOptions = .noFilter) -> NSRegularExpression {
        let pattern = NSRegularExpression.escapedPattern(for: searchTerm)
        if options.contains(.matchesSearchTerm) {
            return try! NSRegularExpression(pattern: "(?:^|[^A-z\\d])\(pattern)(?:$|[^A-z\\d])", options: .caseInsensitive)
        } else if options.contains(.startsWithSearchTerm) {
            return try! NSRegularExpression(pattern: "(?:^|[^A-z\\d])\(pattern)(\\w*)(?:$|[^A-z\\d])", options: .caseInsensitive)
        } else if options.contains(.endsWithSearchTerm) {
            return try! NSRegularExpression(pattern: "(?:^|[^A-z\\d])(\\w*)\(pattern)(?:$|[^A-z\\d])", options: .caseInsensitive)
        }
        return try! NSRegularExpression(pattern: "(?:^|[^A-z\\d])(\\w*)\(pattern)(\\w*)(?:$|[^A-z\\d])", options: .caseInsensitive)
    }
    
    typealias DispatchJob = (([Course: Float]?) -> Void) -> Void
    
    private func dispatch(jobs: [DispatchJob], jobCompletion: (([Course: Float]?) -> Void)?, completion: @escaping (Bool) -> Void) {
        var completionCount: Int = 0
        var overallSuccess = true
        let groupCompletionBlock: (([Course: Float]?) -> Void) = { (entries) in
            jobCompletion?(entries)
            completionCount += 1
            if entries == nil {
                overallSuccess = false
            }
            if completionCount == jobs.count {
                completion(overallSuccess)
            }
        }
        
        for job in jobs {
            DispatchQueue.global(qos: .background).async {
                job(groupCompletionBlock)
            }
        }
    }
    
    func searchResults(within courses: [Course], searchTerm: String, options: SearchOptions) -> [Course: Float]? {
        let comps = searchTerm.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines)
        let searchTools = comps.map {
            ($0, self.searchRegex(for: $0, options: options))
        }

        var newResults: [Course: Float] = [:]
        for course in courses {
            guard !self.shouldAbortSearch else {
                return nil
            }
            guard self.courseSatisfiesSearchOptions(course, searchTerm: searchTerm, options: options) else {
                continue
            }
            
            var relevance: Float = 0.0
            if searchTerm.count == 0 && options != .noFilter {
                relevance = 1.0
            } else {
//                 check Regex and if searchID is provided
                
//
//                if options.contains(.searchID) {
//                    searchTools[searchTerm.lowercased()] = pattern
//                }
//
                
                let courseTexts = self.searchText(for: course, options: options)
                for (comp, regex) in searchTools {
                    var found = false
                    for (courseText, weight) in courseTexts {
                        for match in regex.matches(in: courseText, options: [], range: NSRange(location: 0, length: courseText.count)) {
                            var multiplier: Float = 1.0
                            if match.numberOfRanges > 1 {
                                multiplier = 50.0
                                let nonZeroRanges = (1..<match.numberOfRanges).filter({
                                    let range = match.range(at: $0)
                                    return range.length > 0 || range.location == 0 || range.location + range.length == courseText.count
                                }).count
                                if nonZeroRanges == 1 {
                                    multiplier = 10.0
                                } else if nonZeroRanges > 1 {
                                    multiplier = 1.0
                                }
                            }
                            relevance += multiplier * Float(comp.count) * weight / Float(courseText.count)
                            found = true
                        }
                    }
                    if !found {
                        relevance = 0.0
                        break
                    }
                }
            }
            if relevance > 0.0 {
                guard self.courseSatisfiesTimeIntensiveSearchOptions(course, searchTerm: searchTerm, options: options) else {
                    continue
                }
                if course.isGeneric {
                    relevance *= 1e15
                } else if course.isHistorical {
                    relevance *= 0.1
                } else {
                    relevance *= log(Float(max(2, course.enrollmentNumber)))
                }
                let pattern = try! NSRegularExpression(pattern: "(\\d+|\\S+\\.)(\\.?\\S*)", options: .caseInsensitive)
                if pattern.numberOfMatches(in: searchTerm, options: [], range: NSRange(location: 0, length: searchTerm.count)) > 0 {
                    if course.subjectID?.hasPrefix(searchTerm) ?? true {
                        newResults[course] = relevance
                    }
//                    print(course.courseID)
                    
                }
                else {
                    newResults[course] = relevance
                }
                
            }
        }
        if self.shouldAbortSearch {
            return nil
        }
        return newResults
    }
    
    func fastSearchResults(within courses: [Course], searchTerm: String) -> [Course: Float]? {
        let comps = searchTerm.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines)

        var newResults: [Course: Float] = [:]
        for course in courses {
            guard !self.shouldAbortSearch else {
                return nil
            }
            
            var relevance: Float = 0.0
            let courseText = [course.subjectID ?? "", course.subjectTitle ?? ""].joined(separator: "\n").lowercased()
            for comp in comps {
                if !courseText.contains(comp) {
                    relevance = 0.0
                    break
                }
                relevance += Float(comp.count) / Float(courseText.count)
            }
            if relevance > 0.0 {
                if course.isGeneric {
                    relevance *= 1e15
                } else if course.isHistorical {
                    relevance *= 0.1
                } else {
                    relevance *= log(Float(max(2, course.enrollmentNumber)))
                }
                newResults[course] = relevance
            }
        }
        if self.shouldAbortSearch {
            return nil
        }
        return newResults
    }
    
    var queuedSearchTerm: String?
    var queuedSearchOptions: SearchOptions?
    
    private func runSearchAlgorithm(for searchTerm: String, fast: Bool, options: SearchOptions = .noFilter, within courses: [Course]? = nil, callback: @escaping ([Course: Float]) -> Void) {
        DispatchQueue.global().async {
            var searchTerm = searchTerm
            var options = options
            if self.isSearching {
                self.shouldAbortSearch = true
                if self.queuedSearchTerm != nil {
                    // Update the queued search items, and let the other thread deal with it
                    self.queuedSearchTerm = searchTerm
                    self.queuedSearchOptions = options
                    return
                } else {
                    self.queuedSearchTerm = searchTerm
                    self.queuedSearchOptions = options
                    while self.isSearching {
                        usleep(100)
                    }
                }
                if let queuedTerm = self.queuedSearchTerm,
                    let queuedOptions = self.queuedSearchOptions {
                    searchTerm = queuedTerm
                    options = queuedOptions
                }
                self.queuedSearchTerm = nil
                self.queuedSearchOptions = nil
            }
            self.isSearching = true
            
            var coursesToSearch = courses ?? CourseManager.shared.courses
            if self.showsGenericCourses {
                coursesToSearch += Course.genericCourses.values
            }
            let chunkSize = fast ? coursesToSearch.count : coursesToSearch.count / 4  // Don't chunk for fast search
            self.dispatch(jobs: coursesToSearch.chunked(by: chunkSize).map({ (courses) -> DispatchJob in
                return { (completion) in
                    let result = fast ? self.fastSearchResults(within: courses, searchTerm: searchTerm) : self.searchResults(within: courses, searchTerm: searchTerm, options: options)
                    completion(result)
                }
            }), jobCompletion: { (newResults) in
                if let results = newResults {
                    callback(results)
                }
            }, completion: { success in
                self.isSearching = false
                if self.shouldAbortSearch {
                    self.shouldAbortSearch = false
                } else {
                    callback([:])
                }
            })
        }
    }
    
    func loadSearchResults(for searchTerm: String, options: SearchOptions = .noFilter, within courses: [Course]? = nil, callback: @escaping ([Course: Float]) -> Void) {
        runSearchAlgorithm(for: searchTerm, fast: false, options: options, within: courses, callback: callback)
    }
    
    func loadFastSearchResults(for searchTerm: String, within courses: [Course]? = nil, callback: @escaping ([Course: Float]) -> Void) {
        runSearchAlgorithm(for: searchTerm, fast: true, within: courses, callback: callback)
    }
}
