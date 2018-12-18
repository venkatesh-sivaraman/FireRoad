//
//  main.swift
//  CourseCatalogScrubber
//
//  Created by Venkatesh Sivaraman on 9/22/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import Foundation

let urlPrefix = "http://student.mit.edu/catalog/"
let urlSuffix = ".html"
let urlLastPrefix = "m"

let courseNumbers = [
    "1", "2", "3", "4",
    "5", "6", "7", "8",
    "9", "10", "11", "12",
    "14", "15", "16", "17",
    "18", "20", "21", "21A",
    "21W", "CMS", "21G", "21H",
    "21L", "21M", "WGS", "22",
    "24", "CC", "CSB", "EC",
    "EM", "ES", "HST", "IDS",
    "MAS", "SCM",
    "AS", "MS", "NS",
    "STS", "SWE", "SP"
]

let alphabet = "abcdefghijklmnopqrstuvwxyz"

let parser = CourseCatalogParser()

func courses(from courseCode: String) -> [[CourseAttribute: Any]] {
    if let url = URL(string: "\(urlPrefix)\(urlLastPrefix)\(courseCode)\(urlSuffix)") {
        parser.catalogURL = url
        let regions = parser.htmlRegions(from: url)
        var courses: [[CourseAttribute: Any]] = []
        // Autofill empty regions with the subsequent course information
        var i = 0
        var regionsToAutofill: [HTMLNodeExtractor.HTMLRegion] = []
        while i < regions.count {
            let region = regions[i]
            if region.nodes.count == 1 {
                regionsToAutofill.append(region)
                i += 1
            } else {
                let course = parser.extractCourseProperties(from: region)
                for autofillRegion in regionsToAutofill {
                    var copiedCourse: [CourseAttribute: Any] = [:]
                    for (attribute, value) in course {
                        copiedCourse[attribute] = value
                    }
                    copiedCourse[.subjectID] = autofillRegion.title
                    copiedCourse[.schedule] = nil
                    courses.append(copiedCourse)
                }
                courses.append(course)
                i += 1
                regionsToAutofill = []
            }
        }
        return courses
    }
    return []
}

func writeCondensedCourses(_ courses: [[CourseAttribute: Any]], to file: String) {
    //Academic Year,Subject Id,Subject Code,Subject Number,Print Subject Id,Subject Short Title,Subject Title,Total Units,Is Offered This Year,Is Offered Fall Term,Is Offered Iap,Is Offered Spring Term,Is Offered Summer Term
    do {
        try parser.writeCourses(courses, to: file, attributes: [
            .subjectID,
            .title,
            .subjectLevel,
            .totalUnits,
            .prerequisites,
            .corequisites,
            .oldPrerequisites,
            .oldCorequisites,
            .eitherPrereqOrCoreq,
            .jointSubjects,
            .equivalentSubjects,
            .meetsWithSubjects,
            .notOfferedYear,
            .offeredFall,
            .offeredIAP,
            .offeredSpring,
            .offeredSummer,
            .quarterInformation,
            .instructors,
            .communicationRequirement,
            .hassRequirement,
            .GIR,
            .averageInClassHours,
            .averageOutOfClassHours,
            .enrollment
            ])
    } catch {
        print("Error writing condensed course file: \(error)")
    }
}

func writeFullCourses(_ courses: [[CourseAttribute: Any]], to file: String) {
    //Academic Year,Effective Term Code,Subject Id,Subject Code,Subject Number,Source Subject Id,Print Subject Id,Department Code,Department Name,Subject Short Title,Subject Title,Is Variable Units,Lecture Units,Lab Units,Preparation Units,Total Units,Gir Attribute,Gir Attribute Desc,Comm Req Attribute,Comm Req Attribute Desc,Write Req Attribute,Write Req Attribute Desc,Supervisor Attribute Desc,Prerequisites,Subject Description,Joint Subjects,School Wide Electives,Meets With Subjects,Equivalent Subjects,Is Offered This Year,Is Offered Fall Term,Is Offered Iap,Is Offered Spring Term,Is Offered Summer Term,Fall Instructors,Spring Instructors,Status Change,Last Activity Date,Warehouse Load Date,Master Subject Id,Hass Attribute,Hass Attribute Desc,Term Duration,On Line Page Number
    do {
        try parser.writeCourses(courses, to: file, attributes: [
            .subjectID,
            .title,
            .subjectLevel,
            .lectureUnits,
            .labUnits,
            .preparationUnits,
            .totalUnits,
            .isVariableUnits,
            .hasFinal,
            .GIR,
            .communicationRequirement,
            .hassRequirement,
            .prerequisites,
            .corequisites,
            .oldPrerequisites,
            .oldCorequisites,
            .eitherPrereqOrCoreq,
            .description,
            .jointSubjects,
            .meetsWithSubjects,
            .equivalentSubjects,
            .notOfferedYear,
            .offeredFall,
            .offeredIAP,
            .offeredSpring,
            .offeredSummer,
            .quarterInformation,
            .instructors,
            .schedule,
            .URL,
            .averageRating,
            .averageInClassHours,
            .averageOutOfClassHours,
            .enrollment
            ])
    } catch {
        print("Error writing condensed course file: \(error)")
    }
}

var outputDirectory: String = CommandLine.arguments.count >= 2 ? CommandLine.arguments[1] : "/Users/venkatesh-sivaraman/Documents/ScrapedCourses/"

var evaluationData: [String: [[String: Any]]]?
if CommandLine.arguments.count >= 3 {
    evaluationData = loadEvaluationsJSON(from: CommandLine.arguments[2])
}

var allCourses: [[CourseAttribute: Any]] = []
var departmentCourses: [[CourseAttribute: Any]] = []
for courseCode in courseNumbers {
    departmentCourses = []
    var originalHTML: String?
    for letter in alphabet {
        let totalCode = courseCode + "\(letter)"
        if let html = originalHTML, !html.contains("\(urlLastPrefix)\(totalCode)\(urlSuffix)") {
            continue
        }
        let addlCourses = courses(from: totalCode).filter({ ($0[.subjectID] as? String)?.contains(courseCode) == true })
        if addlCourses.count == 0 {
            continue
        }
        print("======", totalCode)
        departmentCourses += addlCourses
        if letter == alphabet.first {
            originalHTML = parser.htmlContents
        }
    }
    
    if let evaluations = evaluationData {
        augmentCourseData(&departmentCourses, withEvaluationsData: evaluations)
    }
    writeFullCourses(departmentCourses, to: outputDirectory + courseCode + ".txt")
    allCourses += departmentCourses
}

let splitCount = 4
print("Writing condensed courses...")
for i in 0..<splitCount {
    let lowerBound = Int(Float(i) / 4.0 * Float(allCourses.count))
    let upperBound = min(allCourses.count, Int(Float(i + 1) / 4.0 * Float(allCourses.count)))
    print("Courses \(lowerBound) to \(upperBound)")
    writeCondensedCourses([[CourseAttribute: Any]](allCourses[lowerBound..<upperBound]), to: outputDirectory + "condensed_\(i).txt")
}
print("Writing all courses...")
writeFullCourses(allCourses, to: outputDirectory + "courses.txt")
