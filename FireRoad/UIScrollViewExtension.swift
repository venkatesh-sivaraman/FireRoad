//
//  UIScrollViewExtension.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 2/14/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import UIKit

extension UIScrollView {
    
    func renderToImage() -> UIImage {
        let savedFrame = frame
        let savedOffset = contentOffset
        let savedScale = zoomScale
        zoomScale = 1.0
        frame = CGRect(x: 0.0, y: 0.0, width: contentSize.width, height: contentSize.height)
        contentOffset = .zero
        
        UIGraphicsBeginImageContextWithOptions(contentSize, false, 0.0)
        defer {
            UIGraphicsEndImageContext()
            zoomScale = savedScale
            frame = savedFrame
            contentOffset = savedOffset
        }
        guard let ctx = UIGraphicsGetCurrentContext() else {
            return UIImage()
        }
        layer.render(in: ctx)
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    func renderToPDF(_ completion: @escaping (Data?) -> Void) {
        let savedFrame = frame
        let savedOffset = contentOffset
        let savedScale = zoomScale
        zoomScale = 1.0
        frame = CGRect(x: 0.0, y: 0.0, width: contentSize.width, height: contentSize.height)
        contentOffset = .zero
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.zoomScale = 1.0
            self.frame = CGRect(x: 0.0, y: 0.0, width: self.contentSize.width, height: self.contentSize.height)
            self.contentOffset = .zero
            
            let data = NSMutableData()
            UIGraphicsBeginPDFContextToData(data, self.frame, nil)
            UIGraphicsBeginPDFPage()
            guard let ctx = UIGraphicsGetCurrentContext() else {
                completion(nil)
                return
            }
            self.layer.render(in: ctx)
            UIGraphicsEndPDFContext()
            completion(data as Data)
            self.zoomScale = savedScale
            self.frame = savedFrame
            self.contentOffset = savedOffset
        }
    }
}
