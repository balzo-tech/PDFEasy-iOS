//
//  AnalyticsPlatform.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/04/23.
//

import Foundation

protocol AnalyticsPlatform {
    func track(event: AnalyticsEvent)
}
