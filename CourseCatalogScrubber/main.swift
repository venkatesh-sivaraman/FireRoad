//
//  main.swift
//  CourseCatalogScrubber
//
//  Created by Venkatesh Sivaraman on 9/22/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import Foundation

let urlPrefix = "http://student.mit.edu/catalog/m"
let urlSuffix = ".html"

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
    if let url = URL(string: "\(urlPrefix)\(courseCode)\(urlSuffix)") {
        parser.catalogURL = url
        let regions = parser.htmlRegions(from: url)
        let courses = regions.map({ parser.extractCourseProperties(from: $0) })
        /*for course in courses {
            print(course)
        }*/
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
            .totalUnits,
            .notOfferedYear,
            .offeredFall,
            .offeredIAP,
            .offeredSpring,
            .offeredSummer
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
            .lectureUnits,
            .labUnits,
            .preparationUnits,
            .totalUnits,
            .GIR,
            .communicationRequirement,
            .hassRequirement,
            .prerequisites,
            .corequisites,
            .description,
            .jointSubjects,
            .meetsWithSubjects,
            .equivalentSubjects,
            .notOfferedYear,
            .offeredFall,
            .offeredIAP,
            .offeredSpring,
            .offeredSummer,
            .instructors,
            .schedule
            ])
    } catch {
        print("Error writing condensed course file: \(error)")
    }
}

var outputDirectory: String = "/Users/venkatesh-sivaraman/Documents/ScrapedCourses/"

var allCourses: [[CourseAttribute: Any]] = []
var departmentCourses: [[CourseAttribute: Any]] = []
for courseCode in courseNumbers {
    departmentCourses = []
    for letter in alphabet.characters {
        let totalCode = courseCode + "\(letter)"
        let addlCourses = courses(from: totalCode)
        if addlCourses.count == 0 {
            break
        }
        print("======", totalCode)
        departmentCourses += addlCourses
    }
    writeFullCourses(departmentCourses, to: outputDirectory + courseCode + ".txt")
    allCourses += departmentCourses
}

print("Writing condensed courses...")
writeCondensedCourses(allCourses, to: outputDirectory + "condensed.txt")
print("Writing all courses...")
writeFullCourses(allCourses, to: outputDirectory + "courses.txt")
