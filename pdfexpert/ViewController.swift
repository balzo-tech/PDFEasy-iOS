//
//  ViewController.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 13/12/22.
//

import UIKit

class ViewController: UIViewController {
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()

    override func viewDidLoad() {
        
        let spacing:CGFloat = 20
        
        super.viewDidLoad()
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
                
        let stackView = UIStackView.create(withAxis: .vertical)
        self.view.addSubview(stackView)
        stackView.backgroundColor = .red
        stackView.distribution = .equalSpacing
        stackView.autoPinEdgesToSuperviewSafeArea(with: .zero)
        stackView.spacing = 30

        
        stackView.addBlankSpace(space: spacing)

        stackView.addLabel(withText: "Bottone 1",
                                           fontStyle: .title,
                                           colorType: .primaryText)
        stackView.addBlankSpace(space: spacing)

        stackView.addLabel(withText: "Bottone 2",
                                           fontStyle: .title,
                                           colorType: .primaryText)
        stackView.addBlankSpace(space: spacing)

        stackView.addLabel(withText: "Bottone 3",
                                           fontStyle: .title,
                                           colorType: .primaryText)
        stackView.addBlankSpace(space: spacing)
        
    }
}

