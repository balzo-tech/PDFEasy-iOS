//
//  AttributionManager.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/09/23.
//

import Foundation
import UIKit

protocol AttributionManager : AnyObject {
    func onAppDidFinishLaunching(withLaunchOptions launchOptions:  [UIApplication.LaunchOptionsKey: Any]?)
    func onOpenUrl(url: URL)
}
