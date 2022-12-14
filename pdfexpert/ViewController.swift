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
        
        super.viewDidLoad()

        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
                
        self.scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        self.scrollStackView.stackView.backgroundColor = .red
        self.scrollStackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 44, left: 0, bottom: 24, right: 0))
        self.scrollStackView.stackView.spacing = 30
        
        self.scrollStackView.stackView.addBlankSpace(space: 40)
        scrollStackView.stackView.addLabel(withText: "Bottone 1",
                                           fontStyle: .title,
                                           colorType: .primaryText)
        self.scrollStackView.stackView.addBlankSpace(space: 40)

        scrollStackView.stackView.addLabel(withText: "Bottone 2",
                                           fontStyle: .title,
                                           colorType: .primaryText)
        self.scrollStackView.stackView.addBlankSpace(space: 40)

        scrollStackView.stackView.addLabel(withText: "Bottone 3",
                                           fontStyle: .title,
                                           colorType: .primaryText)
        self.scrollStackView.stackView.addBlankSpace(space: 40)
        
    }
}

