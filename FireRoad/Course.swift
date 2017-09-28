//
//  Course.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/2/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

let GIRDescriptions = [
    "PHY1": "Physics I GIR",
    "PHY2": "Physics II GIR",
    "CHEM": "Chemistry GIR",
    "BIOL": "Biology GIR",
    "CAL1": "Calculus I GIR",
    "CAL2": "Calculus II GIR",
    "LAB": "Lab GIR",
    "REST": "REST GIR"
]

func descriptionForGIR(attribute: String) -> String {
    let mod = attribute.replacingOccurrences(of: "GIR:", with: "")
    if let converted = GIRDescriptions[mod] {
        return converted
    }
    return attribute
}

enum CourseOfferingPattern: String {
    case everyYear = "Every year"
    case alternateYears = "Alternate years"
    case never = "Never"
}

class Course: NSObject {
    
    /*
     Be sure to add the new properties to the transferInformation(to:) method!!
     */
    @objc dynamic var academicYear: String? = nil
    @objc dynamic var communicationRequirement: String? = nil {
        didSet {
            if self.communicationRequirement != nil {
                switch self.communicationRequirement! {
                case "CIH": self.communicationReqDescription = "CI-H"
                case "CIHW": self.communicationReqDescription = "CI-HW"
                default: break
                }
            } else {
                self.communicationReqDescription = nil
            }
        }
    }
    @objc dynamic var communicationReqDescription: String? = nil
    @objc dynamic var departmentCode: String? = nil
    @objc dynamic var departmentName: String? = nil
    @objc dynamic var designUnits: Int = 0
    @objc dynamic var effectiveTermCode: String? = nil
    @objc dynamic var equivalentSubjects: [String] = []
    @objc dynamic var GIRAttribute: String? = nil {
        didSet {
            if self.GIRAttribute != nil {
                self.GIRAttributeDescription = descriptionForGIR(attribute: self.GIRAttribute!)
            } else {
                self.GIRAttributeDescription = nil
            }
        }
    }
    @objc dynamic var GIRAttributeDescription: String? = nil
    @objc dynamic var gradeRule: String? = nil
    @objc dynamic var gradeRuleDescription: String? = nil
    @objc dynamic var gradeType: String? = nil
    @objc dynamic var gradeTypeDescription: String? = nil
    @objc dynamic var hassAttribute: String? = nil {
        didSet {
            if self.hassAttribute != nil {
                let comps = self.hassAttribute!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).components(separatedBy: ",")
                var descriptions: [String] = []
                for comp in comps {
                    switch comp {
                    case "HH", "HASS Humanities": descriptions.append("HASS-H")
                    case "HA", "HASS Arts": descriptions.append("HASS-A")
                    case "HS", "HASS Social Sciences": descriptions.append("HASS-S")
                    default: break
                    }
                }
                self.hassAttributeDescription = descriptions.joined(separator: ", ")
            } else {
                self.hassAttributeDescription = nil
            }
        }
    }
    @objc dynamic var hassAttributeDescription: String? = nil
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
    @objc dynamic var isVariableUnits: Bool = false
    @objc dynamic var jointSubjects: [String] = []
    @objc dynamic var labUnits: Int = 0
    @objc dynamic var lastActivityDate: Date? = nil
    @objc dynamic var lectureUnits: Int = 0
    @objc dynamic var masterSubjectID: String? = nil
    @objc dynamic var meetsWithSubjects: [String] = []
    @objc dynamic var notOfferedYear: String? {
        didSet {
            updateOfferingPattern()
        }
    }
    @objc dynamic var onlinePageNumber: String? = nil
    @objc dynamic var preparationUnits: Int = 0
    @objc dynamic var prerequisites: [[String]] = []
    @objc dynamic var corequisites: [[String]] = []
    @objc dynamic var printSubjectID: String? = nil
    @objc dynamic var schoolWideElectives: String? = nil
    @objc dynamic var statusChange: String? = nil
    @objc dynamic var subjectCode: String? = nil
    @objc dynamic var subjectDescription: String? = nil
    @objc dynamic var subjectID: String? = nil {
        didSet {
            if subjectCode == nil, let subject = subjectID,
                let periodRange = subject.range(of: ".") {
                subjectCode = String(subject[subject.startIndex..<periodRange.lowerBound])
            }
        }
    }
    @objc dynamic var subjectNumber: String? = nil
    @objc dynamic var subjectShortTitle: String? = nil
    @objc dynamic var subjectTitle: String? = nil
    @objc dynamic var termDuration: String? = nil
    @objc dynamic var totalUnits: Int = 0
    @objc dynamic var writingRequirement: String? = nil
    @objc dynamic var writingReqDescription: String? = nil
    
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

    override init() {
        
    }
    
    init(courseID: String, courseTitle: String, courseDescription: String, totalUnits: Int = 12) {
        self.subjectID = courseID
        self.masterSubjectID = courseID
        self.subjectTitle = courseTitle
        self.subjectShortTitle = courseTitle
        self.subjectDescription = courseDescription
        self.totalUnits = totalUnits
    }
    
    override var debugDescription: String {
        get {
            return "<Course \(self.subjectID!): \(self.subjectTitle!)>"
        }
    }
    
    func transferInformation(to course: Course) {
        course.academicYear = academicYear
        course.communicationRequirement = communicationRequirement
        course.communicationReqDescription = communicationReqDescription
        course.departmentCode = departmentCode
        course.departmentName = departmentName
        course.designUnits = designUnits
        course.effectiveTermCode = effectiveTermCode
        course.equivalentSubjects = equivalentSubjects
        course.GIRAttribute = GIRAttribute
        course.GIRAttributeDescription = GIRAttributeDescription
        course.gradeRule = gradeRule
        course.gradeRuleDescription = gradeRuleDescription
        course.gradeType = gradeType
        course.gradeTypeDescription = gradeTypeDescription
        course.hassAttribute = hassAttribute
        course.hassAttributeDescription = hassAttributeDescription
        course.instructors = instructors
        course.isOfferedFall = isOfferedFall
        course.isOfferedIAP = isOfferedIAP
        course.isOfferedSpring = isOfferedSpring
        course.isOfferedSummer = isOfferedSummer
        course.isOfferedThisYear = isOfferedThisYear
        course.isVariableUnits = isVariableUnits
        course.jointSubjects = jointSubjects
        course.labUnits = labUnits
        course.lastActivityDate = lastActivityDate
        course.lectureUnits = lectureUnits
        course.masterSubjectID = masterSubjectID
        course.meetsWithSubjects = meetsWithSubjects
        course.onlinePageNumber = onlinePageNumber
        course.preparationUnits = preparationUnits
        course.prerequisites = prerequisites
        course.corequisites = corequisites
        course.printSubjectID = printSubjectID
        course.schoolWideElectives = schoolWideElectives
        course.statusChange = statusChange
        course.subjectCode = subjectCode
        course.subjectDescription = subjectDescription
        course.subjectID = subjectID
        course.subjectNumber = subjectNumber
        course.subjectShortTitle = subjectShortTitle
        course.subjectTitle = subjectTitle
        course.termDuration = termDuration
        course.totalUnits = totalUnits
        course.writingRequirement = writingRequirement
        course.writingReqDescription = writingReqDescription
        course.enrollmentNumber = enrollmentNumber
        course.relatedSubjects = relatedSubjects
    }
    
    override func setValue(_ value: Any?, forKey key: String) {
        var modifiedValue = value
        if type(of: self.value(forKey: key)) == Bool.self {
            if value != nil {
                if value is String {
                    modifiedValue = (value as! String) == "Y"
                }
            } else {
                modifiedValue = false
            }
        } else if type(of: self.value(forKey: key)) == Int.self {
            if value != nil {
                if value is String {
                    modifiedValue = (value as! String).characters.count > 0 ?  Int(Float(value as! String)!) : 0
                }
            } else {
                modifiedValue = 0
            }
        } else if key == "prerequisites" || key == "corequisites" { // [[String]] type
            if value != nil,
                let listString = value as? String {
                modifiedValue = [listString.replacingOccurrences(of: ";", with: ",").replacingOccurrences(of: "#", with: "").components(separatedBy: ",").filter({ $0.characters.count > 0 })]
            } else {
                modifiedValue = []
            }
        } else if self.value(forKey: key) is [String] {
            if value != nil {
                if value is String {
                    if (value as! String).contains("#,#") {
                        modifiedValue = (modifiedValue as! String).replacingOccurrences(of: " ", with: "")
                    }
                    modifiedValue = (modifiedValue as! String).trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ";", with: ",")
                    if (modifiedValue as! String).characters.count > 0 {
                        if (value as! String).contains("#,#") {
                            let subValues = (modifiedValue as! String).components(separatedBy: "#,#")
                            modifiedValue = ["{" + subValues[0] + "}"] + subValues[1].components(separatedBy: ",")
                        } else {
                            modifiedValue = (modifiedValue as! String).components(separatedBy: ",")
                        }
                    } else {
                        modifiedValue = []
                    }
                }
            } else {
                modifiedValue = []
            }
        }
        super.setValue(modifiedValue, forKey: key)
    }
}
