//
//  CourseEvaluationParser.swift
//  CourseCatalogScrubber
//
//  Created by Venkatesh Sivaraman on 1/21/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import Foundation

enum EvaluationConstants {
    static let rating = "rating"
    static let term = "term"
    static let inClassHours = "ic_hours"
    static let outOfClassHours = "oc_hours"
    static let eligibleRaters = "eligible"
    static let respondedRaters = "resp"
    
    static let iapTerm = "IAP"
}

func loadEvaluationsJSON(from path: String) -> [String: [[String: Any]]]? {
    guard let contents = try? String(contentsOfFile: path) else {
        print("No contents at evaluations path")
        return nil
    }
    
    var jsonData: [String: Any] = [:]
    do {
        if let beginRange = contents.range(of: "{") {
            if let endRange = contents.range(of: ";", options: .backwards) {
                if let data = contents[beginRange.lowerBound..<endRange.lowerBound].data(using: .utf8),
                    let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    jsonData = dict
                }
            } else {
                if let data = contents[beginRange.lowerBound..<contents.endIndex].data(using: .utf8),
                    let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    jsonData = dict
                }
            }
        }
        
        var courseEvalData: [String: [[String: Any]]] = [:]
        for (key, value) in jsonData {
            let newKey = key.replacingOccurrences(of: CourseCatalogConstants.jointClass, with: "")
            if let listValue = value as? [[String: Any]] {
                courseEvalData[newKey] = listValue
            } else {
                print("Value for \(key) doesn't cast: \(value)")
            }
        }
        return courseEvalData
    } catch {
        print("Error decoding evaluations JSON: \(error)")
        return nil
    }
}

func augmentCourseData(_ courseData: inout [[CourseAttribute: Any]], withEvaluationsData courseEvalData: [String: [[String: Any]]]) {
    
    for (i, courseAttributesDict) in courseData.enumerated() {
        guard let subjectID = courseAttributesDict[.subjectID] as? String,
            let evaluationData = courseEvalData[subjectID] else {
                continue
        }
        
        let keysToAverage: [String: CourseAttribute] = [
            EvaluationConstants.rating: .averageRating,
            EvaluationConstants.inClassHours: .averageInClassHours,
            EvaluationConstants.outOfClassHours: .averageOutOfClassHours,
            EvaluationConstants.eligibleRaters: .enrollment
        ]
        var averagingData: [String: [Float]] = [:]
        for termData in evaluationData {
            if (termData[EvaluationConstants.term] as? String)?.contains(EvaluationConstants.iapTerm) == true,
                courseData[i][.offeredFall] as? Bool == true || courseData[i][.offeredSpring] as? Bool == true {
                continue
            }
            for key in keysToAverage.keys {
                var value: Float
                // Could be a Double or a Float
                if let f = termData[key] as? Float {
                    value = f
                } else if let d = termData[key] as? Double {
                    value = Float(d)
                } else {
                    continue
                }
                if averagingData[key] != nil {
                    averagingData[key]?.append(value)
                } else {
                    averagingData[key] = [value]
                }
            }
        }
        
        for (evalKey, courseKey) in keysToAverage {
            guard let values = averagingData[evalKey] else {
                continue
            }
            courseData[i][courseKey] = values.reduce(Float(0.0), +) / Float(values.count)
        }
    }
}
