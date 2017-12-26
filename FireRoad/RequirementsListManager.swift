//
//  RequirementsListManager.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 12/11/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

let RequirementsDirectoryName = "requirements"

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
        if let resourcePath = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first as NSString?)?.appendingPathComponent(RequirementsDirectoryName),
            let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
            for pathName in contents where pathName.contains(".reql") {
                let fullPath = URL(fileURLWithPath: resourcePath).appendingPathComponent(pathName).path
                if let reqList = try? RequirementsList(contentsOf: fullPath) {
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
