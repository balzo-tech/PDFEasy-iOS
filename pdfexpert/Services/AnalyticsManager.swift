//
//  AnalyticsManager.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 15/12/22.
//

import Foundation

protocol AnalyticsPlatform {
    func track(event: AnalyticsEvent)
}

class AnalyticsManager: AnalyticsService {
    
    private let platforms: [AnalyticsPlatform]
    
    init() {
        self.platforms = [FirebaseAnalyticsPlatform()]
    }
    
    func track(event: AnalyticsEvent) {
        print("Analytics - Tracked event: \(event)")
        self.platforms.forEach({ $0.track(event: event) })
    }
}
