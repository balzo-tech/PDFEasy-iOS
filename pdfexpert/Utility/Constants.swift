//
//  Constants.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 13/12/22.
//

import Foundation
import AVFoundation

struct Constants {
    
    struct Style {
        static let DefaultHorizontalMargins: CGFloat = 24.0
        static let DefaultFooterHeight: CGFloat = 134.0
        static let DefaultTextButtonHeight: CGFloat = 52.0
        static let FeedCellButtonHeight: CGFloat = 44.0
        static let EditButtonHeight: CGFloat = 26.0
        static let DefaultBottomMargin: CGFloat = 20.0
        static let SurveyPickerDefaultHeight: CGFloat = 300.0
    }
    struct Resources {
        static let DefaultBundleName: String = "ForYouAndMe"
        static let AppVersion: String? = {
            guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                  let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
                assertionFailure("Missing Info Plist")
                return nil
            }
            return "Version: \(version) (\(buildNumber))"
        }()
    }
}
