//
//  CourseThumbnailCell.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 5/28/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol CourseThumbnailCellDelegate: class {
    func courseThumbnailCellWantsViewDetails(_ cell: CourseThumbnailCell)
    func courseThumbnailCellWantsDelete(_ cell: CourseThumbnailCell)
    func courseThumbnailCellWantsConstrain(_ cell: CourseThumbnailCell)
}

extension CourseThumbnailCellDelegate {
    func courseThumbnailCellWantsViewDetails(_ cell: CourseThumbnailCell) {
        
    }
    func courseThumbnailCellWantsDelete(_ cell: CourseThumbnailCell) {
        
    }
    func courseThumbnailCellWantsConstrain(_ cell: CourseThumbnailCell) {
        
    }
}

class CourseThumbnailCell: UICollectionViewCell {
    
    weak var delegate: CourseThumbnailCellDelegate?
    
    var course: Course?
    var isDetached = false
    
    var showsConstraintMenuItem = false
    
    @IBOutlet var textLabel: UILabel?
    @IBOutlet var detailTextLabel: UILabel?
    
    @IBOutlet var warningIcon: UIImageView?
    var showsWarningIcon: Bool = false {
        didSet {
            warningIcon?.isHidden = !showsWarningIcon
        }
    }
    
    @IBOutlet var bigLayoutConstraints: [NSLayoutConstraint]?
    @IBOutlet var smallLayoutConstraints: [NSLayoutConstraint]?
    
    func generateHighlightView() -> UIView? {
        let view = UIView(frame: self.bounds)
        view.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        view.alpha = 0.0
        self.addSubview(view)
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[view]|", options: .alignAllCenterX, metrics: nil, views: ["view": view]))
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[view]|", options: .alignAllCenterY, metrics: nil, views: ["view": view]))
        return view
    }
    
    lazy var highlightView: UIView? = self.generateHighlightView()
    
    private var backgroundColorLayer: CALayer?
    
    override var backgroundColor: UIColor? {
        didSet {
            if let alpha = backgroundColor?.cgColor.alpha,
                alpha == 0.0 {
                return
            }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            backgroundColorLayer?.backgroundColor = backgroundColor?.cgColor
            CATransaction.commit()
            backgroundColor = UIColor.clear
        }
    }
    
    /*override var alpha: CGFloat {
        didSet {
            backgroundColorLayer?.opacity = Float(alpha)
        }
    }*/
    
    var shadowEnabled: Bool = true {
        didSet {
            if shadowEnabled {
                self.layer.shadowColor = UIColor.lightGray.cgColor
                self.layer.shadowOffset = CGSize(width: 1.0, height: 3.0)
                self.layer.shadowRadius = 6.0
                self.layer.shadowOpacity = 0.6
                self.layer.masksToBounds = false
            } else {
                self.layer.shadowOpacity = 0.0
            }
        }
    }
    
    override func awakeFromNib() {
        loadThumbnailAppearance()
    }

    func loadThumbnailAppearance() {
        self.textLabel = self.viewWithTag(12) as? UILabel
        self.detailTextLabel = self.viewWithTag(34) as? UILabel
        let colorLayer = CALayer()
        colorLayer.frame = self.layer.bounds
        colorLayer.backgroundColor = backgroundColor?.cgColor
        colorLayer.cornerRadius = 6.0
        self.layer.insertSublayer(colorLayer, at: 0)
        backgroundColorLayer = colorLayer
        //self.layer.cornerRadius = 6.0
        shadowEnabled = true
        contentView.clipsToBounds = false
    }
    
    func generateLabels(withDetail: Bool = true) {
        let titleLabel = UILabel(frame: .zero)
        titleLabel.textAlignment = .center
        titleLabel.minimumScaleFactor = 0.6
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.allowsDefaultTighteningForTruncation = true
        titleLabel.font = UIFont.systemFont(ofSize: 24.0, weight: .light)
        titleLabel.textColor = UIColor.white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(titleLabel)
        self.textLabel = titleLabel

        if withDetail {
            let detailLabel = UILabel(frame: .zero)
            detailLabel.textAlignment = .center
            detailLabel.minimumScaleFactor = 0.7
            detailLabel.adjustsFontSizeToFitWidth = true
            detailLabel.allowsDefaultTighteningForTruncation = true
            detailLabel.font = UIFont.systemFont(ofSize: 14.0, weight: .semibold)
            detailLabel.textColor = UIColor.white
            detailLabel.numberOfLines = 0
            detailLabel.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(detailLabel)
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4.0).isActive = true
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4.0).isActive = true
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4.0).isActive = true
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 0.0).isActive = true
            detailLabel.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
            detailLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4.0).isActive = true
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4.0).isActive = true
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4.0).isActive = true
            self.detailTextLabel = detailLabel
        } else {
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6.0).isActive = true
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 2.0).isActive = true
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -2.0).isActive = true
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4.0).isActive = true
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundColorLayer?.frame = self.layer.bounds
        repositionFulfillmentIndicators()
    }
    
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                UIView.animate(withDuration: 0.2, delay: 0.0, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut], animations: {
                    self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                    //self.highlightView?.alpha = 1.0
                }, completion: nil)
            } else {
                UIView.animate(withDuration: 0.2, delay: 0.0, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut], animations: {
                    self.transform = CGAffineTransform.identity
                    //self.highlightView?.alpha = 0.0
                }, completion: nil)
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        isHighlighted = true
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        isHighlighted = false
        if delegate != nil, isDetached {
            self.becomeFirstResponder()
            let menu = UIMenuController.shared
            if menu.isMenuVisible {
                menu.setMenuVisible(false, animated: true)
            } else {
                UIMenuController.shared.setTargetRect(self.bounds, in: self)
                UIMenuController.shared.setMenuVisible(true, animated: true)
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        isHighlighted = false
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(viewDetails(_:)) {
            return delegate != nil
        } else if action == #selector(delete(_:)) {
            return delegate != nil
        } else if action == #selector(constrain(_:)) {
            return delegate != nil && showsConstraintMenuItem
        }
        return false
    }
    
    @objc func viewDetails(_ sender: AnyObject) {
        delegate?.courseThumbnailCellWantsViewDetails(self)
    }
    
    override func delete(_ sender: Any?) {
        delegate?.courseThumbnailCellWantsDelete(self)
    }
    
    @objc func constrain(_ sender: AnyObject) {
        delegate?.courseThumbnailCellWantsConstrain(self)
    }
    
    // MARK: - Requirement Fulfillment
    
    private var fulfillmentIndicators: [CALayer] = []
    
    var fulfilledColor: UIColor?
    var unfulfilledColor: UIColor?
    
    var fulfillmentThreshold = 0 {
        didSet {
            updateFulfillmentIndicators()
        }
    }
    var fulfillmentLevel = 0 {
        didSet {
            updateFulfillmentIndicators()
        }
    }
    
    func updateFulfillmentIndicators() {
        for indicator in fulfillmentIndicators {
            indicator.removeFromSuperlayer()
        }
        fulfillmentIndicators = []
        if fulfillmentLevel < fulfillmentThreshold || fulfillmentThreshold == 0 {
            backgroundColorLayer?.opacity = 1.0
        } else {
            backgroundColorLayer?.opacity = 0.4
        }
        if fulfillmentThreshold > 1 {
            let rect = CGRect(x: 0.0, y: 0.0, width: 6.0, height: 6.0)
            let bezierPath = UIBezierPath(ovalIn: rect)
            for i in 0..<max(fulfillmentThreshold, fulfillmentLevel) {
                let indicator = CAShapeLayer()
                indicator.path = bezierPath.cgPath
                indicator.frame = rect
                var fillColor: CGColor?
                if i < fulfillmentLevel {
                    fillColor = fulfilledColor?.cgColor
                    if fillColor == nil, let bgColor = backgroundColorLayer?.backgroundColor {
                        let fillUIColor = UIColor(cgColor: bgColor)
                        var hue: CGFloat = 0.0, saturation: CGFloat = 0.0, brightness: CGFloat = 0.0
                        fillUIColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
                        fillColor = UIColor(hue: hue, saturation: saturation, brightness: brightness / 3.0, alpha: 0.7).cgColor
                    }
                } else {
                    fillColor = unfulfilledColor?.cgColor
                    if fillColor == nil, let bgColor = backgroundColorLayer?.backgroundColor {
                        let fillUIColor = UIColor(cgColor: bgColor)
                        var hue: CGFloat = 0.0, saturation: CGFloat = 0.0, brightness: CGFloat = 0.0
                        fillUIColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
                        fillColor = UIColor(hue: hue, saturation: saturation, brightness: (2.0 + brightness) / 3.0, alpha: 0.6).cgColor
                    }
                }
                indicator.fillColor = fillColor
                layer.addSublayer(indicator)
                fulfillmentIndicators.append(indicator)
            }
        }
        repositionFulfillmentIndicators()
    }
    
    func repositionFulfillmentIndicators() {
        var topThreshold = CGFloat(0.0)
        if let detail = detailTextLabel,
            detail.text?.count != 0 {
            topThreshold = detail.frame.maxY
        } else {
            topThreshold = frame.size.height / 2.0
        }
        let centerY = max((topThreshold + frame.size.height) / 2.0, frame.size.height - 8.0)
        let totalWidth = fulfillmentIndicators.reduce(CGFloat(0.0), { $0 + $1.frame.size.width })
        let margin = min((frame.size.width - totalWidth) / CGFloat(fulfillmentIndicators.count + 1), 4.0)
        var x = frame.size.width / 2.0 - (totalWidth + margin * CGFloat(fulfillmentIndicators.count - 1)) / 2.0
        for indicator in fulfillmentIndicators {
            indicator.frame = CGRect(x: x, y: centerY - indicator.frame.size.height / 2.0, width: indicator.frame.size.width, height: indicator.frame.size.height)
            x += indicator.frame.size.width + margin
        }
    }
}
