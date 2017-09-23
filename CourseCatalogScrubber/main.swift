//
//  main.swift
//  CourseCatalogScrubber
//
//  Created by Venkatesh Sivaraman on 9/22/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import Foundation

func htmlRegions(from url: URL) -> [HTMLNodeExtractor.HTMLRegion] {
    do {
        let text = try String(contentsOf: url)
        let topLevelNodes = HTMLNodeExtractor.extractNodes(from: text)
        let regex = try NSRegularExpression(pattern: "name(?:\\s?)=\"(.+)\"", options: .caseInsensitive)
        let regions = HTMLNodeExtractor.htmlRegions(in: topLevelNodes, demarcatedByTag: "a") { (node: HTMLNode) -> String? in
            if let match = regex.firstMatch(in: node.attributeText, options: [], range: NSRange(location: 0, length: node.attributeText.characters.count)) {
                return (node.attributeText as NSString).substring(with: match.rangeAt(1))
            }
            return nil
        }
        return regions
    } catch {
        print("Error: \(error)")
        return []
    }
}


if let url = URL(string: "http://student.mit.edu/catalog/m1a.html") {
    let regions = htmlRegions(from: url)
    for region in regions {
        print(region.title)
        for node in region.nodes {
            if node.childNodes.count > 0 {
                print(node.contents.components(separatedBy: .newlines).map({ "\"\($0)\"" }).joined(separator: "\n") as NSString)
            } else {
                print(node)
            }
        }
    }
}
