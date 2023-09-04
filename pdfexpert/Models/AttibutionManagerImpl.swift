//
//  AttibutionManagerImpl.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/09/23.
//

import Foundation
import Factory
import BranchSDK
import UIKit

extension Container {
    var attibutionManager: Factory<AttributionManager> {
        self { AttributionManagerImpl() }.singleton
    }
}

class AttributionManagerImpl: AttributionManager {
    
    func onAppDidFinishLaunching(withLaunchOptions launchOptions:  [UIApplication.LaunchOptionsKey: Any]?) {
        #if STAGING
        Branch.setUseTestBranchKey(true)
        #endif
        Branch.getInstance().enableLogging()
//        Branch.getInstance().validateSDKIntegration()
        Branch.getInstance().initSession(launchOptions: launchOptions) { (params, error) in
            print("AttributionManagerImpl - Deeplink detected. Parameters: \((params as? [String: AnyObject]) ?? [:])")
            // TODO: Implement Deeplink from here
        }
    }
    
    func onOpenUrl(url: URL) {
        Branch.getInstance().handleDeepLink(url)
    }
}
