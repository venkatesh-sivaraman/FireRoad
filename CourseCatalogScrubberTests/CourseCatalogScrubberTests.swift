//
//  CourseCatalogScrubberTests.swift
//  CourseCatalogScrubberTests
//
//  Created by Venkatesh Sivaraman on 12/17/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import XCTest
@testable import CourseCatalogScrubber

class CourseCatalogScrubberTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /*func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }*/
    
    func testRequirementsListSingleComponent() {
        let parser = CourseCatalogParser()
        let output = parser.processRequirementsListItem("6.031")
        XCTAssertEqual(output, "6.031")
    }

    func testRequirementsListSingleComponentLetter() {
        let parser = CourseCatalogParser()
        let output = parser.processRequirementsListItem("21G.048")
        XCTAssertEqual(output, "21G.048")
    }
    
    func testRequirementsListSingleComponentMessage1() {
        let parser = CourseCatalogParser()
        let output = parser.processRequirementsListItem("Permission of instructor")
        XCTAssertEqual(output, "''Permission of instructor''")
    }
    
    func testRequirementsListSingleComponentMessage2() {
        let parser = CourseCatalogParser()
        let output = parser.processRequirementsListItem("One math subject")
        XCTAssertEqual(output, "''One math subject''")
    }
    
    func testRequirementsListTwoComponentsAnd() {
        let parser = CourseCatalogParser()
        let output = parser.processRequirementsListItem("6.031 and 6.034 ").replacingOccurrences(of: " ", with: "")
        XCTAssertEqual(output, "6.031,6.034")
    }

    func testRequirementsListTwoComponentsOr() {
        let parser = CourseCatalogParser()
        let output = parser.processRequirementsListItem("6.031 or 6.034 ").replacingOccurrences(of: " ", with: "")
        XCTAssertEqual(output, "6.031/6.034")
    }
    
    func testRequirementsListTwoComponentsOrMessages() {
        let parser = CourseCatalogParser()
        let output = parser.processRequirementsListItem("Chinese I or permission of instructor").replacingOccurrences(of: " ", with: "")
        XCTAssertEqual(output, "''ChineseI''/''permissionofinstructor''")
    }
    
    func testRequirementsListMultipleOrs() {
        let parser = CourseCatalogParser()
        let output = parser.processRequirementsListItem("6.031 or 6.033 or 6.034 ").replacingOccurrences(of: " ", with: "")
        XCTAssertEqual(output, "6.031/6.033/6.034")
    }
    
    func testRequirementsListMultipleAnds() {
        let parser = CourseCatalogParser()
        let output = parser.processRequirementsListItem("6.031 and 6.033 and 6.034 ").replacingOccurrences(of: " ", with: "")
        XCTAssertEqual(output, "6.031,6.033,6.034")
    }
    
    func testRequirementsListMultipleComponents() {
        let parser = CourseCatalogParser()
        let output = parser.processRequirementsListItem("6.031, 6.033, and 6.034 ").replacingOccurrences(of: " ", with: "")
        XCTAssertEqual(output, "6.031,6.033,6.034")
    }

    func testRequirementsListMultipleComponentsWhitespace() {
        let parser = CourseCatalogParser()
        let output = parser.processRequirementsListItem("6.031  ,   6.033  , \n and 6.034  ").replacingOccurrences(of: " ", with: "")
        XCTAssertEqual(output, "6.031,6.033,6.034")
    }

    func testRequirementsListMultipleComponentsSemicolonTerminated() {
        let parser = CourseCatalogParser()
        let output = parser.processRequirementsListItem("6.031 , 6.033 ,  and 6.034  ;").replacingOccurrences(of: " ", with: "")
        XCTAssertEqual(output, "6.031,6.033,6.034")
    }

    func testRequirementsListNestedTwoComponents() {
        let parser = CourseCatalogParser()
        let output = parser.processRequirementsListItem("(6.031 or 6.033) and 6.034 ").replacingOccurrences(of: " ", with: "")
        XCTAssertEqual(output, "(6.031/6.033),6.034")
    }

    func testRequirementsListMultiNested() {
        let parser = CourseCatalogParser()
        let output = parser.processRequirementsListItem("(2.001 , 2.003 , (2.005 or 2.008) , and 2.009) or permission of instructor").replacingOccurrences(of: " ", with: "")
        XCTAssertEqual(output, "(2.001,2.003,(2.005/2.008),2.009)/''permissionofinstructor''")
    }
    
    func testRequirementsListGIR() {
        let parser = CourseCatalogParser()
        let output = parser.processRequirementsListItem("Physics II (GIR)  or  Calculus I (GIR)").replacingOccurrences(of: " ", with: "")
        XCTAssertEqual(output, "GIR:PHY2/GIR:CAL1")
    }

    func testRequirementsListGIRNested() {
        let parser = CourseCatalogParser()
        let output = parser.processRequirementsListItem("(Physics II (GIR),  and  18.03)  or  abcdefgorand").replacingOccurrences(of: " ", with: "")
        XCTAssertEqual(output, "(GIR:PHY2,18.03)/''abcdefgorand''")
    }

    // Make sure permission of instructor isn't quadruple quoted
    func testRequirementsListDoubleQuoting() {
        let parser = CourseCatalogParser()
        let output = parser.processRequirementsListItem("((1.00 or 6.0001) and (2.003, 6.006, 6.009, or 16.06)) or permission of instructor").replacingOccurrences(of: " ", with: "")
        XCTAssertEqual(output, "((1.00/6.0001),(2.003/6.006/6.009/16.06))/''permissionofinstructor''")
    }
}
