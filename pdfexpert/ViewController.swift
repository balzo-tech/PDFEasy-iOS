//
//  ViewController.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 13/12/22.
//

import UIKit
import XLActionController

class ViewController: UIViewController {
    
    private let convertPictureView: GradientView = {
        return GradientView(colors: [UIColor.white, UIColor.white],
                            locations: [0.0, 1.0],
                            startPoint: CGPoint(x: 0.5, y: 0.0),
                            endPoint: CGPoint(x: 0.5, y: 1.0),
                            cornerRadius: 10.0)
    }()
    
    private let convertWordView: GradientView = {
        return GradientView(colors: [UIColor.white, UIColor.white],
                            locations: [0.0, 1.0],
                            startPoint: CGPoint(x: 0.5, y: 0.0),
                            endPoint: CGPoint(x: 0.5, y: 1.0),
                            cornerRadius: 10.0)
    }()
    
    private let scannerView: GradientView = {
        return GradientView(colors: [UIColor.white, UIColor.white],
                            locations: [0.0, 1.0],
                            startPoint: CGPoint(x: 0.5, y: 0.0),
                            endPoint: CGPoint(x: 0.5, y: 1.0),
                            cornerRadius: 10.0)
    }()
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()

    override func viewDidLoad() {
        
        super.viewDidLoad()
        self.view.backgroundColor = ColorPalette.color(withType: .primary)
        self.composeView()
        
        //MARK: Convert Photo
        
        let titlePhoto = UILabel()
        titlePhoto.attributedText = NSAttributedString.create(withText: "Converti \nfoto in PDF",
                                                         fontStyle: .title,
                                                         colorType: .primaryText,
                                                         textAlignment: .left)
        titlePhoto.numberOfLines = 0
        self.convertPictureView.addSubview(titlePhoto)
        titlePhoto.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16.0,
                                                              left: 16.0,
                                                              bottom: 0.0,
                                                              right: 16.0),
                                           excludingEdge: .bottom)
        
        let photoButton = UIButton()
        photoButton.backgroundColor = ColorPalette.color(withType: .primaryText)
        photoButton.setTitle("Convert Now", for: .normal)
        photoButton.setTitleColor(ColorPalette.color(withType: .secondaryText), for: .normal)
        photoButton.layer.cornerRadius = 8
        photoButton.titleLabel?.font = FontPalette.fontStyleData(forStyle: .titleButton).font
        photoButton.autoSetDimension(.height, toSize: 48.0)
        photoButton.addTarget(self, action: #selector(self.convertPhotoPressed), for: .touchUpInside)
        self.convertPictureView.addSubview(photoButton)
        photoButton.autoAlignAxis(.vertical, toSameAxisOf: self.convertPictureView)
        photoButton.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                    left: 16.0,
                                                                    bottom: 16.0,
                                                                    right: 16.0),
                                                 excludingEdge: .top)
        
        //MARK: Word Conversion
        
        let titleWord = UILabel()
        titleWord.attributedText = NSAttributedString.create(withText: "Converti \nWord in PDF",
                                                         fontStyle: .title,
                                                         colorType: .primaryText,
                                                         textAlignment: .left)
        titleWord.numberOfLines = 0
        self.convertWordView.addSubview(titleWord)
        titleWord.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16.0,
                                                              left: 16.0,
                                                              bottom: 0.0,
                                                              right: 16.0),
                                           excludingEdge: .bottom)
        
        let wordButton = UIButton()
        wordButton.backgroundColor = ColorPalette.color(withType: .primaryText)
        wordButton.setTitle("Convert Now", for: .normal)
        wordButton.setTitleColor(ColorPalette.color(withType: .secondaryText), for: .normal)
        wordButton.layer.cornerRadius = 8
        wordButton.titleLabel?.font = FontPalette.fontStyleData(forStyle: .titleButton).font
        wordButton.autoSetDimension(.height, toSize: 48.0)
        wordButton.addTarget(self, action: #selector(self.convertWordPressed), for: .touchUpInside)
        self.convertWordView.addSubview(wordButton)
        wordButton.autoAlignAxis(.vertical, toSameAxisOf: self.convertWordView)
        wordButton.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                    left: 16.0,
                                                                    bottom: 16.0,
                                                                    right: 16.0),
                                                 excludingEdge: .top)
        
        //MARK: Scanner Conversion
        
        let titleScanner = UILabel()
        titleScanner.attributedText = NSAttributedString.create(withText: "Scanner \nPDF",
                                                         fontStyle: .title,
                                                         colorType: .primaryText,
                                                         textAlignment: .left)
        titleScanner.numberOfLines = 0
        self.scannerView.addSubview(titleScanner)
        titleScanner.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16.0,
                                                              left: 16.0,
                                                              bottom: 0.0,
                                                              right: 16.0),
                                           excludingEdge: .bottom)
        
        let scannerButton = UIButton()
        scannerButton.backgroundColor = ColorPalette.color(withType: .primaryText)
        scannerButton.setTitle("Convert Now", for: .normal)
        scannerButton.setTitleColor(ColorPalette.color(withType: .secondaryText), for: .normal)
        scannerButton.layer.cornerRadius = 8
        scannerButton.titleLabel?.font = FontPalette.fontStyleData(forStyle: .titleButton).font
        scannerButton.autoSetDimension(.height, toSize: 48.0)
        scannerButton.addTarget(self, action: #selector(self.scannerPressed), for: .touchUpInside)
        self.scannerView.addSubview(scannerButton)
        scannerButton.autoAlignAxis(.vertical, toSameAxisOf: self.scannerView)
        scannerButton.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                    left: 16.0,
                                                                    bottom: 16.0,
                                                                    right: 16.0),
                                                 excludingEdge: .top)
    }
    
    //MARK: Actions
    @objc private func convertPhotoPressed() {
        // Instantiate custom action sheet controller
        let actionSheet = TwitterActionController()
        // set up a header title
        actionSheet.headerData = "Select the source"
        // Add some actions, note that the first parameter of `Action` initializer is `ActionData`.
        actionSheet.addAction(Action(ActionData(title: "File", subtitle: "@xmartlabs", image: UIImage(named: "file")!), style: .default, handler: { action in
           // do something useful
        }))
        actionSheet.addAction(Action(ActionData(title: "Camera", subtitle: "@remer88", image: UIImage(named: "camera")!), style: .default, handler: { action in
           // do something useful
        }))
        actionSheet.addAction(Action(ActionData(title: "Gallery", subtitle: "@xmartlabs", image: UIImage(named: "camera")!), style: .default, handler: { action in
           // do something useful
        }))
        // present actionSheet like any other view controller
        present(actionSheet, animated: true, completion: nil)
    }
    
    @objc private func convertWordPressed() {
        print("Word Pressed")
    }
    
    @objc private func scannerPressed() {
        print("Scanner Pressed")
    }
    
    //MARK: Private Functions
    
    private func composeView() {
        
        let spacing:CGFloat = 0
        let headerHeight:CGFloat = 167
        let footerHeight:CGFloat = 90
        
        let headerView = UIView()
        headerView.autoSetDimensions(to: CGSize(width: self.view.frame.width, height: headerHeight))
        headerView.backgroundColor = ColorPalette.color(withType: .primary)
        self.view.addSubview(headerView)
        headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        
        let footerView = UIView()
        self.view.addSubview(footerView)
        footerView.backgroundColor = ColorPalette.color(withType: .primary)
        footerView.autoSetDimensions(to: CGSize(width: self.view.frame.width, height: footerHeight))
        footerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
                
        let stackView = UIStackView.create(withAxis: .vertical)
        self.view.addSubview(stackView)
        stackView.backgroundColor = ColorPalette.color(withType: .primary)
        stackView.distribution = .fillEqually
        stackView.autoPinEdge(.bottom,to: .top, of: footerView, withOffset: .zero)
        stackView.autoPinEdge(.top, to: .bottom, of: headerView, withOffset: .zero)
        stackView.autoPinEdge(toSuperviewEdge: .leading, withInset: Constants.Style.DefaultHorizontalMargins)
        stackView.autoPinEdge(toSuperviewEdge: .trailing, withInset: Constants.Style.DefaultHorizontalMargins)

        stackView.spacing = spacing
        
        stackView.addArrangedSubview(self.convertPictureView,
                                     horizontalInset: Constants.Style.DefaultHorizontalMargins,
                                     verticalInset: Constants.Style.DefaultVerticalMargins)

        self.updateGradientView(gradientView: self.convertPictureView,
                                startColor: ColorPalette.color(withType: .gradientPrimaryStart),
                                endColor: ColorPalette.color(withType: .gradientPrimaryEnd),
                                singleColor: ColorPalette.color(withType: .secondaryText))


        stackView.addArrangedSubview(self.convertWordView,
                                     horizontalInset: Constants.Style.DefaultHorizontalMargins,
                                     verticalInset: Constants.Style.DefaultVerticalMargins)
        self.updateGradientView(gradientView: self.convertWordView,
                                startColor: ColorPalette.color(withType: .gradientPrimaryStart),
                                endColor: ColorPalette.color(withType: .gradientPrimaryEnd),
                                singleColor: ColorPalette.color(withType: .secondaryText))

        stackView.addArrangedSubview(self.scannerView,
                                     horizontalInset: Constants.Style.DefaultHorizontalMargins,
                                     verticalInset: Constants.Style.DefaultVerticalMargins)
        self.updateGradientView(gradientView: self.scannerView,
                                startColor: ColorPalette.color(withType: .gradientPrimaryStart),
                                endColor: ColorPalette.color(withType: .gradientPrimaryEnd),
                                singleColor: ColorPalette.color(withType: .secondaryText))
    }
    
    private func updateGradientView(gradientView: GradientView, startColor: UIColor?, endColor: UIColor?, singleColor: UIColor?) {
        if let startColor = startColor, let endColor = endColor {
            gradientView.updateParameters(colors: [startColor, endColor])
        } else {
            gradientView.updateParameters(colors: [singleColor ?? ColorPalette.color(withType: .primary),
                                                        singleColor ?? ColorPalette.color(withType: .gradientPrimaryEnd)])
        }
    }
}

