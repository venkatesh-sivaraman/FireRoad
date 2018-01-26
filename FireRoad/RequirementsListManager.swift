//
//  RequirementsListManager.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 12/11/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

let RequirementsDirectoryName = "requirements"
let TestRequirementsDirectoryName = "test-reqs"

// Put test requirement files in ~/Library/Developer/CoreSimulator/Devices/22A9FC79-1571-4808-ABA7-EEF4AFEB551B/data/Containers/Data/Application/F786476B-E86C-419E-B08F-DD27AC53BEBB/Documents/test-reqs for iPhone 8 Plus

class RequirementsListManager: NSObject {
    static let shared: RequirementsListManager = RequirementsListManager()
    
    private(set) var requirementsLists: [RequirementsList] = []
    
    private var requirementsListsByID: [String: RequirementsList] = [:]
    
    func clearRequirementsLists() {
        requirementsLists = []
        requirementsListsByID = [:]
    }

    func reloadRequirementsLists() {
        requirementsLists = []
        requirementsListsByID = [:]
        loadRequirementsLists()
    }
    
    private static let requirementsVersionDefaultsKey = "RequirementsListManager.requirementsVersion"
    var requirementsVersion: Int {
        get {
            return UserDefaults.standard.integer(forKey: RequirementsListManager.requirementsVersionDefaultsKey)
        } set {
            UserDefaults.standard.set(newValue, forKey: RequirementsListManager.requirementsVersionDefaultsKey)
        }
    }
    
    func loadRequirementsLists() {
        // We only want to load these lists once
        guard requirementsLists.count == 0 else {
            return
        }
        requirementsListsByID = [:]
        guard let docsPath = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first as NSString?) else {
            return
        }
        let resourcePath = docsPath.appendingPathComponent(RequirementsDirectoryName)
        if var contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
            contents = contents.map({ URL(fileURLWithPath: resourcePath).appendingPathComponent($0).path })
            // Testing contents
            let testPath = docsPath.appendingPathComponent(TestRequirementsDirectoryName)
            if let testContents = try? FileManager.default.contentsOfDirectory(atPath: testPath) {
                contents += testContents.map({ URL(fileURLWithPath: testPath).appendingPathComponent($0).path })
            }
            for fullPath in contents where fullPath.contains(".reql") {
                if let reqList = try? RequirementsList(contentsOf: fullPath) {
                    if let idx = requirementsLists.index(where: { $0.listID == reqList.listID }) {
                        requirementsLists.remove(at: idx)
                    }
                    requirementsLists.append(reqList)
                    requirementsListsByID[reqList.listID] = reqList
                }
            }
        }
        requirementsLists.sort(by: { ($0.mediumTitle?.compare($1.mediumTitle ?? "") ?? .orderedDescending) == .orderedAscending })
    }
    
    func requirementList(withID id: String) -> RequirementsList? {
        if requirementsLists.count == 0 {
            loadRequirementsLists()
        }
        return requirementsListsByID[id]
    }
}
