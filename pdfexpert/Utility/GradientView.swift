//
//  GradientView.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 14/12/22.
//

import UIKit
import PureLayout

public class GradientView: UIView {
    
    private let gradientMask: CAGradientLayer
    
    init(colors: [UIColor], locations: [Double], startPoint: CGPoint, endPoint: CGPoint) {
        self.gradientMask = CAGradientLayer()
        super.init(frame: .zero)
        
        self.gradientMask.startPoint = startPoint
        self.gradientMask.endPoint = endPoint
        self.gradientMask.colors = colors.map { $0.cgColor }
        self.gradientMask.locations = locations.map { NSNumber(value: $0)}
        
        self.layer.addSublayer(self.gradientMask)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.gradientMask.frame = CGRect(x: 0.0, y: 0.0, width: self.frame.size.width, height: self.frame.size.height)
        CATransaction.commit()
    }
    
    // MARK: - Public Methods
    
    func updateParameters(colors: [UIColor]? = nil, locations: [Double]? = nil, startPoint: CGPoint? = nil, endPoint: CGPoint? = nil) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let colors = colors {
            self.gradientMask.colors = colors.map { $0.cgColor }
        }
        if let locations = locations {
            self.gradientMask.locations = locations.map { NSNumber(value: $0)}
        }
        if let startPoint = startPoint {
            self.gradientMask.startPoint = startPoint
        }
        if let endPoint = endPoint {
            self.gradientMask.endPoint = endPoint
        }
        CATransaction.commit()
    }
}

public extension UIView {
    func addGradientView(_ gradientView: GradientView) {
        self.insertSubview(gradientView, at: 0)
        gradientView.autoPinEdgesToSuperviewEdges()
    }
}
