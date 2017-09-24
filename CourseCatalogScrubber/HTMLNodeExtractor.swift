//
//  HTMLNodeExtractor.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 9/22/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import Cocoa

class HTMLNode: CustomDebugStringConvertible {
    var tagText: String
    var attributeText: String
    var contents: String
    /// The contents property but without HTML tags.
    var strippedContents: String
    /// The range of the text within the HTML tags.
    var contentsRange: NSRange = NSRange(location: 0, length: 0)
    /// The range of the text including the HTML tags.
    var enclosingRange: NSRange = NSRange(location: 0, length: 0)
    var childNodes: [HTMLNode]
    
    var debugDescription: String {
        if childNodes.count == 0 {
            if contents.characters.count == 0 {
                return "<\(tagText)\(attributeText)/>"
            } else {
                return "<\(tagText)\(attributeText)>: \"\(strippedContents)\""
            }
        }
        return "<\(tagText)\(attributeText)>: \"\(strippedContents)\", \(childNodes.map({ String(reflecting: $0) }).joined(separator: "\n"))"
    }
    
    init(tagText: String) {
        self.tagText = tagText
        self.attributeText = ""
        self.contents = ""
        self.strippedContents = ""
        self.childNodes = []
    }
}

extension String {
    
    init?(htmlEncodedString: String) {
        
        guard let data = htmlEncodedString.data(using: .utf8) else {
            return nil
        }
        
        let options: [String: Any] = [
            NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
            NSCharacterEncodingDocumentAttribute: String.Encoding.utf8.rawValue
        ]
        
        guard let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        
        self.init(attributedString.string)
    }
    
}

class HTMLNodeExtractor: NSObject {

    /**
     Defines HTML tags, without the closing '>' character so that they can be 
     matched despite the presence of attribute text using regular expressions.
     */
    enum HTMLTags {
        static let htmlTagOpening = "<html"
        static let bodyTagOpening = "<body"
        static let bodyTagClosing = "</body"
        
        static let selfClosingTags = [
            "br", "img", "hr"
        ]
    }
    
    private class func regexForOpeningTag(_ tag: String) -> NSRegularExpression {
        let escapedTag = NSRegularExpression.escapedPattern(for: tag)
        guard let regex = try? NSRegularExpression(pattern: "\(escapedTag).*?>", options: .dotMatchesLineSeparators) else {
            fatalError("Regex error for tag \(tag)")
        }
        return regex
    }
    
    class func stripHTMLTags(from text: String, replacementString: String = "") -> String {
        guard let tagRegex = try? NSRegularExpression(pattern: "<(/?)(\\w+)(.*?)(/?)>", options: .dotMatchesLineSeparators) else {
            print("Failed to generate tag regex")
            return text
        }
        return tagRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: replacementString)
    }
    
    /**
     Parses the given HTML text and returns the top-level HTML nodes contained 
     within it. The top-level HTML nodes contain in their `childNodes` property 
     a list of the nodes contained within them, as well as their contents in 
     raw text format. This continues down the tree, resulting in a complete node 
     representation of the HTML document.
     
     - Parameter text: The HTML text to parse.
     
     - Returns: A list of HTML nodes representing the document.
     */
    class func extractNodes(from text: String, ignoreErrors: Bool = false) -> [HTMLNode]? {
        if text.contains(HTMLTags.htmlTagOpening) {
            guard let startRange = regexForOpeningTag(HTMLTags.bodyTagOpening).firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.characters.count))?.range,
                let endRange = regexForOpeningTag(HTMLTags.bodyTagClosing).firstMatch(in: text, options: [], range: NSRange(location: startRange.location + startRange.length, length: text.characters.count - (startRange.location + startRange.length)))?.range else {
                    assert(false, "The given HTML text has an HTML tag but no body tag.")
                    return nil
            }
            let startIndex = startRange.location + startRange.length
            return extractNodes(from: (text as NSString).substring(with: NSRange(location: startIndex, length: endRange.location - startIndex)), ignoreErrors: ignoreErrors)
        }
        
        var nodes: [HTMLNode] = []
        var nodeStack: [HTMLNode] = []
        var textString = text as NSString
        
        // Remove contents
        guard let commentRegex = try? NSRegularExpression(pattern: "<!--(.*?)-->", options: .dotMatchesLineSeparators) else {
            print("Failed to generate comment regex")
            return nil
        }
        textString = commentRegex.stringByReplacingMatches(in: textString as String, options: [], range: NSRange(location: 0, length: textString.length), withTemplate: "") as NSString
        
        // Matches tags of the form <xyz ...>, </xyz ...>, <xyz ... />, etc.
        guard let tagRegex = try? NSRegularExpression(pattern: "<(/?)(\\w+)(.*?)(/?)>", options: .dotMatchesLineSeparators) else {
            print("Failed to generate tag regex")
            return nil
        }
        let matches = tagRegex.matches(in: textString as String, options: [], range: NSRange(location: 0, length: textString.length))
        for match in matches {
            let closingFragment = textString.substring(with: match.rangeAt(1))
            let attributeText = textString.substring(with: match.rangeAt(3))
            let selfClosingFragment = textString.substring(with: match.rangeAt(4))
            let tagText = textString.substring(with: match.rangeAt(2)).lowercased()
            if closingFragment == "/" {
                guard let currentNode = nodeStack.last else {
                    //print("No current node for closing tag \(tagText)")
                    if ignoreErrors {
                        continue
                    }
                    return nil
                }
                currentNode.contentsRange = NSRange(location: currentNode.contentsRange.location, length: match.range.location - currentNode.contentsRange.location)
                currentNode.enclosingRange = NSRange(location: currentNode.enclosingRange.location, length: match.range.location + match.range.length - currentNode.enclosingRange.location)
                currentNode.contents = textString.substring(with: currentNode.contentsRange)
                
                // Update the last node's stripped contents
                var lastContentsBound = currentNode.contentsRange.location
                if let lastNodesLastNode = currentNode.childNodes.last {
                    lastContentsBound = lastNodesLastNode.enclosingRange.location + lastNodesLastNode.enclosingRange.length
                } else {
                    currentNode.strippedContents = ""
                }
                currentNode.strippedContents += textString.substring(with: NSRange(location: lastContentsBound, length: currentNode.contentsRange.location + currentNode.contentsRange.length - lastContentsBound))

                guard tagText == currentNode.tagText else {
                    //print("Tag closing for \(tagText) doesn't match current stack item (\(currentNode.tagText))")
                    nodeStack.removeLast()
                    continue
                }
                nodeStack.removeLast()
            } else {
                let newNode = HTMLNode(tagText: tagText)
                newNode.attributeText = attributeText
                newNode.contentsRange.location = match.range.location + match.range.length
                newNode.enclosingRange.location = match.range.location
                
                if nodeStack.count == 0 {
                    nodes.append(newNode)
                } else if let lastNode = nodeStack.last {
                    
                    // Update the last node's stripped contents
                    var lastContentsBound = lastNode.contentsRange.location
                    if let lastNodesLastNode = lastNode.childNodes.last {
                        lastContentsBound = lastNodesLastNode.enclosingRange.location + lastNodesLastNode.enclosingRange.length
                    } else {
                        lastNode.strippedContents = ""
                    }
                    lastNode.strippedContents += textString.substring(with: NSRange(location: lastContentsBound, length: newNode.enclosingRange.location - lastContentsBound))
                    lastNode.childNodes.append(newNode)
                }
                
                if !HTMLTags.selfClosingTags.contains(tagText) && selfClosingFragment == "" {
                    nodeStack.append(newNode)
                } else {
                    newNode.enclosingRange.length = match.range.length
                }
            }
        }
        
        return nodes
    }
    
    struct HTMLRegion {
        var title: String
        var nodes: [HTMLNode]
    }
    
    /**
     Traverses the given nodes and searches for elements that have the given tag. 
     The returned regions are the children and downstream siblings of the 
     matching tags.
     
     - Parameters:
        * nodes: The nodes in which to search recursively.
        * tag: The HTML tag text to search for (e.g. "a", "img").
        * titleGenerator: A closure that returns a title for the given region. 
            Use this closure to determine whether or not a given node is a 
            delimiter for the desired region type, by returning `nil` if it is 
            not a delimiter. The title returned by this closure will be used as 
            the `title` property of the corresponding returned region.
     
     - Returns: An array of HTML regions containing the nodes delimited by the 
        matching tags, including the matched tags themselves.
     */
    class func htmlRegions(in nodes: [HTMLNode], demarcatedByTag tag: String, withTitles titleGenerator: (HTMLNode) -> String?) -> [HTMLRegion] {
        var currentRegion: HTMLRegion?
        var regions: [HTMLRegion] = []
        
        for node in nodes {
            if node.tagText.lowercased() == tag.lowercased(),
                let title = titleGenerator(node) {
                if let region = currentRegion {
                    regions.append(region)
                    // In case there's an HTML error, get regions from within the collected nodes as well
                    for collectedNode in region.nodes {
                        regions += htmlRegions(in: collectedNode.childNodes, demarcatedByTag: tag, withTitles: titleGenerator)
                    }
                }
                currentRegion = HTMLRegion(title: title, nodes: [node])
            } else if currentRegion != nil {
                currentRegion?.nodes.append(node)
            } else if node.childNodes.count > 0 {
                regions += htmlRegions(in: node.childNodes, demarcatedByTag: tag, withTitles: titleGenerator)
            }
        }
        
        if let region = currentRegion {
            regions.append(region)
            for collectedNode in region.nodes {
                regions += htmlRegions(in: collectedNode.childNodes, demarcatedByTag: tag, withTitles: titleGenerator)
            }
        }
        return regions
    }
}
