//
//  ArrayExtension.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 9/29/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import Foundation

extension Collection {
    
    func chunked(by distance: IndexDistance) -> [[SubSequence.Iterator.Element]] {
        var index = startIndex
        let iterator: AnyIterator<Array<SubSequence.Iterator.Element>> = AnyIterator {
            defer {
                index = self.index(index, offsetBy: distance, limitedBy: self.endIndex) ?? self.endIndex
            }
            
            let newIndex = self.index(index, offsetBy: distance, limitedBy: self.endIndex) ?? self.endIndex
            let range = index ..< newIndex
            return index != self.endIndex ? Array(self[range]) : nil
        }
        
        return Array(iterator)
    }
    
}
