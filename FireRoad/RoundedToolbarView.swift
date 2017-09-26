//
//  RoundedToolbarView.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 9/25/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class RoundedToolbarView: UIView {
    var designCornerRadius: CGFloat {
        if frame.size.height < 48.0 {
            return 6.0
        }
        if #available(iOS 11.0, *) {
            return 12.0
        }
        return 8.0
    }
    
    @IBOutlet var blurView: UIVisualEffectView! = nil
    @IBOutlet var imageView: UIImageView! = nil

    override func layoutSubviews() {
        super.layoutSubviews()
        self.blurView.layer.cornerRadius = designCornerRadius
        self.blurView.layer.masksToBounds = true
        //self.view.layer.cornerRadius = 15.0
        //self.view.layer.masksToBounds = true
        self.imageView.image = self.generateShadowImage()
    }
    
    func generateShadowImage() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 60.0, height: 60.0), false, 0.0)
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.saveGState()
        ctx?.setShadow(offset: CGSize(width: 0.0, height: 0.5), blur: 6.0, color: UIColor.black.withAlphaComponent(0.2).cgColor)
        let bezierPath = UIBezierPath(roundedRect: CGRect(x: 15.0, y: 15.0, width: 30.0, height: 30.0).insetBy(dx: 12.0 / designCornerRadius - 1.0, dy: 12.0 / designCornerRadius - 1.0), cornerRadius: designCornerRadius)
        bezierPath.lineWidth = 2.0
        UIColor.white.setFill()
        bezierPath.fill()
        ctx?.restoreGState()
        UIColor.lightGray.withAlphaComponent(0.2).setStroke()
        bezierPath.stroke()
        bezierPath.fill(with: .clear, alpha: 1.0)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img!.resizableImage(withCapInsets: UIEdgeInsets(top: 29.0, left: 29.0, bottom: 29.0, right: 29.0), resizingMode: .stretch)
    }
}
