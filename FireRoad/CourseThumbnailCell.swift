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
}

extension CourseThumbnailCellDelegate {
    func courseThumbnailCellWantsViewDetails(_ cell: CourseThumbnailCell) {
        
    }
    func courseThumbnailCellWantsDelete(_ cell: CourseThumbnailCell) {
        
    }
}

class CourseThumbnailCell: UICollectionViewCell {
    
    weak var delegate: CourseThumbnailCellDelegate?
    
    @IBOutlet var textLabel: UILabel?
    @IBOutlet var detailTextLabel: UILabel?
    
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
            backgroundColorLayer?.backgroundColor = backgroundColor?.cgColor
            backgroundColor = UIColor.clear
        }
    }
    
    override func awakeFromNib() {
        self.textLabel = self.viewWithTag(12) as? UILabel
        self.detailTextLabel = self.viewWithTag(34) as? UILabel
        let colorLayer = CALayer()
        colorLayer.frame = self.layer.bounds
        colorLayer.backgroundColor = backgroundColor?.cgColor
        colorLayer.cornerRadius = 6.0
        self.layer.insertSublayer(colorLayer, at: 0)
        backgroundColorLayer = colorLayer
        //self.layer.cornerRadius = 6.0
        self.layer.shadowColor = UIColor.lightGray.cgColor
        self.layer.shadowOffset = CGSize(width: 1.0, height: 3.0)
        self.layer.shadowRadius = 8.0
        self.layer.shadowOpacity = 0.5
        self.layer.masksToBounds = false
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundColorLayer?.frame = self.layer.bounds
    }
    
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                UIView.animate(withDuration: 0.2, delay: 0.0, options: [.beginFromCurrentState, .curveEaseInOut], animations: {
                    self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                    //self.highlightView?.alpha = 1.0
                }, completion: nil)
            } else {
                UIView.animate(withDuration: 0.2, delay: 0.0, options: [.beginFromCurrentState, .curveEaseInOut], animations: {
                    self.transform = CGAffineTransform.identity
                    //self.highlightView?.alpha = 0.0
                }, completion: nil)
            }
        }
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(viewDetails(_:)) {
            return delegate != nil
        } else if action == #selector(delete(_:)) {
            return delegate != nil
        }
        return false
    }
    
    func viewDetails(_ sender: AnyObject) {
        delegate?.courseThumbnailCellWantsViewDetails(self)
    }
    
    override func delete(_ sender: Any?) {
        delegate?.courseThumbnailCellWantsDelete(self)
    }
}
