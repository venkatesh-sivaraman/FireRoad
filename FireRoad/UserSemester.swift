//
//  Semester.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 4/23/20.
//  Copyright © 2020 Base 12 Innovations. All rights reserved.
//

import UIKit

enum Season: Int, CustomStringConvertible {
    case fall = 0
    case iap = 1
    case spring = 2
    case summer = 3
    
    static var values: [Season] = [
        .fall, .iap, .spring, .summer
    ]
    
    var description: String {
        switch self {
        case .fall:
            return "fall"
        case .iap:
            return "IAP"
        case .spring:
            return "spring"
        case .summer:
            return "summer"
        }
    }
}

/**
 A type that describes a semester in a user's road. A semester can be
 prior credit, or it can have a season and year associated with it.
 */
class UserSemester: NSObject, Comparable {
    
    private(set) var season: Season?
    private(set) var year: Int?
    private(set) var isPriorCredit = false
    
    private init(season: Season?, year: Int?, isPriorCredit: Bool) {
        self.season = season
        self.year = year
        self.isPriorCredit = isPriorCredit
    }
    
    convenience init(oldValue: Int) {
        if oldValue == 0 {
            self.init(season: nil, year: nil, isPriorCredit: true)
            return
        }
        let seasons: [Season] = [.fall, .iap, .spring]
        self.init(season: seasons[(oldValue - 1) % 3], year: (oldValue - 1) / 3 + 1)
    }
    
    convenience init(season: Season, year: Int) {
        self.init(season: season, year: year, isPriorCredit: false)
    }
    
    static func priorCredit() -> UserSemester {
        return UserSemester(season: nil, year: nil, isPriorCredit: true)
    }
    
    static func descriptionForYear(_ year: Int) -> String {
        var ordinal = "th"
        if year == 1 {
            ordinal = "st"
        } else if year == 2 {
            ordinal = "nd"
        } else if year == 3 {
            ordinal = "rd"
        }
        
        return "\(year)\(ordinal) Year"
    }
    
    override var description: String {
        if isPriorCredit {
            return "Prior Credit"
        }
        
        guard let year = year, let season = season else {
            return "Undefined"
        }
        
        return "\(UserSemester.descriptionForYear(year)) \(season.description.capitalizingFirstLetter())"
    }
    
    var semesterID: String {
        if isPriorCredit {
            return "prior-credit"
        }
        guard let season = season, let year = year else {
            return "undefined"
        }
        return "\(season)-\(year)"
    }
    
    /// This is the value of the `semester` field in the old road format.
    var oldSemesterID: Int {
        if isPriorCredit {
            return 0
        }
        
        guard let year = year, let season = season,
            season != .summer else {
                return 0
        }
        return year * 3 + season.rawValue - 2;
    }
    
    static func < (lhs: UserSemester, rhs: UserSemester) -> Bool {
        if lhs.isPriorCredit {
            return !rhs.isPriorCredit
        } else if rhs.isPriorCredit {
            return false
        }
        
        guard let lYear = lhs.year, let rYear = rhs.year else {
            return false
        }
        if lYear != rYear {
            return lYear < rYear
        }
        
        guard let lSeason = lhs.season, let rSeason = rhs.season else {
            return false
        }
        return lSeason.rawValue < rSeason.rawValue
    }
    
    static func == (lhs: UserSemester, rhs: UserSemester) -> Bool {
        if lhs.isPriorCredit && rhs.isPriorCredit {
            return true
        } else if lhs.isPriorCredit != rhs.isPriorCredit {
            return false
        }
        return lhs.season == rhs.season && lhs.year == rhs.year
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UserSemester else { return false }
        return other == self
    }
    
    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(year)
        hasher.combine(season)
        hasher.combine(isPriorCredit)
        return hasher.finalize()
    }
}
