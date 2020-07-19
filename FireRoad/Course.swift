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
        return attribute != nil && (self == .ciHW || attribute == self)
    }
}

enum HASSAttribute: String, AttributeEnum {
    case any = "HASS"
    case humanities = "HASS-H"
    case arts = "HASS-A"
    case socialSciences = "HASS-S"
    case elective = "HASS-E"

    static let descriptions: [HASSAttribute: String] = [
        .any: "HASS",
        .humanities: "HASS Humanities",
        .arts: "HASS Arts",
        .socialSciences: "HASS Social Sciences",
        .elective: "HASS Elective"
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

struct CourseScheduleDay: OptionSet, CustomDebugStringConvertible, Comparable, Hashable {
    var hashValue: Int {
        return rawValue
    }
    
    var rawValue: Int
    
    static let none = CourseScheduleDay(rawValue: 0)
    static let monday = CourseScheduleDay(rawValue: 1 << 6)
    static let tuesday = CourseScheduleDay(rawValue: 1 << 5)
    static let wednesday = CourseScheduleDay(rawValue: 1 << 4)
    static let thursday = CourseScheduleDay(rawValue: 1 << 3)
    static let friday = CourseScheduleDay(rawValue: 1 << 2)
    static let saturday = CourseScheduleDay(rawValue: 1 << 1)
    static let sunday = CourseScheduleDay(rawValue: 1 << 0)
    
    static let gregorianOrdering: [CourseScheduleDay: Int] = [
        .sunday: 1,
        .monday: 2,
        .tuesday: 3,
        .wednesday: 4,
        .thursday: 5,
        .friday: 6,
        .saturday: 7
    ]
    static let ordering: [CourseScheduleDay] = [
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday,
        .saturday,
        .sunday
    ]
    
    static func index(of day: CourseScheduleDay) -> Int {
        return ordering.index(of: day) ?? 0
    }
    
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
        for character in days {
            guard let value = CourseScheduleDay.ordering.first(where: { stringMappings[$0.rawValue] == String(character) }) else {
                print("Invalid day \(character)")
                continue
            }
            offered = offered.union(value)
        }
        return offered
    }
    
    static func <(lhs: CourseScheduleDay, rhs: CourseScheduleDay) -> Bool {
        return lhs.rawValue > rhs.rawValue
    }
    
    func minDay() -> CourseScheduleDay {
        for day in CourseScheduleDay.ordering {
            if contains(day) {
                return day
            }
        }
        return .none
    }
    
    func maxDay() -> CourseScheduleDay {
        for day in CourseScheduleDay.ordering.reversed() {
            if contains(day) {
                return day
            }
        }
        return .none
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
        let comps = time.components(separatedBy: .punctuationCharacters).compactMap({ Int($0) })
        guard comps.count > 0 else {
            print("Not enough components in time string: \(time)")
            return CourseScheduleTime(hour: 12, minute: 0, PM: true)
        }
        var pm = ((comps[0] <= 7) || evening)
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
        return stringEquivalent(withTimeOfDay: (PM && hour > 7 && hour != 12))
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

class CourseScheduleItem: NSObject, Comparable {
    var days: CourseScheduleDay
    var startTime: CourseScheduleTime
    var endTime: CourseScheduleTime
    var isEvening: Bool
    var location: String?
    
    init(days: String, startTime: String, endTime: String, isEvening: Bool = false, location: String? = nil) {
        self.days = CourseScheduleDay.fromString(days)
        self.startTime = CourseScheduleTime.fromString(startTime, evening: isEvening)
        self.endTime = CourseScheduleTime.fromString(endTime, evening: isEvening)
        if self.startTime.PM == true && isEvening == false {
            self.endTime.PM = true
        }
        self.isEvening = isEvening
        self.location = location
    }
    
    func stringEquivalent(withLocation: Bool = true) -> String {
        return "\(days) \(startTime)–\(endTime)" + (location != nil && withLocation ? " (\(location!))" : "")
    }
    
    override var description: String {
        return stringEquivalent(withLocation: true)
    }
    
    static func <(lhs: CourseScheduleItem, rhs: CourseScheduleItem) -> Bool {
        let minL = lhs.days.minDay()
        let minR = rhs.days.minDay()
        if minL != minR {
            return minL < minR
        }
        return lhs.startTime < rhs.startTime
    }
}

enum CourseScheduleType {
    static let lecture = "Lecture"
    static let recitation = "Recitation"
    static let lab = "Lab"
    static let design = "Design"
    static let custom = "Custom"

    static let ordering = [CourseScheduleType.lecture,
                           CourseScheduleType.recitation,
                           CourseScheduleType.design,
                           CourseScheduleType.lab,
                           CourseScheduleType.custom]
    
    private static let abbreviations = [
        CourseScheduleType.lecture: "Lec",
        CourseScheduleType.recitation: "Rec",
        CourseScheduleType.lab: "Lab",
        CourseScheduleType.design: "Des",
        CourseScheduleType.custom: ""
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

enum CourseLevel: String {
    case undergraduate = "U"
    case graduate = "G"
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
    case pdfOption
    case hasFinal
    case notOfferedYear
    case onlinePageNumber
    case schoolWideElectives
    case quarterInformation
    case offeringPattern
    case enrollmentNumber
    case relatedSubjects
    case schedule
    case subjectLevel
    case url
    case eitherPrereqOrCoreq
    case isPublic
    case creator
    case customColor
    case parent
    case children
    case isHalfClass

    case rating
    case inClassHours
    case outOfClassHours
    
    case sourceSemester
    case isHistorical
    
    case virtualStatus

    
    static let csvHeaders: [String: CourseAttribute] = [
        "Subject Id": .subjectID,
        "Subject Title": .subjectTitle,
        "Subject Short Title": .subjectShortTitle,
        "Subject Level": .subjectLevel,
        "Subject Description": .subjectDescription,
        "Subject Code": .subjectCode,
        "Department Name": .department,
        "Equivalent Subjects": .equivalentSubjects,
        "Joint Subjects": .jointSubjects,
        "Meets With Subjects": .meetsWithSubjects,
        "Prereqs": .prerequisites,
        "Coreqs": .corequisites,
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
        "PDF Option": .pdfOption,
        "Has Final": .hasFinal,
        "Not Offered Year": .notOfferedYear,
        "On Line Page Number": .onlinePageNumber,
        "School Wide Electives": .schoolWideElectives,
        "Quarter Information": .quarterInformation,
        "Offering Pattern": .offeringPattern,
        "Enrollment Number": .enrollmentNumber,
        "Related Subjects": .relatedSubjects,
        "Schedule": .schedule,
        "URL": .url,
        "Rating": .rating,
        "In-Class Hours": .inClassHours,
        "Out-of-Class Hours": .outOfClassHours,
        "Enrollment": .enrollmentNumber,
        "Prereq or Coreq": .eitherPrereqOrCoreq,
        "Custom Color": .customColor,
        "Source Semester": .sourceSemester,
        "Historical": .isHistorical,
        "Parent": .parent,
        "Children": .children,
        "Half Class": .isHalfClass,
        "Virtual Status": .virtualStatus
    ]

    static let jsonKeys: [String: CourseAttribute] = [
        "subject_id": .subjectID,
        "title": .subjectTitle,
        "level": .subjectLevel,
        "description": .subjectDescription,
        "department": .department,
        "equivalent_subjects": .equivalentSubjects,
        "joint_subjects": .jointSubjects,
        "meets_with_subjects": .meetsWithSubjects,
        "prerequisites": .prerequisites,
        "corequisites": .corequisites,
        "gir_attribute": .girAttribute,
        "communication_requirement": .communicationRequirement,
        "hass_attribute": .hassAttribute,
        "instructors": .instructors,
        "offered_fall": .isOfferedFall,
        "offered_IAP": .isOfferedIAP,
        "offered_spring": .isOfferedSpring,
        "offered_summer": .isOfferedSummer,
        "offered_this_year": .isOfferedThisYear,
        "units": .totalUnits,
        "total_units": .totalUnits,
        "is_variable_units": .isVariableUnits,
        "lab_units": .labUnits,
        "lecture_units": .lectureUnits,
        "design_units": .designUnits,
        "preparation_units": .preparationUnits,
        "pdf_option": .pdfOption,
        "has_final": .hasFinal,
        "not_offered_year": .notOfferedYear,
        "quarter_information": .quarterInformation,
        "offering_pattern": .offeringPattern,
        "enrollment_number": .enrollmentNumber,
        "related_subjects": .relatedSubjects,
        "schedule": .schedule,
        "url": .url,
        "rating": .rating,
        "in_class_hours": .inClassHours,
        "out_of_class_hours": .outOfClassHours,
        "prereq_or_coreq": .eitherPrereqOrCoreq,
        "public": .isPublic,
        "creator": .creator,
        "custom_color": .customColor,
        "source_semester": .sourceSemester,
        "is_historical": .isHistorical,
        "parent": .parent,
        "children": .children,
        "is_half_class": .isHalfClass,
        "virtual_status": .virtualStatus
    ]

    init?(csvHeader: String) {
        if let val = CourseAttribute.csvHeaders[csvHeader] {
            self = val
        } else {
            return nil
        }
    }
    
    init?(jsonKey: String) {
        if jsonKey == "id" {
            // Alternate key used in old road files
            self = .subjectID
        } else if let val = CourseAttribute.jsonKeys[jsonKey] {
            self = val
        } else {
            return nil
        }
    }
    
    func jsonKey() -> String {
        return CourseAttribute.jsonKeys.first(where: { $1 == self })?.key ?? "KEY_NOT_FOUND"
    }
}

// MARK: - Course Model Object

class Course: NSObject {
    
    @objc dynamic var subjectID: String? = nil
    @objc dynamic var subjectTitle: String? = nil
    @objc dynamic var subjectShortTitle: String? = nil
    var subjectLevel: CourseLevel? = nil
    @objc dynamic var subjectDescription: String? = nil
    var subjectCode: String? {
        if let subject = subjectID,
            let periodRange = subject.range(of: ".") {
            return String(subject[subject.startIndex..<periodRange.lowerBound])
        } else if isGeneric, girAttribute != nil {
            return "GIR"
        } else if isGeneric, let index = subjectID?.rangeOfCharacter(from: .whitespaces)?.lowerBound {
            return String(subjectID![subjectID!.startIndex..<index])
        } else if isGeneric {
            return String(subjectID!)
        }

        return nil
    }
    @objc dynamic var department: String?
    
    private var _equivalentSubjects: [String] = []
    @objc dynamic var equivalentSubjects: [String] {
        get {
            if let cache = parseDeferredValues[.equivalentSubjects] {
                _equivalentSubjects = extractListString(cache)
                parseDeferredValues[.equivalentSubjects] = nil
            }
            return _equivalentSubjects
        } set {
            _equivalentSubjects = newValue
        }
    }
    private var _jointSubjects: [String] = []
    @objc dynamic var jointSubjects: [String] {
        get {
            if let cache = parseDeferredValues[.jointSubjects] {
                _jointSubjects = extractListString(cache)
                parseDeferredValues[.jointSubjects] = nil
            }
            return _jointSubjects
        } set {
            _jointSubjects = newValue
        }
    }
    private var _meetsWithSubjects: [String] = []
    @objc dynamic var meetsWithSubjects: [String] {
        get {
            if let cache = parseDeferredValues[.meetsWithSubjects] {
                _meetsWithSubjects = extractListString(cache)
                parseDeferredValues[.meetsWithSubjects] = nil
            }
            return _meetsWithSubjects
        } set {
            _meetsWithSubjects = newValue
        }
    }
    
    private var _prerequisites: RequirementsListStatement? = nil
    @objc dynamic var prerequisites: RequirementsListStatement? {
        get {
            if let cache = parseDeferredValues[.prerequisites] {
                if cache.count > 0 {
                    _prerequisites = RequirementsListStatement(statement: cache.replacingOccurrences(of: "'", with: "\""))
                }
                parseDeferredValues[.prerequisites] = nil
            }
            return _prerequisites
        } set {
            _prerequisites = newValue
        }
    }
    private var _corequisites: RequirementsListStatement? = nil
    @objc dynamic var corequisites: RequirementsListStatement? {
        get {
            if let cache = parseDeferredValues[.corequisites] {
                if cache.count > 0 {
                    _corequisites = RequirementsListStatement(statement: cache.replacingOccurrences(of: "'", with: "\""))
                }
                parseDeferredValues[.corequisites] = nil
            }
            return _corequisites
        } set {
            _corequisites = newValue
        }
    }
    
    @objc dynamic var eitherPrereqOrCoreq: Bool = false

    var girAttribute: GIRAttribute?
    var communicationRequirement: CommunicationAttribute?
    var hassAttribute: [HASSAttribute]?

    @objc dynamic var gradeRule: String?
    @objc dynamic var gradeType: String?
    
    private var _instructors: [String] = []
    @objc dynamic var instructors: [String] {
        get {
            if let cache = parseDeferredValues[.instructors] {
                _instructors = extractListString(cache)
                parseDeferredValues[.instructors] = nil
            }
            return _instructors
        } set {
            _instructors = newValue
        }
    }
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
    @objc dynamic var hasFinal: Bool = false
    @objc dynamic var pdfOption: Bool = false
    @objc dynamic var isHalfClass: Bool = false
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
    
    @objc dynamic var url: String?
    @objc dynamic var sourceSemester: String?
    @objc dynamic var isHistorical: Bool = false

    @objc dynamic var parent: String?
    @objc dynamic var _children: [String] = []
    @objc dynamic var children: [String] {
        get {
            if let cache = parseDeferredValues[.children] {
                _children = extractListString(cache)
                parseDeferredValues[.children] = nil
            }
            return _children
        } set {
            _children = newValue
        }
    }

    // Supplemental attributes
    @objc dynamic var enrollmentNumber: Int = 0
    var relatedSubjects: [(String, Float)] = []
    
    var schedule: [String: [[CourseScheduleItem]]]?
    
    @objc dynamic var rating: Float = 0.0
    @objc dynamic var inClassHours: Float = 0.0
    @objc dynamic var outOfClassHours: Float = 0.0
    
    var isGeneric = false
    /// If non-null and beginning with @, defines an index for which to retrieve a color
    @objc dynamic var customColor: String?
    @objc dynamic var isPublic: Bool = true
    /// If non-null, indicates that this is a custom course
    @objc dynamic var creator: String?
    @objc dynamic var virtualStatus: String?

    static let genericCourses: [String: Course] = {
        var ret: [String: Course] = [:]
        let genericDesc = "Use this generic subject to indicate that you are fulfilling a requirement, but do not yet have a specific subject selected."
        for (value, description) in CommunicationAttribute.descriptions {
            let course = Course(courseID: value.rawValue, courseTitle: "Generic \(description)", courseDescription: genericDesc, generic: true)
            course.hassAttribute = [.any]
            course.communicationRequirement = value
            course.isOfferedFall = true
            course.isOfferedSpring = true
            course.isOfferedIAP = true
            ret[value.rawValue] = course
        }
        for (value, description) in HASSAttribute.descriptions where value != .any {
            var course = Course(courseID: value.rawValue, courseTitle: "Generic \(description)", courseDescription: genericDesc, generic: true)
            course.hassAttribute = [value]
            course.isOfferedFall = true
            course.isOfferedSpring = true
            course.isOfferedIAP = true
            ret[value.rawValue] = course
            
            let ci = CommunicationAttribute.ciH
            course = Course(courseID: [ci.rawValue, value.rawValue].joined(separator: " "), courseTitle: "Generic \(ci.rawValue) \(description)", courseDescription: genericDesc, generic: true)
            course.hassAttribute = [value]
            course.communicationRequirement = ci
            course.isOfferedFall = true
            course.isOfferedSpring = true
            course.isOfferedIAP = true
            ret[course.subjectID!] = course
        }
        for (value, description) in GIRAttribute.descriptions {
            let course = Course(courseID: value.rawValue, courseTitle: "Generic \(description)", courseDescription: genericDesc, generic: true)
            course.girAttribute = value
            course.isOfferedFall = true
            course.isOfferedSpring = true
            course.isOfferedIAP = true
            ret[value.rawValue] = course
        }
        return ret
    }()
    
    private var parseDeferredValues: [CourseAttribute: String] = [:]

    override init() {
        
    }
    
    init(courseID: String, courseTitle: String, courseDescription: String, totalUnits: Int = 12, generic: Bool = false) {
        super.init()
        defer {
            self.subjectID = courseID
            self.subjectTitle = courseTitle
            self.subjectShortTitle = courseTitle
            self.subjectDescription = courseDescription
            self.totalUnits = totalUnits
            self.isGeneric = generic
        }
    }
    
    init(json: [String: Any]) {
        super.init()
        defer {
            readJSON(json)
        }
    }
    
    override var debugDescription: String {
        get {
            return "<Course \(self.subjectID!): \(self.subjectTitle!)>"
        }
    }
    
    func readJSON(_ json: [String: Any]) {
        for (key, val) in json {
            guard let attr = CourseAttribute(jsonKey: key) else {
                continue
            }
            setValue(val, forKey: attr.rawValue)
        }
    }
    
    /// Not a full JSON encoding - just enough to identify the course
    func toJSON() -> [String: Any] {
        var ret: [String: Any] = [:]
        ret[CourseAttribute.subjectID.jsonKey()] = subjectID
        ret[CourseAttribute.subjectTitle.jsonKey()] = subjectTitle
        ret["units"] = totalUnits // Used in road file as an alternate syntax for "total_units"
        if creator != nil {
            ret[CourseAttribute.creator.jsonKey()] = creator
            ret[CourseAttribute.isPublic.jsonKey()] = isPublic
            ret[CourseAttribute.inClassHours.jsonKey()] = inClassHours
            ret[CourseAttribute.outOfClassHours.jsonKey()] = outOfClassHours
            ret[CourseAttribute.isOfferedFall.jsonKey()] = isOfferedFall
            ret[CourseAttribute.isOfferedIAP.jsonKey()] = isOfferedIAP
            ret[CourseAttribute.isOfferedSpring.jsonKey()] = isOfferedSpring
            ret[CourseAttribute.isOfferedSummer.jsonKey()] = isOfferedSummer
            if let schedule = schedule {
                let scheduleString = schedule.map({ (type, items) -> String in
                    return type + "," + items.map({ (itemSet) -> String in
                        return (itemSet.first?.location ?? "") + "/" + itemSet.map({ item -> String in
                            return [item.days.stringEquivalent(),
                                    item.isEvening ? "1" : "0",
                                    item.startTime.stringEquivalent().replacingOccurrences(of: ":", with: ".") + "-" +
                                        item.endTime.stringEquivalent().replacingOccurrences(of: ":", with: ".")].joined(separator: "/")
                        }).joined(separator: "/")
                    }).joined(separator: ",")
                }).joined(separator: ";")
                ret[CourseAttribute.schedule.jsonKey()] = scheduleString
            }
        }
        if let color = customColor {
            ret[CourseAttribute.customColor.jsonKey()] = color
        }
        return ret
    }
    
    override func setValue(_ value: Any?, forKey key: String) {
        if let attribute = CourseAttribute(rawValue: key) {
            switch attribute {
            case .prerequisites, .corequisites:
                if (value as? RequirementsListStatement) != nil {
                    super.setValue(value, forKey: key)
                } else {
                    parseDeferredValues[attribute] = value as? String
                }
            case .equivalentSubjects, .jointSubjects, .meetsWithSubjects, .instructors, .children:
                if (value as? [String]) != nil {
                    super.setValue(value, forKey: key)
                } else {
                    parseDeferredValues[attribute] = value as? String
                }
            case .isOfferedFall, .isOfferedIAP, .isOfferedSpring, .isOfferedSummer, .isOfferedThisYear,
                 .isVariableUnits, .hasFinal, .pdfOption, .eitherPrereqOrCoreq, .isPublic,
                 .isHistorical, .isHalfClass:
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
            case .rating, .inClassHours, .outOfClassHours:
                if (value as? Float) != nil {
                    super.setValue(value, forKey: key)
                } else {
                    super.setValue(extractFloatString(value as? String), forKey: key)
                }
            case .girAttribute:
                self.girAttribute = GIRAttribute(rawValue: ((value as? String) ?? ""))
            case .communicationRequirement:
                self.communicationRequirement = CommunicationAttribute(rawValue: ((value as? String) ?? ""))
            case .hassAttribute:
                self.hassAttribute = (value as? String)?.components(separatedBy: ",").compactMap { HASSAttribute(rawValue: $0) }
            case .schedule:
                if let formattedSched = value as? [String: [[CourseScheduleItem]]] {
                    self.schedule = formattedSched
                } else if let text = value as? String {
                    self.schedule = parseScheduleString(text)
                } else if value == nil {
                    self.schedule = nil
                }
            case .subjectLevel:
                if let string = value as? String {
                    self.subjectLevel = CourseLevel(rawValue: string)
                } else {
                    print("Unidentified subject level: \(value ?? "nil")")
                }
            case .customColor:
                if let string = value as? String {
                    self.customColor = string
                }
            case .virtualStatus:
                if let string = value as? String {
                    self.virtualStatus = string
                }
            default:
                if let string = value as? String {
                    super.setValue(string.replacingOccurrences(of: "\\n", with: "\n"), forKey: key)
                } else {
                    super.setValue(value, forKey: key)
                }
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
            let earlyTime = CourseScheduleItem(days: "M", startTime: "9", endTime: "10", isEvening: false, location: nil)
            if items.count > 0 {
                ret[groupType] = items.sorted(by: { ($0.first ?? earlyTime) < ($1.first ?? earlyTime) })
            }
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
    
    func extractFloatString(_ string: String?) -> Float {
        if let text = string {
            return Float(text) ?? 0.0
        }
        return 0.0
    }

    func extractCourseListString(_ string: String?) -> [[String]] {
        if let listString = string {
            return listString.components(separatedBy: ";").map { item in
                item.replacingOccurrences(of: "[J]", with: "").replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "#", with: "").components(separatedBy: ",").filter({ $0.count > 0 })
            }
        }
        return []
    }
    
    func extractListString(_ string: String?) -> [String] {
        if let value = string {
            var modifiedValue: String = value.replacingOccurrences(of: "[J]", with: "").replacingOccurrences(of: "\\n", with: "\n")
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
    
    /**
     If `allCourses` is not nil, it may be a list of courses that can potentially
     satisfy the requirement. If a combination of courses satisfies the requirement,
     this method will return true.
     */
    func satisfies(requirement: String, allCourses: [Course]? = nil) -> Bool {
        let req = requirement.replacingOccurrences(of: "GIR:", with: "")
        if subjectID == req ||
            jointSubjects.contains(req) ||
            equivalentSubjects.contains(req) {
            return true
        }
        
        // For example: 6.00 satisfies the 6.0001 requirement
        if self.children.count > 0, self.children.contains(req) {
            return true
        }
        
        // For example: 6.0001 and 6.0002 together satisfy the 6.00 requirement
        if let courses = allCourses,
            req == self.parent,
            let parentCourse = CourseManager.shared.getCourse(withID: req),
            parentCourse.children.count > 0 {
            
            let courseIDs = Set<String>(courses.compactMap({ $0.subjectID }))
            let childrenIDs = Set<String>(parentCourse.children)
            // Check that all children are present in the list of courses
            if childrenIDs.intersection(courseIDs) == childrenIDs {
                return true
            }
        }
        
        return false
    }
    
    /**
     Returns whether or not this course satisfies a general requirement, such as
     GIR, HASS, or CI.
     */
    func satisfiesGeneralRequirement(_ requirement: String) -> Bool {
        let req = requirement.replacingOccurrences(of: "GIR:", with: "")
        if girAttribute?.satisfies(GIRAttribute(rawValue: req)) == true ||
            hassAttribute?.first(where: { $0.satisfies(HASSAttribute(rawValue: req)) }) != nil ||
            communicationRequirement?.satisfies(CommunicationAttribute(rawValue: req)) == true {
            return true
        }
        return false
    }
    
    class func isRequirementAutomaticallySatisfied(_ requirement: String) -> Bool {
        let req = requirement.replacingOccurrences(of: "GIR:", with: "")
        if CourseManager.shared.getCourse(withID: req) != nil {
            return false
        }
        if GIRAttribute(rawValue: req) != nil ||
            HASSAttribute(rawValue: req) != nil ||
            CommunicationAttribute(rawValue: req) != nil {
            return false
        }
        return true
    }
}
