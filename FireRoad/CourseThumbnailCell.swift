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
    
    override func awakeFromNib() {
        self.textLabel = self.viewWithTag(12) as? UILabel
        self.detailTextLabel = self.viewWithTag(34) as? UILabel
        self.layer.cornerRadius = 6.0
        self.layer.masksToBounds = true
    }
    
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                UIView.animate(withDuration: 0.2, delay: 0.0, options: .beginFromCurrentState, animations: { 
                    self.highlightView?.alpha = 1.0
                }, completion: nil)
            } else {
                UIView.animate(withDuration: 0.2, delay: 0.0, options: .beginFromCurrentState, animations: {
                    self.highlightView?.alpha = 0.0
                }, completion: nil)
            }
        }
    }
    
    func viewDetails(_ sender: AnyObject) {
        delegate?.courseThumbnailCellWantsViewDetails(self)
    }
    
    override func delete(_ sender: Any?) {
        delegate?.courseThumbnailCellWantsDelete(self)
    }
}
