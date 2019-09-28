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
        let searchEngine = CourseSearchEngine()
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
            let (searchTerm, expected, option) = test
            var options: SearchOptions = .noFilter
            options.formUnion(option)
            guard let keys = searchEngine.searchResults(within: testCourses, searchTerm: searchTerm, options: options)?.keys else {
                assert(false, "Search engine returned nil")
                continue
            }
            let observedResults = Set<Course>(keys)
            assert(observedResults == expected, "Incorrect results for \(option): \(observedResults) != \(expected)")
            print("Passed: \(searchTerm)")
        }
    }
    
    func testRequirementsCalculations() throws {
        guard let path = Bundle(for: FireRoadTests.self).path(forResource: "test", ofType: "reql") else {
            print("No path")
            return
        }
        let courses = [
            Course(courseID: "A", courseTitle: "A", courseDescription: ""),
            Course(courseID: "B", courseTitle: "B", courseDescription: ""),
            Course(courseID: "C", courseTitle: "C", courseDescription: ""),
            Course(courseID: "D", courseTitle: "D", courseDescription: ""),
            Course(courseID: "E", courseTitle: "E", courseDescription: ""),
            Course(courseID: "F", courseTitle: "F", courseDescription: ""),
            Course(courseID: "G", courseTitle: "G", courseDescription: ""),
            Course(courseID: "H", courseTitle: "H", courseDescription: ""),
            Course(courseID: "I", courseTitle: "I", courseDescription: "")
        ]
        let reqFile = try RequirementsList(contentsOf: path)
        reqFile.computeRequirementStatus(with: [courses[0], courses[1], courses[2]])
        var percentages = reqFile.requirements?.map({ $0.percentageFulfilled }) ?? []
        var expected: [Float] = [ 100.0, 0.0, 0.0, 50.0, 100.0, 100.0, 75.0, 75.0 ]
        for i in 0..<percentages.count {
            assert(fabs(percentages[i] - expected[i]) < 1.0, "Percentages don't match: \(percentages) should be \(expected)")
        }

        reqFile.computeRequirementStatus(with: [courses[0], courses[1], courses[3]])
        percentages = reqFile.requirements?.map({ $0.percentageFulfilled }) ?? []
        expected = [ Float(100.0 * 2.0 / 3.0), 100.0, 0.0, 50.0, 100.0, 100.0, 75.0, 75.0 ]
        for i in 0..<percentages.count {
            assert(fabs(percentages[i] - expected[i]) < 1.0, "Percentages don't match: \(percentages) should be \(expected)")
        }

        reqFile.computeRequirementStatus(with: [courses[3], courses[4], courses[5]])
        percentages = reqFile.requirements?.map({ $0.percentageFulfilled }) ?? []
        expected = [ 0.0, 100.0, 0.0, Float(100.0 / 6.0), 100.0, 100.0, 25.0, 25.0 ]
        for i in 0..<percentages.count {
            assert(fabs(percentages[i] - expected[i]) < 1.0, "Percentages don't match: \(percentages) should be \(expected)")
        }

        reqFile.computeRequirementStatus(with: [courses[3], courses[4], courses[5], courses[6]])
        percentages = reqFile.requirements?.map({ $0.percentageFulfilled }) ?? []
        expected = [ 0.0, 100.0, 50.0, Float(100.0 / 3.0), 100.0, 100.0, Float(100.0 * 2.0 / 3.0), Float(100.0 * 2.0 / 3.0) ]
        for i in 0..<percentages.count {
            assert(fabs(percentages[i] - expected[i]) < 1.0, "Percentages don't match: \(percentages) should be \(expected)")
        }

        reqFile.computeRequirementStatus(with: [courses[3], courses[4], courses[6], courses[7]])
        percentages = reqFile.requirements?.map({ $0.percentageFulfilled }) ?? []
        expected = [ 0.0, 100.0, 100.0, 50.0, 100.0, 100.0, 100.0, 100.0 ]
        for i in 0..<percentages.count {
            assert(fabs(percentages[i] - expected[i]) < 1.0, "Percentages don't match: \(percentages) should be \(expected)")
        }

        reqFile.computeRequirementStatus(with: [courses[0], courses[1], courses[2], courses[6]])
        percentages = reqFile.requirements?.map({ $0.percentageFulfilled }) ?? []
        expected = [ 100.0, 0.0, 50.0, Float(100.0 * 2.0 / 3.0), 100.0, 100.0, 80.0, 80.0 ]
        for i in 0..<percentages.count {
            assert(fabs(percentages[i] - expected[i]) < 1.0, "Percentages don't match: \(percentages) should be \(expected)")
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
    
    func testComputeQueue() {
        let q = ComputeQueue(label: "myTestComputeQ")
        var results: [String] = []
        for i in 1..<25 {
            q.async(taskName: "\(i)", waitForSignal: true) {
                let url = URL(string: "http://student.mit.edu/catalog/m\(i)a.html")!
                let task = URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
                    print(i)
                    if let resp = response {
                        print((resp as? HTTPURLResponse)?.statusCode ?? 0)
                        results.append("\(resp.url?.absoluteString ?? "No url")")
                    } else {
                        print("None")
                        results.append("\(error?.localizedDescription ?? "")")
                    }
                    q.proceed()
                })
                task.resume()
            }
        }
        while results.count < 24 {
            usleep(500)
        }
        print(results)
    }
    
    func testChangeDate() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-yyyy HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = dateFormatter.date(from: "08-20-2018 19:00:00") else {
            XCTAssert(false, "Couldn't get date from string")
            return
        }
        print(date, date.timeIntervalSinceReferenceDate)
    }
}
