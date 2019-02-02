//
//  SubjectMarker.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/26/19.
//  Copyright © 2019 Base 12 Innovations. All rights reserved.
//

import Foundation

enum SubjectMarker: String {
    case pnr = "pnr"
    case abcnr = "abcnr"
    case exploratory = "exp"
    case pdf = "pdf"
    case listener = "listener"
    case easy = "easy"
    case difficult = "difficult"
    case maybe = "maybe"
    
    static let allMarkers: [SubjectMarker] = [.pnr, .abcnr, .exploratory, .pdf, .listener, .maybe, .easy, .difficult]
    
    func readableName() -> String {
        switch (self) {
        case .pnr:
            return "P/NR"
        case .abcnr:
            return "A/B/C/NR"
        case .exploratory:
            return "Exploratory"
        case .pdf:
            return "P/D/F"
        case .listener:
            return "Listener"
        case .easy:
            return "Easy"
        case .difficult:
            return "Difficult"
        case .maybe:
            return "Maybe"
        }
    }
    
    func imageName() -> String {
        switch (self) {
        case .pnr:
            return "marker-pnr"
        case .abcnr:
            return "marker-abcnr"
        case .exploratory:
            return "marker-exp"
        case .pdf:
            return "marker-pdf"
        case .listener:
            return "marker-listener"
        case .easy:
            return "marker-easy"
        case .difficult:
            return "marker-hard"
        case .maybe:
            return "marker-maybe"
        }
    }
}
