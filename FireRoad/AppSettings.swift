//
//  AppSettings.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/28/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol AppSettingsDelegate: class {
    func showAuthenticationView()
}

struct AppSettingsItem {
    enum SettingType {
        case boolean
        case readOnlyText
        case button
        case checkmark
    }
    
    var title: String
    var type: SettingType
    var getter: (() -> Any?)?
    var setter: ((Any?) -> Void)?
    var currentValue: Any? {
        get {
            return getter?()
        } set {
            setter?(newValue)
        }
    }
}

struct AppSettingsGroup {
    var items: [AppSettingsItem]
    var header: String?
    var footer: String?
    var reloadOnSelect: Bool
}

class AppSettings: NSObject {

    static var shared: AppSettings = AppSettings()
    
    private let hidesAllWarningsDefaultsKey = "AppSettings.hidesAllWarnings"
    
    var hidesAllWarnings: Bool {
        get {
            if UserDefaults.standard.object(forKey: hidesAllWarningsDefaultsKey) == nil {
                UserDefaults.standard.set(false, forKey: hidesAllWarningsDefaultsKey)
                return false
            }
            return UserDefaults.standard.bool(forKey: hidesAllWarningsDefaultsKey)
        } set {
            UserDefaults.standard.set(newValue, forKey: hidesAllWarningsDefaultsKey)
        }
    }
    
    private let allowsCorequisitesTogetherDefaultsKey = "AppSettings.allowsCorequisitesTogether"
    
    var allowsCorequisitesTogether: Bool {
        get {
            if UserDefaults.standard.object(forKey: allowsCorequisitesTogetherDefaultsKey) == nil {
                UserDefaults.standard.set(true, forKey: allowsCorequisitesTogetherDefaultsKey)
                return true
            }
            return UserDefaults.standard.bool(forKey: allowsCorequisitesTogetherDefaultsKey)
        } set {
            UserDefaults.standard.set(newValue, forKey: allowsCorequisitesTogetherDefaultsKey)
        }
    }
    
    private let allowsRecommendationsDefaultsKey = "CourseManager.allowsRecommendations"
    
    private var _allowsRecommendations: Bool?
    var allowsRecommendations: Bool? {
        get {
            if _allowsRecommendations == nil {
                switch UserDefaults.standard.integer(forKey: allowsRecommendationsDefaultsKey) {
                case 0:
                    _allowsRecommendations = nil
                case 1:
                    _allowsRecommendations = false
                default:
                    _allowsRecommendations = true
                }
            }
            return _allowsRecommendations
        } set {
            if let newValue = newValue {
                UserDefaults.standard.set(newValue ? 2 : 1, forKey: allowsRecommendationsDefaultsKey)
                _allowsRecommendations = newValue
            } else {
                UserDefaults.standard.set(0, forKey: allowsRecommendationsDefaultsKey)
                _allowsRecommendations = newValue
            }
        }
    }
    
    private let hasShownSignupDefaultsKey = "CourseManager.hasShownSignup"
    var hasShownSignup: Bool {
        get {
            if UserDefaults.standard.object(forKey: hasShownSignupDefaultsKey) == nil {
                UserDefaults.standard.set(false, forKey: hasShownSignupDefaultsKey)
                return false
            }
            return UserDefaults.standard.bool(forKey: hasShownSignupDefaultsKey)
        } set {
            UserDefaults.standard.set(newValue, forKey: hasShownSignupDefaultsKey)
        }
    }

    private let userCurrentSemesterDefaultsKey = "AppSettings.userCurrentSemester"
    
    var userCurrentSemester: Int {
        get {
            if UserDefaults.standard.object(forKey: userCurrentSemesterDefaultsKey) == nil {
                UserDefaults.standard.set(0, forKey: userCurrentSemesterDefaultsKey)
                return 0
            }
            return UserDefaults.standard.integer(forKey: userCurrentSemesterDefaultsKey)
        } set {
            if newValue != userCurrentSemester, let sem = UserSemester(rawValue: newValue) {
                CourseManager.shared.updateUserSemester(sem)
            }
            UserDefaults.standard.set(newValue, forKey: userCurrentSemesterDefaultsKey)
        }
    }
    
    private let showedIntroDefaultsKey = "AppSettings.showedIntro"
    
    var showedIntro: Bool {
        get {
            if UserDefaults.standard.object(forKey: showedIntroDefaultsKey) == nil {
                UserDefaults.standard.set(false, forKey: showedIntroDefaultsKey)
                return false
            }
            return UserDefaults.standard.bool(forKey: showedIntroDefaultsKey)
        } set {
            UserDefaults.standard.set(newValue, forKey: showedIntroDefaultsKey)
        }
    }

    weak var presentationDelegate: AppSettingsDelegate?
    
    var settings: [AppSettingsGroup] {
        var recItems: [AppSettingsItem] = [
            AppSettingsItem(title: "Sync and Recommendations", type: .boolean, getter: { self.allowsRecommendations ?? false }, setter: { newValue in
                self.allowsRecommendations = newValue as? Bool
                if self.allowsRecommendations == true, !CourseManager.shared.isLoggedIn {
                    self.presentationDelegate?.showAuthenticationView()
                }
            })]
        if self.allowsRecommendations == true {
            recItems.append(AppSettingsItem(title: CourseManager.shared.isLoggedIn ? "Log Out" : "Log In", type: .button, getter: { CourseManager.shared.recommenderUsername }, setter: { _ in
                if CourseManager.shared.isLoggedIn {
                    self.allowsRecommendations = false
                    CourseManager.shared.logout()
                } else {
                    self.presentationDelegate?.showAuthenticationView()
                }
            }))
        }
        return [
            AppSettingsGroup(items: recItems, header: nil, footer: "Your course selections will be synced across your devices and securely used to generate helpful recommendations. MIT login is required.", reloadOnSelect: true),
            AppSettingsGroup(items: [
                AppSettingsItem(title: "Hide All Warnings", type: .boolean, getter: { self.hidesAllWarnings }, setter: { newValue in
                    self.hidesAllWarnings = (newValue as? Bool) ?? false
                }), AppSettingsItem(title: "Allow Corequisites Together", type: .boolean, getter: { self.allowsCorequisitesTogether }, setter: { newValue in
                    self.allowsCorequisitesTogether = (newValue as? Bool) ?? true
                })], header: "My Road", footer: "Turn off Allow Corequisites Together to display a warning when corequisites are taken in the same semester.", reloadOnSelect: false),
            AppSettingsGroup(items: [
                self.yearSettingsItem(with: "1st Year", yearNumber: 1),
                self.yearSettingsItem(with: "2nd Year", yearNumber: 2),
                self.yearSettingsItem(with: "3rd Year", yearNumber: 3),
                self.yearSettingsItem(with: "4th Year", yearNumber: 4),
                self.yearSettingsItem(with: "5th Year", yearNumber: 5)
                ], header: "Class Year", footer: "Choose your current or upcoming school year.", reloadOnSelect: true),
            AppSettingsGroup(items: [
                AppSettingsItem(title: "Created by Venkatesh Sivaraman. Course evaluation data courtesy of Edward Fan; additional major/minor requirements contributed by Tanya Smith, Maia Hannahs, and Cindy Shi. In-app icons courtesy of icons8.com.\n\nAll subject descriptions, evaluations, and course requirements © Massachusetts Institute of Technology. FireRoad is not intended to be your sole source of course information - please be sure to check your department's website to make sure you have the most up-to-date information.", type: .readOnlyText, getter: nil, setter: nil),
                AppSettingsItem(title: "Send Feedback", type: .button, getter: nil, setter: { _ in
                    guard let url = URL(string: "mailto:base12apps@gmail.com?subject=FireRoad%20Feedback") else {
                        return
                    }
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }),
                AppSettingsItem(title: "Requirements Editor", type: .button, getter: nil, setter: { _ in
                    guard let url = URL(string: CourseManager.urlBase + "/requirements") else {
                        return
                    }
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                })], header: "About and Contact", footer: "Use the Requirements Editor to request changes to major and minor specifications. For other corrections or feedback, choose Send Feedback.", reloadOnSelect: false)
        ]}
    
    func yearSettingsItem(with title: String, yearNumber: Int) -> AppSettingsItem {
        return AppSettingsItem(title: title, type: .checkmark, getter: { UserSemester(rawValue: self.userCurrentSemester)?.yearNumber() == yearNumber }, setter: { newValue in
            if (newValue as? Bool) == true {
                self.userCurrentSemester = CourseManager.shared.inferSemester(from: yearNumber)
            }
        })
    }
}
