//
//  CourseManager.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/2/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class StreamReader: NSObject, StreamDelegate {
    private var lineFragment: String? = nil
    private var mainStream: InputStream? = nil
    
    private var workBlock: (([String]) -> Bool)? = nil
    private var completionBlock: ((Bool) -> Void)? = nil

    init?(fileAt path: String) {
        guard let stream = InputStream(fileAtPath: path) else {
            print("Failed")
            return nil
        }
        self.mainStream = stream
    }
    
    func read(work: @escaping (([String]) -> Bool), completion: @escaping ((Bool) -> Void)) {
        self.workBlock = work
        self.completionBlock = completion

        self.mainStream?.delegate = self
        self.mainStream?.schedule(in: RunLoop.current, forMode: .defaultRunLoopMode)
        self.mainStream?.open()
        if RunLoop.current != RunLoop.main {
            RunLoop.current.run()
        }
    }
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        guard let stream = aStream as? InputStream else {
            return
        }
        
        switch eventCode {
        case Stream.Event.endEncountered:
            return
        case Stream.Event.hasBytesAvailable:
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let len = stream.read(&buffer, maxLength: 4096)
                if len < 0 {
                    let error = stream.streamError
                    print("Input stream has less than 0 bytes\(error!)")
                    self.workBlock = nil
                    self.completionBlock?(false)
                    self.completionBlock = nil
                    return
                } else if len == 0 {
                    print("Input stream completed")
                    self.workBlock = nil
                    self.completionBlock?(true)
                    self.completionBlock = nil
                    break
                } else if len > 0 {
                    var messageFromServer = NSString(bytes: &buffer, length: len, encoding: String.Encoding.utf8.rawValue) as String?
                    
                    if messageFromServer == nil {
                        print("Network has been closed")
                        self.workBlock = nil
                        self.completionBlock?(true)
                        self.completionBlock = nil
                        break
                    }
                    else if stream == self.mainStream {
                        if self.lineFragment != nil && self.lineFragment!.characters.count > 0 {
                            messageFromServer = self.lineFragment! + messageFromServer!
                        }
                        self.lineFragment = nil
                        var lines: [String] = messageFromServer!.components(separatedBy: "\n")
                        if lines.count > 0 && lines.last!.characters.count > 0 {
                            self.lineFragment = lines.last!
                            lines.remove(at: lines.count - 1)
                        }
                        if self.workBlock != nil && self.workBlock!(lines) {
                            self.workBlock = nil
                            self.completionBlock?(false)
                            self.completionBlock = nil
                        }
                    }
                }
                
            }
        default:
            print("Event code \(eventCode)")
            break
        }
    }
}

class CourseManager: NSObject {
    
    var courses: [Course] = []
    var coursesByID: [String: Course] = [:]
    var coursesByTitle: [String: Course] = [:]
    static let shared: CourseManager = CourseManager()
    var loadedDepartments: [String] = []
    
    private var loadingCompletionBlock: ((Bool) -> Void)? = nil

    /*
 Academic Year,Effective Term Code,Subject Id,Subject Code,Subject Number,Source Subject Id,Print Subject Id,Department Code,Department Name,Subject Short Title,Subject Title,Is Variable Units,Lecture Units,Lab Units,Preparation Units,Total Units,Gir Attribute,Gir Attribute Desc,Comm Req Attribute,Comm Req Attribute Desc,Write Req Attribute,Write Req Attribute Desc,Supervisor Attribute Desc,Prerequisites,Subject Description,Joint Subjects,School Wide Electives,Meets With Subjects,Equivalent Subjects,Is Offered This Year,Is Offered Fall Term,Is Offered Iap,Is Offered Spring Term,Is Offered Summer Term,Fall Instructors,Spring Instructors,Status Change,Last Activity Date,Warehouse Load Date,Master Subject Id,Hass Attribute,Hass Attribute Desc,Term Duration,On Line Page Number
*/
    private var textKeyMapping: [String: String] = [
        "Academic Year": "academicYear",
        "Comm Req Attribute": "communicationRequirement",
        "Department Name": "departmentName",
        "Subject Id": "subjectID",
        "Print Subject Id": "printSubjectID",
        "Subject Code": "subjectCode",
        "Subject Number": "subjectNumber",
        "Subject Title": "subjectTitle",
        "Subject Description": "subjectDescription",
        "Subject Short Title": "subjectShortTitle",
        "Is Offered Fall Term": "isOfferedFall",
        "Is Offered Iap": "isOfferedIAP",
        "Is Offered Spring Term": "isOfferedSpring",
        "Is Offered Summer Term": "isOfferedSummer",
        "Is Offered This Year": "isOfferedThisYear",
        "Total Units": "totalUnits",
        "Design Units": "designUnits",
        "Lecture Units": "lectureUnits",
        "Lab Units": "labUnits",
        "Is Variable Units": "isVariableUnits",
        "Preparation Units": "preparationUnits",
        "Joint Subjects": "jointSubjects",
        "Meets With Subjects": "meetsWithSubjects",
        "Equivalent Subjects": "equivalentSubjects",
        "Prerequisites": "prerequisites",
        "Fall Instructors": "fallInstructors",
        "Spring Instructors": "springInstructors",
        "Gir Attribute": "GIRAttribute",
        "Grade Rule": "gradeRule",
        "Grade Type": "gradeType",
        "Hass Attribute": "hassAttribute",
        "Term Duration": "termDuration",
        "Write Req Attribute": "writingRequirement",
        "On Line Page Number": "onlinePageNumber"
    ]
    private var csvHeaders: [String]? = nil
    
    static let colorMapping: [String: UIColor] = [
        "1": UIColor(hue: 3.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "2": UIColor(hue: 6.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "3": UIColor(hue: 9.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "4": UIColor(hue: 12.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "5": UIColor(hue: 15.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "6": UIColor(hue: 18.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "7": UIColor(hue: 21.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "8": UIColor(hue: 24.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "9": UIColor(hue: 27.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "10": UIColor(hue: 30.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "11": UIColor(hue: 1.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "12": UIColor(hue: 4.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "14": UIColor(hue: 7.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "15": UIColor(hue: 10.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "16": UIColor(hue: 13.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "17": UIColor(hue: 16.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "18": UIColor(hue: 19.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "20": UIColor(hue: 22.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "21A": UIColor(hue: 25.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "CMS": UIColor(hue: 25.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "21W": UIColor(hue: 25.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "21G": UIColor(hue: 25.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "21H": UIColor(hue: 25.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "21L": UIColor(hue: 25.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "21M": UIColor(hue: 25.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "WGS": UIColor(hue: 25.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "22": UIColor(hue: 28.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "24": UIColor(hue: 31.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "CC": UIColor(hue: 2.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "CSB": UIColor(hue: 5.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "EC": UIColor(hue: 8.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "EM": UIColor(hue: 11.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "ES": UIColor(hue: 14.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "HST": UIColor(hue: 17.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "IDS": UIColor(hue: 20.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "MAS": UIColor(hue: 23.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "SCM": UIColor(hue: 26.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "STS": UIColor(hue: 29.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
        "SWE": UIColor(hue: 32.0 / 32.0, saturation: 0.7, brightness: 0.87, alpha: 1.0),
    ]
    
    func loadCourses(completion: @escaping ((Bool) -> Void)) {
        
        //Academic Year,Effective Term Code,Subject Id,Subject Code,Subject Number,Source Subject Id,Print Subject Id,Department Code,Department Name,Subject Short Title,Subject Title,Is Variable Units,Lecture Units,Lab Units,Preparation Units,Total Units,Gir Attribute,Gir Attribute Desc,Comm Req Attribute,Comm Req Attribute Desc,Write Req Attribute,Write Req Attribute Desc,Supervisor Attribute Desc,Prerequisites,Subject Description,Joint Subjects,School Wide Electives,Meets With Subjects,Equivalent Subjects,Is Offered This Year,Is Offered Fall Term,Is Offered Iap,Is Offered Spring Term,Is Offered Summer Term,Fall Instructors,Spring Instructors,Status Change,Last Activity Date,Warehouse Load Date,Master Subject Id,Hass Attribute,Hass Attribute Desc,Term Duration,On Line Page Number

        DispatchQueue.global(qos: .background).async {
            guard let path = Bundle.main.path(forResource: "condensed", ofType: "txt") else {
                print("Failed")
                return
            }
            self.courses = []
            self.coursesByID = [:]
            self.coursesByTitle = [:]
            self.loadedDepartments = []

            self.readSummaryFile(at: path, { [weak self] (success) in
                self?.csvHeaders = nil
                if success {
                    var completionCount: Int = 0
                    let groupCompletionBlock: ((Bool) -> Void) = { (success) in
                        if success {
                            completionCount += 1
                            if completionCount == 2 {
                                DispatchQueue.main.async {
                                    completion(success)
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                completion(success)
                            }
                        }
                    }
                    DispatchQueue.global(qos: .background).async {
                        guard let enrollPath = Bundle.main.path(forResource: "enrollment", ofType: "txt") else {
                            print("Failed with enrollment")
                            return
                        }
                        guard let enrollReader = StreamReader(fileAt: enrollPath) else {
                            print("Failed with enrollment")
                            return
                        }
                        enrollReader.read(work: { (lines) -> Bool in
                            
                            for line in lines {
                                let comps = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).components(separatedBy: ",")
                                if comps.contains("Subject Id") {
                                    self?.csvHeaders = comps
                                } else if self != nil && self!.csvHeaders != nil {
                                    var course: Course? = nil
                                    for (i, comp) in comps.enumerated() {
                                        if self!.csvHeaders![i] == "Subject Id" {
                                            course = self!.coursesByID[comp]
                                        } else if self!.csvHeaders![i] == "Subject Enrollment Number" {
                                            course?.enrollmentNumber = max(course!.enrollmentNumber, Int(Float(comp)!))
                                        }
                                    }
                                } else {
                                    print("No CSV headers found, so this file can't be read.")
                                    return true
                                }
                            }

                            return false
                        }, completion: groupCompletionBlock)
                    }
                    DispatchQueue.global(qos: .background).async {
                        guard let relatedPath = Bundle.main.path(forResource: "related", ofType: "txt") else {
                            print("Failed with related")
                            return
                        }
                        guard let relatedReader = StreamReader(fileAt: relatedPath) else {
                            print("Failed with related")
                            return
                        }
                        relatedReader.read(work: { (lines) -> Bool in
                            
                            for line in lines {
                                let comps = line.components(separatedBy: ",")
                                if self != nil {
                                    if let course = self!.getCourse(withID: comps[0].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) {
                                        var related: [(String, Float)] = []
                                        for compIdx in stride(from: 1, to: comps.count, by: 2) {
                                            related.append((comps[compIdx], Float(comps[compIdx + 1])!))
                                        }
                                        course.relatedSubjects = related.sorted(by: { $0.1 > $1.1 })
                                    } else {
                                        print("No course")
                                    }
                                }
                            }
                            
                            return false
                        }, completion: groupCompletionBlock)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(success)
                    }
                }
            })
        }
        
    }
    
    
    func getCourse(withID subjectID: String) -> Course? {
        if subjectID.characters.count == 0 {
            return nil
        }
        if let course = self.coursesByID[subjectID] {
            return course
        }
        return nil
    }
    
    func getCourse(withTitle subjectTitle: String) -> Course? {
        if subjectTitle.characters.count == 0 {
            return nil
        }
        if let course = self.coursesByTitle[subjectTitle] {
            return course
        }
        return nil
    }
    
    func color(forCourse course: Course) -> UIColor {
        if course.subjectCode != nil {
            if let color = CourseManager.colorMapping[course.subjectCode!] {
                return color
            }
        }
        return UIColor.lightGray
    }
    
    func readSummaryFile(at path: String, _ completion: @escaping ((Bool) -> Void)) {
        guard let mainReader = StreamReader(fileAt: path) else {
            print("Failed to initialize reader")
            return
        }
        
        mainReader.read(work: { (lines) -> Bool in
            
            for line in lines {
                let course = Course()
                let comps = line.components(separatedBy: ",")
                if comps.contains("Subject Id") {
                    self.csvHeaders = comps
                } else if self.csvHeaders != nil {
                    var i = 0
                    var quotedLine: String = ""
                    for comp in comps {
                        var trimmed: String = quotedLine + (quotedLine.characters.count > 0 ? "," : "") + comp
                        if (trimmed.characters.count - trimmed.replacingOccurrences(of: "\"", with: "").characters.count) % 2 == 1 {
                            quotedLine = trimmed
                        } else {
                            quotedLine = ""
                            trimmed = trimmed.characters.first == Character("\"") ? trimmed.substring(with: trimmed.index(trimmed.startIndex, offsetBy: 1)..<trimmed.index(trimmed.endIndex, offsetBy: -1)) : trimmed
                            do {
                                let regex = try NSRegularExpression(pattern: "</?\\w*>", options: .caseInsensitive)
                                let mutableString = (trimmed as NSString).mutableCopy() as! NSMutableString
                                regex.replaceMatches(in: mutableString, options: [], range: NSMakeRange(0, trimmed.characters.count), withTemplate: "")
                                trimmed = mutableString as String
                            } catch {
                                print("Error with regex: \(error)")
                            }
                            if i >= self.csvHeaders!.count {
                                //print("Beyond bounds")
                            } else if self.textKeyMapping.contains(where: { $0.0 == self.csvHeaders![i] }) {
                                course.setValue(trimmed, forKey: self.textKeyMapping[self.csvHeaders![i]]!)
                            }
                            i += 1
                        }
                    }
                } else {
                    print("No CSV headers found, so this file can't be read.")
                    return true
                }
                if course.subjectID == nil || (self.coursesByID[course.subjectID!] == nil && (course.printSubjectID == nil || self.coursesByID[course.printSubjectID!] == nil)) {
                    self.courses.append(course)
                } else if self.coursesByID[course.subjectID!] != nil {
                    course.transferInformation(to: self.coursesByID[course.subjectID!]!)
                } else if course.printSubjectID != nil && self.coursesByID[course.printSubjectID!] != nil {
                    course.transferInformation(to: self.coursesByID[course.printSubjectID!]!)
                }
                if course.subjectID != nil && self.coursesByID[course.subjectID!] == nil {
                    self.coursesByID[course.subjectID!] = course
                }
                if course.printSubjectID != nil && self.coursesByID[course.printSubjectID!] == nil {
                    self.coursesByID[course.printSubjectID!] = course
                }
                if course.subjectTitle != nil && self.coursesByTitle[course.subjectTitle!] == nil {
                    self.coursesByTitle[course.subjectTitle!] = course
                }
            }
            
            return false
        }, completion: completion)
    }
    
    func loadCourseDetails(about course: Course, _ completion: @escaping ((Bool) -> Void)) {
        if self.getCourse(withID: course.subjectID!) == nil {
            completion(false)
            return
        }
        if self.loadedDepartments.contains(course.subjectCode!) {
            completion(true)
            return
        }
        guard let path = Bundle.main.path(forResource: course.subjectCode!, ofType: "txt") else {
            print("Failed")
            completion(false)
            return
        }
        DispatchQueue.global().async {
            self.readSummaryFile(at: path) { (success) in
                self.loadedDepartments.append(course.subjectCode!)
                self.csvHeaders = nil
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        }
        
    }
}
