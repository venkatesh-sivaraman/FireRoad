//
//  ComputeQueue.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/9/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import UIKit

class ComputeQueue: NSObject {

    var label: String
    lazy private var queue = DispatchQueue(label: label)
    lazy private var accessQueue = DispatchQueue(label: label + "_access")

    init(label: String) {
        self.label = label
    }
    
    var isComputing = false
    private var computeItems: [(String?, () -> Void)] = []
    private var computeNames = Set<String>()
    
    func async(execute: @escaping () -> Void) {
        accessQueue.async {
            self.computeItems.append((nil, execute))
            self.compute()
        }
    }
    
    func async(taskName: String, execute: @escaping () -> Void) {
        accessQueue.sync {
            self.computeItems.append((taskName, execute))
            self.computeNames.insert(taskName)
            self.compute()
        }
    }
    
    func contains(_ job: String) -> Bool {
        return self.computeNames.contains(job)
    }
    
    private func compute() {
        if isComputing {
            return
        }
        queue.async {
            while self.computeItems.count > 0 {
                let (taskName, work) = self.accessQueue.sync { return self.computeItems.remove(at: 0) }
                work()
                if let name = taskName {
                    _ = self.accessQueue.sync { self.computeNames.remove(name) }
                }
            }
        }
        isComputing = false
    }
    
}
