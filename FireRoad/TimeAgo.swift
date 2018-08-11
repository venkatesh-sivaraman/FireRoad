//
//  TimeAgo.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 8/9/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import Foundation

extension Date {
    func timeAgo(numericDates: Bool = false) -> String {
        
        let calendar = Calendar.current
        let unitFlags = Set<Calendar.Component>([.minute, .hour, .day, .weekOfYear, .month, .year, .second])
        let now = Date()
        var earliest: Date
        var latest: Date
        if now.compare(self) == .orderedAscending {
            earliest = now
            latest = self
        } else {
            earliest = self
            latest = now
        }
        let components: DateComponents = calendar.dateComponents(unitFlags, from: earliest, to: latest)
        
        let year = components.year ?? 0
        if (year >= 2) {
            return "\(year) years ago"
        } else if (year >= 1){
            if (numericDates){
                return "1 year ago"
            } else {
                return "Last year"
            }
        }
        let month = components.month ?? 0
        if (month >= 2) {
            return "\(month) months ago"
        } else if (month >= 1){
            if (numericDates){
                return "1 month ago"
            } else {
                return "Last month"
            }
        }
        let weekOfYear = components.weekOfYear ?? 0
        if (weekOfYear >= 2) {
            return "\(weekOfYear) weeks ago"
        } else if (weekOfYear >= 1){
            if (numericDates){
                return "1 week ago"
            } else {
                return "Last week"
            }
        }
        let day = components.day ?? 0
        if (day >= 2) {
            return "\(day) days ago"
        } else if (day >= 1){
            if (numericDates){
                return "1 day ago"
            } else {
                return "Yesterday"
            }
        }
        let hour = components.hour ?? 0
        if (hour >= 2) {
            return "\(hour) hours ago"
        } else if (hour >= 1){
            if (numericDates){
                return "1 hour ago"
            } else {
                return "An hour ago"
            }
        }
        let minute = components.minute ?? 0
        if (minute >= 2) {
            return "\(minute) minutes ago"
        } else if (minute >= 1){
            if (numericDates){
                return "1 minute ago"
            } else {
                return "A minute ago"
            }
        }
        let second = components.second ?? 0
        if (second >= 3) {
            return "\(second) seconds ago"
        }
        
        return "Just now"
    }
}
