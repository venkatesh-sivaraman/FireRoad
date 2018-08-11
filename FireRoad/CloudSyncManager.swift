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
    static let changedDatePreferencesSuffix = "changedDates"
    static let fileIDPreferencesSuffix = "fileIDs"
    
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
    
    func setChangedDate(_ date: Date?, forFileNamed name: String) {
        print("Setting change date for \(name) to \(date?.timeAgo() ?? "n/a")")
        var dict: [String: String] = UserDefaults.standard.dictionary(forKey: preferencesPrefix + CloudSyncManager.changedDatePreferencesSuffix) as? [String: String] ?? [:]
        dict[name] = date != nil ? standardString(from: date!) : nil
        UserDefaults.standard.set(dict, forKey: preferencesPrefix + CloudSyncManager.changedDatePreferencesSuffix)
    }
    
    func changedDate(forFileNamed name: String) -> Date? {
        guard let dict = UserDefaults.standard.dictionary(forKey: preferencesPrefix + CloudSyncManager.changedDatePreferencesSuffix) else {
            return nil
        }
        return date(from: dict[name] as? String ?? "")
    }
    
    func setDownloadDate(_ date: Date?, forFileNamed name: String) {
        print("Setting download date for \(name) to \(date?.timeAgo() ?? "n/a")")
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
                
                let alert = UIAlertController(title: "Sync Conflict", message: message, preferredStyle: .alert)
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
        print("Executing sync with \(name)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        print(name, json)
        
        var body: [String: Any] = ["name": name, "contents": json]
        body["changed"] = justModified ? self.standardString(from: Date()) : (self.standardString(from: self.downloadDate(forFileNamed: name) ?? Date()))
        if let id = self.documentID(forFileNamed: name) {
            body["id"] = id
        }
        if let downloaded = self.downloadDate(forFileNamed: name) {
            body["downloaded"] = self.standardString(from: downloaded)
        }
        body["agent"] = UIDevice.current.name
        if override {
            body["override"] = true
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
            print("Syncing of \(name) was successful: \(success), \(syncResult?.status ?? "no status")")
            if let newContents = syncResult?.newContents {
                print("Updating contents")
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

        print("Received response for \(name): \(result)")
        guard (result["success"] as? Bool) == true else {
            if let message = result["error_msg"] as? String {
                self.presentErrorMessage(with: message)
            } else if let message = result["error"] as? String {
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
            self.setChangedDate(Date(), forFileNamed: name)
            if let id = result["id"] as? Int {
                self.setDocumentID(id, forFileNamed: name)
            }
            realCompletion(true, SyncResult(status: resultType, raw: result, newContents: nil, newName: nil))
        case SyncResult.updateLocal:
            self.setDownloadDate(Date(), forFileNamed: name)
            self.setChangedDate(Date(), forFileNamed: name)
            if let id = result["id"] as? Int {
                self.setDocumentID(id, forFileNamed: name)
            }
            realCompletion(true, SyncResult(status: resultType, raw: result, newContents: result["contents"], newName: result["name"] as? String))
        case SyncResult.conflict:
            guard let modifiedDateString = result["other_date"] as? String,
                let modifiedAgentString = result["other_agent"] as? String else {
                    return
            }
            var modifiedDate: Date?
            if modifiedDateString.count > 0 {
                modifiedDate = self.date(from: modifiedDateString)
            }
            self.isHandlingConflict = true
            self.presentConflictMessage(for: name, modifiedAt: modifiedDate, by: modifiedAgentString, completion: { (action) in
                self.conflictResponse(with: document, result: result, action: action, clientCompletion: completion, realCompletion: realCompletion)
            })
        case SyncResult.noChange:
            print("No change for \(name)")
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
            print("Keep local")
            self.sync(with: document, override: true) { success, result in
                if success {
                    self.setDownloadDate(Date(), forFileNamed: name)
                    self.setChangedDate(Date(), forFileNamed: name)
                }
                clientCompletion?(success, result)
            }
        case ConflictResponse.keepRemote:
            print("Keep remote")
            self.setDownloadDate(Date(), forFileNamed: name)
            self.setChangedDate(Date(), forFileNamed: name)
            realCompletion(true, SyncResult(status: SyncResult.conflict, raw: result, newContents: result["other_contents"], newName: result["other_name"] as? String))
        case ConflictResponse.keepBoth:
            print("Keep both")
            // Keep the remote copy in a duplicate file
            self.sync(with: document, override: true) { success, result in
                if success {
                    self.setDownloadDate(Date(), forFileNamed: name)
                    self.setChangedDate(Date(), forFileNamed: name)
                }
                clientCompletion?(success, result)
            }
            if let contents = result["other_contents"] {
                self.createFile(with: nil, name: (result["other_name"] as? String) ?? self.conflictName(from: name), contents: contents)
            }
        case ConflictResponse.delete:
            print("Delete")
            self.setDownloadDate(nil, forFileNamed: name)
            self.setChangedDate(nil, forFileNamed: name)
            self.deleteFile(with: name)
            realCompletion(true, SyncResult(status: SyncResult.conflict, raw: result, newContents: nil, newName: nil))
        default:
            print("Unknown action \(action)")
        }
    }
    
    func sync(with document: UserDocument, justModified: Bool = true, override: Bool = false, _ completion: ((Bool, SyncResult?) -> Void)? = nil) {
        guard AppSettings.shared.allowsRecommendations == true else {
            return
        }
        
        DispatchQueue.global().async {
            guard let request = self.syncRequest(with: document, justModified: justModified, override: override) else {
                print("Can't get URL request")
                completion?(false, nil)
                return
            }

            CourseManager.shared.loginAndSendDataTask(with: request, errorHandler: {
                completion?(false, nil)
            }, successHandler: { data in
                DispatchQueue.global().async {
                    self.syncResponse(with: document, data: data, completion: completion)
                }
            })
        }
    }
    
    func deleteFileFromCloud(with name: String, completion: ((Bool) -> Void)? = nil) {
        setChangedDate(nil, forFileNamed: name)
        setDownloadDate(nil, forFileNamed: name)
        guard let id = documentID(forFileNamed: name) else {
            completion?(false)
            return
        }
        setDocumentID(nil, forFileNamed: name)
        
        guard let cloudURL = URL(string: urls.delete) else {
            completion?(false)
            return
        }
        
        var request = URLRequest(url: cloudURL)
        request.httpMethod = "POST"
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: ["id": id])
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
                
                guard (result["success"] as? Bool) == true else {
                    if let message = result["error_msg"] as? String {
                        self.presentErrorMessage(with: message)
                    } else if let message = result["error"] as? String {
                        print("Sync error for \(name): \(message)")
                    }
                    completion?(false)
                    return
                }
                
                print("Successfully deleted \(name) from server.")
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
        
        guard (result["success"] as? Bool) == true else {
            if let message = result["error_msg"] as? String {
                self.presentErrorMessage(with: message)
            } else if let message = result["error"] as? String {
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
        
        for (fileID, _) in files {
            guard let id = Int(fileID) else {
                continue
            }
            queue.async(taskName: fileID, waitForSignal: true) {
                if let name = self.fileName(forDocumentID: id) {
                    // Sync the file
                    print("Syncing \(name)")
                    guard let url = self.urlForUserFile(named: name + self.pathExtension) else {
                        queue.proceed()
                        return
                    }
                    let doc = self.newDocumentGenerator()
                    doc.filePath = url.path
                    do {
                        try doc.readUserCourses(from: url.path)
                        self.sync(with: doc, justModified: false) { (success, result) in
                            queue.proceed()
                        }
                    } catch {
                        print("Error writing JSON: \(error)")
                    }
                } else {
                    // Download the new file
                    print("Downloading \(id)")
                    self.downloadFile(with: id) { json in
                        guard let jsonDict = json as? [String: Any],
                            let name = jsonDict["name"] as? String,
                            let contents = jsonDict["contents"] else {
                                queue.proceed()
                                return
                        }
                        self.createFile(with: id, name: name, contents: contents) { newName in
                            if let newName = newName,
                                let downloadedString = jsonDict["downloaded"] as? String {
                                self.setDownloadDate(self.date(from: downloadedString) ?? Date(), forFileNamed: newName)
                            }
                            queue.proceed()
                        }
                    }
                }
            }
        }
        
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
                        print("Uploading \(myFileName)")
                        
                        let doc = self.newDocumentGenerator()
                        let path = (dir as NSString).appendingPathComponent(file)
                        doc.filePath = path
                        do {
                            try doc.readUserCourses(from: path)
                        } catch {
                            print("Couldn't read courses from file")
                            queue.proceed()
                            return
                        }
                        self.sync(with: doc, { (success, result) in
                            print("Uploaded \(myFileName) successfully: \(success)")
                            queue.proceed()
                        })
                    } else if let id = self.documentID(forFileNamed: myFileName),
                        !files.keys.contains(String(id)) {
                        // Sync the file
                        print("Syncing \(myFileName)")
                        guard let url = self.urlForUserFile(named: myFileName + self.pathExtension) else {
                            queue.proceed()
                            return
                        }
                        let doc = self.newDocumentGenerator()
                        doc.filePath = url.path
                        do {
                            try doc.readUserCourses(from: url.path)
                            self.sync(with: doc, justModified: false) { (success, result) in
                                queue.proceed()
                            }
                        } catch {
                            print("Error writing JSON: \(error)")
                        }
                    } else {
                        queue.proceed()
                    }
                }
            }
        } else {
            print("Couldn't get files from \(self.filesDirectory ?? "<no dir>")")
        }
        
        // On completion
        queue.async {
            print("Complete!")
            self.syncInProgress = false
            completion?(true)
        }
    }
    
    func syncAll(completion: ((Bool) -> Void)?) {
        print("Sync all")
        guard AppSettings.shared.allowsRecommendations == true,
            let url = URL(string: urls.browse),
            !CloudSyncManager.isHandlingConflict else {
                return
        }
        
        DispatchQueue.global().async {
            while self.syncInProgress {
                usleep(500)
            }
            self.syncInProgress = true

            print("Executing sync all")
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
                guard (result["success"] as? Bool) == true else {
                    if let message = result["error_msg"] as? String {
                        self.presentErrorMessage(with: message)
                    } else if let message = result["error"] as? String {
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
        print("Creating file", name)
        let newFile = newDocumentGenerator()
        let newName = conflictName(from: name)

        newFile.filePath = urlForUserFile(named: newName + pathExtension)?.path
        do {
            try newFile.readCourses(fromJSON: contents)
        } catch {
            print("Error reading contents from JSON: \(contents)")
        }
        newFile.setNeedsSave()
        newFile.autosave(cloudSync: false)
        
        if id != nil {
            setDocumentID(id, forFileNamed: newName)
        }
        if id == nil || newName != name {
            setDownloadDate(Date(), forFileNamed: newName)
            sync(with: newFile) { (success, result) in
                completion?(success ? newName : nil)
            }
            setDownloadDate(Date(), forFileNamed: newName)
        } else {
            completion?(newName)
        }
    }
    
    func renameFile(at originalName: String, to newName: String, shouldSync: Bool = true, completion: ((URL?) -> Void)? = nil) {
        print("Renaming file at \(originalName) to \(newName), should sync \(shouldSync)")
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
            if let date = changedDate(forFileNamed: originalBase) {
                setChangedDate(nil, forFileNamed: originalBase)
                setChangedDate(date, forFileNamed: newName)
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
                sync(with: doc)
            }
        } catch {
            let alert = UIAlertController(title: "Could Not Rename File", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
            alert.show()
            completion?(nil)
        }
    }
    
    func deleteFile(with name: String, completion: ((Bool) -> Void)? = nil) {
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
            
            self.deleteFileFromCloud(with: name, completion: { success in
                if let comp = completion {
                    DispatchQueue.main.async {
                        comp(success)
                    }
                }
            })
        }
    }
}
