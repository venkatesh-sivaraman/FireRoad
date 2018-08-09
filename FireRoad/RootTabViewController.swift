//
//  RootTabViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 10/7/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class RootTabViewController: UITabBarController, AuthenticationViewControllerDelegate, IntroViewControllerDelegate, CourseManagerAuthenticationDelegate {
    
    var blurView: UIVisualEffectView?
    var courseUpdatingHUD: MBProgressHUD?
    var successHUD: MBProgressHUD?
    
    func hideHUD() {
        self.courseUpdatingHUD?.hide(animated: true)
        UIView.animate(withDuration: 0.3, animations: {
            self.blurView?.effect = nil
        }, completion: { completed in
            self.blurView?.removeFromSuperview()
        })
    }
    
    var justLoaded = false
    override func viewDidLoad() {
        updateSemesters()
        justLoaded = true
        CourseManager.shared.authenticationDelegate = self
        
        loadRecentCourseroad()
        
        let menu = UIMenuController.shared
        menu.menuItems = [
            UIMenuItem(title: MenuItemStrings.view, action: #selector(CourseThumbnailCell.viewDetails(_:))),
            UIMenuItem(title: MenuItemStrings.rate, action: #selector(CourseThumbnailCell.rate(_:))),
            UIMenuItem(title: MenuItemStrings.warnings, action: #selector(CourseThumbnailCell.showWarnings(_:)))
        ]
    }
    
    var showingIntro = false
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if justLoaded, !CourseManager.shared.isLoaded {
            CourseManager.shared.loadCourses()
        }
        justLoaded = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !AppSettings.shared.showedIntro || AppSettings.shared.userCurrentSemester == 0 {
            showingIntro = true
            showIntro()
        }
        if !showingIntro {
            if AppSettings.shared.allowsRecommendations == nil {
                let alert = UIAlertController(title: "FireRoad Recommendations", message: "Allow your course ratings, roads, and schedules to be uploaded to the FireRoad server to generate personalized subject recommendations?\n\nYou can change this later in the app settings.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Allow", style: .default, handler: { (ac) in
                    AppSettings.shared.allowsRecommendations = true
                    CourseManager.shared.loginIfNeeded { _ in }
                }))
                alert.addAction(UIAlertAction(title: "Don't Allow", style: .cancel, handler: { (ac) in
                    AppSettings.shared.allowsRecommendations = false
                }))
                present(alert, animated: true, completion: nil)
            } else if AppSettings.shared.allowsRecommendations == true {
                CourseManager.shared.loginIfNeeded { _ in }
            }
        }
    }
    
    func updateSemesters() {
        guard courseUpdatingHUD == nil || courseUpdatingHUD?.isHidden == false else {
            return
        }
        let oldAvailableSemesters = CourseManager.shared.availableCatalogSemesters
        CourseManager.shared.checkForCatalogSemesterUpdates { (state, _, error, code) in
            DispatchQueue.main.async {
                switch state {
                case .completed:
                    if (CourseManager.shared.catalogSemester == nil ||
                        CourseManager.shared.catalogSemester?.pathValue == oldAvailableSemesters.last?.pathValue),
                        let currentSemester = CourseManager.shared.availableCatalogSemesters.last {
                        print("Setting current semester to \(currentSemester.stringValue)")
                        CourseManager.shared.catalogSemester = currentSemester
                        self.updateCourseCatalog()
                    } else if let newVersion = CourseManager.shared.availableCatalogSemesters.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                            // Prompt the user about updating the course catalog to the new semester
                            let alert = UIAlertController(title: "\(newVersion.season.capitalized) \(newVersion.year) Catalog Available", message: "Would you like to switch to the new catalog?", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { _ in
                                CourseManager.shared.catalogSemester = newVersion
                                self.updateCourseCatalog()
                            }))
                            alert.addAction(UIAlertAction(title: "Not Now", style: .cancel, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        })
                    }
                case .error:
                    if CourseManager.shared.catalogSemester == nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                            var message = ""
                            if let codeNum = code {
                                message = "The request received error code \(codeNum). Please try again later."
                            } else if let error = error {
                                message = error.localizedDescription
                            } else {
                                message = "Couldn't load initial course catalog. Please try again later."
                            }
                            let alert = UIAlertController(title: "Error Loading Catalog", message: message, preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                            alert.addAction(UIAlertAction(title: "Retry", style: .default, handler: { _ in
                                self.updateSemesters()
                            }))
                            self.present(alert, animated: true, completion: nil)
                        })
                    }
                    break
                default:
                    print("Shouldn't have gotten \(state) from catalog semester updater")
                }
            }
        }
    }
    
    func updateCourseCatalog() {
        CourseManager.shared.checkForCourseCatalogUpdates { (state, progressOpt, error, code) in
            DispatchQueue.main.async {
                switch state {
                case .newVersionAvailable:
                    guard self.courseUpdatingHUD == nil else {
                        break
                    }
                    let blur = UIVisualEffectView(effect: nil)
                    blur.frame = self.view.bounds
                    self.blurView = blur
                    self.view.addSubview(blur)
                    blur.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
                    blur.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
                    blur.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
                    blur.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
                    
                    let hud = MBProgressHUD.showAdded(to: blur.contentView, animated: true)
                    hud.mode = .determinateHorizontalBar
                    hud.label.text = "Updating subject catalog…"
                    self.courseUpdatingHUD = hud
                    
                    UIView.animate(withDuration: 0.3, animations: {
                        blur.effect = UIBlurEffect(style: .light)
                    })
                case .noUpdatesAvailable:
                    if !CourseManager.shared.isLoaded {
                        CourseManager.shared.loadCourses()
                    }
                    break
                case .downloading:
                    guard let progress = progressOpt else {
                        break
                    }
                    self.courseUpdatingHUD?.progress = progress
                case .completed:
                    if CourseManager.shared.isLoaded {
                        self.courseUpdatingHUD?.label.text = "Loading subjects…"
                        self.courseUpdatingHUD?.progress = 0.0
                        print("Loading courses")
                        CourseManager.shared.loadCourses()
                        self.updateCourseLoadingProgressHUD()
                    } else {
                        self.hideHUD()
                        print("Loading courses")
                        CourseManager.shared.loadCourses()
                        self.reloadRequirementsView()
                    }
                case .error:
                    self.hideHUD()
                    var errorMessage = ""
                    if let err = error {
                        errorMessage += err.localizedDescription + "\n\n"
                    } else if let errorCode = code {
                        errorMessage += "Received HTTP error code \(errorCode).\n\n"
                    }
                    errorMessage += "Update will try again on the next launch."
                    let alert = UIAlertController(title: "Error Updating Subjects", message: errorMessage, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                    CourseManager.shared.loadCourses()
                    self.reloadRequirementsView()
                }
            }
        }
    }
    
    func addCourse(_ course: Course, to semester: UserSemester? = nil) -> UserSemester? {
        guard let courseRoadVC = childViewController(where: { $0 is CourseroadViewController }) as? CourseroadViewController else {
            return nil
        }
        //self.selectedViewController = containingVC
        let ret = courseRoadVC.addCourse(course, to: semester)
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud.mode = .customView
        let imageView = UIImageView(image: UIImage(named: "Checkmark"))
        imageView.frame = CGRect(x: 0.0, y: 0.0, width: 72.0, height: 72.0)
        hud.customView = imageView
        hud.label.text = "Added \(course.subjectID!)"
        hud.isSquare = true
        successHUD = hud
        let tapper = UITapGestureRecognizer(target: self, action: #selector(RootTabViewController.tapOnHUD(_:)))
        hud.addGestureRecognizer(tapper)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            hud.hide(animated: true)
            self.successHUD = nil
        }
        return ret
    }
    
    func addCourseToSchedule(_ course: Course) {
        guard let scheduleVC = childViewController(where: { $0 is ScheduleViewController }) as? ScheduleViewController else {
            print("Couldn't get schedule view controller")
            return
        }
        _ = scheduleVC.addCourse(course)
        if let tab = viewControllers?.first(where: { scheduleVC.isDescendant(of: $0) }) {
            selectedViewController = tab
        }
    }

    var currentUser: User? {
        didSet {
            if CourseManager.shared.isLoaded {
                currentUser?.setBaselineRatings()
            }
        }
    }
    
    var currentSchedule: ScheduleDocument? {
        guard let scheduleVC = childViewController(where: { $0 is ScheduleViewController }) as? ScheduleViewController else {
            print("Couldn't get schedule view controller")
            return nil
        }
        return scheduleVC.currentSchedule
    }
    
    var currentScheduleOptions: [Schedule]? {
        guard let scheduleVC = childViewController(where: { $0 is ScheduleViewController }) as? ScheduleViewController else {
            print("Couldn't get schedule view controller")
            return nil
        }
        return scheduleVC.scheduleOptions
    }
    
    func displaySchedule(with courses: [Course], name: String) {
        guard let scheduleVC = childViewController(where: { $0 is ScheduleViewController }) as? ScheduleViewController else {
            print("Couldn't get schedule view controller")
            return
        }
        scheduleVC.loadNewSchedule(named: name + SchedulePathExtension, courses: courses, addToEmptyIfPossible: true)
        if let tab = viewControllers?.first(where: { scheduleVC.isDescendant(of: $0) }) {
            selectedViewController = tab
        }
    }
    
    func reloadRequirementsView() {
        RequirementsListManager.shared.clearRequirementsLists()
        if let browserVC = childViewController(where: { $0 is RequirementsBrowserViewController }) as? RequirementsBrowserViewController, browserVC.isViewLoaded {
            browserVC.reloadRequirements()
        } else {
            RequirementsListManager.shared.reloadRequirementsLists()
        }
    }
    
    @objc func tapOnHUD(_ sender: UITapGestureRecognizer) {
        successHUD?.hide(animated: true)
        successHUD = nil
    }
    
    func updateCourseLoadingProgressHUD() {
        DispatchQueue.global().async {
            while !CourseManager.shared.isLoaded {
                self.courseUpdatingHUD?.progress = CourseManager.shared.loadingProgress
                usleep(100)
            }
            self.hideHUD()
        }
    }
    
    // MARK: - Authentication
    
    var authenticationCompletionBlocks: [(String?) -> Void]?
    
    func showAuthenticationView(with request: URLRequest, completion: ((String?) -> Void)?) {
        if authenticationCompletionBlocks == nil {
            authenticationCompletionBlocks = []
        }
        if let comp = completion {
            authenticationCompletionBlocks?.append(comp)
        }
        DispatchQueue.main.async {
            guard let auth = self.storyboard?.instantiateViewController(withIdentifier: "AuthenticationVC") as? AuthenticationViewController else {
                return
            }
            auth.delegate = self
            auth.request = request
            let nav = UINavigationController(rootViewController: auth)
            self.present(nav, animated: true, completion: nil)
        }
    }

    func authenticationViewControllerCanceled(_ auth: AuthenticationViewController) {
        dismiss(animated: true, completion: nil)
        AppSettings.shared.allowsRecommendations = false
        if let blocks = authenticationCompletionBlocks {
            for block in blocks {
                block(nil)
            }
        }
        authenticationCompletionBlocks = nil
    }
    
    func authenticationViewController(_ auth: AuthenticationViewController, finishedWith jsonString: String?) {
        dismiss(animated: true, completion: nil)
        if let blocks = authenticationCompletionBlocks {
            for block in blocks {
                block(jsonString)
            }
        }
        authenticationCompletionBlocks = nil
    }
    
    // MARK: - Handling Courseroads
    
    let recentCourseroadPathDefaultsKey = "recent-courseroad-filepath"
    
    var courseroadDirectory: String? {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
    }
    
    func urlForCourseroad(named name: String) -> URL? {
        guard let dirPath = courseroadDirectory else {
            return nil
        }
        let url = URL(fileURLWithPath: dirPath).appendingPathComponent(name)
        return url
    }
    
    func loadCourseroad(named name: String) {
        guard let url = urlForCourseroad(named: name) else {
            return
        }
        do {
            currentUser = try User(contentsOfFile: url.path)
            UserDefaults.standard.set(url.lastPathComponent, forKey: recentCourseroadPathDefaultsKey)
        } catch {
            print("Error loading user: \(error)")
        }
    }
    
    func loadNewCourseroad(named name: String) {
        self.currentUser = User()
        if let url = self.urlForCourseroad(named: name) {
            self.currentUser?.filePath = url.path
        }
        self.currentUser?.coursesOfStudy = [ "girs" ]
        self.currentUser?.autosave()
        if let path = self.currentUser?.filePath {
            UserDefaults.standard.set((path as NSString).lastPathComponent, forKey: self.recentCourseroadPathDefaultsKey)
        }
    }
    
    var isLoadingUser = false
    
    func loadRecentCourseroad() {
        var loaded = false
        if let recentPath = UserDefaults.standard.string(forKey: recentCourseroadPathDefaultsKey),
            let url = urlForCourseroad(named: recentPath) {
            do {
                currentUser = try User(contentsOfFile: url.path)
                loaded = true
            } catch {
                print("Error loading user: \(error)")
            }
        }
        if !loaded {
            isLoadingUser = true
            DispatchQueue.global().async {
                while !CourseManager.shared.isLoaded {
                    usleep(100)
                }
                DispatchQueue.main.async {
                    self.loadNewCourseroad(named: "First Steps.road")
                    self.isLoadingUser = false
                }
            }
        }
    }
    
    func importCourseroad(from oldURL: URL, copy: Bool) {
        let presenter = self.presentedViewController ?? self
        
        let base = (oldURL.lastPathComponent as NSString).deletingPathExtension
        var newID = base
        if let newURL = urlForCourseroad(named: newID + ".road"),
            FileManager.default.fileExists(atPath: newURL.path) {
            var counter = 2
            while let otherURL = urlForCourseroad(named: base + " \(counter).road"),
                FileManager.default.fileExists(atPath: otherURL.path) {
                    counter += 1
            }
            newID = base + " \(counter)"
        }
        
        do {
            guard let newURL = urlForCourseroad(named: newID + ".road") else {
                return
            }
            if copy {
                try FileManager.default.copyItem(at: oldURL, to: newURL)
            } else {
                try FileManager.default.moveItem(at: oldURL, to: newURL)
            }
            
            guard let courseroadVC = childViewController(where: { $0 is CourseroadViewController }) as? CourseroadViewController else {
                print("Couldn't get courseroad view controller")
                return
            }
            courseroadVC.loadCourseroad(named: newID + ".road")
            if let tab = viewControllers?.first(where: { courseroadVC.isDescendant(of: $0) }) {
                selectedViewController = tab
            }
        } catch {
            let alert = UIAlertController(title: "Could Not Import Road", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
            presenter.present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: - Intro
    
    func showIntro() {
        let sb = UIStoryboard(name: "Intro", bundle: nil)
        guard let intro = sb.instantiateInitialViewController() as? IntroViewController else {
            print("Couldn't get intro out of storyboard")
            return
        }
        intro.delegate = self
        present(intro, animated: true, completion: nil)
    }
    
    func introViewController(_ intro: IntroViewController, selected yearNumber: Int) {
        AppSettings.shared.userCurrentSemester = CourseManager.shared.inferSemester(from: yearNumber)
    }
    
    func introViewControllerDismissed(_ intro: IntroViewController) {
        showingIntro = false
        AppSettings.shared.showedIntro = true
        dismiss(animated: true, completion: nil)
    }
}
