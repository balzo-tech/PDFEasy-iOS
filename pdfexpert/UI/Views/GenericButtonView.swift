//
//  GenericButtonView.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 14/12/22.
//

import UIKit

enum GenericButtonTextStyleCategory: StyleCategory {
    case primaryBackground(shadow: Bool = true)
    case secondaryBackground(shadow: Bool = true)
    case transparentBackground(shadow: Bool = true)
    case feed
    
    var style: Style<GenericButtonView> {
        switch self {
        case .primaryBackground(let shadow): return Style<GenericButtonView> { buttonView in
            buttonView.backgroundColor = ColorPalette.color(withType: .primary)
            buttonView.addGradientView(.init(type: .primaryBackground))
            buttonView.button.apply(style: ButtonTextStyleCategory.secondaryBackground(customHeight: nil).style)
            buttonView.buttonAttributedTextStyle = AttributedTextStyle(fontStyle: .header2, colorType: .tertiaryText)
            if shadow {
                buttonView.addShadowLinear(goingDown: false)
            }
            }
        case .secondaryBackground(let shadow): return Style<GenericButtonView> { buttonView in
            buttonView.backgroundColor = ColorPalette.color(withType: .secondary)
            buttonView.button.apply(style: ButtonTextStyleCategory.primaryBackground(customHeight: nil).style)
            buttonView.buttonAttributedTextStyle = AttributedTextStyle(fontStyle: .header2, colorType: .secondaryText)
            if shadow {
                buttonView.addShadowLinear(goingDown: false)
            }
            }
        case .transparentBackground(let shadow): return Style<GenericButtonView> { buttonView in
            buttonView.backgroundColor = .clear
            buttonView.button.apply(style: ButtonTextStyleCategory.primaryBackground(customHeight: nil).style)
            buttonView.buttonAttributedTextStyle = AttributedTextStyle(fontStyle: .header2, colorType: .secondaryText)
            if shadow {
                buttonView.addShadowLinear(goingDown: false)
            }
            }
        case .feed: return Style<GenericButtonView> { buttonView in
            buttonView.backgroundColor = .clear
            buttonView.button.apply(style: ButtonTextStyleCategory.feed.style)
            buttonView.buttonAttributedTextStyle = AttributedTextStyle(fontStyle: .header2, colorType: .primaryText)
            }
        }
    }
}


class GenericButtonView: UIView {
    
    fileprivate var buttonAttributedTextStyle: AttributedTextStyle?
    
    fileprivate let button: UIButton = {
        let button = UIButton()
        button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 0.0, leading: 18.0, bottom: 0.0, trailing: 18.0)
        return button
    }()
    
    private var buttonEnabledObserver: NSKeyValueObservation?
    
    init(withTextStyleCategory textStyleCategory: GenericButtonTextStyleCategory,
         fillWidth: Bool = true,
         horizontalInset: CGFloat = Constants.Style.DefaultHorizontalMargins,
         topInset: CGFloat = 32.0,
         bottomInset: CGFloat = 32.0) {
        super.init(frame: .zero)
        
        self.addSubview(self.button)
        self.button.autoPinEdge(toSuperviewEdge: .top, withInset: topInset)
        self.button.autoPinEdge(toSuperviewEdge: .bottom, withInset: bottomInset)
        self.button.autoPinEdge(toSuperviewEdge: .leading, withInset: horizontalInset, relation: fillWidth ? .equal : .greaterThanOrEqual)
        self.button.autoPinEdge(toSuperviewEdge: .trailing, withInset: horizontalInset, relation: fillWidth ? .equal : .greaterThanOrEqual)
        self.button.autoAlignAxis(toSuperviewAxis: .vertical)
        self.apply(style: textStyleCategory.style)
        
        self.sharedSetup()
    }
    
    convenience init(withTextStyleCategory textStyleCategory: GenericButtonTextStyleCategory,
                     fillWidth: Bool = true,
                     horizontalInset: CGFloat = Constants.Style.DefaultHorizontalMargins,
                     height: CGFloat = Constants.Style.DefaultFooterHeight) {
        self.init(withStyle: textStyleCategory.style, fillWidth: fillWidth, horizontalInset: horizontalInset, height: height)
    }
    
    private init(withStyle style: Style<GenericButtonView>,
                 fillWidth: Bool = true,
                 horizontalInset: CGFloat = Constants.Style.DefaultHorizontalMargins,
                 height: CGFloat) {
        super.init(frame: .zero)
        
        self.addSubview(self.button)
        if let buttonHeight = self.button.heightConstraintValue, buttonHeight > height {
            self.autoSetDimension(.height, toSize: buttonHeight)
        } else {
            self.autoSetDimension(.height, toSize: height)
        }
        self.button.autoPinEdge(toSuperviewEdge: .top, withInset: 0.0, relation: .greaterThanOrEqual)
        self.button.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0.0, relation: .greaterThanOrEqual)
        self.button.autoPinEdge(toSuperviewEdge: .leading, withInset: horizontalInset, relation: fillWidth ? .equal : .greaterThanOrEqual)
        self.button.autoPinEdge(toSuperviewEdge: .trailing, withInset: horizontalInset, relation: fillWidth ? .equal : .greaterThanOrEqual)
        self.button.autoCenterInSuperview()
        self.apply(style: style)
        
        self.sharedSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private Methods
    
    private func sharedSetup() {
        self.buttonEnabledObserver = self.button.observe(\UIButton.isEnabled, changeHandler: { button, _ in
            if button.isEnabled {
                self.button.alpha = 1.0
            } else {
                self.button.alpha = 0.5
            }
        })
    }
    
    // MARK: - Public Methods
    
    public func addTarget(target: Any?, action: Selector) {
        self.button.addTarget(target, action: action, for: .touchUpInside)
    }
    
    public func setButtonText(_ text: String) {
        guard let attributedTextStyle = self.buttonAttributedTextStyle else {
            assertionFailure("Setting a text without attributed text style")
            return
        }
        let attributedText = NSAttributedString.create(withText: text, attributedTextStyle: attributedTextStyle)
        self.button.setAttributedTitle(attributedText, for: .normal)
    }
    
    public func setButtonEnabled(enabled: Bool) {
        self.button.isEnabled = enabled
    }
}

