//
//  CourseCatalogConstants.swift
//  CourseCatalogScrubber
//
//  Created by Venkatesh Sivaraman on 1/21/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import Foundation

enum CourseCatalogConstants {
    static let equivalentSubjectsPrefix = "credit cannot also be received for"
    static let notOfferedPrefix = "not offered academic year"
    static let unitsPrefix = "units:"
    static let unitsArrangedPrefix = "units arranged"
    static let prerequisitesPrefix = "prereq:"
    static let corequisitesPrefix = "coreq:"
    static let meetsWithPrefix = "subject meets with"
    static let jointSubjectsPrefix = "same subject as"
    static let pdfString = "P/D/F"
    
    static let undergrad = "undergrad"
    static let graduate = "graduate"
    static let undergradValue = "U"
    static let graduateValue = "G"
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
    case isVariableUnits
    case pdfOption
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
    case subjectLevel
    
    // Evaluation fields
    case averageRating
    case averageInClassHours
    case averageOutOfClassHours
    case raterCount
    case enrollment
    
    var debugDescription: String {
        return rawValue
    }
    
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
        .isVariableUnits: "Is Variable Units",
        .pdfOption: "PDF Option",
        .hasFinal: "Has Final",
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
        .quarterInformation: "Quarter Information",
        .subjectLevel: "Subject Level",
        .averageRating: "Rating",
        .averageInClassHours: "In-Class Hours",
        .averageOutOfClassHours: "Out-of-Class Hours",
        .raterCount: "Rater Count",
        .enrollment: "Enrollment"
    ]
}
