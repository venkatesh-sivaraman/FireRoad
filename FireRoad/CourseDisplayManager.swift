//
//  CourseDisplayManager.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 12/7/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import Foundation

protocol CourseDisplayManager: class {
    func addCourse(_ course: Course, to semester: UserSemester?) -> UserSemester?
    func viewDetails(for course: Course)
}
