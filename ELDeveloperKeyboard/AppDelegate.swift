//
//  AppDelegate.swift
//  KaartKeyboard
//
//  Created by Zack LaVergne on 5/17/2017.
//  Copyright (c) 2017 Kaart Group. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var defaults = UserDefaults(suiteName: "group.com.kaartgroup.KaartKeyboard")

    /// Whether the user has added our keyboard in Settings.
    ///
    /// Static because it reads nothing but the bundle and the user's keyboard list. It used to be
    /// an instance method reached through an AppDelegateSingleton whose `appDelegate` property was
    /// never assigned -- nothing anywhere wrote to it -- so both call sites fell through their
    /// `?? false` and this never actually ran. The Set-Up row stayed visible after the keyboard was
    /// enabled, and the onboarding screen never presented itself. With no instance state to reach,
    /// the singleton was only ever the thing standing between the call sites and the answer.
    static func isKeyboardExtensionEnabled() -> Bool {
        // No fatalError here, which is what a missing identifier used to raise. It cannot happen in
        // a built app bundle, and "we could not tell" is a question this function already has an
        // answer for: report not-enabled and show the onboarding, rather than killing the app on
        // the way to its first screen.
        guard let appBundleIdentifier = Bundle.main.bundleIdentifier else { return false }

        guard let keyboards = UserDefaults.standard.dictionaryRepresentation()["AppleKeyboards"] as? [String] else {
            // There is no key `AppleKeyboards` in NSUserDefaults. That happens sometimes.
            return false
        }

        let keyboardExtensionBundleIdentifierPrefix = appBundleIdentifier + "."
        return keyboards.contains { $0.hasPrefix(keyboardExtensionBundleIdentifierPrefix) }
    }

//    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
//        defaults?.set(true, forKey: "english")
//        return true
//    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

