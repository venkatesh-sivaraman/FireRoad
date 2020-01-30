//
//  ProgressAssertion.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/29/20.
//  Copyright © 2020 Base 12 Innovations. All rights reserved.
//

import Foundation

/**
 An object that represents an override to a requirement. Requirements
 can be overridden by providing a list of courses that will substitute
 for the requirement (each course is described by its subject ID), or
 by "ignoring" the requirement. Ignoring a requirement amounts to
 removing that requirement from the tree, so it will not contribute to
 progress in any way.
 */
struct ProgressAssertion {
    var substitutions: [String]?
    var ignore: Bool
    
    static let substitutionsKey = "substitutions"
    static let ignoreKey = "ignore"
    
    func toJSON() -> [String: Any] {
        var result: [String: Any] = [:]
        if let subs = substitutions {
            result[ProgressAssertion.substitutionsKey] = subs
        }
        if ignore {
            result[ProgressAssertion.ignoreKey] = ignore
        }
        return result
    }
    
    static func fromJSON(_ json: [String: Any]) -> ProgressAssertion {
        let courses = json[ProgressAssertion.substitutionsKey] as? [String]
        let ignore = (json[ProgressAssertion.ignoreKey] as? Bool) ?? false
        return ProgressAssertion(substitutions: courses, ignore: ignore)
    }
}
