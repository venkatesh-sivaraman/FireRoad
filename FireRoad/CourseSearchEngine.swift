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
    
    static let anyRequirement = SearchOptions(rawValue: 1 << 0)
    static let fulfillsGIR = SearchOptions(rawValue: 1 << 1)
    static let fulfillsHASS = SearchOptions(rawValue: 1 << 2)
    static let fulfillsCIH = SearchOptions(rawValue: 1 << 3)
    static let fulfillsCIHW = SearchOptions(rawValue: 1 << 4)
    
    static let offeredAnySemester = SearchOptions(rawValue: 1 << 10)
    static let offeredFall = SearchOptions(rawValue: 1 << 11)
    static let offeredSpring = SearchOptions(rawValue: 1 << 12)
    static let offeredIAP = SearchOptions(rawValue: 1 << 13)
    
    static let containsSearchTerm = SearchOptions(rawValue: 1 << 14)
    static let matchesSearchTerm = SearchOptions(rawValue: 1 << 15)
    static let startsWithSearchTerm = SearchOptions(rawValue: 1 << 16)
    static let endsWithSearchTerm = SearchOptions(rawValue: 1 << 17)
    
    static let searchID = SearchOptions(rawValue: 1 << 20)
    static let searchTitle = SearchOptions(rawValue: 1 << 21)
    static let searchPrereqs = SearchOptions(rawValue: 1 << 23)
    static let searchCoreqs = SearchOptions(rawValue: 1 << 24)
    static let searchInstructors = SearchOptions(rawValue: 1 << 25)
    static let searchRequirements = SearchOptions(rawValue: 1 << 26)
    static let searchAllFields: SearchOptions = [
        .searchID,
        .searchTitle,
        .searchPrereqs,
        .searchCoreqs,
        .searchInstructors,
        .searchRequirements
    ]
    
    static let noFilter: SearchOptions = [
        .anyRequirement,
        .offeredAnySemester,
        .containsSearchTerm,
        .searchAllFields
    ]
}

class CourseSearchEngine: NSObject {
    
    var isSearching = false
    var shouldAbortSearch = false
    
    private func courseSatisfiesSearchOptions(_ course: Course, searchTerm: String, options: SearchOptions) -> Bool {
        var fulfillsRequirement = false
        if options.contains(.anyRequirement) {
            fulfillsRequirement = true
        } else if options.contains(.fulfillsGIR), course.girAttribute != nil {
            fulfillsRequirement = true
        } else if options.contains(.fulfillsHASS), course.hassAttribute != nil {
            fulfillsRequirement = true
        } else if options.contains(.fulfillsCIH), course.communicationRequirement == .ciH {
            fulfillsRequirement = true
        } else if options.contains(.fulfillsCIHW), course.communicationRequirement == .ciHW {
            fulfillsRequirement = true
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
        
        return fulfillsRequirement && fulfillsOffered
    }
    
    private func searchText(for course: Course, options: SearchOptions) -> String {
        var courseComps: [String?] = []
        if options.contains(.searchID) {
            courseComps += [course.subjectID, course.subjectID, course.subjectID, course.subjectID, course.subjectID]
        }
        if options.contains(.searchTitle) {
            courseComps += [course.subjectTitle, course.subjectTitle]
        }
        if options.contains(.searchRequirements) {
            courseComps += [course.communicationRequirement?.rawValue, course.communicationRequirement?.descriptionText(), course.hassAttribute?.rawValue, course.hassAttribute?.descriptionText(), course.girAttribute?.rawValue, course.girAttribute?.descriptionText()]
        }
        if options.contains(.searchPrereqs) {
            let prereqs: [String?] = course.prerequisites.flatMap({ $0 })
            courseComps += prereqs
        }
        if options.contains(.searchCoreqs) {
            let coreqs: [String?] = course.corequisites.flatMap({ $0 })
            courseComps += coreqs
        }
        
        let courseText = (courseComps.flatMap({ $0 }) + (options.contains(.searchAllFields) ? course.instructors : [])).joined(separator: " ").lowercased()
        return courseText
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
            let courseText = self.searchText(for: course, options: options)
            for (comp, regex) in searchTools {
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
                    relevance += multiplier * Float(comp.count)
                }
            }
            if relevance > 0.0 {
                relevance *= log(Float(max(2, course.enrollmentNumber)))
                newResults[course] = relevance
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
                relevance += Float(comp.count)
            }
            if relevance > 0.0 {
                relevance *= log(Float(max(2, course.enrollmentNumber)))
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
    
    private func runSearchAlgorithm(for searchTerm: String, fast: Bool, options: SearchOptions = .noFilter, callback: @escaping ([Course: Float]) -> Void) {
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
            
            let chunkSize = CourseManager.shared.courses.count / 4
            self.dispatch(jobs: CourseManager.shared.courses.chunked(by: chunkSize).map({ (courses) -> DispatchJob in
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
    
    func loadSearchResults(for searchTerm: String, options: SearchOptions = .noFilter, callback: @escaping ([Course: Float]) -> Void) {
        runSearchAlgorithm(for: searchTerm, fast: false, options: options, callback: callback)
    }
    
    func loadFastSearchResults(for searchTerm: String, callback: @escaping ([Course: Float]) -> Void) {
        runSearchAlgorithm(for: searchTerm, fast: true, callback: callback)
    }
}
