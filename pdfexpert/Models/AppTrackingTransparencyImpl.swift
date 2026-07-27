//
//  AppTrackingTransparencyImpl.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 03/05/21.
//

import Foundation
import AppTrackingTransparency
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

    func requestPermissionIfNeeded() async {
        // There is no advertising identifier on the simulator, so the prompt
        // would only sit in front of every screen during development.
        #if targetEnvironment(simulator)
        return
        #else
        if #available(iOS 14, *) {
            debugPrint(for: self, message: "Current Auth Status: \(ATTrackingManager.trackingAuthorizationStatus.rawValue)")
        }
        guard self.permissionGranted == nil else {
            return
        }
        if #available(iOS 14, *) {
            return await withCheckedContinuation({ continuation in
                ATTrackingManager.requestTrackingAuthorization(completionHandler: { authorizationStatus in
                    self.trackAuthorizationEvent(authorizationStatus: authorizationStatus)
                    continuation.resume()
                })
            })
        } else {
            return
        }
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
