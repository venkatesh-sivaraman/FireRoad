//
//  StringExtension.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 9/30/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import Foundation

extension String {
    var dates: [Date]? {
        return try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
            .matches(in: self, range: NSRange(location: 0, length: characters.count))
            .flatMap{$0.date}
    }
}

extension String {
    func capitalizingFirstLetter() -> String {
        let first = String(characters.prefix(1)).capitalized
        let other = String(characters.dropFirst())
        return first + other
    }
}
