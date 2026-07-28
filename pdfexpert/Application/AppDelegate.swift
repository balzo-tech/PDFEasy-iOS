//
//  AppDelegate.swift
//  pdfexpert
//
//  Created by Leonardo Passeri on 28/03/23.
//

import UIKit
import FirebaseCore
import FirebaseAppCheck
import AppleAttribution
import Factory

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // App Check has to be told which provider to use *before* Firebase is
        // configured — afterwards the default one is already in place. It is what
        // lets the proxy tell our app from a script with a copy of its traffic,
        // which is the only reason the OpenAI key can live on a server instead of
        // in this binary.
        AppCheck.setAppCheckProviderFactory(PdfProAppCheckProviderFactory())

        // Firebase init
        FirebaseApp.configure()

        // ProjectInfo Validation
        ProjectInfo.validate()

        // Apple Search Ads attribution. Started only with a real key: `configure`
        // is idempotent and cannot be undone, so an empty one would leave the SDK
        // running against nothing for the rest of the session. It captures the
        // AdServices token by itself from here; no ATT prompt is involved.
        if !ProjectInfo.appleAttributionApiKey.isEmpty {
            AppleAttribution.configure(apiKey: ProjectInfo.appleAttributionApiKey)
        }
        
        self.setupAppearance()
        
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
    
    private func setupAppearance() {
        UINavigationBar.appearance().isTranslucent = false
        UINavigationBar.appearance().tintColor = UIColor(ColorPalette.primaryText)
        UINavigationBar.appearance().largeTitleTextAttributes = [.font : FontPalette.uiFontMedium(withSize: 24)]
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(ColorPalette.secondaryBG)
        tabBarAppearance.selectionIndicatorTintColor = UIColor(ColorPalette.buttonGradientStart)
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().standardAppearance = tabBarAppearance
    }
}

