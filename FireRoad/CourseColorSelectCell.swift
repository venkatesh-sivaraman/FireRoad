//
//  CourseColorSelectViewCell.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/20/19.
//  Copyright © 2019 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol CourseColorSelectDelegate: class {
    func colorSelectCell(_ cell: CourseColorSelectCell, selected colorLabel: String)
}

class CourseColorSelectCell: UITableViewCell {

    private let tagPrefix = 100
    private let numRows = 7
    private let numCols = 6
    private var buttonMap: [CourseColorSelectButton: String] = [:]
    
    weak var delegate: CourseColorSelectDelegate?
    var selectedColor: String? {
        didSet {
            updateSelection()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        var currentIndex = 0
        let image = UIImage(named: "Checkmark")?.withRenderingMode(.alwaysTemplate)
        for row in 10..<(10 + numRows) {
            guard let rowView = viewWithTag(row) else {
                continue
            }
            for col in 100..<(100 + numCols) {
                guard let button = rowView.viewWithTag(col) as? CourseColorSelectButton else {
                    continue
                }
                button.backgroundBase = CourseManager.shared.color(forColorLabel: "@\(currentIndex)")
                buttonMap[button] = "@\(currentIndex)"
                button.layer.cornerRadius = 6.0
                button.layer.borderColor = UIColor.darkGray.cgColor
                button.layer.borderWidth = 0.5
                button.addTarget(self, action: #selector(CourseColorSelectCell.colorSelectButtonTapped(_:)), for: .touchUpInside)
                button.tintColor = UIColor.white
                button.selectedImage = image
                
                currentIndex += 1
            }
        }
    }
    
    func updateSelection() {
        for (button, label) in buttonMap {
            button.mySelected = label == selectedColor
        }
    }
    
    @IBAction func colorSelectButtonTapped(_ sender: CourseColorSelectButton) {
        guard let label = buttonMap[sender] else {
            return
        }
        delegate?.colorSelectCell(self, selected: label)
        selectedColor = label
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}

class CourseColorSelectButton: UIButton {
    var backgroundBase: UIColor? {
        didSet {
            updateBackground()
        }
    }
    
    override open var isHighlighted: Bool {
        didSet {
            updateBackground()
        }
    }
    
    var mySelected: Bool = false {
        didSet {
            updateBackground()
        }
    }
    
    var selectedImage: UIImage?
    
    func updateBackground() {
        guard let base = backgroundBase else {
            return
        }
        
        var h: CGFloat = 0.0
        var s: CGFloat = 0.0
        var v: CGFloat = 0.0
        base.getHue(&h, saturation: &s, brightness: &v, alpha: nil)
        
        if mySelected {
            if isHighlighted {
                backgroundColor = base
            } else {
                backgroundColor = base.withAlphaComponent(0.5)
            }
            setImage(selectedImage, for: .normal)
        } else {
            if isHighlighted {
                backgroundColor = UIColor(hue: h, saturation: s * 0.7, brightness: v * 0.6, alpha: 1.0)
            } else {
                backgroundColor = base
            }
            setImage(nil, for: .normal)
        }
    }
}
