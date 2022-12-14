//
//  ScrollStackView.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 14/12/22.
//

import Foundation
import PureLayout

public class ScrollStackView: UIView {
    
    public let scrollView = UIScrollView()
    public let stackView = UIStackView()
    
    // MARK: - Initialization
    
    convenience public init(axis: NSLayoutConstraint.Axis, spacing: CGFloat = 0.0, horizontalInset: CGFloat = 0.0) {
        self.init(axis: axis, spacing: spacing, leftInset: horizontalInset, rightInset: horizontalInset)
    }
    
    public init(axis: NSLayoutConstraint.Axis, spacing: CGFloat = 0.0, leftInset: CGFloat = 0.0, rightInset: CGFloat = 0.0) {
        super.init(frame: .zero)
        
        self.addSubview(self.scrollView)
        self.scrollView.addSubview(self.stackView)
        self.stackView.axis = axis
        self.stackView.spacing = spacing
        
        self.scrollView.autoPinEdgesToSuperviewEdges()
        self.stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0,
                                                                       left: leftInset,
                                                                       bottom: 0.0,
                                                                       right: rightInset))
        
        switch axis {
        case .horizontal: self.stackView.autoAlignAxis(toSuperviewAxis: .horizontal)
        case .vertical: self.stackView.autoAlignAxis(toSuperviewAxis: .vertical)
        @unknown default:
            assertionFailure("Unexpected axis")
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

