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
    static let ciHAbbreviation = "CIH"
    static let ciHWAbbreviation = "CIHW"
    
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
    
    var debugDescription: String {
        return rawValue
    }
}


class CourseCatalogParser: NSObject {
    
    var catalogURL: URL?
    
    /**
     Finds the regions in the HTML source of the given URL that correspond to MIT
     courses. The courses are delimited by tags of the form <a name="course#">.
     */
    func htmlRegions(from url: URL) -> [HTMLNodeExtractor.HTMLRegion] {
        do {
            let text = try String(contentsOf: url)
            guard let topLevelNodes = HTMLNodeExtractor.extractNodes(from: text, ignoreErrors: true) else {
                return []
            }
            let regex = try NSRegularExpression(pattern: "name(?:\\s?)=\"(.+)\"", options: .caseInsensitive)
            let regions = HTMLNodeExtractor.htmlRegions(in: topLevelNodes, demarcatedByTag: "a") { (node: HTMLNode) -> String? in
                if let match = regex.firstMatch(in: node.attributeText, options: [], range: NSRange(location: 0, length: node.attributeText.characters.count)) {
                    return (node.attributeText as NSString).substring(with: match.rangeAt(1))
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
            if let match = regex.firstMatch(in: node.attributeText, options: [], range: NSRange(location: 0, length: node.attributeText.characters.count)) {
                informationItems.append((node.attributeText as NSString).substring(with: match.rangeAt(1)))
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
            return [trimmedList.replacingOccurrences(of: " or", with: "").replacingOccurrences(of: " and", with: "").components(separatedBy: informationSeparator).map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ $0.characters.count > 0 && !$0.lowercased().contains(CourseCatalogConstants.none) })]
        }
        return trimmedList.replacingOccurrences(of: " or", with: "").replacingOccurrences(of: " and", with: "").components(separatedBy: informationSeparator).map({ [$0.trimmingCharacters(in: .whitespacesAndNewlines)] }).filter({ $0[0].characters.count > 0 && !$0[0].lowercased().contains(CourseCatalogConstants.none) })
    }
    
    func processInformationItem(_ item: String, into attributes: inout [CourseAttribute: Any]) {
        if let prereqRange = item.range(of: CourseCatalogConstants.prerequisitesPrefix, options: .caseInsensitive) {
            if let coreqRange = item.range(of: CourseCatalogConstants.corequisitesPrefix, options: .caseInsensitive) {
                attributes[.prerequisites] = filterCourseListString(item.substring(with: prereqRange.upperBound..<coreqRange.lowerBound))
                attributes[.corequisites] = filterCourseListString(item.substring(from: coreqRange.upperBound))
            } else {
                attributes[.prerequisites] = filterCourseListString(item.substring(from: prereqRange.upperBound))
            }
            
        } else if let coreqRange = item.range(of: CourseCatalogConstants.corequisitesPrefix, options: .caseInsensitive) {
            attributes[.corequisites] = filterCourseListString(item.substring(from: coreqRange.upperBound))
            
        } else if let meetsWithRange = item.range(of: CourseCatalogConstants.meetsWithPrefix, options: .caseInsensitive) {
            attributes[.meetsWithSubjects] = filterCourseListString(item.substring(from: meetsWithRange.upperBound)).flatMap({ $0 })
            
        } else if let equivalentRange = item.range(of: CourseCatalogConstants.equivalentSubjectsPrefix, options: .caseInsensitive) {
            attributes[.equivalentSubjects] = filterCourseListString(item.substring(from: equivalentRange.upperBound)).flatMap({ $0 })
            
        } else if let jointSubjectsRange = item.range(of: CourseCatalogConstants.jointSubjectsPrefix, options: .caseInsensitive) {
            attributes[.jointSubjects] = filterCourseListString(item.substring(from: jointSubjectsRange.upperBound)).flatMap({ $0 })
            
        } else if let notOfferedRange = item.range(of: CourseCatalogConstants.notOfferedPrefix, options: .caseInsensitive) {
            attributes[.notOfferedYear] = item.substring(from: notOfferedRange.upperBound).trimmingCharacters(in: .whitespacesAndNewlines)
            
        } else if let unitsRange = item.range(of: CourseCatalogConstants.unitsPrefix, options: .caseInsensitive) {
            let unitsString = item.substring(from: unitsRange.upperBound).trimmingCharacters(in: .whitespacesAndNewlines)
            let components = unitsString.components(separatedBy: .punctuationCharacters).flatMap({ Int($0) })
            if components.count == 3 {
                attributes[.lectureUnits] = components[0]
                attributes[.labUnits] = components[1]
                attributes[.preparationUnits] = components[2]
            }
            attributes[.totalUnits] = components.reduce(0, +)
        }/* else if let unitsArrangedRange = item.range(of: CourseCatalogConstants.unitsArrangedPrefix, options: .caseInsensitive) {
             attributes[.units] = item.substring(from: unitsArrangedRange.upperBound).trimmingCharacters(in: .whitespacesAndNewlines)
             
         }*/ else if classTimeRegex.firstMatch(in: item, options: [], range: NSRange(location: 0, length: item.characters.count)) != nil {
            attributes[.schedule] = item.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: "")
            
        } else if let subjectID = attributes[.subjectID] as? String,
            let idRange = item.range(of: subjectID),
            idRange.lowerBound == item.startIndex {
            attributes[.title] = item.substring(from: idRange.upperBound).replacingOccurrences(of: CourseCatalogConstants.jointClass, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            
        } else if item.characters.count > 75 {
            if let existingDescription = attributes[.description] as? String,
                existingDescription.characters.count > item.characters.count {
                if let notes = attributes[.notes] as? String {
                    attributes[.notes] = notes + "\n" + item.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    attributes[.notes] = item.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else {
                attributes[.description] = item.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
        } else if item.contains(CourseCatalogConstants.urlPrefix) {
            // Don't save URLs
        } else if item.range(of: CourseCatalogConstants.fall, options: .caseInsensitive) != nil {
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
            attributes[.hassRequirement] = item.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if item.range(of: CourseCatalogConstants.ciH, options: .caseInsensitive) != nil {
            attributes[.communicationRequirement] = CourseCatalogConstants.ciHAbbreviation
        } else if item.range(of: CourseCatalogConstants.ciHW, options: .caseInsensitive) != nil {
            attributes[.communicationRequirement] = CourseCatalogConstants.ciHWAbbreviation
        } else if let girRequirement = CourseCatalogConstants.GIRRequirements[item.trimmingCharacters(in: .whitespacesAndNewlines)] {
            attributes[.GIR] = girRequirement
        } else if instructorRegex.firstMatch(in: item, options: [], range: NSRange(location: 0, length: item.characters.count)) != nil {
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
                
                let contents = node.contents.replacingOccurrences(of: "<br>", with: "", options: .caseInsensitive)
                let lines = contents.components(separatedBy: .newlines)
                for line in lines {
                    guard unnecessaryLinesIdentifyingText.first(where: { line.lowercased().contains($0) }) == nil else {
                        continue
                    }
                    if let lineNodes = HTMLNodeExtractor.extractNodes(from: line),
                        lineNodes.count == 1, lineNodes[0].enclosingRange.length >= line.characters.count - 5 {
                        if nodeIsDelimitingATag(lineNodes[0]), informationItems.count > 0 {
                            shouldStop = true
                            break
                        }
                        informationItems.append(lineNodes[0].contents)
                    } else {
                        if HTMLNodeExtractor.stripHTMLTags(from: line).trimmingCharacters(in: .whitespacesAndNewlines).characters.count > 0 {
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
        //print("Information items: \(informationItems.filter({ $0.characters.count > 0 }).joined(separator: "\n") as NSString)")
        
        var processedItems: [CourseAttribute: Any] = [.subjectID : region.title]
        if let url = catalogURL {
            processedItems[.URL] = url.absoluteString + "#\(region.title)"
        }
        for item in informationItems {
            guard item.characters.count > 0,
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
        .URL: "URL"
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
