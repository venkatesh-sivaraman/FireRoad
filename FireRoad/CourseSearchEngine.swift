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
            courseComps += [course.subjectID, course.subjectID, course.subjectID]
        }
        if options.contains(.searchTitle) {
            courseComps.append(course.subjectTitle)
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
    
    func loadSearchResults(for searchTerm: String, options: SearchOptions = .noFilter, callback: @escaping ([Course: Float]) -> Void) {
        DispatchQueue.global().async {
            if self.isSearching {
                self.shouldAbortSearch = true
                while self.isSearching {
                    usleep(100)
                }
            }
            let comps = searchTerm.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines)
            
            var newResults: [Course: Float] = [:]
            for course in CourseManager.shared.courses {
                guard !self.shouldAbortSearch else {
                    print("Aborting search")
                    self.isSearching = false
                    self.shouldAbortSearch = false
                    return
                }
                guard self.courseSatisfiesSearchOptions(course, searchTerm: searchTerm, options: options) else {
                    continue
                }
                
                var relevance: Float = 0.0
                let courseText = self.searchText(for: course, options: options)
                for comp in comps {
                    let regex = self.searchRegex(for: comp, options: options)
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
            self.isSearching = false
            self.shouldAbortSearch = false
            callback(newResults)
        }
    }
}
