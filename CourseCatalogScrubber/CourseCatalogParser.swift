//
//  CourseCatalogParser.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 9/24/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import Cocoa

enum CourseCatalogConstants {
    static let equivalentSubjectsPrefix = "credit cannot also be received for"
    static let notOfferedPrefix = "not offered academic year"
    static let unitsPrefix = "units:"
    static let unitsArrangedPrefix = "units arranged"
    static let prerequisitesPrefix = "prereq:"
    static let corequisitesPrefix = "coreq:"
    static let meetsWithPrefix = "subject meets with"
    static let jointSubjectsPrefix = "same subject as"
    
    static let undergrad = "undergrad"
    static let graduate = "graduate"
    static let fall = "fall"
    static let spring = "spring"
    static let iap = "iap"
    static let summer = "summer"
    
    static let staff = "staff"
    static let none = "none"
    
    static let urlPrefix = "http"
    
    static let hassH = "hass humanities"
    static let hassA = "hass arts"
    static let hassS = "hass social sciences"
    static let ciH = "communication intensive hass"
    static let ciHW = "communication intensive writing"
    static let ciHAbbreviation = "CI-H"
    static let ciHWAbbreviation = "CI-HW"
    static let hassHAbbreviation = "HASS-H"
    static let hassAAbbreviation = "HASS-A"
    static let hassSAbbreviation = "HASS-S"
    
    static func abbreviation(for attribute: String) -> String {
        switch attribute.lowercased() {
        case self.hassH: return self.hassHAbbreviation
        case self.hassA: return self.hassAAbbreviation
        case self.hassS: return self.hassSAbbreviation
        case self.ciH: return self.ciHAbbreviation
        case self.ciHW: return self.ciHWAbbreviation
        default:
            print("Don't have an abbreviation for \(attribute)")
            return attribute
        }
    }
    
    static let finalFlag = "+final"
    
    static let GIRRequirements: [String: String] = [
        "1/2 Rest Elec in Sci & Tech": "RST2",
        "Rest Elec in Sci & Tech": "REST",
        "Physics I": "PHY1",
        "Physics II": "PHY2",
        "Calculus I": "CAL1",
        "Calculus II": "CAL2",
        "Chemistry": "CHEM",
        "Biology": "BIOL",
        "Institute Lab": "LAB",
        "Partial Lab": "LAB2"
    ]
    
    static let jointClass = "[J]"
}

enum CourseAttribute: String, CustomDebugStringConvertible {
    case subjectID
    case title
    case description
    case offeredFall
    case offeredIAP
    case offeredSpring
    case offeredSummer
    case lectureUnits
    case labUnits
    case preparationUnits
    case totalUnits
    case instructors
    case prerequisites
    case corequisites
    case notes
    case schedule
    case notOfferedYear
    case hassRequirement
    case communicationRequirement
    case meetsWithSubjects
    case jointSubjects
    case equivalentSubjects
    case GIR
    case URL
    case hasFinal
    case quarterInformation
    
    var debugDescription: String {
        return rawValue
    }
}


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
        } else {
            for child in node.childNodes {
                informationItems += recursivelyExtractInformationItems(from: child)
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
        guard let regex = try? NSRegularExpression(pattern: "([MTWRF]+)(\\d+)", options: []) else {
            fatalError("Couldn't initialize class time regex")
        }
        return regex
    }()
    
    let instructorRegex: NSRegularExpression = {
        guard let regex = try? NSRegularExpression(pattern: "[A-Z]\\. \\w+", options: []) else {
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
        guard let quarterInfoRegex = try? NSRegularExpression(pattern: "\\((begins|ends)\\s+(.+?)\\)", options: .caseInsensitive) else {
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
            let locationRegex = try? NSRegularExpression(pattern: "[A-Z]*[0-9-]+", options: []) else {
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
                    var locationStart = 0
                    var timeComps: [String] = []
                    for submatch in timeRegex.matches(in: time, options: [], range: NSRange(location: 0, length: time.count)) {
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
                        locationStart = submatch.range.location + submatch.range.length
                    }
                    for locationMatch in locationRegex.matches(in: time, options: [], range: NSRange(location: locationStart, length: time.count - locationStart)) {
                        guard let locationRange = Range(locationMatch.range(at: 0), in: time) else {
                            continue
                        }
                        typeComps.append(([String(time[locationRange])] + timeComps).joined(separator: "/"))
                    }
                }
            }
            scheduleComponents.append(typeComps.joined(separator: ","))
        }
        return scheduleComponents.joined(separator: ";")
    }
    
    func processInformationItem(_ item: String, into attributes: inout [CourseAttribute: Any]) {
        if let prereqRange = item.range(of: CourseCatalogConstants.prerequisitesPrefix, options: .caseInsensitive) {
            if let coreqRange = item.range(of: CourseCatalogConstants.corequisitesPrefix, options: .caseInsensitive) {
                attributes[.prerequisites] = filterCourseListString(String(item[prereqRange.upperBound..<coreqRange.lowerBound]))
                attributes[.corequisites] = filterCourseListString(String(item[coreqRange.upperBound..<item.endIndex]))
            } else {
                attributes[.prerequisites] = filterCourseListString(String(item[prereqRange.upperBound..<item.endIndex]))
            }
            
        } else if let coreqRange = item.range(of: CourseCatalogConstants.corequisitesPrefix, options: .caseInsensitive) {
            attributes[.corequisites] = filterCourseListString(String(item[coreqRange.upperBound..<item.endIndex]))
            
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
            
        } else if let subjectID = attributes[.subjectID] as? String,
            let firstMatch = courseIDListRegex.firstMatch(in: item, options: [], range: NSRange(location: 0, length: item.count)),
            let firstMatchRange = Range(firstMatch.range, in: item),
            String(item[firstMatchRange]).contains(subjectID) {
            attributes[.title] = String(item[firstMatchRange.upperBound..<item.endIndex]).replacingOccurrences(of: CourseCatalogConstants.jointClass, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        } else if item.count > 75 {
            if let existingDescription = attributes[.description] as? String,
                existingDescription.count > item.count {
                if let notes = attributes[.notes] as? String {
                    attributes[.notes] = notes + "\n" + item.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    attributes[.notes] = item.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else {
                attributes[.description] = item.trimmingCharacters(in: .whitespacesAndNewlines)
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
            
        } else if let unitsRange = item.range(of: CourseCatalogConstants.unitsPrefix, options: .caseInsensitive) {
            let unitsString = String(item[unitsRange.upperBound..<item.endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let components = unitsString.components(separatedBy: .punctuationCharacters).flatMap({ Int($0) })
            if components.count == 3 {
                attributes[.lectureUnits] = components[0]
                attributes[.labUnits] = components[1]
                attributes[.preparationUnits] = components[2]
            }
            attributes[.totalUnits] = components.reduce(0, +)
        }/* else if let unitsArrangedRange = item.range(of: CourseCatalogConstants.unitsArrangedPrefix, options: .caseInsensitive) {
             attributes[.units] = item.substring(from: unitsArrangedRange.upperBound).trimmingCharacters(in: .whitespacesAndNewlines)
             
         }*/ else if item.range(of: CourseCatalogConstants.fall, options: .caseInsensitive) != nil {
            attributes[.offeredFall] = true
        } else if item.range(of: CourseCatalogConstants.spring, options: .caseInsensitive) != nil {
            attributes[.offeredSpring] = true
        } else if item.range(of: CourseCatalogConstants.iap, options: .caseInsensitive) != nil {
            attributes[.offeredIAP] = true
        } else if item.range(of: CourseCatalogConstants.summer, options: .caseInsensitive) != nil {
            attributes[.offeredSummer] = true
        } else if item.range(of: CourseCatalogConstants.hassH, options: .caseInsensitive) != nil ||
            item.range(of: CourseCatalogConstants.hassA, options: .caseInsensitive) != nil ||
            item.range(of: CourseCatalogConstants.hassS, options: .caseInsensitive) != nil {
            attributes[.hassRequirement] = CourseCatalogConstants.abbreviation(for: item.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if item.range(of: CourseCatalogConstants.ciH, options: .caseInsensitive) != nil ||
            item.range(of: CourseCatalogConstants.ciHW, options: .caseInsensitive) != nil {
            attributes[.communicationRequirement] = CourseCatalogConstants.abbreviation(for: item.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if let girRequirement = CourseCatalogConstants.GIRRequirements[item.trimmingCharacters(in: .whitespacesAndNewlines)] {
            attributes[.GIR] = girRequirement
        } else if instructorRegex.firstMatch(in: item, options: [], range: NSRange(location: 0, length: item.count)) != nil {
            attributes[.instructors] = item.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: "")
        }
    }
    
    /**
     Extracts course information from the given HTML region.
     */
    func extractCourseProperties(from region: HTMLNodeExtractor.HTMLRegion) -> [CourseAttribute: Any] {
        var informationItems: [String] = []
        for node in region.nodes {
            if node.childNodes.count > 0 {
                var shouldStop = false
                let childItems = recursivelyExtractInformationItems(from: node, shouldStop: &shouldStop)
                if shouldStop, informationItems.count > 0 {
                    break
                }
                
                let contents = node.contents.replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
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
                
                if shouldStop {
                    break
                }
                
                informationItems += childItems
            } else if nodeIsDelimitingATag(node), informationItems.count > 0 {
                break
            } else {
                informationItems.append(node.contents)
            }
        }
        //print("Information items: \(informationItems.filter({ $0.count > 0 }).joined(separator: "\n") as NSString)")
        
        var processedItems: [CourseAttribute: Any] = [.subjectID : region.title]
        if let url = catalogURL {
            processedItems[.URL] = url.absoluteString + "#\(region.title)"
        }
        for item in informationItems {
            guard item.count > 0,
                let escapedItem = String(htmlEncodedString: item) else {
                    continue
            }
            processInformationItem(escapedItem, into: &processedItems)
        }
        return processedItems
    }
    
    // MARK: - File Writing
    
    //let headings = "Subject Id,Subject Title,Lecture Units,Lab Units,Preparation Units,Total Units,Gir Attribute,Comm Req Attribute,Prerequisites,Subject Description,Joint Subjects,Meets With Subjects,Equivalent Subjects,Is Offered This Year,Is Offered Fall Term,Is Offered Iap,Is Offered Spring Term,Is Offered Summer Term,Fall Instructors,Spring Instructors,Hass Attribute,Term Duration,URL,Notes"
    
    static let csvHeadings: [CourseAttribute: String] = [
        .subjectID: "Subject Id",
        .title: "Subject Title",
        .description: "Subject Description",
        .offeredFall: "Is Offered Fall Term",
        .offeredIAP: "Is Offered Iap",
        .offeredSpring: "Is Offered Spring Term",
        .offeredSummer: "Is Offered Summer Term",
        .lectureUnits: "Lecture Units",
        .labUnits: "Lab Units",
        .preparationUnits: "Preparation Units",
        .totalUnits: "Total Units",
        .instructors: "Instructors",
        .prerequisites: "Prerequisites",
        .corequisites: "Corequisites",
        .notes: "Notes",
        .schedule: "Schedule",
        .notOfferedYear: "Not Offered Year",
        .hassRequirement: "Hass Attribute",
        .GIR: "Gir Attribute",
        .communicationRequirement: "Comm Req Attribute",
        .meetsWithSubjects: "Meets With Subjects",
        .jointSubjects: "Joint Subjects",
        .equivalentSubjects: "Equivalent Subjects",
        .URL: "URL",
        .quarterInformation: "Quarter Information"
    ]
    
    func headingForAttribute(_ attribute: CourseAttribute) -> String {
        guard let heading = CourseCatalogParser.csvHeadings[attribute] else {
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
            return "\"" + string.replacingOccurrences(of: "\"", with: "\"\"") + "\""
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
