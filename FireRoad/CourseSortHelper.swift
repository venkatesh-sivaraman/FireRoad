//
//  CourseSortHelper.swift
//  FireRoad
//
//  Created by Kathryn Jin on 1/29/20.
//  Copyright © 2020 Base 12 Innovations. All rights reserved.
//

/**
 A helper class for sorting courses by a variety of metrics. Clients can
 initialize a sort helper using a particular sort field as well as a desired
 behavior for the "automatic" sort option, then use the helper's sortingFunction
 method as a binary comparator in an Array sort.
 */
class CourseSortHelper {
    var sortType: SortOption
    var automaticType: AutomaticOption
    
    init(sortType: SortOption, automaticType: AutomaticOption) {
        self.sortType = sortType
        self.automaticType = automaticType
    }
    
    func sortingFunction(course1: (key: Course, value: Float), course2: (key: Course, value: Float)) -> Bool {
        switch self.sortType {
        case .number:
            return (course1.0.subjectID ?? "").localizedStandardCompare(course2.0.subjectID ?? "") == .orderedAscending
        case .rating:
            return course1.0.rating > course2.0.rating
        case .hours:
            let course1hours = course1.0.inClassHours + course1.0.outOfClassHours
            let course2hours = course2.0.inClassHours + course2.0.outOfClassHours
            if course1hours == 0 && course2hours != 0 {
                return false
            } else if course2hours == 0 && course1hours != 0 {
                return true
            } else {
                return course1hours < course2hours
            }
            
        case .automatic:
            switch self.automaticType {
            case .relevance:
                return course1.1 < course2.1
            case .number:
                return (course1.0.subjectID ?? "").localizedStandardCompare(course2.0.subjectID ?? "") == .orderedAscending
            }
        }
    }
    
    func sortingFunction(course1: (Course), course2: (Course)) -> Bool {
        return self.sortingFunction(course1: (course1, 0.0), course2: (course2, 0.0))
    }
}

enum SortOption {
    case automatic, rating, hours, number
}

enum AutomaticOption {
    case relevance, number
}
