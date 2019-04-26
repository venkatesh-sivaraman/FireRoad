//
//  CourseCatalogParser.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 9/24/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import Cocoa

/// Courses for which to print all attributes as tests
let auditCourses = [
    "6.006", "6.141", "21G.740", "6.00", "21G.502", "21M.480", "18.701", "21L.013"
]

class CourseCatalogParser: NSObject {
    
    var catalogURL: URL?
    
    var htmlContents: String?
    
    /**
     Finds the regions in the HTML source of the given URL that correspond to MIT
     courses. The courses are delimited by tags of the form <a name="course#">.
     */
    func htmlRegions(from url: URL) -> [HTMLNodeExtractor.HTMLRegion] {
        do {
            let text = try String(contentsOf: url)
            htmlContents = text
            guard let topLevelNodes = HTMLNodeExtractor.extractNodes(from: text, ignoreErrors: true) else {
                return []
            }
            let regex = try NSRegularExpression(pattern: "name(?:\\s?)=\"(.+)\"", options: .caseInsensitive)
            let regions = HTMLNodeExtractor.htmlRegions(in: topLevelNodes, demarcatedByTag: "a") { (node: HTMLNode) -> String? in
                if let match = regex.firstMatch(in: node.attributeText, options: [], range: NSRange(location: 0, length: node.attributeText.count)) {
                    return (node.attributeText as NSString).substring(with: match.range(at: 1))
                }
                return nil
            }
            return regions
        } catch {
            print("Error: \(error)")
            return []
        }
    }
    
    /**
     Quickly determines whether a node is a delimiting link tag (of the form
     `<a name="xyz">`).
     */
    func nodeIsDelimitingATag(_ node: HTMLNode) -> Bool {
        return node.tagText.lowercased() == "a" && node.attributeText.range(of: "name") != nil
    }
    
    /**
     Expands the information found in the given node, removing HTML tags and taking
     the titles from image tags.
     */
    func recursivelyExtractInformationItems(from node: HTMLNode, shouldStop: UnsafeMutablePointer<Bool>? = nil) -> [String] {
        var informationItems: [String] = []
        if node.tagText.lowercased() == "img" {
            guard let regex = try? NSRegularExpression(pattern: "title(?:\\s?)=\"(.+?)\"", options: .caseInsensitive) else {
                print("Couldn't initialize img title regex")
                return informationItems
            }
            if let match = regex.firstMatch(in: node.attributeText, options: [], range: NSRange(location: 0, length: node.attributeText.count)) {
                informationItems.append((node.attributeText as NSString).substring(with: match.range(at: 1)))
            }
        } else if nodeIsDelimitingATag(node) {
            shouldStop?.pointee = true
            return informationItems
        } else if node.tagText.lowercased() == "a" {
            informationItems.append(node.contents.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if node.tagText.lowercased() == "span", node.contents.count > 0 {
            informationItems.append(node.contents.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            for child in node.childNodes {
                var shouldStopNow = false
                informationItems += recursivelyExtractInformationItems(from: child, shouldStop: &shouldStopNow)
                if shouldStopNow {
                    break
                }
            }
        }
        shouldStop?.pointee = false
        return informationItems
    }
    
    /**
     Text that will be found in lines that do not need to be included in the final
     set of information items.
     */
    var unnecessaryLinesIdentifyingText: [String] = [
        "textbook"
    ]
    
    let classTimeRegex: NSRegularExpression = {
        guard let regex = try? NSRegularExpression(pattern: "([MTWRF]+)(\\s*EVE\\s*\\()?(\\d+)\\)?", options: []) else {
            fatalError("Couldn't initialize class time regex")
        }
        return regex
    }()
    
    let instructorRegex: NSRegularExpression = {
        guard let regex = try? NSRegularExpression(pattern: "(?:^|[^A-z0-9])[A-Z]\\. \\w+", options: []) else {
            fatalError("Couldn't initialize instructor regex")
        }
        return regex
    }()
    
    let courseIDListRegex: NSRegularExpression = {
        guard let regex = try? NSRegularExpression(pattern: "([A-Z0-9.-]+(,\\s)?)+(?![:])", options: []) else {
            fatalError("Couldn't initialize course ID list regex")
        }
        return regex
    }()
    
    let spaceRegex = try! NSRegularExpression(pattern: "(?<=[^\\s])\\s+(?=[\\s,\\.;-])", options: [])
    
    func condenseSpaces(in string: String) -> String {
        let mut = NSMutableString(string: string)
        spaceRegex.replaceMatches(in: mut, options: [], range: NSRange(location: 0, length: mut.length), withTemplate: "")
        return (mut as String).trimmingCharacters(in: .whitespaces)
    }
    
    /**
     Removes all parenthetical expressions from the given string and leaves
     open/close parenthesis pairs, so that anything left is unparenthesized.
     
     Example: a, (b or c), (d and e) => a, (), ()
     */
    func collapseParentheses(in string: String) -> String {
        let mut = NSMutableString()
        var parenLevel = 0
        for i in string.indices {
            if string[i] == "(" {
                parenLevel += 1
                if parenLevel == 1 {
                    mut.append(String(string[i]))
                }
            } else if string[i] == ")" {
                parenLevel -= 1
                if parenLevel == 0 {
                    mut.append(String(string[i]))
                }
            } else if parenLevel == 0 {
                mut.append(String(string[i]))
            }
        }
        return mut as String
    }
    
    let informationSeparator = CharacterSet.newlines.union(CharacterSet(charactersIn: "-/,;"))
    
    func filterCourseListString(_ list: String) -> [[String]] {
        let trimmedList = list.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        if trimmedList.contains(";") {
            let components = trimmedList.components(separatedBy: ";")
            return components.flatMap {
                filterCourseListString($0)
            }
        }
        if trimmedList.contains(" or") {
            return [trimmedList.replacingOccurrences(of: " or", with: ",").replacingOccurrences(of: " and", with: ",").components(separatedBy: informationSeparator).map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ $0.count > 0 && !$0.lowercased().contains(CourseCatalogConstants.none) })]
        }
        return trimmedList.replacingOccurrences(of: " or", with: "").replacingOccurrences(of: " and", with: ",").components(separatedBy: informationSeparator).map({ [$0.trimmingCharacters(in: .whitespacesAndNewlines)] }).filter({ $0[0].count > 0 && !$0[0].lowercased().contains(CourseCatalogConstants.none) })
    }
    
    func parseScheduleString(_ schedule: String, quarterInformation: UnsafeMutablePointer<String>?) -> String {
        guard schedule.trimmingCharacters(in: .whitespacesAndNewlines).count > 0 else {
            return schedule.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Remove quarter information first
        guard let quarterInfoRegex = try? NSRegularExpression(pattern: "(begins|ends)\\s+(.+?)(\\.|\\))", options: .caseInsensitive) else {
            print("Failed to load quarter info regex")
            return schedule
        }
        if let quarterInfoMatch = quarterInfoRegex.firstMatch(in: schedule, options: [], range: NSRange(location: 0, length: schedule.count)) {
            if let typeRange = Range(quarterInfoMatch.range(at: 1), in: schedule),
                let dateRange = Range(quarterInfoMatch.range(at: 2), in: schedule) {
                let scheduleType = String(schedule[typeRange])
                let date = String(schedule[dateRange])
                quarterInformation?.pointee = "\(scheduleType.lowercased() == "begins" ? 1 : 0),\(date.lowercased())"
            }
        }
        
        let trimmedSchedule = quarterInfoRegex.stringByReplacingMatches(in: schedule, options: [], range: NSRange(location: 0, length: schedule.count), withTemplate: "")
        
        // Class type regex matches "Lecture:abc XX:"
        // Time regex matches "MTWRF9-11 ( 1-123 )" or "MTWRF EVE (8-10) ( 1-234 )".
        guard let classTypeRegex = try? NSRegularExpression(pattern: "(\\w+):(.+?)(?=\\z|\\w+:)", options: .dotMatchesLineSeparators),
            let timeRegex = try? NSRegularExpression(pattern: "(?<!\\(\\s\\w?)([MTWRFS]+)\\s*(?:([0-9-\\.:]+)|(EVE\\s*\\(\\s*(.+?)\\s*\\)))", options: []),
            let locationRegex = try? NSRegularExpression(pattern: "\\(\\s*([A-Z0-9,\\s-]+)\\s*\\)", options: []) else {
            print("Failed to load class type/time regex")
            return schedule
        }
        var scheduleComponents: [String] = []
        for match in classTypeRegex.matches(in: trimmedSchedule, options: [], range: NSRange(location: 0, length: trimmedSchedule.count)) {
            guard let typeRange = Range(match.range(at: 1), in: trimmedSchedule),
                let contentsRange = Range(match.range(at: 2), in: trimmedSchedule) else {
                    continue
            }
            let scheduleType = String(trimmedSchedule[typeRange])
            let contents = String(trimmedSchedule[contentsRange])
            var typeComps = [scheduleType]
            if contents.contains("TBA") {
                typeComps.append("TBA")
            } else {
                let times = contents.components(separatedBy: "or")
                for time in times {
                    var locationStart = time.count
                    var locationComps: [String] = [""]
                    if let locationMatch = locationRegex.matches(in: time, options: [], range: NSRange(location: 0, length: time.count)).first(where: {
                        if let locationRange = Range($0.range(at: 1), in: time),
                            !String(time[locationRange]).contains("PM") {
                            return true
                        }
                        return false
                    }), let locationRange = Range(locationMatch.range(at: 1), in: time),
                        !String(time[locationRange]).contains("PM") {
                        
                        // Replace the empty component
                        locationComps = String(time[locationRange]).components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        locationStart = min(locationStart, locationMatch.range(at: 0).location)
                    }
                    var timeComps: [String] = []
                    for submatch in timeRegex.matches(in: time, options: [], range: NSRange(location: 0, length: locationStart)) {
                        guard let dayRange = Range(submatch.range(at: 1), in: time) else {
                            print("Couldn't get days in \(time)")
                            continue
                        }
                        timeComps.append(String(time[dayRange]))
                        if let timeOfDayRange = Range(submatch.range(at: 2), in: time) {
                            timeComps.append("0")
                            timeComps.append(String(time[timeOfDayRange]))
                        } else if let eveningTimeRange = Range(submatch.range(at: 4), in: time) {
                            timeComps.append("1")
                            timeComps.append(String(time[eveningTimeRange]))
                        } else {
                            print("Couldn't get time of day in \(time)")
                        }
                    }
                    for loc in locationComps {
                        typeComps.append(([loc] + timeComps).joined(separator: "/"))
                    }
                }
            }
            scheduleComponents.append(typeComps.joined(separator: ","))
        }
        return scheduleComponents.joined(separator: ";")
    }
    
    func processInformationItem(_ item: String, into attributes: inout [CourseAttribute: Any]) {
        var definitelyNotDesc = false // Filter out candidates for description
        if let prereqRange = item.range(of: CourseCatalogConstants.prerequisitesPrefix, options: .caseInsensitive) {
            // First check if coreq is in parentheses, then find its range in the whole string
            if collapseParentheses(in: item).range(of: CourseCatalogConstants.corequisitesPrefix, options: .caseInsensitive) != nil,
                let coreqRange = item.range(of: CourseCatalogConstants.corequisitesPrefix, options: .caseInsensitive) {
                let prereqString = String(item[prereqRange.upperBound..<coreqRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                attributes[.oldPrerequisites] = filterCourseListString(prereqString)
                attributes[.prerequisites] = processRequirementsListItem(prereqString)
                attributes[.oldCorequisites] = filterCourseListString(String(item[coreqRange.upperBound..<item.endIndex]))
                attributes[.corequisites] = processRequirementsListItem(String(item[coreqRange.upperBound..<item.endIndex]))
                if prereqString.range(of: CourseCatalogConstants.eitherPrereqOrCoreqFlag, options: .caseInsensitive)?.upperBound == prereqString.endIndex {
                    attributes[.eitherPrereqOrCoreq] = true
                }
            } else {
                attributes[.oldPrerequisites] = filterCourseListString(String(item[prereqRange.upperBound..<item.endIndex]))
                attributes[.prerequisites] = processRequirementsListItem(String(item[prereqRange.upperBound..<item.endIndex]))
            }
            definitelyNotDesc = true
        } else if let coreqRange = item.range(of: CourseCatalogConstants.corequisitesPrefix, options: .caseInsensitive) {
            attributes[.oldCorequisites] = filterCourseListString(String(item[coreqRange.upperBound..<item.endIndex]))
            attributes[.corequisites] = processRequirementsListItem(String(item[coreqRange.upperBound..<item.endIndex]))
            definitelyNotDesc = true
        } else if item.contains(CourseCatalogConstants.urlPrefix) {
            // Don't save URLs
        } else if classTimeRegex.firstMatch(in: item, options: [], range: NSRange(location: 0, length: item.count)) != nil {
            var trimmedItem = item
            if item.contains(CourseCatalogConstants.finalFlag) {
                attributes[.hasFinal] = true
                trimmedItem = trimmedItem.replacingOccurrences(of: CourseCatalogConstants.finalFlag, with: "")
            }
            var quarterInformation = ""
            attributes[.schedule] = parseScheduleString(trimmedItem.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: ""), quarterInformation: &quarterInformation)
            if quarterInformation.count > 0 {
                attributes[.quarterInformation] = quarterInformation
            }
            definitelyNotDesc = true
        } else if let subjectID = attributes[.subjectID] as? String,
            let firstMatch = courseIDListRegex.firstMatch(in: item, options: [], range: NSRange(location: 0, length: item.count)),
            let firstMatchRange = Range(firstMatch.range, in: item),
            String(item[firstMatchRange]).contains(subjectID),
            item.count <= 125 {
            attributes[.title] = String(item[firstMatchRange.upperBound..<item.endIndex]).replacingOccurrences(of: CourseCatalogConstants.jointClass, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            definitelyNotDesc = true
        } else if item.range(of: CourseCatalogConstants.undergrad, options: .caseInsensitive) != nil,
            abs(item.count - CourseCatalogConstants.undergrad.count) < 10 {
            attributes[.subjectLevel] = CourseCatalogConstants.undergradValue
        } else if item.range(of: CourseCatalogConstants.graduate, options: .caseInsensitive) != nil,
            abs(item.count - CourseCatalogConstants.graduate.count) < 10 {
            attributes[.subjectLevel] = CourseCatalogConstants.graduateValue
        } else if item.count > 75,
            let existingDescription = attributes[.description] as? String,
            existingDescription.count > item.count {
            if let notes = attributes[.notes] as? String {
                attributes[.notes] = notes + "\n" + item.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                attributes[.notes] = item.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else if item.range(of: CourseCatalogConstants.meetsWithPrefix, options: .caseInsensitive) != nil ||
            item.range(of: CourseCatalogConstants.equivalentSubjectsPrefix, options: .caseInsensitive) != nil ||
            item.range(of: CourseCatalogConstants.jointSubjectsPrefix, options: .caseInsensitive) != nil {
            
            let prefixes = [CourseCatalogConstants.meetsWithPrefix, CourseCatalogConstants.equivalentSubjectsPrefix, CourseCatalogConstants.jointSubjectsPrefix].map({ NSRegularExpression.escapedPattern(for: $0) }).joined(separator: "|")
            guard let prefixRegex = try? NSRegularExpression(pattern: "(\(prefixes))(.+?)(?=\\z|\(prefixes))", options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
                print("Failed to load prefix regex")
                return
            }
            for (i, match) in prefixRegex.matches(in: item, options: [], range: NSRange(location: 0, length: item.count)).enumerated() {
                guard let prefixRange = Range(match.range(at: 1), in: item),
                    let contentsRange = Range(match.range(at: 2), in: item) else {
                    continue
                }
                guard i > 0 || match.range.location <= 3 else {
                    continue
                }
                let prefix = item[prefixRange]
                let contents = item[contentsRange]
                switch prefix.lowercased() {
                case CourseCatalogConstants.meetsWithPrefix:
                    attributes[.meetsWithSubjects] = filterCourseListString(String(contents)).flatMap({ $0 })
                case CourseCatalogConstants.equivalentSubjectsPrefix:
                    attributes[.equivalentSubjects] = filterCourseListString(String(contents)).flatMap({ $0 })
                case CourseCatalogConstants.jointSubjectsPrefix:
                    attributes[.jointSubjects] = filterCourseListString(String(contents)).flatMap({ $0 })
                default:
                    print("Unrecognized prefix \(prefix)")
                }
            }
            
        } else if let notOfferedRange = item.range(of: CourseCatalogConstants.notOfferedPrefix, options: .caseInsensitive) {
            attributes[.notOfferedYear] = String(item[notOfferedRange.upperBound..<item.endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            
        } else if item.range(of: CourseCatalogConstants.unitsArrangedPrefix, options: .caseInsensitive) != nil {
            attributes[.isVariableUnits] = true
        } else if let unitsRange = item.range(of: CourseCatalogConstants.unitsPrefix, options: .caseInsensitive) {
            let unitsString = String(item[unitsRange.upperBound..<item.endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let components = unitsString.components(separatedBy: .whitespaces).first?.components(separatedBy: .punctuationCharacters).compactMap({ Int($0) }),
                components.count >= 3 {
                attributes[.lectureUnits] = components[0]
                attributes[.labUnits] = components[1]
                attributes[.preparationUnits] = components[2]
                attributes[.totalUnits] = components[0..<3].reduce(0, +)
            }
            attributes[.pdfOption] = unitsString.contains(CourseCatalogConstants.pdfString)
        } else if item.range(of: CourseCatalogConstants.hassH, options: .caseInsensitive) != nil ||
            item.range(of: CourseCatalogConstants.hassA, options: .caseInsensitive) != nil ||
            item.range(of: CourseCatalogConstants.hassS, options: .caseInsensitive) != nil {
            attributes[.hassRequirement] = CourseCatalogConstants.abbreviation(for: item.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if item.contains("+"), item.count < 50,
            item.range(of: CourseCatalogConstants.hassHBasic, options: .caseInsensitive) != nil ||
            item.range(of: CourseCatalogConstants.hassABasic, options: .caseInsensitive) != nil ||
            item.range(of: CourseCatalogConstants.hassSBasic, options: .caseInsensitive) != nil,
            let firstComponent = item.components(separatedBy: "+").first?.trimmingCharacters(in: .whitespacesAndNewlines) {
            // TODO: Include all components
            attributes[.hassRequirement] = CourseCatalogConstants.abbreviation(for: firstComponent)
        } else if item.range(of: CourseCatalogConstants.ciH, options: .caseInsensitive) != nil ||
            item.range(of: CourseCatalogConstants.ciHW, options: .caseInsensitive) != nil {
            attributes[.communicationRequirement] = CourseCatalogConstants.abbreviation(for: item.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if let girRequirement = CourseCatalogConstants.GIRRequirements[item.trimmingCharacters(in: .whitespacesAndNewlines)] {
            attributes[.GIR] = girRequirement
        } else if instructorRegex.firstMatch(in: item, options: [], range: NSRange(location: 0, length: item.count)) != nil {
            let newComponent = item.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: "")
            if attributes[.instructors] != nil, (attributes[.instructors] as? String)?.range(of: CourseCatalogConstants.fall, options: .caseInsensitive) != nil || newComponent.range(of: CourseCatalogConstants.spring, options: .caseInsensitive) != nil {
                attributes[.instructors] = (attributes[.instructors] as! String) + "\n" + newComponent
            } else {
                attributes[.instructors] = newComponent
            }
        } else if item.range(of: CourseCatalogConstants.fall, options: .caseInsensitive) != nil {
            attributes[.offeredFall] = true
        } else if item.range(of: CourseCatalogConstants.spring, options: .caseInsensitive) != nil {
            attributes[.offeredSpring] = true
        } else if item.range(of: CourseCatalogConstants.iap, options: .caseInsensitive) != nil {
            attributes[.offeredIAP] = true
        } else if item.range(of: CourseCatalogConstants.summer, options: .caseInsensitive) != nil {
            attributes[.offeredSummer] = true
        }
        // The longest item that is more than 30 characters long should be the description
        if item.count > 30, !definitelyNotDesc {
            if attributes[.description] == nil || (attributes[.description] as! String).count < item.count {
                attributes[.description] = item.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
    
    // This only handles one level of parenthesization, I think
    private static let requirementsListComponent = "([^(),;]+(\\s*\\[GIR\\])?|\\((.*)\\))"
    private let requirementsListComponentRegex: NSRegularExpression = try! NSRegularExpression(pattern: "\(CourseCatalogParser.requirementsListComponent)((\\s*,)|(\\s+(?=and))|(\\s+(?=or)))", options: .dotMatchesLineSeparators)
    private let requirementsListAndFinalRegex: NSRegularExpression = try! NSRegularExpression(pattern: "^\\s*(and)?\\s*\(CourseCatalogParser.requirementsListComponent)\\s*;?", options: .dotMatchesLineSeparators)
    private let requirementsListOrFinalRegex: NSRegularExpression = try! NSRegularExpression(pattern: "^\\s*or\\s*\(CourseCatalogParser.requirementsListComponent)\\s*;?", options: .dotMatchesLineSeparators)

    /**
     Convert the registrar site string into a requirements list-parseable string.
     If the requirements contain more than one element, the result is parenthesized.
     */
    func processRequirementsListItem(_ item: String) -> String {
        let filteredItem = item.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "(GIR)", with: "[GIR]")
        guard filteredItem.count > 0, !filteredItem.lowercased().contains("none") else {
            return ""
        }
        
        // Search for parenthetical groups and replace them with macros
        var parenLevels: [String] = [""]
        var substitutions: [String: String] = [:]
        for i in filteredItem.indices {
            if filteredItem[i] == "(" {
                parenLevels.append("")
            } else if filteredItem[i] == ")" {
                guard parenLevels.count > 1,
                    let lastItem = parenLevels.popLast() else {
                    print("Invalid prerequisite syntax: \(item)")
                    continue
                }
                let key = "#@%\(substitutions.count)%@#"
                //print("Processing \(lastItem)")
                var subResult = processSingleLevelRequirementsItem(lastItem)
                for (key, sub) in substitutions {
                    subResult = subResult.replacingOccurrences(of: "''" + key + "''", with: "(" + sub + ")")
                }
                substitutions[key] = subResult
                parenLevels[parenLevels.endIndex - 1] = parenLevels.last! + key
            } else {
                parenLevels[parenLevels.endIndex - 1] = parenLevels.last! + String(filteredItem[i])
            }
        }
        
        guard var result = parenLevels.last else {
            print("Unmatched parentheses: \(item)")
            return ""
        }
        result = processSingleLevelRequirementsItem(result)
        for (key, sub) in substitutions {
            result = result.replacingOccurrences(of: "''" + key + "''", with: "(" + sub + ")")
        }
        //print(item, "becomes", result)
        return result
    }
    
    func processSingleLevelRequirementsItem(_ item: String) -> String {
        guard item.count > 0 else {
            return ""
        }
        
        var filteredItem = item.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
        guard !filteredItem.lowercased().contains("none") else {
            return ""
        }
        
        var components: [String] = []
        var isOr = false
        while filteredItem.count > 0 {
            //print("Testing", filteredItem)
            if let match = requirementsListComponentRegex.firstMatch(in: filteredItem, range: NSRange(location: 0, length: filteredItem.count)) {
                let range = Range(match.range(at: 1), in: filteredItem)!
                //print(String(filteredItem[Range(match.range, in: filteredItem)!]), match.numberOfRanges)
                var currentComponent = filteredItem[range].trimmingCharacters(in: .whitespacesAndNewlines)
                if currentComponent[currentComponent.startIndex] == "(",
                    currentComponent[currentComponent.index(before: currentComponent.endIndex)] == ")" {
                    currentComponent = String(currentComponent[currentComponent.index(after: currentComponent.startIndex)..<currentComponent.index(before: currentComponent.endIndex)])
                }
                components.append(processSingleLevelRequirementsItem(currentComponent))
                let wholeRange = Range(match.range, in: filteredItem)!
                filteredItem = String(filteredItem[wholeRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let match = requirementsListOrFinalRegex.firstMatch(in: filteredItem, range: NSRange(location: 0, length: filteredItem.count)) {
                let lastComponent = String(filteredItem[Range(match.range(at: 1), in: filteredItem)!])
                if lastComponent == filteredItem {
                    // The component hasn't changed - simply return it
                    components.append(lastComponent)
                } else {
                    components.append(processSingleLevelRequirementsItem(lastComponent))
                }
                isOr = true
                
                let wholeRange = Range(match.range, in: filteredItem)!
                filteredItem = String(filteredItem[wholeRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                
            } else if let match = requirementsListAndFinalRegex.firstMatch(in: filteredItem, range: NSRange(location: 0, length: filteredItem.count)), filteredItem != "or", filteredItem != "and" {
                let lastComponent = String(filteredItem[Range(match.range(at: 2), in: filteredItem)!])
                if lastComponent == filteredItem {
                    // The component hasn't changed - simply return it
                    components.append(lastComponent)
                } else {
                    components.append(processSingleLevelRequirementsItem(lastComponent))
                }
                
                let wholeRange = Range(match.range, in: filteredItem)!
                filteredItem = String(filteredItem[wholeRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                print("\(filteredItem) doesn't match anything")
                break
            }
        }
        
        //print("Components:", components)
        var base: String
        if isOr {
            base = components.joined(separator: "/")
        } else {
            base = components.joined(separator: ", ")
        }
        if components.count > 1 {
            return base
        } else {
            return processBaseRequirement(base)
        }
    }
    
    private let courseRegex = try! NSRegularExpression(pattern: "([A-z0-9]+)\\.([A-z0-9]+)", options: [])
    
    /**
     Processes an atomic requirement, such as "6.031" or "permission of instructor."
     */
    private func processBaseRequirement(_ item: String) -> String {
        // Handle GIRs
        if item.contains(CourseCatalogConstants.girSuffix) {
            let girSymbol = item.replacingOccurrences(of: CourseCatalogConstants.girSuffix, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let girID = CourseCatalogConstants.GIRRequirements[girSymbol]!
            return "GIR:" + girID
        }
        
        // Handle courses, already-processed items
        if let match = courseRegex.firstMatch(in: item, options: [], range: NSRange(location: 0, length: item.count)),
            match.range.location == 0 {
            return item
        }
        if item.contains("GIR:") || item.contains("''") {
            return item
        }
        
        // The rest are plain strings
        return "''" + item + "''"
    }
    
    /**
     Extracts course information from the given HTML region.
     */
    func extractCourseProperties(from region: HTMLNodeExtractor.HTMLRegion) -> [CourseAttribute: Any] {
        var informationItems: [String] = []
        if region.title == "6.041A" {
            print("Here")
        }
        for node in region.nodes {
            if node.childNodes.count > 0 {
                var shouldStop = false
                let childItems = recursivelyExtractInformationItems(from: node, shouldStop: &shouldStop)
                if shouldStop, informationItems.count > 0 {
                    break
                }
                
                let contents = node.contents.replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive).replacingOccurrences(of: "&nbsp;", with: " ")
                let lines = contents.components(separatedBy: .newlines)
                for line in lines {
                    guard unnecessaryLinesIdentifyingText.first(where: { line.lowercased().contains($0) }) == nil else {
                        continue
                    }
                    if let lineNodes = HTMLNodeExtractor.extractNodes(from: line),
                        lineNodes.count == 1, lineNodes[0].enclosingRange.length >= line.count - 5 {
                        if nodeIsDelimitingATag(lineNodes[0]), informationItems.count > 0 {
                            shouldStop = true
                            break
                        }
                        informationItems.append(lineNodes[0].contents)
                    } else {
                        if HTMLNodeExtractor.stripHTMLTags(from: line).trimmingCharacters(in: .whitespacesAndNewlines).count > 0 {
                            let strippedLine = HTMLNodeExtractor.stripHTMLTags(from: line, replacementString: "\n")
                            informationItems.append(strippedLine)
                        }
                    }
                }
                
                informationItems += childItems
                if shouldStop {
                    break
                }
            } else if nodeIsDelimitingATag(node) {
                if informationItems.count > 0 {
                    break
                }
            } else if node.contents.count == 0 {
                var shouldStop = false
                informationItems += recursivelyExtractInformationItems(from: node, shouldStop: &shouldStop)
                if shouldStop {
                    break
                }
            } else {
                informationItems.append(node.contents.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        //print("Information items: \(informationItems.filter({ $0.count > 0 }).joined(separator: "\n") as NSString)")
        informationItems.sort(by: { $0.replacingOccurrences(of: "\n", with: "").count < $1.replacingOccurrences(of: "\n", with: "").count })
        var processedItems: [CourseAttribute: Any] = [.subjectID : region.title]
        if let url = catalogURL {
            processedItems[.URL] = url.absoluteString + "#\(region.title)"
        }
        for item in informationItems {
            guard item.count > 0 else {
                continue
            }
            let escapedItem = HTMLNodeExtractor.stripHTMLTags(from: item).replacingOccurrences(of: "\"", with: "'").replacingOccurrences(of: "\n", with: " ")
            processInformationItem(escapedItem, into: &processedItems)
        }
        
        if auditCourses.contains(processedItems[.subjectID] as? String ?? "") {
            print(processedItems)
        }
        return processedItems
    }
    
    // MARK: - File Writing
    
    //let headings = "Subject Id,Subject Title,Lecture Units,Lab Units,Preparation Units,Total Units,Gir Attribute,Comm Req Attribute,Prerequisites,Subject Description,Joint Subjects,Meets With Subjects,Equivalent Subjects,Is Offered This Year,Is Offered Fall Term,Is Offered Iap,Is Offered Spring Term,Is Offered Summer Term,Fall Instructors,Spring Instructors,Hass Attribute,Term Duration,URL,Notes"
    
    func headingForAttribute(_ attribute: CourseAttribute) -> String {
        guard let heading = CourseAttribute.csvHeadings[attribute] else {
            fatalError("No CSV heading defined for attribute \(attribute.rawValue)")
        }
        return heading
    }
    
    func writingDescriptionForAttribute(_ attribute: CourseAttribute, of course: [CourseAttribute: Any]) -> String {
        guard let item = course[attribute] else {
            return ""
        }
        
        switch item {
        case let string as String:
            return "\"" + string.replacingOccurrences(of: "\"", with: "\"\"").replacingOccurrences(of: "\n", with: "\\n") + "\""
        case let integer as Int:
            return "\(integer)"
        case let float as Float:
            return String(format: "%.2f", float)
        case let boolean as Bool:
            return boolean ? "Y": "N"
        case let courseList as [[String]]:
            return "\"" + courseList.map({ item in item.joined(separator: ",") }).joined(separator: ";") + "\""
        case let courseList as [String]:
            return "\"" + courseList.joined(separator: ",") + "\""
        default:
            print("Don't have a way to represent attribute \(attribute): \(item)")
            return String(describing: item)
        }
    }
    
    func writeCourses(_ courses: [[CourseAttribute: Any]], to file: String, attributes: [CourseAttribute]) throws {
        var csvComponents: [[String]] = [attributes.map({ headingForAttribute($0) })]
        for course in courses {
            csvComponents.append(attributes.map({ writingDescriptionForAttribute($0, of: course) }))
        }
        
        let csvString = csvComponents.map({ item in item.joined(separator: ",") }).joined(separator: "\n")
        try csvString.write(toFile: file, atomically: true, encoding: .utf8)
    }
    
}
