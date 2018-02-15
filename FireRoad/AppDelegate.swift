//
//  AppDelegate.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/2/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        HTTPCookieStorage.shared.cookieAcceptPolicy = .always
        loadCookies()
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        guard let rootTab = window?.rootViewController as? RootTabViewController else {
            return true
        }
        do {
            _ = try User(contentsOfFile: url.path, readOnly: true)
            rootTab.importCourseroad(from: url, copy: (options[.openInPlace] as? Bool) ?? false)
            return true
        } catch {
            let alert = UIAlertController(title: "Error in Road", message: "The file you opened could not be read.", preferredStyle: .alert)
            var presented: UIViewController = rootTab
            while presented.presentedViewController != nil {
                presented = presented.presentedViewController!
            }
            presented.present(alert, animated: true, completion: nil)
            
            if options[.openInPlace] as? Bool != true {
                try? FileManager.default.removeItem(at: url)
            }
            return false
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        saveCookies()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        loadCookies()
        
        if let rootTab = window?.rootViewController as? RootTabViewController {
            rootTab.updateSemesters()
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        saveCookies()
    }
    
    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        return true
    }
    
    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        return true
    }

    let cookieStorageKey = "adalfk823nfdbnvcj7ds8sd"
    func saveCookies() {
        guard let cookies = HTTPCookieStorage.shared.cookies else {
            return
        }
        let array = cookies.flatMap { (cookie) -> [HTTPCookiePropertyKey: Any]? in
            cookie.properties
        }
        UserDefaults.standard.set(array, forKey: cookieStorageKey)
        UserDefaults.standard.synchronize()
    }
    
    func loadCookies() {
        guard let cookies = UserDefaults.standard.value(forKey: cookieStorageKey) as? [[HTTPCookiePropertyKey: Any]] else {
            return
        }
        cookies.forEach { (cookie) in
            guard let cookie = HTTPCookie.init(properties: cookie) else {
                return
            }
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }
}

