//
//  AppTrackingTransparency.swift
//  FourBooks
//
//  Created by Leonardo Passeri on 03/05/21.
//  Copyright © 2021 4Books. All rights reserved.
//

import Foundation
import Factory

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
