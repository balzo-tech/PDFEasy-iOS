//
//  UIStackView+Extensions.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 14/12/22.
//

import UIKit
import PureLayout

public extension UIStackView {
    func addBlankSpace(space: CGFloat) {
        let view = UIView()
        view.backgroundColor = .clear
        let attribute = self.axis == .vertical ? NSLayoutConstraint.Attribute.height : NSLayoutConstraint.Attribute.width
        NSLayoutConstraint.activate([NSLayoutConstraint(item: view,
                                                        attribute: attribute,
                                                        relatedBy: NSLayoutConstraint.Relation.equal,
                                                        toItem: nil,
                                                        attribute: NSLayoutConstraint.Attribute.notAnAttribute,
                                                        multiplier: 1,
                                                        constant: space)])
        self.addArrangedSubview(view)
    }
    
    func addArrangedSubview(_ view: UIView, horizontalInset: CGFloat, verticalInset: CGFloat = 0) {
        self.addArrangedSubview(view, leftInset: horizontalInset,
                                rightInset: horizontalInset,
                                topInset: verticalInset,
                                bottomInset: verticalInset)
    }
    
    func addArrangedSubview(_ view: UIView, leftInset: CGFloat,
                            rightInset: CGFloat,
                            topInset: CGFloat = 0,
                            bottomInset: CGFloat = 0) {
        
        if leftInset > 0.0 || rightInset > 0.0 || topInset > 0.0 || bottomInset > 0.0 {
            let containerView = view.embedInView(withInsets: UIEdgeInsets(top: topInset,
                                                                          left: leftInset,
                                                                          bottom: bottomInset,
                                                                          right: rightInset))
            self.addArrangedSubview(containerView)
        } else {
            self.addArrangedSubview(view)
        }
    }
    
    func addLabel(text: String,
                  font: UIFont,
                  textColor: UIColor,
                  textAlignment: NSTextAlignment = .center,
                  numberOfLines: Int = 0,
                  lineSpacing: CGFloat = 0.0,
                  underlined: Bool = false,
                  horizontalInset: CGFloat = 0) {
        let label = self.getLabel(text: text,
                                  font: font,
                                  textColor: textColor,
                                  textAlignment: textAlignment,
                                  numberOfLines: numberOfLines,
                                  lineSpacing: lineSpacing,
                                  underlined: underlined)
        self.addArrangedSubview(label, horizontalInset: horizontalInset)
    }
    
    func addLabel(attributedString: NSAttributedString, numberOfLines: Int = 0, horizontalInset: CGFloat = 0) {
        let label = self.getLabel(attributedString: attributedString, numberOfLines: numberOfLines)
        self.addArrangedSubview(label, horizontalInset: horizontalInset)
    }
    
    func addHeaderImage(image: UIImage?, height: CGFloat? = nil, horizontalInset: CGFloat = 0) {
        let imageContainerView = UIView()
        imageContainerView.backgroundColor = UIColor.clear
        let imageView = UIImageView()
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageContainerView.addSubview(imageView)
        imageView.autoPinEdge(toSuperviewEdge: .top)
        imageView.autoPinEdge(toSuperviewEdge: .bottom)
        imageView.autoAlignAxis(toSuperviewAxis: .vertical)
        imageView.autoPinEdge(toSuperviewEdge: .leading, withInset: horizontalInset, relation: .greaterThanOrEqual)
        imageView.autoPinEdge(toSuperviewEdge: .trailing, withInset: horizontalInset, relation: .greaterThanOrEqual)
        if let height = height {
            imageView.autoSetDimension(.height, toSize: height)
        }
        self.addArrangedSubview(imageContainerView)
    }
    
    func addTextualSeparator(lineColor: UIColor,
                             text: String,
                             font: UIFont,
                             textColor: UIColor,
                             textAlignment: NSTextAlignment = .center,
                             numberOfLines: Int = 0,
                             underlined: Bool = false,
                             horizontalSpacing: CGFloat = 16,
                             horizontalInset: CGFloat = 0) {
        let stackView = UIStackView()
        stackView.spacing = horizontalSpacing
        stackView.distribution = .fill
        stackView.axis = .horizontal
        
        let lineViewBuilder: (() -> UIView) = {
            let lineContainerView = UIView()
            lineContainerView.backgroundColor = UIColor.clear
            let lineView = UIView()
            lineView.backgroundColor = lineColor
            lineView.autoSetDimension(.height, toSize: 1.0)
            lineContainerView.addSubview(lineView)
            lineView.autoPinEdge(toSuperviewEdge: .leading)
            lineView.autoPinEdge(toSuperviewEdge: .trailing)
            lineView.autoAlignAxis(toSuperviewAxis: .horizontal)
            lineView.autoPinEdge(toSuperviewEdge: .top, withInset: 0.0, relation: .greaterThanOrEqual)
            lineView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0.0, relation: .greaterThanOrEqual)
            lineView.setContentCompressionResistancePriority(UILayoutPriority(200), for: .horizontal)
            lineView.setContentHuggingPriority(UILayoutPriority(200), for: .horizontal)
            return lineContainerView
        }
        
        stackView.addArrangedSubview(lineViewBuilder())
        
        let labelContainerView = UIView()
        labelContainerView.backgroundColor = UIColor.clear
        stackView.addArrangedSubview(labelContainerView)
        labelContainerView.autoAlignAxis(toSuperviewAxis: .vertical)
        
        let label = self.getLabel(text: text,
                                  font: font,
                                  textColor: textColor,
                                  textAlignment: textAlignment,
                                  numberOfLines: numberOfLines,
                                  underlined: underlined)
        label.setContentCompressionResistancePriority(UILayoutPriority(300), for: .horizontal)
        label.setContentHuggingPriority(UILayoutPriority(300), for: .horizontal)
        labelContainerView.addSubview(label)
        label.autoPinEdgesToSuperviewEdges()
        
        stackView.addArrangedSubview(lineViewBuilder())
        
        self.addArrangedSubview(stackView, horizontalInset: horizontalInset)
    }
    
    func addLineSeparator(lineColor: UIColor,
                          inset: CGFloat = 0,
                          isVertical: Bool) {
        
        self.addBlankSpace(space: 16)
        
        let lineViewBuilder: (() -> UIView) = {
            let lineContainerView = UIView()
            lineContainerView.backgroundColor = UIColor.clear
            let lineView = UIView()
            lineView.backgroundColor = lineColor
            lineView.autoSetDimension((isVertical) ? .width : .height, toSize: 1.0)
            lineContainerView.addSubview(lineView)
            lineView.autoPinEdge(toSuperviewEdge: (isVertical) ? .leading : .top)
            lineView.autoPinEdge(toSuperviewEdge: (isVertical) ? .trailing : .bottom)
            lineView.autoAlignAxis(toSuperviewAxis: .horizontal)
            lineView.autoPinEdge(toSuperviewEdge: (isVertical) ? .top : .leading, withInset: inset, relation: .equal)
            lineView.autoPinEdge(toSuperviewEdge: (isVertical) ? .bottom : .trailing, withInset: inset, relation: .equal)
            
            return lineContainerView
        }
        
        self.addArrangedSubview(lineViewBuilder())
        
        self.addBlankSpace(space: 16)
    }
    
    private func getLabel(text: String,
                          font: UIFont,
                          textColor: UIColor,
                          textAlignment: NSTextAlignment = .center,
                          numberOfLines: Int = 0,
                          lineSpacing: CGFloat = 0.0,
                          underlined: Bool = false) -> UILabel {
        let label = UILabel()
        if underlined || lineSpacing != 0.0 {
            let attributedText = NSMutableAttributedString(string: text)
            
            attributedText.addAttribute(.font,
                                        value: font,
                                        range: NSRange(location: 0, length: attributedText.length))
            
            attributedText.addAttribute(.foregroundColor,
                                        value: textColor,
                                        range: NSRange(location: 0, length: attributedText.length))
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = textAlignment
            paragraphStyle.lineSpacing = lineSpacing
            attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedText.length))
            
            if underlined {
                attributedText.addAttribute(.underlineStyle,
                                            value: NSUnderlineStyle.single.rawValue,
                                            range: NSRange(location: 0, length: attributedText.length))
            }
            
            label.attributedText = attributedText
            label.numberOfLines = numberOfLines
        } else {
            label.text = text
            label.font = font
            label.textColor = textColor
            label.textAlignment = textAlignment
            label.numberOfLines = numberOfLines
        }
        return label
    }
    
    private func getLabel(attributedString: NSAttributedString, numberOfLines: Int = 0) -> UILabel {
        let label = UILabel()
        label.attributedText = attributedString
        label.numberOfLines = numberOfLines
        return label
    }
    
    static func create(withAxis axis: NSLayoutConstraint.Axis, spacing: CGFloat = 0) -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = axis
        stackView.spacing = spacing
        return stackView
    }
}

fileprivate extension UIView {
    func embedInView(withInsets insets: UIEdgeInsets) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        containerView.addSubview(self)
        self.autoPinEdgesToSuperviewEdges(with: insets)
        return containerView
    }
}
