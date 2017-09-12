//
//  User.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/2/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

enum UserSemester: Int {
    case PreviousCredit = 0
    case FreshmanFall = 1
    case FreshmanIAP = 2
    case FreshmanSpring = 3
    case SophomoreFall = 4
    case SophomoreIAP = 5
    case SophomoreSpring = 6
    case JuniorFall = 7
    case JuniorIAP = 8
    case JuniorSpring = 9
    case SeniorFall = 10
    case SeniorIAP = 11
    case SeniorSpring = 12
    
    func toString() -> String {
        switch self {
        case .PreviousCredit: return "Previous Credit"
        case .FreshmanFall: return "Freshman Fall"
        case .FreshmanIAP: return "Freshman IAP"
        case .FreshmanSpring: return "Freshman Spring"
        case .SophomoreFall: return "Sophomore Fall"
        case .SophomoreIAP: return "Sophomore IAP"
        case .SophomoreSpring: return "Sophomore Spring"
        case .JuniorFall: return "Junior Fall"
        case .JuniorIAP: return "Junior IAP"
        case .JuniorSpring: return "Junior Spring"
        case .SeniorFall: return "Senior Fall"
        case .SeniorIAP: return "Senior IAP"
        case .SeniorSpring: return "Senior Spring"
        }
    }
    
    func isIAP() -> Bool {
        return (self == .FreshmanIAP || self == .SophomoreIAP || self == .JuniorIAP || self == .SeniorIAP)
    }
    
    func isFall() -> Bool {
        return (self == .FreshmanFall || self == .SophomoreFall || self == .JuniorFall || self == .SeniorFall)
    }
    
    func isSpring() -> Bool {
        return (self == .FreshmanSpring || self == .SophomoreSpring || self == .JuniorSpring || self == .SeniorSpring)
    }
    
    static let allEnrolledSemesters: [UserSemester] = [
        .FreshmanFall, .FreshmanIAP, .FreshmanSpring,
        .SophomoreFall, .SophomoreIAP, .SophomoreSpring,
        .JuniorFall, .JuniorIAP, .JuniorSpring,
        .SeniorFall, .SeniorIAP, .SeniorSpring
    ]
}

class User: NSObject {
    
    private var selectedCourses: [UserSemester: [Course]]? = nil
    
    override init() {
        self.selectedCourses = [
            .FreshmanFall: [CourseManager.shared.getCourse(withID: "8.02")!,
            CourseManager.shared.getCourse(withID: "5.112")!,
            CourseManager.shared.getCourse(withID: "6.006")!,
            CourseManager.shared.getCourse(withID: "17.55")!],
            .FreshmanSpring: [CourseManager.shared.getCourse(withID: "18.03")!,
            CourseManager.shared.getCourse(withID: "7.013")!,
            CourseManager.shared.getCourse(withID: "21M.284")!,
            CourseManager.shared.getCourse(withID: "6.046")!]
        ]
    }
    
    func courses(forSemester semester: UserSemester) -> [Course] {
        if selectedCourses != nil && selectedCourses!.contains(where: { $0.0 == semester }) {
            return selectedCourses![semester]!
        }
        return []
    }
    
    func delete(_ course: Course, fromSemester semester: UserSemester) {
        var semesterCourses = self.courses(forSemester: semester)
        if let delIdx = semesterCourses.index(of: course) {
            semesterCourses.remove(at: delIdx)
        }
        self.selectedCourses?[semester] = semesterCourses
    }
    
    func add(_ course: Course, toSemester destSemester: UserSemester) {
        var semesterCourses = self.courses(forSemester: destSemester)
        if !semesterCourses.contains(course) {
            semesterCourses.append(course)
        }
        self.selectedCourses?[destSemester] = semesterCourses
    }
    
    func insert(_ course: Course, toSemester destSemester: UserSemester, atIndex idx: Int) {
        var semesterCourses = self.courses(forSemester: destSemester)
        if !semesterCourses.contains(course) {
            semesterCourses.insert(course, at: min(idx, semesterCourses.count))
        }
        self.selectedCourses?[destSemester] = semesterCourses
    }
    
    func move(_ course: Course, fromSemester semester: UserSemester, toSemester destSemester: UserSemester, atIndex idx: Int) {
        self.delete(course, fromSemester: semester)
        self.insert(course, toSemester: destSemester, atIndex: idx)
    }
}
