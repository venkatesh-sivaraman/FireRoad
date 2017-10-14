//
//  RequirementsBrowserTableCell.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 10/13/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class RequirementsBrowserTableCell: UITableViewCell {

    var fulfillmentIndicator: UIView? {
        return viewWithTag(56)
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        let oldColor = fulfillmentIndicator?.backgroundColor
        super.setHighlighted(highlighted, animated: animated)
        fulfillmentIndicator?.backgroundColor = oldColor
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        let oldColor = fulfillmentIndicator?.backgroundColor
        super.setSelected(selected, animated: animated)
        fulfillmentIndicator?.backgroundColor = oldColor

    }
}
