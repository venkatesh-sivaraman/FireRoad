//
//  ScheduleImageProvider.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/27/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import UIKit

class ScheduleItemProvider: UIActivityItemProvider {

    var renderingBlock: () -> Any
    
    init(placeholderItem: Any, renderingBlock: @escaping () -> Any) {
        self.renderingBlock = renderingBlock
        super.init(placeholderItem: placeholderItem)
    }
    
    override var item: Any {
        return DispatchQueue.main.sync {
            return renderingBlock()
        }
    }
}
