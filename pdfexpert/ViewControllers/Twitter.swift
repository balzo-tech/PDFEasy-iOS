//
//  Twitter.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 19/12/22.
//

import UIKit
import XLActionController


open class TwitterCell: ActionCell {
    
    @IBOutlet weak var cellView: UIView!
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        initialize()
    }

    func initialize() {
        backgroundColor = ColorPalette.color(withType: .secondary)
        cellView.backgroundColor = ColorPalette.color(withType: .secondary)
        cellView.layer.cornerRadius = 10.0
        cellView.layer.borderWidth = 1.0
        cellView.layer.borderColor = ColorPalette.color(withType: .tertiaryText).cgColor
        actionImageView?.clipsToBounds = true
        actionImageView?.layer.cornerRadius = 5.0
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(white: 0.0, alpha: 0.15)
        selectedBackgroundView = backgroundView
    }
}

open class TwitterActionControllerHeader: UICollectionReusableView {
    
    lazy var label: UILabel = {
        let label = UILabel()
        
        label.textAlignment = .left
        label.backgroundColor = ColorPalette.color(withType: .secondary)
        label.font = FontPalette.fontStyleData(forStyle: .title).font
        label.textColor = ColorPalette.color(withType: .primaryText)
        return label
    }()
    
    lazy var bottomLine: UIView = {
        let bottomLine = UIView()
        
        bottomLine.backgroundColor = ColorPalette.color(withType: .primary)
        return bottomLine
    }()
    
    lazy var upperLine: UIView = {
        let upperLine = UIView()
        
        upperLine.backgroundColor = ColorPalette.color(withType: .primary)
        return upperLine
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let stackView = UIStackView.create(withAxis: .vertical)
        self.addSubview(stackView)
        stackView.backgroundColor = ColorPalette.color(withType: .primary)
        stackView.distribution = .fillProportionally
        stackView.autoPinEdgesToSuperviewEdges(with: .zero)
        stackView.backgroundColor = ColorPalette.color(withType: .secondary)
        
        
        stackView.addBlankSpace(space: 44)
        stackView.addArrangedSubview(label, horizontalInset: 32)
        stackView.addBlankSpace(space: 81)

    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}


open class TwitterActionController: ActionController<TwitterCell, ActionData, TwitterActionControllerHeader, String, UICollectionReusableView, Void> {

    static let bottomPadding: CGFloat = 1060.0

    lazy var hideBottomSpaceView: UIView = {
        let width = collectionView.bounds.width - safeAreaInsets.left - safeAreaInsets.right
        let height = contentHeight + TwitterActionController.bottomPadding + safeAreaInsets.bottom
        let hideBottomSpaceView = UIView(frame: CGRect.init(x: 0, y: 0, width: width, height: height))
        hideBottomSpaceView.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin, .flexibleHeight]
        hideBottomSpaceView.backgroundColor = ColorPalette.color(withType: .secondary)
        return hideBottomSpaceView
    }()

    public override init(nibName nibNameOrNil: String? = nil, bundle nibBundleOrNil: Bundle? = nil) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        settings.animation.present.duration = 0.6
        settings.animation.dismiss.duration = 0.6
        cellSpec = CellSpec.nibFile(nibName: "TwitterCell", bundle: Bundle(for: TwitterCell.self), height: { _ in 90 })
        headerSpec = .cellClass(height: { _ -> CGFloat in return 160 })

        onConfigureHeader = { header, title in
            header.label.text = title
        }
        onConfigureCellForAction = { cell, action, indexPath in
            cell.setup(action.data?.title, detail: action.data?.subtitle, image: action.data?.image)
            cell.alpha = action.enabled ? 1.0 : 0.5
        }
    }
  
    required public init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.clipsToBounds = false
        collectionView.addSubview(hideBottomSpaceView)
        collectionView.sendSubviewToBack(hideBottomSpaceView)
    }

    @available(iOS 11, *)
    override open func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        hideBottomSpaceView.frame.size.height = contentHeight + TwitterActionController.bottomPadding + safeAreaInsets.bottom
        hideBottomSpaceView.frame.size.width = collectionView.bounds.width - safeAreaInsets.left - safeAreaInsets.right
    }

    override open func dismissView(_ presentedView: UIView, presentingView: UIView, animationDuration: Double, completion: ((_ completed: Bool) -> Void)?) {
        onWillDismissView()
        let animationSettings = settings.animation.dismiss
        let upTime = 0.1
        UIView.animate(withDuration: upTime, delay: 0, options: .curveEaseIn, animations: { [weak self] in
            self?.collectionView.frame.origin.y -= 10
        }, completion: { [weak self] (completed) -> Void in
            UIView.animate(withDuration: animationDuration - upTime,
                delay: 0,
                usingSpringWithDamping: animationSettings.damping,
                initialSpringVelocity: animationSettings.springVelocity,
                options: UIView.AnimationOptions.curveEaseIn,
                animations: { [weak self] in
                    presentingView.transform = CGAffineTransform.identity
                    self?.performCustomDismissingAnimation(presentedView, presentingView: presentingView)
                },
                completion: { [weak self] finished in
                    self?.onDidDismissView()
                    completion?(finished)
                })
        })
    }
}

