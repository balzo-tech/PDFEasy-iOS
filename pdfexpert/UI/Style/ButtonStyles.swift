//
//  ButtonStyles.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 13/12/22.
//

import UIKit
import PureLayout

enum ButtonTextStyleCategory: StyleCategory {
    case primaryBackground(customHeight: CGFloat?)
    case secondaryBackground(customHeight: CGFloat?)
    case genericErrorStyle
    case feed
    case edit
    case clearSelectAll
    
    var style: Style<UIButton> {
        switch self {
        case .primaryBackground(let customHeight): return Style<UIButton> { button in
            let buttonHeight = self.buttonHeight(fromCustomHeight: customHeight)
            button.heightConstraintValue = buttonHeight
            button.layer.cornerRadius = buttonHeight / 2.0
            button.backgroundColor = ColorPalette.color(withType: .gradientPrimaryEnd)
            button.setTitleColor(ColorPalette.color(withType: .secondaryText), for: .normal)
            button.titleLabel?.font = FontPalette.fontStyleData(forStyle: .header2).font
            button.addShadowButton()
            }
        case .secondaryBackground(let customHeight): return Style<UIButton> { button in
            let buttonHeight = self.buttonHeight(fromCustomHeight: customHeight)
            button.heightConstraintValue = buttonHeight
            button.layer.cornerRadius = buttonHeight / 2.0
            button.backgroundColor = ColorPalette.color(withType: .secondary)
            button.setTitleColor(ColorPalette.color(withType: .tertiaryText), for: .normal)
            button.titleLabel?.font = FontPalette.fontStyleData(forStyle: .header2).font
            button.addShadowButton()
            }
        case .genericErrorStyle: return Style<UIButton> { button in
            let buttonHeight = Constants.Style.DefaultTextButtonHeight
            button.heightConstraintValue = buttonHeight
            button.layer.cornerRadius = buttonHeight / 2.0
            button.backgroundColor = ColorPalette.errorPrimaryColor
            button.setTitleColor(ColorPalette.errorSecondaryColor, for: .normal)
            button.titleLabel?.font = FontPalette.fontStyleData(forStyle: .header2).font
            button.addShadowButton()
            }
        case .feed: return Style<UIButton> { button in
            let buttonHeight = Constants.Style.FeedCellButtonHeight
            button.heightConstraintValue = buttonHeight
            button.layer.cornerRadius = buttonHeight / 2.0
            button.backgroundColor = ColorPalette.color(withType: .secondary)
            button.setTitleColor(ColorPalette.color(withType: .primaryText), for: .normal)
            button.titleLabel?.font = FontPalette.fontStyleData(forStyle: .header2).font
            button.addShadowButton()
            }
        case .edit: return Style<UIButton> { button in
            let buttonHeight = Constants.Style.EditButtonHeight
            button.heightConstraintValue = buttonHeight
            button.layer.cornerRadius = buttonHeight / 2.0
            button.backgroundColor = .clear
            button.setTitleColor(ColorPalette.color(withType: .secondaryText), for: .normal)
            button.titleLabel?.font = FontPalette.fontStyleData(forStyle: .header3).font
            button.layer.borderWidth = 2.0
            button.layer.borderColor = ColorPalette.color(withType: .secondaryText).cgColor
            }
        case .clearSelectAll: return Style<UIButton> { button in
            let buttonHeight = Constants.Style.EditButtonHeight
            button.heightConstraintValue = buttonHeight
            button.backgroundColor = .clear
            button.setTitleColor(ColorPalette.color(withType: .primary), for: .normal)
            button.titleLabel?.font = FontPalette.fontStyleData(forStyle: .paragraph).font
            button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 8.0, leading: 8.0, bottom: 8.0, trailing: 8.0)
            }
        }
    }
        
    private func buttonHeight(fromCustomHeight customHeight: CGFloat?) -> CGFloat {
        if let customHeight = customHeight {
            return customHeight
        } else {
            return Constants.Style.DefaultTextButtonHeight
        }
    }
}
