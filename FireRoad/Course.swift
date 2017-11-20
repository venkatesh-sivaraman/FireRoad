//
//  Course.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/2/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

// MARK: Attribute Enums

protocol AttributeEnum {
    func descriptionText() -> String
    func satisfies(_ attribute: Self?) -> Bool
}

enum GIRAttribute: String, AttributeEnum {
    case physics1 = "PHY1"
    case physics2 = "PHY2"
    case chemistry = "CHEM"
    case biology = "BIOL"
    case calculus1 = "CAL1"
    case calculus2 = "CAL2"
    case lab = "LAB"
    case rest = "REST"
    
    static let allValues: [GIRAttribute] = [
        .physics1,
        .physics2,
        .chemistry,
        .biology,
        .calculus1,
        .calculus2,
        .lab,
        .rest
    ]
    
    static let descriptions: [GIRAttribute: String] = [
        .physics1: "Physics I GIR",
        .physics2: "Physics II GIR",
        .chemistry: "Chemistry GIR",
        .biology: "Biology GIR",
        .calculus1: "Calculus I GIR",
        .calculus2: "Calculus II GIR",
        .lab: "Lab GIR",
        .rest: "REST GIR"
    ]
    
    static let sortedDescriptions = GIRAttribute.descriptions.sorted(by: { $1.value.count > $0.value.count })

    func descriptionText() -> String {
        return GIRAttribute.descriptions[self] ?? self.rawValue
    }
    
    func satisfies(_ attribute: GIRAttribute?) -> Bool {
        return attribute != nil && attribute == self
    }
    
    init?(rawValue: String) {
        let trimmedRawValue = rawValue.lowercased().replacingOccurrences(of: "gir:", with: "").trimmingCharacters(in: .whitespaces)
        if let value = GIRAttribute.allValues.first(where: { $0.rawValue.lowercased() == trimmedRawValue }) {
            self = value
        } else if let converted = GIRAttribute.sortedDescriptions.first(where: { $1.lowercased().contains(trimmedRawValue) })?.key {
            self = converted
        } else {
            return nil
        }
    }
}

enum CommunicationAttribute: String, AttributeEnum {
    case ciH = "CI-H"
    case ciHW = "CI-HW"
    
    static let descriptions: [CommunicationAttribute: String] = [
        .ciH: "Communication Intensive",
        .ciHW: "Communication Intensive with Writing"
    ]
    
    func descriptionText() -> String {
        return CommunicationAttribute.descriptions[self] ?? self.rawValue
    }
    
    func satisfies(_ attribute: CommunicationAttribute?) -> Bool {
        return attribute != nil && attribute == self
    }
}

enum HASSAttribute: String, AttributeEnum {
    case any = "HASS"
    case humanities = "HASS-H"
    case arts = "HASS-A"
    case socialSciences = "HASS-S"
    
    static let descriptions: [HASSAttribute: String] = [
        .any: "HASS",
        .humanities: "HASS Humanities",
        .arts: "HASS Arts",
        .socialSciences: "HASS Social Sciences"
    ]
    
    func descriptionText() -> String {
        return HASSAttribute.descriptions[self] ?? self.rawValue
    }
    
    /**
     Returns whether the HASS attribute satisfies the requirement delineated
     by another attribute object. If the given attribute is "any", then any value
     will return true. Otherwise, the two attributes must be equal.
     */
    func satisfies(_ attribute: HASSAttribute?) -> Bool {
        if let attrib = attribute {
            if attrib == .any {
                return true
            }
            return attrib == self
        }
        return false
    }
}

// MARK: - Scheduling Attributes

enum CourseOfferingPattern: String {
    case everyYear = "Every year"
    case alternateYears = "Alternate years"
    case never = "Never"
}

struct CourseScheduleDay: OptionSet, CustomDebugStringConvertible {
    var rawValue: Int
    
    static let none = CourseScheduleDay(rawValue: 0)
    static let monday = CourseScheduleDay(rawValue: 1 << 0)
    static let tuesday = CourseScheduleDay(rawValue: 1 << 1)
    static let wednesday = CourseScheduleDay(rawValue: 1 << 2)
    static let thursday = CourseScheduleDay(rawValue: 1 << 3)
    static let friday = CourseScheduleDay(rawValue: 1 << 4)
    static let saturday = CourseScheduleDay(rawValue: 1 << 5)
    static let sunday = CourseScheduleDay(rawValue: 1 << 6)
    
    static let ordering: [CourseScheduleDay] = [
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday,
        .saturday,
        .sunday
    ]
    
    private static let stringMappings: [Int: String] = [
        CourseScheduleDay.monday.rawValue: "M",
        CourseScheduleDay.tuesday.rawValue: "T",
        CourseScheduleDay.wednesday.rawValue: "W",
        CourseScheduleDay.thursday.rawValue: "R",
        CourseScheduleDay.friday.rawValue: "F",
        CourseScheduleDay.saturday.rawValue: "S",
        CourseScheduleDay.sunday.rawValue: "S"
    ]
    
    func stringEquivalent() -> String {
        var ret = ""
        for item in CourseScheduleDay.ordering {
            if contains(item) {
                ret += CourseScheduleDay.stringMappings[item.rawValue] ?? ""
            }
        }
        return ret
    }
    
    var debugDescription: String {
        return stringEquivalent()
    }
    
    static func fromString(_ days: String) -> CourseScheduleDay {
        var offered = CourseScheduleDay.none
        var currentOrderingIndex = 0
        for character in days {
            while character != CourseScheduleDay.ordering[currentOrderingIndex].stringEquivalent().first {
                currentOrderingIndex += 1
            }
            guard currentOrderingIndex < CourseScheduleDay.ordering.count else {
                print("Ran out of possible weekday letters")
                return .none
            }
            offered = offered.union(CourseScheduleDay.ordering[currentOrderingIndex])
        }
        return offered
    }
}

struct CourseScheduleTime: CustomDebugStringConvertible, Comparable {
    var hour: Int
    var minute: Int
    var PM: Bool
    
    /**
     If evening is false, times >= 7 will be AM and times less than 7
     will be PM. If evening is true, the opposite will be assigned.
     */
    static func fromString(_ time: String, evening: Bool = false) -> CourseScheduleTime {
        let comps = time.components(separatedBy: .punctuationCharacters).flatMap({ Int($0) })
        guard comps.count > 0 else {
            print("Not enough components in time string: \(time)")
            return CourseScheduleTime(hour: 12, minute: 0, PM: true)
        }
        var pm = ((comps[0] >= 7) == evening)
        if comps[0] == 12 {
            pm = !evening
        }
        if comps.count == 1 {
            return CourseScheduleTime(hour: comps[0], minute: 0, PM: pm)
        }
        return CourseScheduleTime(hour: comps[0], minute: comps[1], PM: pm)
    }
    
    func stringEquivalent(withTimeOfDay: Bool = false) -> String {
        return String(format: "%d", hour) + (minute != 0 ? String(format: ":%02d", minute) : "") + (withTimeOfDay ? (PM ? " PM" : " AM") : "")
    }
    
    var debugDescription: String {
        return stringEquivalent(withTimeOfDay: (PM && hour >= 7 && hour != 12))
    }
    
    var hour24: Int {
        return hour + (PM && hour != 12 ? 12 : 0)
    }
    
    static func <(lhs: CourseScheduleTime, rhs: CourseScheduleTime) -> Bool {
        let lHour = lhs.hour24
        let rHour = rhs.hour24
        if lHour != rHour {
            return lHour < rHour
        }
        if lhs.minute != rhs.minute {
            return lhs.minute < rhs.minute
        }
        return false
    }
    
    static func ==(lhs: CourseScheduleTime, rhs: CourseScheduleTime) -> Bool {
        return lhs.hour == rhs.hour && lhs.minute == rhs.minute && lhs.PM == rhs.PM
    }
    
    func delta(to otherValue: CourseScheduleTime) -> (Int, Int) {
        if self > otherValue {
            let res = otherValue.delta(to: self)
            return (-res.0, -res.1)
        }
        var myHour = hour24
        let destinationHour = otherValue.hour24
        var minutes = 0
        while myHour < destinationHour {
            minutes += 60
            myHour += 1
        }
        minutes += otherValue.minute - minute
        return (minutes / 60, minutes % 60)
    }
}

class CourseScheduleItem: NSObject {
    var days: CourseScheduleDay
    var startTime: CourseScheduleTime
    var endTime: CourseScheduleTime
    var isEvening: Bool
    var location: String?
    
    init(days: String, startTime: String, endTime: String, isEvening: Bool = false, location: String? = nil) {
        self.days = CourseScheduleDay.fromString(days)
        self.startTime = CourseScheduleTime.fromString(startTime, evening: isEvening)
        self.endTime = CourseScheduleTime.fromString(endTime, evening: isEvening)
        self.isEvening = isEvening
        self.location = location
    }
    
    func stringEquivalent(withLocation: Bool = true) -> String {
        return "\(days) \(startTime)–\(endTime)" + (location != nil && withLocation ? " (\(location!))" : "")
    }
    
    override var description: String {
        return stringEquivalent(withLocation: true)
    }
}

enum CourseScheduleType {
    static let lecture = "Lecture"
    static let recitation = "Recitation"
    static let lab = "Lab"
    static let design = "Design"
    
    static let ordering = [CourseScheduleType.lecture,
                           CourseScheduleType.recitation,
                           CourseScheduleType.design,
                           CourseScheduleType.lab]
    
    private static let abbreviations = [
        CourseScheduleType.lecture: "Lec",
        CourseScheduleType.recitation: "Rec",
        CourseScheduleType.lab: "Lab",
        CourseScheduleType.design: "Des"
    ]
    
    static func abbreviation(for scheduleType: String) -> String? {
        return abbreviations[scheduleType]
    }
}

enum CourseQuarter {
    case wholeSemester
    case beginningOnly
    case endOnly
}

// MARK: - Course Attributes

enum CourseAttribute: String {
    case subjectID
    case subjectTitle
    case subjectShortTitle
    case subjectDescription
    case subjectCode
    case department
    case equivalentSubjects
    case jointSubjects
    case meetsWithSubjects
    case prerequisites
    case corequisites
    case girAttribute
    case communicationRequirement
    case hassAttribute
    case gradeRule
    case gradeType
    case instructors
    case isOfferedFall
    case isOfferedIAP
    case isOfferedSpring
    case isOfferedSummer
    case isOfferedThisYear
    case totalUnits
    case isVariableUnits
    case labUnits
    case lectureUnits
    case designUnits
    case preparationUnits
    case notOfferedYear
    case onlinePageNumber
    case schoolWideElectives
    case quarterInformation
    case offeringPattern
    case enrollmentNumber
    case relatedSubjects
    case schedule

    static let csvHeaders: [String: CourseAttribute] = [
        "Subject Id": .subjectID,
        "Subject Title": .subjectTitle,
        "Subject Short Title": .subjectShortTitle,
        "Subject Description": .subjectDescription,
        "Subject Code": .subjectCode,
        "Department Name": .department,
        "Equivalent Subjects": .equivalentSubjects,
        "Joint Subjects": .jointSubjects,
        "Meets With Subjects": .meetsWithSubjects,
        "Prerequisites": .prerequisites,
        "Corequisites": .corequisites,
        "Gir Attribute": .girAttribute,
        "Comm Req Attribute": .communicationRequirement,
        "Hass Attribute": .hassAttribute,
        "Grade Rule": .gradeRule,
        "Grade Type": .gradeType,
        "Instructors": .instructors,
        "Is Offered Fall Term": .isOfferedFall,
        "Is Offered Iap": .isOfferedIAP,
        "Is Offered Spring Term": .isOfferedSpring,
        "Is Offered Summer Term": .isOfferedSummer,
        "Is Offered This Year": .isOfferedThisYear,
        "Total Units": .totalUnits,
        "Is Variable Units": .isVariableUnits,
        "Lab Units": .labUnits,
        "Lecture Units": .lectureUnits,
        "Design Units": .designUnits,
        "Preparation Units": .preparationUnits,
        "Not Offered Year": .notOfferedYear,
        "On Line Page Number": .onlinePageNumber,
        "School Wide Electives": .schoolWideElectives,
        "Quarter Information": .quarterInformation,
        "Offering Pattern": .offeringPattern,
        "Enrollment Number": .enrollmentNumber,
        "Related Subjects": .relatedSubjects,
        "Schedule": .schedule,
    ]
    
    init?(csvHeader: String) {
        if let val = CourseAttribute.csvHeaders[csvHeader] {
            self = val
        } else {
            return nil
        }
    }
}

// MARK: - Course Model Object

class Course: NSObject {
    
    /*
     Be sure to add the new properties to the transferInformation(to:) method!!
     */
    @objc dynamic var subjectID: String? = nil
    @objc dynamic var subjectTitle: String? = nil
    @objc dynamic var subjectShortTitle: String? = nil
    @objc dynamic var subjectDescription: String? = nil
    var subjectCode: String? {
        if let subject = subjectID,
            let periodRange = subject.range(of: ".") {
            return String(subject[subject.startIndex..<periodRange.lowerBound])
        }
        return nil
    }
    @objc dynamic var department: String?
    
    @objc dynamic var equivalentSubjects: [String] = []
    @objc dynamic var jointSubjects: [String] = []
    @objc dynamic var meetsWithSubjects: [String] = []
    @objc dynamic var prerequisites: [[String]] = []
    @objc dynamic var corequisites: [[String]] = []

    var girAttribute: GIRAttribute?
    var communicationRequirement: CommunicationAttribute?
    var hassAttribute: HASSAttribute?

    @objc dynamic var gradeRule: String?
    @objc dynamic var gradeType: String?
    
    @objc dynamic var instructors: [String] = []
    @objc dynamic var isOfferedFall: Bool = false
    @objc dynamic var isOfferedIAP: Bool = false
    @objc dynamic var isOfferedSpring: Bool = false
    @objc dynamic var isOfferedSummer: Bool = false
    @objc dynamic var isOfferedThisYear: Bool = true {
        didSet {
            updateOfferingPattern()
        }
    }
    
    @objc dynamic var totalUnits: Int = 0
    @objc dynamic var isVariableUnits: Bool = false
    @objc dynamic var labUnits: Int = 0
    @objc dynamic var lectureUnits: Int = 0
    @objc dynamic var designUnits: Int = 0
    @objc dynamic var preparationUnits: Int = 0
    @objc dynamic var notOfferedYear: String? {
        didSet {
            updateOfferingPattern()
        }
    }

    @objc dynamic var onlinePageNumber: String? = nil
    @objc dynamic var schoolWideElectives: String? = nil
    
    @objc dynamic var quarterInformation: String? {
        didSet {
            guard let comps = quarterInformation?.components(separatedBy: ","),
                comps.count == 2 else {
                    quarterOffered = .wholeSemester
                    quarterBoundaryDate = nil
                    return
            }
            switch comps[0] {
            case "1":
                quarterOffered = .endOnly
            case "0":
                quarterOffered = .beginningOnly
            default:
                quarterOffered = .wholeSemester
            }
            quarterBoundaryDate = comps[1].dates?.first
        }
    }
    var quarterOffered: CourseQuarter = .wholeSemester
    var quarterBoundaryDate: Date?
    
    var offeringPattern: CourseOfferingPattern = .everyYear
    
    func updateOfferingPattern() {
        if let notOffered = notOfferedYear, notOffered.count > 0 {
            offeringPattern = .alternateYears
        } else {
            offeringPattern = isOfferedThisYear ? .everyYear : .never
        }
    }
    
    // Supplemental attributes
    @objc dynamic var enrollmentNumber: Int = 0
    var relatedSubjects: [(String, Float)] = []
    
    var schedule: [String: [[CourseScheduleItem]]]?

    override init() {
        
    }
    
    init(courseID: String, courseTitle: String, courseDescription: String, totalUnits: Int = 12) {
        super.init()
        defer {
            self.subjectID = courseID
            self.subjectTitle = courseTitle
            self.subjectShortTitle = courseTitle
            self.subjectDescription = courseDescription
            self.totalUnits = totalUnits
        }
    }
    
    override var debugDescription: String {
        get {
            return "<Course \(self.subjectID!): \(self.subjectTitle!)>"
        }
    }
    
    override func setValue(_ value: Any?, forKey key: String) {
        if let attribute = CourseAttribute(rawValue: key) {
            switch attribute {
            case .prerequisites, .corequisites:
                if (value as? [[String]]) != nil {
                    super.setValue(value, forKey: key)
                } else {
                    super.setValue(extractCourseListString(value as? String), forKey: key)
                }
            case .equivalentSubjects, .jointSubjects, .meetsWithSubjects, .instructors:
                if (value as? [String]) != nil {
                    super.setValue(value, forKey: key)
                } else {
                    super.setValue(extractListString(value as? String), forKey: key)
                }
            case .isOfferedFall, .isOfferedIAP, .isOfferedSpring, .isOfferedSummer, .isOfferedThisYear,
                 .isVariableUnits:
                if (value as? Bool) != nil {
                    super.setValue(value, forKey: key)
                } else {
                    super.setValue(extractBooleanString(value as? String), forKey: key)
                }
            case .totalUnits, .labUnits, .lectureUnits, .designUnits, .preparationUnits,
                 .enrollmentNumber:
                if (value as? Int) != nil {
                    super.setValue(value, forKey: key)
                } else {
                    super.setValue(extractIntegerString(value as? String), forKey: key)
                }
            case .offeringPattern:
                if let pattern = CourseOfferingPattern(rawValue: ((value as? String) ?? "")) {
                    self.offeringPattern = pattern
                } else {
                    print("Unidentified offering pattern: \(String(reflecting: value))")
                }
            case .girAttribute:
                self.girAttribute = GIRAttribute(rawValue: ((value as? String) ?? ""))
            case .communicationRequirement:
                self.communicationRequirement = CommunicationAttribute(rawValue: ((value as? String) ?? ""))
            case .hassAttribute:
                self.hassAttribute = HASSAttribute(rawValue: (value as? String) ?? "")
            case .schedule:
                if let formattedSched = value as? [String: [[CourseScheduleItem]]] {
                    self.schedule = formattedSched
                } else if let text = value as? String {
                    self.schedule = parseScheduleString(text)
                } else if value == nil {
                    self.schedule = nil
                }
            default:
                super.setValue(value, forKey: key)
            }
        } else {
            super.setValue(value, forKey: key)
        }
    }
    
    func parseScheduleString(_ scheduleString: String) -> [String: [[CourseScheduleItem]]] {
        var ret: [String: [[CourseScheduleItem]]] = [:]
        // Semicolons separate lecture, recitation, lab options
        let scheduleGroups = scheduleString.components(separatedBy: ";")
        for group in scheduleGroups {
            guard group.count > 0 else {
                continue
            }
            var commaComponents = group.components(separatedBy: ",")
            guard commaComponents.count > 0 else {
                continue
            }
            let groupType = commaComponents.removeFirst()
            var items: [[CourseScheduleItem]] = []
            for scheduleOption in commaComponents {
                var slashComponents = scheduleOption.components(separatedBy: "/")
                guard slashComponents.count > 1 else {
                    continue
                }
                let location = slashComponents.removeFirst()
                items.append([])
                let chunks = slashComponents.chunked(by: 3)
                for chunk in chunks {
                    guard chunk.count == 3,
                        let integerEvening = Int(chunk[1]) else {
                        continue
                    }
                    var startTime = "", endTime = ""
                    let timeString = chunk[2].lowercased().replacingOccurrences(of: "am", with: "").replacingOccurrences(of: "pm", with: "").trimmingCharacters(in: .whitespaces)
                    if timeString.contains("-") {
                        let comps = timeString.components(separatedBy: "-")
                        startTime = comps[0]
                        endTime = comps[1]
                    } else {
                        startTime = timeString
                        if let integerTime = Int(startTime) {
                            endTime = "\((integerTime % 12) + 1)"
                        } else {
                            // It may be a time like 7.30
                            if let dotRange = startTime.range(of: "."),
                                let hour = Int(String(startTime[startTime.startIndex..<dotRange.lowerBound])) {
                                endTime = "\((hour % 12) + 1).\(startTime[dotRange.upperBound..<startTime.endIndex])"
                            } else {
                                print("Start time can't be represented as an integer: \(startTime)")
                            }
                        }
                    }
                    items[items.count - 1].append(CourseScheduleItem(days: chunk[0], startTime: startTime, endTime: endTime, isEvening: (integerEvening != 0), location: location))
                }
            }
            ret[groupType] = items
        }
        
        return ret
    }
    
    func extractBooleanString(_ string: String?) -> Bool {
        if string != nil {
            return string == "Y"
        }
        return false
    }
    
    func extractIntegerString(_ string: String?) -> Int {
        if let text = string {
            return text.count > 0 ?  Int(Float(text)!) : 0
        }
        return 0
    }
    
    func extractCourseListString(_ string: String?) -> [[String]] {
        if let listString = string {
            return [listString.replacingOccurrences(of: ";", with: ",").replacingOccurrences(of: "[J]", with: "").replacingOccurrences(of: "#", with: "").components(separatedBy: ",").filter({ $0.count > 0 })]
        }
        return []
    }
    
    func extractListString(_ string: String?) -> [String] {
        if let value = string {
            var modifiedValue: String = value.replacingOccurrences(of: "[J]", with: "")
            if value.contains("#,#") {
                modifiedValue = modifiedValue.replacingOccurrences(of: " ", with: "")
            }
            modifiedValue = modifiedValue.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ";", with: ",")
            if modifiedValue.count > 0 {
                if value.contains("#,#") {
                    let subValues = modifiedValue.components(separatedBy: "#,#")
                    return ["{" + subValues[0] + "}"] + subValues[1].components(separatedBy: ",")
                } else {
                    return modifiedValue.components(separatedBy: ",")
                }
            } else {
                return []
            }
        }
        return []
    }
    
    // MARK: - Requirements
    
    func satisfies(requirement: String) -> Bool {
        let req = requirement.replacingOccurrences(of: "GIR:", with: "")
        return subjectID == req ||
            jointSubjects.contains(req) ||
            equivalentSubjects.contains(req) ||
            girAttribute?.satisfies(GIRAttribute(rawValue: req)) == true ||
            hassAttribute?.satisfies(HASSAttribute(rawValue: req)) == true ||
            communicationRequirement?.satisfies(CommunicationAttribute(rawValue: req)) == true
    }
}
