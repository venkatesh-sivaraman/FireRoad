//
//  FireRoadTests.swift
//  FireRoadTests
//
//  Created by Venkatesh Sivaraman on 5/2/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import XCTest
@testable import FireRoad

class FireRoadTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSearchRegex() {
        let browser = CourseBrowserViewController()
        let testCourses = [
            Course(courseID: "1.002", courseTitle: "Hello World", courseDescription: "Description"),
            Course(courseID: "2.004", courseTitle: "Control Systems Worldness", courseDescription: "Description"),
            Course(courseID: "6.122", courseTitle: "Unworldly Possession", courseDescription: "Description"),
            Course(courseID: "21M.384", courseTitle: "Mello System", courseDescription: "Description"),
            Course(courseID: "17.12A", courseTitle: "Hewo Blah", courseDescription: "Description")
        ]
        
        let testCases: [(String, Set<Course>, SearchOptions)] = [
            ("World", Set<Course>([testCourses[0]]), .matchesSearchTerm),
            ("ello", Set<Course>(), .matchesSearchTerm),
            ("System", Set<Course>([testCourses[3]]), .matchesSearchTerm),
            ("ello", Set<Course>([testCourses[0], testCourses[3]]), .endsWithSearchTerm),
            ("World", Set<Course>([testCourses[0], testCourses[1]]), .startsWithSearchTerm),
            ("World", Set<Course>([testCourses[0], testCourses[1], testCourses[2]]), .containsSearchTerm),
            ("He", Set<Course>([testCourses[0], testCourses[4]]), .startsWithSearchTerm),
            ("12", Set<Course>([testCourses[2], testCourses[4]]), .startsWithSearchTerm),
        ]
        for test in testCases {
            CourseManager.shared.courses = testCourses
            
            let (searchTerm, expected, option) = test
            var options: SearchOptions = [.anyRequirement, .offeredAnySemester, .searchAllFields]
            options.formUnion(option)
            let observedResults = Set<Course>(browser.searchResults(for: searchTerm, options: options))
            assert(observedResults == expected, "Incorrect results for \(option): \(observedResults) != \(expected)")
            print("Passed: \(searchTerm)")
        }
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
