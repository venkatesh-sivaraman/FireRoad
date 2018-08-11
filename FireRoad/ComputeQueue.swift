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
    private var computeItems: [(String?, () -> Void, Bool)] = []
    private var computeNames = Set<String>()
    private var currentTask: (String?, () -> Void, Bool)?
    private var canProceed = false
    
    func async(execute: @escaping () -> Void) {
        accessQueue.async {
            self.computeItems.append((nil, execute, false))
            self.compute()
        }
    }
    
    func async(taskName: String, waitForSignal: Bool = false, execute: @escaping () -> Void) {
        accessQueue.sync {
            self.computeItems.append((taskName, execute, waitForSignal))
            self.computeNames.insert(taskName)
            self.compute()
        }
    }
    
    func contains(_ job: String) -> Bool {
        return self.computeNames.contains(job)
    }
    
    func proceed() {
        accessQueue.async {
            self.canProceed = true
        }
    }
    
    private func compute() {
        if isComputing {
            return
        }
        queue.async {
            while self.computeItems.count > 0 {
                let task = self.accessQueue.sync { return self.computeItems.remove(at: 0) }
                self.currentTask = task
                let (taskName, work, waitForSignal) = task
                work()
                if waitForSignal {
                    while !self.canProceed {
                        usleep(500)
                    }
                    self.canProceed = false
                }
                if let name = taskName {
                    _ = self.accessQueue.sync { self.computeNames.remove(name) }
                }
            }
        }
        isComputing = false
    }
    
}
