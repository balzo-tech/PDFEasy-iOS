//
//  AppTrackingTransparency.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 03/05/21.
//

import Foundation
import Factory
import AppTrackingTransparency

protocol AppTrackingTransparency : AnyObject {
    var serviceSupported: Bool { get }
    var permissionGranted: Bool? { get }
    func requestPermissionIfNeeded() async
}

extension Container {
    var appTrackingTransparancy: Factory<AppTrackingTransparency> {
        self { AppTrackingTransparencyImpl() }.singleton
    }
}
