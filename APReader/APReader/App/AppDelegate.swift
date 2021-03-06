//
//  AppDelegate.swift
//  APReader
//
//  Created by Tangos on 2020/7/25.
//  Copyright © 2020 Tangorios. All rights reserved.
//

import UIKit
import MSAL
import AppCenter
import AppCenterAnalytics
import AppCenterCrashes
import Tiercel

let appDelegate = UIApplication.shared.delegate as! AppDelegate

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    // workaround
    var window: UIWindow?

    var sessionManager: SessionManager = {
        var configuration = SessionConfiguration()
        configuration.allowsCellularAccess = true
        let path = Cache.defaultDiskCachePathClosure("APReader.OneDrive")
        let cacahe = Cache("OneDrive", downloadPath: path)
        let manager = SessionManager("OneDrive", configuration: configuration, cache: cacahe, operationQueue: DispatchQueue(label: "com.tango.SessionManager.operationQueue"))
        return manager
    }()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        MSAppCenter.start("07987603-5e0a-4898-bcef-185ff9250a0f", withServices:[
          MSAnalytics.self,
          MSCrashes.self
        ])
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        guard let sourceApplication = options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String else {
            return false
        }
        
        return MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: sourceApplication)
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {

        if sessionManager.identifier == identifier {
            sessionManager.completionHandler = completionHandler
        }
    }

}

