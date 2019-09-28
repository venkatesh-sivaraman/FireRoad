//
//  DepartmentCell.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 12/16/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class HighlightCollectionCell: UICollectionViewCell {
    
    @IBOutlet var selectionView: UIView?
    
    private var highlightPulseOffDate: Date?
    
    override var isHighlighted: Bool {
        didSet {
            let duration = 0.2
            self.selectionView?.alpha = 0.0
            self.selectionView?.isHidden = false
            if isHighlighted {
                highlightPulseOffDate = Date().addingTimeInterval(duration)
                UIView.animate(withDuration: duration, delay: 0.0, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut], animations: {
                    self.selectionView?.alpha = 1.0
                }, completion: nil)
            } else {
                let delay = max(highlightPulseOffDate?.timeIntervalSinceNow ?? 0.0, 0.0)
                highlightPulseOffDate = nil
                UIView.animate(withDuration: duration, delay: delay, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut], animations: {
                    self.selectionView?.alpha = 0.0
                }, completion: { completed in
                    if completed {
                        self.selectionView?.isHidden = true
                    }
                })
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
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        isHighlighted = false
    }
}
