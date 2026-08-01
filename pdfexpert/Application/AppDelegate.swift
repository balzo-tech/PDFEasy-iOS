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

#if targetEnvironment(macCatalyst)

    // MARK: - The File menu
    //
    // SwiftUI cannot place these. `CommandGroup(replacing: .newItem)` needs the
    // "New" group UIKit builds for multi-scene apps, and this one is
    // single-window (`UIApplicationSupportsMultipleScenes = false`): every
    // button put there vanished, taking its shortcut with it — ⌘N, ⌘O, ⌘⇧S and
    // ⌘⇧P all did nothing, and the File menu showed only the system's own items,
    // greyed out because the app is not document-based.
    //
    // ⚠️ Two shortcuts have to be freed before ours are added, or the menu bar
    // fails to build and the app comes up with no window at all — the same way a
    // duplicated ⌃⌘S killed it once before. The system File menu carries Open…
    // on ⌘O (in `.open`, *not* `.openRecent`) and Duplicate on ⇧⌘S (in
    // `.document`). Removing all three costs nothing here: every item in them
    // was greyed out, because this app is not document-based.

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .main else { return }

        builder.remove(menu: .open)
        builder.remove(menu: .openRecent)
        builder.remove(menu: .document)

        let create = UIMenu(title: "",
                            identifier: UIMenu.Identifier("eu.balzo.pdfexpert.menu.create"),
                            options: .displayInline,
                            children: [
            UIKeyCommand(title: String(localized: "New PDF"),
                         action: #selector(self.menuNewPdf),
                         input: "n",
                         modifierFlags: .command),
            UIKeyCommand(title: String(localized: "Open…"),
                         action: #selector(self.menuOpenPdf),
                         input: "o",
                         modifierFlags: .command),
            UIKeyCommand(title: String(localized: "Scan"),
                         action: #selector(self.menuScan),
                         input: "s",
                         modifierFlags: [.command, .shift]),
            UIKeyCommand(title: String(localized: "Image to PDF"),
                         action: #selector(self.menuImageToPdf),
                         input: "p",
                         modifierFlags: [.command, .shift])
        ])

        let tools = UIMenu(title: "",
                           identifier: UIMenu.Identifier("eu.balzo.pdfexpert.menu.tools"),
                           options: .displayInline,
                           children: [
            UICommand(title: String(localized: "Merge PDFs"), action: #selector(self.menuMerge)),
            UICommand(title: String(localized: "Split PDF"), action: #selector(self.menuSplit)),
            UICommand(title: String(localized: "Compress PDF"), action: #selector(self.menuCompress))
        ])

        // Inserted back to front: each one goes to the top, so the tools end up
        // under the four that create a document.
        builder.insertChild(tools, atStartOfMenu: .file)
        builder.insertChild(create, atStartOfMenu: .file)
    }

    /// Menu items stay enabled while a tool or the onboarding is up and simply
    /// do nothing — same rule the keyboard has always followed on iPad. Greying
    /// them out instead would need this responder to be asked, and it is not on
    /// the chain once a full-screen cover is showing.
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        switch action {
        case #selector(self.menuNewPdf), #selector(self.menuOpenPdf), #selector(self.menuScan),
             #selector(self.menuImageToPdf), #selector(self.menuMerge), #selector(self.menuSplit),
             #selector(self.menuCompress):
            return true
        default:
            return super.canPerformAction(action, withSender: sender)
        }
    }

    @objc private func menuNewPdf() { PdfProMenuActions.run(.createPdf) }
    @objc private func menuOpenPdf() { PdfProMenuActions.run(.importPdf) }
    @objc private func menuScan() { PdfProMenuActions.run(.scan) }
    @objc private func menuImageToPdf() { PdfProMenuActions.run(.imageToPdf) }
    @objc private func menuMerge() { PdfProMenuActions.run(.merge) }
    @objc private func menuSplit() { PdfProMenuActions.run(.split) }
    @objc private func menuCompress() { PdfProMenuActions.run(.compressPdf) }

#endif

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

