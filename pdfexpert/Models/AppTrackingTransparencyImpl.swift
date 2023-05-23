//
//  AppTrackingTransparencyImpl.swift
//  FourBooks
//
//  Created by Leonardo Passeri on 03/05/21.
//  Copyright © 2021 4Books. All rights reserved.
//

import Foundation
import AppTrackingTransparency
#if FACEBOOK
import FacebookCore
#endif
import Factory

class AppTrackingTransparencyImpl: AppTrackingTransparency {
    
    var serviceSupported: Bool {
        if #available(iOS 14, *) {
            return true
        } else {
            return false
        }
    }
    
    var permissionGranted: Bool? {
        if #available(iOS 14, *) {
            return ATTrackingManager.trackingAuthorizationStatus.granted
        } else {
            return true
        }
    }
    
    @Injected(\.analyticsManager) var analyticsManager
    
    init() {
        self.updateFacebookAdvertiseTrackingSettings()
    }
    
    func requestPermissionIfNeeded() async {
        if #available(iOS 14, *) {
            debugPrint(for: self, message: "Current Auth Status: \(ATTrackingManager.trackingAuthorizationStatus.rawValue)")
        }
        guard self.permissionGranted == nil else {
            return
        }
        if #available(iOS 14, *) {
            return await withCheckedContinuation({ continuation in
                ATTrackingManager.requestTrackingAuthorization(completionHandler: { authorizationStatus in
                    self.updateFacebookAdvertiseTrackingSettings()
                    self.trackAuthorizationEvent(authorizationStatus: authorizationStatus)
                    continuation.resume()
                })
            })
        } else {
            return
        }
    }
    
    private func updateFacebookAdvertiseTrackingSettings() {
        let enableAdvertiserTracking = self.permissionGranted ?? false
        #if FACEBOOK
        Settings.isAdvertiserIDCollectionEnabled = enableAdvertiserTracking
        #endif
    }
    
    private func trackAuthorizationEvent(authorizationStatus: ATTrackingManager.AuthorizationStatus) {
        switch authorizationStatus {
          case .authorized:
            debugPrint(for: self, message: "Authorization Granted")
            self.analyticsManager.track(event: .appTrackingTransparancyAuthorized)
          default:
            debugPrint(for: self, message: "Authorization not granted")
            break
          }
    }
}

@available(iOS 14.0, *)
extension ATTrackingManager.AuthorizationStatus {
    var granted: Bool? {
        switch self {
        case .authorized: return true
        case .notDetermined: return nil
        case .denied, .restricted: return false
        @unknown default: return false
        }
    }
}
