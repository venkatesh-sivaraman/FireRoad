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
        } else if let converted = GIRAttribute.descriptions.sorted(by: { $1.value.characters.count > $0.value.characters.count }).first(where: { $1.lowercased().contains(trimmedRawValue) })?.key {
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

class CourseScheduleItem: NSObject {
    var days: String
    var startTime: String
    var endTime: String
    var isEvening: Bool
    var location: String?
    
    init(days: String, startTime: String, endTime: String, isEvening: Bool = false, location: String? = nil) {
        self.days = days
        self.startTime = startTime
        self.endTime = endTime
        self.isEvening = isEvening
        self.location = location
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
        if let notOffered = notOfferedYear, notOffered.characters.count > 0 {
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
                                endTime = "\((hour % 12) + 1)\(startTime[dotRange.upperBound..<startTime.endIndex])"
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
            return text.characters.count > 0 ?  Int(Float(text)!) : 0
        }
        return 0
    }
    
    func extractCourseListString(_ string: String?) -> [[String]] {
        if let listString = string {
            return [listString.replacingOccurrences(of: ";", with: ",").replacingOccurrences(of: "#", with: "").components(separatedBy: ",").filter({ $0.characters.count > 0 })]
        }
        return []
    }
    
    func extractListString(_ string: String?) -> [String] {
        if let value = string {
            var modifiedValue: String = value
            if value.contains("#,#") {
                modifiedValue = modifiedValue.replacingOccurrences(of: " ", with: "")
            }
            modifiedValue = modifiedValue.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ";", with: ",")
            if modifiedValue.characters.count > 0 {
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
}
