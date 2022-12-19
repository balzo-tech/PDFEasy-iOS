//
//  FontPalette.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 13/12/22.
//

import UIKit

public struct FontStyleData {
    let font: UIFont
    let lineSpacing: CGFloat
    let uppercase: Bool
    
    public init(font: UIFont, lineSpacing: CGFloat, uppercase: Bool) {
        self.font = font
        self.lineSpacing = lineSpacing
        self.uppercase = uppercase
    }
}

public typealias FontStyleMap = [FontStyle: FontStyleData]

public enum FontStyle: String, CaseIterable {
    case title
    case header2
    case header3
    case paragraph
    case menu
    case titleButton
    
    fileprivate var defaultData: FontStyleData {
        switch self {
        case .title: return FontStyleData(font: UIFont(name: "Montserrat-ExtraBold", size: 28.0) ?? UIFont.systemFont(ofSize: 24.0, weight: .bold), lineSpacing: 6.0, uppercase: false)
        case .header2: return FontStyleData(font: UIFont(name: "Montserrat-Regular", size: 20.0) ?? UIFont.systemFont(ofSize: 20.0, weight: .regular), lineSpacing: 6.0, uppercase: false)
        case .paragraph: return FontStyleData(font: UIFont(name: "Montserrat-Medium", size: 16.0) ?? UIFont.systemFont(ofSize: 16.0, weight: .regular), lineSpacing: 5.0, uppercase: false)
        case .header3: return FontStyleData(font: UIFont(name: "Montserrat-Medium", size: 13.0) ?? UIFont.systemFont(ofSize: 13.0, weight: .regular), lineSpacing: 5.0, uppercase: false)
        case .menu: return FontStyleData(font: UIFont(name: "Montserrat-Medium", size: 13.0) ?? UIFont.systemFont(ofSize: 13.0, weight: .regular), lineSpacing: 5.0, uppercase: false)
        case .titleButton: return FontStyleData(font: UIFont(name: "Montserrat-Bold", size: 16.0) ?? UIFont.systemFont(ofSize: 16.0, weight: .bold), lineSpacing: 5.0, uppercase: false)
        }
    }
}

public class FontPalette {
    
    private static var fontStyleMap: FontStyleMap = [:]
    
    public static func initialize(withFontStyleMap fontStyleMap: FontStyleMap) {
        self.fontStyleMap = fontStyleMap
    }
    
    static func fontStyleData(forStyle style: FontStyle) -> FontStyleData {
        return self.fontStyleMap[style] ?? style.defaultData
    }
    
    static func checkFontAvailability() {
        FontStyle.allCases.forEach { style in
            assert(self.fontStyleMap[style] != nil, "Missing font style data for style '\(style.rawValue)'")
        }
    }
}
