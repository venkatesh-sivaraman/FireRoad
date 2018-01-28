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
    
    weak var presentationDelegate: AppSettingsDelegate?
    
    lazy var settings: [AppSettingsGroup] = [
        AppSettingsGroup(items: [
            AppSettingsItem(title: "Allow Recommendations", type: .boolean, getter: { self.allowsRecommendations ?? false }, setter: { newValue in
                self.allowsRecommendations = newValue as? Bool
                if self.allowsRecommendations == true,
                    CourseManager.shared.recommenderUserID == nil || CourseManager.shared.loadPassword() == nil {
                    self.presentationDelegate?.showAuthenticationView()
                }
            })], header: nil, footer: "Your course selections and ratings will be securely sent to the FireRoad MIT server in order to help you find other courses you might like."),
        AppSettingsGroup(items: [
            AppSettingsItem(title: "Hide All Warnings", type: .boolean, getter: { self.hidesAllWarnings }, setter: { newValue in
                self.hidesAllWarnings = (newValue as? Bool) ?? false
            }), AppSettingsItem(title: "Allow Corequisites Together", type: .boolean, getter: { self.allowsCorequisitesTogether }, setter: { newValue in
                self.allowsCorequisitesTogether = (newValue as? Bool) ?? true
            })], header: "My Road", footer: "Turn off Allow Corequisites Together to display a warning when corequisites are taken in the same semester."),
        AppSettingsGroup(items: [
            AppSettingsItem(title: "Created by Venkatesh Sivaraman. In-app icons courtesy of icons8.com. All subject descriptions, evaluations, and course requirements © Massachusetts Institute of Technology.", type: .readOnlyText, getter: nil, setter: nil)], header: "Acknowledgements", footer: nil),
    ]
}
