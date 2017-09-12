//
//  Course.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/2/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

func descriptionForGIR(attribute: String) -> String {
    let mod = attribute.replacingOccurrences(of: "GIR:", with: "")
    switch mod {
    case "PHY1": return "Physics I GIR"
    case "PHY2": return "Physics II GIR"
    case "CHEM": return "Chemistry GIR"
    case "BIOL": return "Biology GIR"
    case "CAL1": return "Calculus I GIR"
    case "CAL2": return "Calculus II GIR"
    case "LAB": return "Lab GIR"
    case "REST": return "REST GIR"
    default: return ""
    }
}

class Course: NSObject {
    
    var academicYear: String? = nil
    var communicationRequirement: String? = nil {
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
    var communicationReqDescription: String? = nil
    var departmentCode: String? = nil
    var departmentName: String? = nil
    var designUnits: Int = 0
    var effectiveTermCode: String? = nil
    var equivalentSubjects: [String] = []
    var fallInstructors: [String] = []
    var GIRAttribute: String? = nil {
        didSet {
            if self.GIRAttribute != nil {
                self.GIRAttributeDescription = descriptionForGIR(attribute: self.GIRAttribute!)
            } else {
                self.GIRAttributeDescription = nil
            }
        }
    }
    var GIRAttributeDescription: String? = nil
    var gradeRule: String? = nil
    var gradeRuleDescription: String? = nil
    var gradeType: String? = nil
    var gradeTypeDescription: String? = nil
    var hassAttribute: String? = nil {
        didSet {
            if self.hassAttribute != nil {
                let comps = self.hassAttribute!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).components(separatedBy: ",")
                var descriptions: [String] = []
                for comp in comps {
                    switch comp {
                    case "HH": descriptions.append("HASS-H")
                    case "HA": descriptions.append("HASS-A")
                    case "HS": descriptions.append("HASS-S")
                    default: break
                    }
                }
                self.hassAttributeDescription = descriptions.joined(separator: ", ")
            } else {
                self.hassAttributeDescription = nil
            }
        }
    }
    var hassAttributeDescription: String? = nil
    var isOfferedFall: Bool = false
    var isOfferedIAP: Bool = false
    var isOfferedSpring: Bool = false
    var isOfferedSummer: Bool = false
    var isOfferedThisYear: Bool = false
    var isVariableUnits: Bool = false
    var jointSubjects: [String] = []
    var labUnits: Int = 0
    var lastActivityDate: Date? = nil
    var lectureUnits: Int = 0
    var masterSubjectID: String? = nil
    var meetsWithSubjects: [String] = []
    var onlinePageNumber: String? = nil
    var preparationUnits: Int = 0
    var prerequisites: [String] = []    //Coreqs in brackets
    var printSubjectID: String? = nil
    var schoolWideElectives: String? = nil
    var springInstructors: [String] = []
    var statusChange: String? = nil
    var subjectCode: String? = nil
    var subjectDescription: String? = nil
    var subjectID: String? = nil
    var subjectNumber: String? = nil
    var subjectShortTitle: String? = nil
    var subjectTitle: String? = nil
    var termDuration: String? = nil
    var totalUnits: Int = 0
    var writingRequirement: String? = nil
    var writingReqDescription: String? = nil
    
    // Supplemental attributes
    var enrollmentNumber: Int = 0
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
        course.fallInstructors = fallInstructors
        course.GIRAttribute = GIRAttribute
        course.GIRAttributeDescription = GIRAttributeDescription
        course.gradeRule = gradeRule
        course.gradeRuleDescription = gradeRuleDescription
        course.gradeType = gradeType
        course.gradeTypeDescription = gradeTypeDescription
        course.hassAttribute = hassAttribute
        course.hassAttributeDescription = hassAttributeDescription
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
        course.printSubjectID = printSubjectID
        course.schoolWideElectives = schoolWideElectives
        course.springInstructors = springInstructors
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
    }
    
    override func setValue(_ value: Any?, forKey key: String) {
        var modifiedValue = value
        if self.value(forKey: key) is Int {
            if value != nil {
                if value is String {
                    modifiedValue = (value as! String).characters.count > 0 ?  Int(Float(value as! String)!) : 0
                }
            } else {
                modifiedValue = 0
            }
        } else if self.value(forKey: key) is Bool {
            if value != nil {
                if value is String {
                    modifiedValue = (value as! String) == "Y"
                }
            } else {
                modifiedValue = false
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
