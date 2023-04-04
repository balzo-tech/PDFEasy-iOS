//
//  AnalyticsManagerImpl.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/07/2020.
//

import Foundation
import Factory

extension Container {
    var analyticsManager: Factory<AnalyticsManager> {
        self { AnalyticsManagerImpl() }.singleton
    }
}

class AnalyticsManagerImpl: AnalyticsManager {
    
    private let platforms: [AnalyticsPlatform]
    
    init() {
        self.platforms = [FirebaseAnalyticsPlatform()]
    }
    
    func track(event: AnalyticsEvent) {
        print("Analytics - Tracked event: \(event)")
        self.platforms.forEach({ $0.track(event: event) })
    }
}
