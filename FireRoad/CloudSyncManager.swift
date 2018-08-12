//
//  CloudSyncManager.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 8/9/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol CloudSyncManagerDelegate: class {
    func cloudSyncManager(_ manager: CloudSyncManager, modifiedFileNamed name: String)
    func cloudSyncManager(_ manager: CloudSyncManager, renamedFileNamed name: String, to newName: String)
    func cloudSyncManager(_ manager: CloudSyncManager, deletedFileNamed name: String)
}

extension Notification.Name {
    static let CloudSyncManagerFinishedSyncing = Notification.Name(rawValue: "CloudSyncManagerFinishedSyncingNotification")
}

/// Used for printing success messages about cloud sync
func debugPrint(_ something: Any) {
    #if DEBUG
    print(something)
    #endif
}

let InitialDocumentTitle = "First Steps"

class CloudSyncManager: NSObject {

    struct URLSet {
        var sync: String
        var delete: String
        var browse: String
    }
    
    var preferencesPrefix: String
    var urls: URLSet
    var filesDirectory: String?
    var newDocumentGenerator: (() -> UserDocument)
    var pathExtension: String
    var isHandlingConflict = false
    
    weak var delegate: CloudSyncManagerDelegate?
    
    init(urls: URLSet, preferencesPrefix: String, filesDirectory: String?, docGen: @escaping (() -> UserDocument), pathExtension: String) {
        self.urls = urls
        self.preferencesPrefix = preferencesPrefix
        self.filesDirectory = filesDirectory
        self.newDocumentGenerator = docGen
        self.pathExtension = pathExtension
    }
    
    static let roadManager = CloudSyncManager(urls: URLSet(sync: CourseManager.urlBase + "/sync/sync_road/",
                                                           delete: CourseManager.urlBase + "/sync/delete_road/",
                                                           browse: CourseManager.urlBase + "/sync/roads/"),
                                              preferencesPrefix: "CloudSyncManager.Road.",
                                              filesDirectory: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first,
                                              docGen: { User() },
                                              pathExtension: ".road")
    
    static let scheduleManager = CloudSyncManager(urls: URLSet(sync: CourseManager.urlBase + "/sync/sync_schedule/",
                                                           delete: CourseManager.urlBase + "/sync/delete_schedule/",
                                                           browse: CourseManager.urlBase + "/sync/schedules/"),
                                              preferencesPrefix: "CloudSyncManager.Schedule.",
                                              filesDirectory: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first,
                                              docGen: { ScheduleDocument(courses: []) },
                                              pathExtension: ".sched")

    static let allManagers = [CloudSyncManager.roadManager, CloudSyncManager.scheduleManager]
    
    static var isHandlingConflict: Bool {
        return allManagers.contains(where: { $0.isHandlingConflict })
    }
    
    // MARK: Paths
    
    func urlForUserFile(named name: String) -> URL? {
        guard let dirPath = filesDirectory else {
            return nil
        }
        let url = URL(fileURLWithPath: dirPath).appendingPathComponent(name)
        return url
    }
    
    // MARK: - Preferences
    
    private static let dateFormatters: [DateFormatter] = ["yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ", // ISO 8601
        "yyyy-MM-dd'T'HH:mm:ssZZZZZ"].map({
            let formatter = DateFormatter()
            formatter.dateFormat = $0
            return formatter
        })
    
    func standardString(from date: Date) -> String {
        return CloudSyncManager.dateFormatters[0].string(from: date)
    }
    
    func date(from standardString: String) -> Date? {
        return CloudSyncManager.dateFormatters.compactMap({ $0.date(from: standardString )}).first
    }
    
    static let downloadDatePreferencesSuffix = "downloadDates"
    static let cloudModifiedDatePreferencesSuffix = "cloudModifiedDates"
    static let fileIDPreferencesSuffix = "fileIDs"
    static let userIDPreferencesSuffix = "uploaderUserIDs"

    private var documentIDs: [String: Int] {
        return UserDefaults.standard.dictionary(forKey: preferencesPrefix + CloudSyncManager.fileIDPreferencesSuffix) as? [String: Int] ?? [:]
    }
    
    func setDocumentID(_ id: Int?, forFileNamed name: String) {
        var documentIDs: [String: Int] = UserDefaults.standard.dictionary(forKey: preferencesPrefix + CloudSyncManager.fileIDPreferencesSuffix) as? [String: Int] ?? [:]
        documentIDs[name] = id
        UserDefaults.standard.set(documentIDs, forKey: preferencesPrefix + CloudSyncManager.fileIDPreferencesSuffix)
    }
    
    func documentID(forFileNamed name: String) -> Int? {
        guard let documentIDs = UserDefaults.standard.dictionary(forKey: preferencesPrefix + CloudSyncManager.fileIDPreferencesSuffix),
            let id = documentIDs[name] as? Int else {
                return nil
        }
        return id
    }
    
    func setUserID(_ id: String?, forFileNamed name: String) {
        var userIDs: [String: String] = UserDefaults.standard.dictionary(forKey: preferencesPrefix + CloudSyncManager.userIDPreferencesSuffix) as? [String: String] ?? [:]
        userIDs[name] = id
        UserDefaults.standard.set(userIDs, forKey: preferencesPrefix + CloudSyncManager.userIDPreferencesSuffix)
    }
    
    func userID(forFileNamed name: String) -> String? {
        guard let userIDs = UserDefaults.standard.dictionary(forKey: preferencesPrefix + CloudSyncManager.userIDPreferencesSuffix),
            let id = userIDs[name] as? String else {
                return nil
        }
        return id
    }
    
    func fileName(forDocumentID documentID: Int) -> String? {
        guard let documentIDs = UserDefaults.standard.dictionary(forKey: preferencesPrefix + CloudSyncManager.fileIDPreferencesSuffix) else {
            return nil
        }
        for (name, id) in documentIDs {
            if id as? Int == documentID {
                return name
            }
        }
        return nil
    }
    
    func setCloudModifiedDate(_ date: Date?, forFileNamed name: String) {
        debugPrint("Setting cloud modified date for \(name) to \(date?.timeAgo() ?? "n/a")")
        var dict: [String: String] = UserDefaults.standard.dictionary(forKey: preferencesPrefix + CloudSyncManager.cloudModifiedDatePreferencesSuffix) as? [String: String] ?? [:]
        dict[name] = date != nil ? standardString(from: date!) : nil
        UserDefaults.standard.set(dict, forKey: preferencesPrefix + CloudSyncManager.cloudModifiedDatePreferencesSuffix)
    }
    
    func cloudModifiedDate(forFileNamed name: String) -> Date? {
        guard let dict = UserDefaults.standard.dictionary(forKey: preferencesPrefix + CloudSyncManager.cloudModifiedDatePreferencesSuffix) else {
            return nil
        }
        return date(from: dict[name] as? String ?? "")
    }
    
    /// Returns the path with the most recent cloud modified date.
    func recentlyModifiedDocumentName() -> String? {
        guard let dict = UserDefaults.standard.dictionary(forKey: preferencesPrefix + CloudSyncManager.cloudModifiedDatePreferencesSuffix) else {
            return nil
        }
        if dict.count > 0,
            let (name, _) = dict.map({ ($0.key, date(from: ($0.value as? String) ?? "") ?? Date.distantPast) }).max(by: { $0.1.compare($1.1) == .orderedAscending }) {
            return name + pathExtension
        }
        return nil
    }
    
    func setDownloadDate(_ date: Date?, forFileNamed name: String) {
        debugPrint("Setting download date for \(name) to \(date?.timeAgo() ?? "n/a")")
        var dict: [String: String] = UserDefaults.standard.dictionary(forKey: preferencesPrefix + CloudSyncManager.downloadDatePreferencesSuffix) as? [String: String] ?? [:]
        dict[name] = date != nil ? standardString(from: date!) : nil
        UserDefaults.standard.set(dict, forKey: preferencesPrefix + CloudSyncManager.downloadDatePreferencesSuffix)
    }
    
    func downloadDate(forFileNamed name: String) -> Date? {
        guard let dict = UserDefaults.standard.dictionary(forKey: preferencesPrefix + CloudSyncManager.downloadDatePreferencesSuffix) else {
            return nil
        }
        return date(from: dict[name] as? String ?? "")
    }
    
    // MARK: - Alert Presentation
    
    func presentErrorMessage(with message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Sync Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
            alert.show()
        }
    }
    
    func presentConflictMessage(for file: String, modifiedAt modifiedDate: Date?, by modifiedAgent: String, completion: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            if let modifiedDate = modifiedDate {
                let agentString = modifiedAgent.count > 0 && modifiedAgent != "Anonymous" ? " by " + modifiedAgent : ""
                let message = "The remote copy of \"\(file)\" was modified \(modifiedDate.timeAgo().lowercased())\(agentString)."
                
                let alert = UIAlertController(title: "Sync Conflict", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: ConflictResponse.keepLocal, style: .default, handler: { ac in
                    DispatchQueue.global().async {
                        completion(ConflictResponse.keepLocal)
                    }
                }))
                alert.addAction(UIAlertAction(title: ConflictResponse.keepRemote, style: .default, handler: { ac in
                    DispatchQueue.global().async {
                        completion(ConflictResponse.keepRemote)
                    }
                }))
                alert.addAction(UIAlertAction(title: ConflictResponse.keepBoth, style: .cancel, handler: { ac in
                    DispatchQueue.global().async {
                        completion(ConflictResponse.keepBoth)
                    }
                }))
                alert.show()
            } else {
                let message = "The remote copy of \"\(file)\" was deleted."
                
                let alert = UIAlertController(title: "File Deleted", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: ConflictResponse.delete, style: .destructive, handler: { ac in
                    DispatchQueue.global().async {
                        completion(ConflictResponse.delete)
                    }
                }))
                alert.addAction(UIAlertAction(title: ConflictResponse.keepLocal, style: .cancel, handler: { ac in
                    DispatchQueue.global().async {
                        completion(ConflictResponse.keepLocal)
                    }
                }))
                alert.show()
            }
        }
    }
    
    // MARK: - Syncing
    
    enum JSONKeys {
        static let success = "success"
        static let logError = "error"
        static let userError = "error_msg"
        static let changeDate = "changed"
        static let downloadDate = "downloaded"
        static let id = "id"
        static let name = "name"
        static let contents = "contents"
        static let agent = "agent"
        static let override = "override"
        
        // Conflicts
        static let otherAgent = "other_agent"
        static let otherDate = "other_date"
        static let otherContents = "other_contents"
        static let otherName = "other_name"
    }

    struct SyncResult {
        static let updateRemote = "update_remote"
        static let updateLocal = "update_local"
        static let conflict = "conflict"
        static let error = "error"
        static let noChange = "no_change"
        
        var status: String
        var raw: [String: Any]
        var newContents: Any?
        var newName: String?
    }
    
    enum ConflictResponse {
        static let keepLocal = "Keep Local"
        static let keepRemote = "Keep Remote"
        static let keepBoth = "Keep Both"
        static let delete = "Delete Local"
    }
    
    var syncInProgress = false
    
    // MARK: Individual Files
    
    private func syncRequest(with document: UserDocument, justModified: Bool, override: Bool) -> URLRequest? {
        guard let name = document.fileName,
            let json = try? document.writeCoursesToJSON(),
            let url = URL(string: urls.sync) else {
                print("Can't get filename, JSON, or URL")
                return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        var body: [String: Any] = [JSONKeys.name: name, JSONKeys.contents: json]
        body[JSONKeys.changeDate] = justModified ? self.standardString(from: Date()) : (self.standardString(from: self.downloadDate(forFileNamed: name) ?? Date()))
        if let id = self.documentID(forFileNamed: name) {
            if let userID = self.userID(forFileNamed: name),
                let currentUser = CourseManager.shared.recommenderUserID,
                currentUser != userID {
                // Pretend it's a new file
            } else {
                body[JSONKeys.id] = id
            }
        }
        if let downloaded = self.downloadDate(forFileNamed: name) {
            body[JSONKeys.downloadDate] = self.standardString(from: downloaded)
        }
        body[JSONKeys.agent] = UIDevice.current.name
        if override {
            body[JSONKeys.override] = true
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print(error.localizedDescription)
        }
        
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        CourseManager.shared.applyBasicAuthentication(to: &request)

        return request
    }
    
    private func syncResponse(with document: UserDocument, data: Data, completion: ((Bool, SyncResult?) -> Void)?) {
        guard let name = document.fileName else {
            print("No name for document")
            completion?(false, nil)
            return
        }
        
        let realCompletion: (Bool, SyncResult?) -> Void = { (success, syncResult) in
            debugPrint("Syncing of \(name) was successful: \(success), \(syncResult?.status ?? "no status")")
            if let newContents = syncResult?.newContents {
                debugPrint("Updating contents")
                do {
                    try document.readCourses(fromJSON: newContents)
                    if let newName = syncResult?.newName, newName != name {
                        self.renameFile(at: name, to: newName, shouldSync: false, completion: { newURL in
                            document.filePath = newURL?.path
                            document.setNeedsSave()
                            document.autosave(cloudSync: false, sync: true)
                            DispatchQueue.main.async {
                                self.delegate?.cloudSyncManager(self, renamedFileNamed: name, to: newName)
                            }
                        })
                    } else {
                        document.setNeedsSave()
                        document.autosave(cloudSync: false, sync: true)
                        DispatchQueue.main.async {
                            self.delegate?.cloudSyncManager(self, modifiedFileNamed: name)
                        }
                    }
                } catch {
                    print("Invalid JSON for new contents")
                }
            }
            
            completion?(success, syncResult)
        }
        
        guard let deserialized = try? JSONSerialization.jsonObject(with: data),
            let result = deserialized as? [String: Any] else {
                print("Error decoding JSON")
                realCompletion(false, nil)
                return
        }

        guard (result[JSONKeys.success] as? Bool) == true else {
            if let message = result[JSONKeys.userError] as? String {
                self.presentErrorMessage(with: message)
            } else if let message = result[JSONKeys.logError] as? String {
                print("Sync error for \(name): \(message)")
            }
            realCompletion(false, SyncResult(status: SyncResult.error, raw: result, newContents: nil, newName: nil))
            return
        }
        
        guard let resultType = result["result"] as? String else {
            realCompletion(false, SyncResult(status: SyncResult.error, raw: result, newContents: nil, newName: nil))
            return
        }
        
        switch resultType {
        case SyncResult.updateRemote:
            self.setDownloadDate(Date(), forFileNamed: name)
            self.setCloudModifiedDate(Date(), forFileNamed: name)
            if let id = result[JSONKeys.id] as? Int {
                self.setDocumentID(id, forFileNamed: name)
            }
            if let userID = CourseManager.shared.recommenderUserID {
                self.setUserID(userID, forFileNamed: name)
            }
            realCompletion(true, SyncResult(status: resultType, raw: result, newContents: nil, newName: nil))
        case SyncResult.updateLocal:
            self.setDownloadDate(Date(), forFileNamed: name)
            if let dateString = result[JSONKeys.changeDate] as? String,
                let changeDate = date(from: dateString) {
                self.setCloudModifiedDate(changeDate, forFileNamed: name)
            }
            if let id = result[JSONKeys.id] as? Int {
                self.setDocumentID(id, forFileNamed: name)
            }
            if let userID = CourseManager.shared.recommenderUserID {
                self.setUserID(userID, forFileNamed: name)
            }
            realCompletion(true, SyncResult(status: resultType, raw: result, newContents: result[JSONKeys.contents], newName: result[JSONKeys.name] as? String))
        case SyncResult.conflict:
            guard let modifiedDateString = result[JSONKeys.otherDate] as? String,
                let modifiedAgentString = result[JSONKeys.otherAgent] as? String else {
                    return
            }
            var modifiedDate: Date?
            if modifiedDateString.count > 0 {
                modifiedDate = self.date(from: modifiedDateString)
            }
            if modifiedDate != nil {
                self.isHandlingConflict = true
                self.presentConflictMessage(for: name, modifiedAt: modifiedDate, by: modifiedAgentString, completion: { (action) in
                    self.conflictResponse(with: document, result: result, action: action, clientCompletion: completion, realCompletion: realCompletion)
                })
            } else {
                // The file was deleted on the server - just delete it locally
                self.setDownloadDate(nil, forFileNamed: name)
                self.setCloudModifiedDate(nil, forFileNamed: name)
                self.deleteFile(with: name)
                realCompletion(true, SyncResult(status: SyncResult.conflict, raw: result, newContents: nil, newName: nil))
            }
        case SyncResult.noChange:
            if let dateString = result[JSONKeys.changeDate] as? String,
                let changeDate = date(from: dateString) {
                self.setCloudModifiedDate(changeDate, forFileNamed: name)
            }
            realCompletion(true, SyncResult(status: resultType, raw: result, newContents: nil, newName: nil))
        default:
            print("Unknown sync result \(resultType)")
            realCompletion(false, SyncResult(status: resultType, raw: result, newContents: nil, newName: nil))
        }
    }
    
    private func conflictResponse(with document: UserDocument, result: [String: Any], action: String, clientCompletion: ((Bool, SyncResult?) -> Void)?, realCompletion: ((Bool, SyncResult?) -> Void)) {
        self.isHandlingConflict = false
        guard let name = document.fileName else {
            print("No name for document")
            realCompletion(false, nil)
            return
        }

        switch action {
        case ConflictResponse.keepLocal:
            self.sync(with: document, override: true, pause: false) { success, result in
                if success {
                    self.setDownloadDate(Date(), forFileNamed: name)
                    self.setCloudModifiedDate(Date(), forFileNamed: name)
                }
                clientCompletion?(success, result)
            }
        case ConflictResponse.keepRemote:
            self.setDownloadDate(Date(), forFileNamed: name)
            if let dateString = result[JSONKeys.otherDate] as? String,
                let changeDate = date(from: dateString) {
                self.setCloudModifiedDate(changeDate, forFileNamed: name)
            }
            realCompletion(true, SyncResult(status: SyncResult.conflict, raw: result, newContents: result[JSONKeys.otherContents], newName: result[JSONKeys.otherName] as? String))
        case ConflictResponse.keepBoth:
            // Keep the remote copy in a duplicate file
            self.sync(with: document, override: true, pause: false) { success, result in
                if success {
                    self.setDownloadDate(Date(), forFileNamed: name)
                    self.setCloudModifiedDate(Date(), forFileNamed: name)
                }
                clientCompletion?(success, result)
            }
            if let contents = result[JSONKeys.otherContents] {
                self.createFile(with: nil, name: (result[JSONKeys.otherName] as? String) ?? self.conflictName(from: name), contents: contents)
            }
        case ConflictResponse.delete:
            self.setDownloadDate(nil, forFileNamed: name)
            self.setCloudModifiedDate(nil, forFileNamed: name)
            self.deleteFile(with: name)
            realCompletion(true, SyncResult(status: SyncResult.conflict, raw: result, newContents: nil, newName: nil))
        default:
            print("Unknown action \(action)")
        }
    }
    
    func sync(with document: UserDocument, justModified: Bool = true, override: Bool = false, pause: Bool = true, _ completion: ((Bool, SyncResult?) -> Void)? = nil) {
        guard AppSettings.shared.allowsRecommendations == true else {
            return
        }
        
        DispatchQueue.global().async {
            while pause && self.syncInProgress {
                usleep(100)
            }
            if pause {
                self.syncInProgress = true
            }
            
            guard let request = self.syncRequest(with: document, justModified: justModified, override: override) else {
                if pause {
                    self.syncInProgress = false
                }
                completion?(false, nil)
                return
            }

            CourseManager.shared.loginAndSendDataTask(with: request, errorHandler: {
                if pause {
                    self.syncInProgress = false
                }
                completion?(false, nil)
            }, successHandler: { data in
                DispatchQueue.global().async {
                    self.syncResponse(with: document, data: data, completion: { (success, result) in
                        if pause {
                            self.syncInProgress = false
                        }
                        completion?(success, result)
                    })
                }
            })
        }
    }
    
    func deleteFileFromCloud(with name: String, completion: ((Bool) -> Void)? = nil) {
        setCloudModifiedDate(nil, forFileNamed: name)
        setDownloadDate(nil, forFileNamed: name)
        guard let id = documentID(forFileNamed: name) else {
            completion?(false)
            return
        }
        setDocumentID(nil, forFileNamed: name)
        setUserID(nil, forFileNamed: name)
        
        guard AppSettings.shared.allowsRecommendations == true,
            let cloudURL = URL(string: urls.delete) else {
            completion?(false)
            return
        }
        
        var request = URLRequest(url: cloudURL)
        request.httpMethod = "POST"
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: [JSONKeys.id: id])
        } catch {
            print(error.localizedDescription)
        }
        
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        CourseManager.shared.applyBasicAuthentication(to: &request)
        
        CourseManager.shared.loginAndSendDataTask(with: request, errorHandler: {
            print("Error deleting file on server")
        }, successHandler: { data in
            DispatchQueue.global().async {
                guard let deserialized = try? JSONSerialization.jsonObject(with: data),
                    let result = deserialized as? [String: Any] else {
                        print("Error decoding JSON")
                        completion?(false)
                        return
                }
                
                guard (result[JSONKeys.success] as? Bool) == true else {
                    if let message = result[JSONKeys.userError] as? String {
                        self.presentErrorMessage(with: message)
                    } else if let message = result[JSONKeys.logError] as? String {
                        print("Sync error for \(name): \(message)")
                    }
                    completion?(false)
                    return
                }
                
                debugPrint("Successfully deleted \(name) from server.")
                completion?(true)
            }
        })

    }
    
    // MARK: Overall Sync
    
    func syncAllResponse(with data: Data, completion: ((Bool) -> Void)?) {
        guard let deserialized = try? JSONSerialization.jsonObject(with: data),
            let result = deserialized as? [String: Any] else {
                print("JSON read error")
                self.syncInProgress = false
                completion?(false)
                return
        }
        
        guard (result[JSONKeys.success] as? Bool) == true else {
            if let message = result[JSONKeys.userError] as? String {
                self.presentErrorMessage(with: message)
            } else if let message = result[JSONKeys.logError] as? String {
                print("Sync error: \(message)")
            }
            self.syncInProgress = false
            completion?(false)
            return
        }
        
        guard let files = result["files"] as? [String: Any] else {
            self.syncInProgress = false
            completion?(false)
            return
        }
        
        let queue = ComputeQueue(label: self.preferencesPrefix)
        var deletedInitial: String?
        
        // Upload existing files that don't have IDs
        if let dir = self.filesDirectory,
            let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) {
            for file in contents {
                let myFileName = (file as NSString).deletingPathExtension
                guard (file as NSString).pathExtension == self.pathExtension.replacingOccurrences(of: ".", with: "") else {
                    continue
                }
                
                queue.async(taskName: myFileName, waitForSignal: true) {
                    if self.documentID(forFileNamed: myFileName) == nil {
                        // Upload the file
                        let deleted = self.syncAllUploadFile(named: myFileName, in: queue, deleteIfEmpty: (myFileName == InitialDocumentTitle))
                        if deleted {
                            deletedInitial = myFileName
                        }
                    } else if let id = self.documentID(forFileNamed: myFileName),
                        !files.keys.contains(String(id)) {
                        // Sync the file
                        self.syncAllSyncFile(named: myFileName, in: queue)
                    } else {
                        queue.proceed()
                    }
                }
            }
        } else {
            print("Couldn't get files from \(self.filesDirectory ?? "<no dir>")")
        }
        
        for (fileID, _) in files {
            guard let id = Int(fileID) else {
                continue
            }
            queue.async(taskName: fileID, waitForSignal: true) {
                if let name = self.fileName(forDocumentID: id),
                    let path = self.urlForUserFile(named: name + self.pathExtension)?.path,
                    FileManager.default.fileExists(atPath: path) {
                    // Sync the file
                    self.syncAllSyncFile(named: name, in: queue)
                } else {
                    // Download the new file
                    self.syncAllDownloadFile(with: id, in: queue)
                }
            }
        }
        
        // On completion
        queue.async {
            debugPrint("Complete!")
            if let deleteName = deletedInitial {
                DispatchQueue.main.async {
                    self.delegate?.cloudSyncManager(self, deletedFileNamed: deleteName)
                }
            }
            self.syncInProgress = false
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .CloudSyncManagerFinishedSyncing, object: self)
            }
            completion?(true)
        }
    }
    
    private func syncAllSyncFile(named name: String, in queue: ComputeQueue) {
        debugPrint("Syncing \(name)")
        guard let url = self.urlForUserFile(named: name + self.pathExtension) else {
            queue.proceed()
            return
        }
        let doc = self.newDocumentGenerator()
        doc.filePath = url.path
        do {
            try doc.readUserCourses(from: url.path)
            self.sync(with: doc, justModified: false, pause: false) { (success, result) in
                queue.proceed()
            }
        } catch {
            print("Error writing JSON: \(error)")
            queue.proceed()
        }
    }
    
    private func syncAllDownloadFile(with id: Int, in queue: ComputeQueue) {
        debugPrint("Downloading \(id)")
        self.downloadFile(with: id) { json in
            guard let jsonDict = json as? [String: Any],
                let name = jsonDict[JSONKeys.name] as? String,
                let contents = jsonDict[JSONKeys.contents] else {
                    queue.proceed()
                    return
            }
            self.createFile(with: id, name: name, contents: contents) { newName in
                if let newName = newName {
                    if let dateString = jsonDict[JSONKeys.changeDate] as? String,
                        let changeDate = self.date(from: dateString) {
                        self.setCloudModifiedDate(changeDate, forFileNamed: newName)
                    }
                    if let downloadedString = jsonDict[JSONKeys.downloadDate] as? String {
                        self.setDownloadDate(self.date(from: downloadedString) ?? Date(), forFileNamed: newName)
                    }
                }
                queue.proceed()
            }
        }
    }
    
    @discardableResult
    private func syncAllUploadFile(named name: String, in queue: ComputeQueue, deleteIfEmpty: Bool = false) -> Bool {
        debugPrint("Uploading \(name)")
        
        guard let dir = self.filesDirectory else {
            queue.proceed()
            return false
        }
        
        let doc = self.newDocumentGenerator()
        let path = (dir as NSString).appendingPathComponent(name + pathExtension)
        doc.filePath = path
        do {
            try doc.readUserCourses(from: path)
        } catch {
            print("Couldn't read courses from file")
            queue.proceed()
            return false
        }
        
        if deleteIfEmpty && doc.isEmpty {
            self.deleteFile(with: name) { (success) in
                debugPrint("Uploaded empty file \(name) successfully: \(success)")
                queue.proceed()
            }
            return true
        }
        
        self.sync(with: doc, pause: false) { (success, result) in
            debugPrint("Uploaded \(name) successfully: \(success)")
            queue.proceed()
        }
        return false
    }
    
    func syncAll(completion: ((Bool) -> Void)?) {
        debugPrint("Sync all")
        guard AppSettings.shared.allowsRecommendations == true,
            let url = URL(string: urls.browse),
            !CloudSyncManager.isHandlingConflict else {
                debugPrint("Aborting sync")
                return
        }
        
        DispatchQueue.global().async {
            while self.syncInProgress {
                usleep(500)
            }
            self.syncInProgress = true

            debugPrint("Executing sync all")
            var request = URLRequest(url: url)
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            CourseManager.shared.applyBasicAuthentication(to: &request)
            
            CourseManager.shared.loginAndSendDataTask(with: request, errorHandler: {
                self.syncInProgress = false
                completion?(false)
            }, successHandler: { data in
                DispatchQueue.global().async {
                    self.syncAllResponse(with: data, completion: completion)
                }
            })
        }
    }
    
    func downloadFile(with id: Int, completion: ((Any?) -> Void)?) {
        guard AppSettings.shared.allowsRecommendations == true else {
            return
        }
        var comps = URLComponents(string: urls.browse)
        comps?.queryItems = [URLQueryItem(name: "id", value: String(id))]
        guard let url = comps?.url else {
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        CourseManager.shared.applyBasicAuthentication(to: &request)
        
        CourseManager.shared.loginAndSendDataTask(with: request, errorHandler: {
            completion?(nil)
        }, successHandler: { data in
            do {
                let deserialized = try JSONSerialization.jsonObject(with: data)
                guard let result = deserialized as? [String: Any] else {
                    completion?(nil)
                    return
                }
                guard (result[JSONKeys.success] as? Bool) == true else {
                    if let message = result[JSONKeys.userError] as? String {
                        self.presentErrorMessage(with: message)
                    } else if let message = result[JSONKeys.logError] as? String {
                        print("Browse error: \(message)")
                    }
                    completion?(nil)
                    return
                }
                
                guard let file = result["file"] else {
                    completion?(nil)
                    return
                }
                
                completion?(file)
            } catch {
                print("Error decoding JSON: \(error)")
                completion?(nil)
            }
        })
    }
    
    // MARK: - Model Logic
    
    func conflictName(from originalName: String) -> String {
        let base = (originalName as NSString).deletingPathExtension
        var newID = base
        if let newURL = urlForUserFile(named: base + pathExtension),
            FileManager.default.fileExists(atPath: newURL.path) {
            
            var counter = 2
            while let otherURL = urlForUserFile(named: base + " \(counter)" + pathExtension),
                FileManager.default.fileExists(atPath: otherURL.path) {
                    counter += 1
            }
            newID = base + " \(counter)"
        }
        
        return newID
    }
    
    /**
     Creates a new file with the given name and contents. If the ID is none,
     uploads the file to the server; otherwise, assumes the file was obtained
     from the server.
     */
    func createFile(with id: Int?, name: String, contents: Any, completion: ((String?) -> Void)? = nil) {
        debugPrint("Creating file", name)
        let newFile = newDocumentGenerator()
        let newName = conflictName(from: name)

        newFile.filePath = urlForUserFile(named: newName + pathExtension)?.path
        do {
            try newFile.readCourses(fromJSON: contents)
        } catch {
            print("Error reading contents from JSON: \(contents)")
        }
        newFile.setNeedsSave()
        newFile.autosave(cloudSync: false, sync: true)
        
        if id != nil {
            setDocumentID(id, forFileNamed: newName)
            if let userID = CourseManager.shared.recommenderUserID {
                setUserID(userID, forFileNamed: name)
            }
        }
        if id == nil || newName != name {
            setDownloadDate(Date(), forFileNamed: newName)
            sync(with: newFile, pause: false) { (success, result) in
                completion?(success ? newName : nil)
            }
            setDownloadDate(Date(), forFileNamed: newName)
        } else {
            completion?(newName)
        }
    }
    
    func renameFile(at originalName: String, to newName: String, shouldSync: Bool = true, completion: ((URL?) -> Void)? = nil) {
        debugPrint("Renaming file at \(originalName) to \(newName), should sync \(shouldSync)")
        let originalBase = (originalName as NSString).deletingPathExtension

        let newID = newName + pathExtension
        guard let oldURL = urlForUserFile(named: originalBase + pathExtension),
            let newURL = urlForUserFile(named: newID),
            !FileManager.default.fileExists(atPath: newURL.path) else {
                let errorAlert = UIAlertController(title: "File Already Exists", message: "Please choose another title.", preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                errorAlert.show()
                completion?(nil)
                return
        }
        
        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            if let id = documentID(forFileNamed: originalBase) {
                setDocumentID(nil, forFileNamed: originalBase)
                setDocumentID(id, forFileNamed: newName)
            }
            if let userID = userID(forFileNamed: originalBase) {
                setUserID(nil, forFileNamed: originalBase)
                setUserID(userID, forFileNamed: newName)
            }
            if let date = cloudModifiedDate(forFileNamed: originalBase) {
                setCloudModifiedDate(nil, forFileNamed: originalBase)
                setCloudModifiedDate(date, forFileNamed: newName)
            }
            if let date = downloadDate(forFileNamed: originalBase) {
                setDownloadDate(nil, forFileNamed: originalBase)
                setDownloadDate(date, forFileNamed: newName)
            }

            completion?(newURL)
            
            if shouldSync {
                let doc = newDocumentGenerator()
                doc.filePath = newURL.path
                try doc.readUserCourses(from: newURL.path)
                sync(with: doc, pause: false)
            }
        } catch {
            let alert = UIAlertController(title: "Could Not Rename File", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
            alert.show()
            completion?(nil)
        }
    }
    
    func deleteFile(with name: String, localOnly: Bool = false, completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.global().async {
            guard let url = self.urlForUserFile(named: name + self.pathExtension) else {
                return
            }
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("Error deleting file: \(error)")
                return
            }
            
            if !localOnly {
                self.deleteFileFromCloud(with: name, completion: { success in
                    if let comp = completion {
                        DispatchQueue.main.async {
                            comp(success)
                        }
                    }
                })
            } else {
                DispatchQueue.main.async {
                    self.delegate?.cloudSyncManager(self, deletedFileNamed: name)
                }
                completion?(true)
            }
        }
    }
    
    func removeSyncInformation(forFileNamed name: String) {
        self.setDocumentID(nil, forFileNamed: name)
        self.setUserID(nil, forFileNamed: name)
        self.setDownloadDate(nil, forFileNamed: name)
        self.setCloudModifiedDate(nil, forFileNamed: name)
    }
    
    /// Returns a list of existing file names (without extension).
    func fileList() -> [String] {
        return documentIDs.keys.compactMap { (file) -> String? in
            if let path = urlForUserFile(named: file + pathExtension)?.path,
                FileManager.default.fileExists(atPath: path) {
                return file
            }
            return nil
        }
    }
}
