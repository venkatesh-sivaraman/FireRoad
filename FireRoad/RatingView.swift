//
//  RatingView.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/5/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import UIKit

class RatingView: UIView {

    override func awakeFromNib() {
        super.awakeFromNib()
        isUserInteractionEnabled = true
    }
    
    var course: Course? {
        didSet {
            if let id = course?.subjectID {
                rating = CourseManager.shared.userRatings[id]
            }
        }
    }
    
    /**
     The rating ranges from -5 to 5, even though the visual representation ranges
     from 0 to 5. Thus, the displayed rating will be rounded up to the nearest
     whole star. -4 goes to 1 star, -2 to 2 stars, etc.
     */
    var rating: Int? {
        didSet {
            updateStars()
        }
    }
    
    func setRating(fromNumberOfStars numStars: Int) {
        rating = (max(1, min(5, numStars)) - 3) * 2
    }
    
    func submitRating() {
        guard let id = course?.subjectID,
            let rating = rating else {
            return
        }
        CourseManager.shared.setUserRatings([id: rating], autoGenerated: false)
    }
    
    var starPath: UIBezierPath?
    
    var insetFraction: CGFloat = 0.3
    /// A value of 0.0 indicates a decagon, a value of 1.0 would result in 5 radiating lines.
    var starPointiness: CGFloat = 0.4
    
    private func generateStarPath() {
        let path = UIBezierPath()
        let pentagon1 = pointsOnPolygon(withSides: 5, radius: self.frame.size.height * (1.0 - insetFraction * 2.0) / 2.0, offset: 0.0)
        let pentagon2 = pointsOnPolygon(withSides: 5, radius: self.frame.size.height * (1.0 - insetFraction * 2.0) / 2.0 * (1.0 - starPointiness), offset: CGFloat.pi / 5.0)
        guard pentagon1.count == 5,
            pentagon2.count == 5 else {
                print("Pentagons with insufficient or too many sides!")
                return
        }
        path.move(to: pentagon2[4])
        for i in 0..<5 {
            path.addLine(to: pentagon1[i])
            path.addLine(to: pentagon2[i])
        }
        starPath = path
    }
    
    private func pointsOnPolygon(withSides sides: Int, radius: CGFloat, offset: CGFloat) -> [CGPoint] {
        let thetaInterval = 2.0 * CGFloat.pi / CGFloat(sides)
        var ret: [CGPoint] = []
        for i in 0..<sides {
            ret.append(CGPoint(x: radius * sin(thetaInterval * CGFloat(i) + offset),
                               y: -radius * cos(thetaInterval * CGFloat(i) + offset)))
        }
        return ret
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if stars.count == 0 {
            setupStars()
        } else {
            layoutStars()
        }
    }
    
    var stars: [CAShapeLayer] = []
    
    private func setupStars() {
        if starPath == nil {
            generateStarPath()
        }
        guard let starPath = starPath else {
            return
        }
        for star in stars {
            star.removeFromSuperlayer()
        }
        stars = []
        for _ in 0..<5 {
            let shape = CAShapeLayer()
            shape.path = starPath.cgPath
            shape.strokeColor = tintColor.cgColor
            shape.lineWidth = 2.0
            shape.fillColor = tintColor.cgColor
            stars.append(shape)
            layer.addSublayer(shape)
        }
        layoutStars()
        updateStars()
    }
    
    private func layoutStars() {
        let dimension = (1.0 - insetFraction * 2.0) * frame.size.height
        let margin = (insetFraction * frame.size.height) / 2.0
        let totalWidth = dimension * CGFloat(stars.count) + margin * CGFloat(stars.count - 1)
        var x = frame.size.width / 2.0 - totalWidth / 2.0
        for star in stars {
            star.position = CGPoint(x: x + dimension / 2.0, y: frame.size.height / 2.0)
            x += dimension + margin
        }
    }
    
    private func updateStars() {
        let ratingToDisplay = Int(floor(Float(rating ?? -6) / 2.0 + 3.0))
        for (i, star) in stars.enumerated() {
            if ratingToDisplay >= i + 1 {
                star.fillColor = tintColor.cgColor
            } else {
                star.fillColor = UIColor.clear.cgColor
            }
        }
    }
    
    var currentlyHighlightedStar: CAShapeLayer? {
        didSet {
            guard oldValue != currentlyHighlightedStar else {
                return
            }
            if let old = oldValue {
                let animation = CASpringAnimation(keyPath: "transform")
                animation.isRemovedOnCompletion = false
                animation.toValue = CATransform3DIdentity
                animation.damping = 4.0
                animation.stiffness = 30.0
                animation.mass = 0.5
                animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
                animation.fillMode = kCAFillModeForwards
                old.add(animation, forKey: "touch")
            }
            if let new = currentlyHighlightedStar {
                let animation = CASpringAnimation(keyPath: "transform")
                animation.isRemovedOnCompletion = false
                animation.fromValue = CATransform3DIdentity
                animation.toValue = CATransform3DMakeScale(1.2, 1.2, 1.0)
                animation.damping = 4.0
                animation.stiffness = 30.0
                animation.mass = 0.5
                animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
                animation.fillMode = kCAFillModeForwards
                new.add(animation, forKey: "touch")
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first else {
            return
        }
        let loc = touch.location(in: self)
        let xDistances = (0..<5).map {
            ($0, fabs(stars[$0].position.x - loc.x))
        }
        guard let minimum = xDistances.min(by: { $0.1 < $1.1 }) else {
            return
        }
        currentlyHighlightedStar = stars[minimum.0]
        setRating(fromNumberOfStars: minimum.0 + 1)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        guard let touch = touches.first else {
            return
        }
        let loc = touch.location(in: self)
        let xDistances = (0..<5).map {
            ($0, fabs(stars[$0].position.x - loc.x))
        }
        guard let minimum = xDistances.min(by: { $0.1 < $1.1 }) else {
            return
        }
        currentlyHighlightedStar = stars[minimum.0]
        setRating(fromNumberOfStars: minimum.0 + 1)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        currentlyHighlightedStar = nil
        guard let touch = touches.first else {
            return
        }
        let loc = touch.location(in: self)
        let xDistances = (0..<5).map {
            ($0, fabs(stars[$0].position.x - loc.x))
        }
        guard let minimum = xDistances.min(by: { $0.1 < $1.1 }) else {
            return
        }
        setRating(fromNumberOfStars: minimum.0 + 1)
        submitRating()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        currentlyHighlightedStar = nil
    }
}
