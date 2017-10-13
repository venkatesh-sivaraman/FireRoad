//
//  RequirementsList.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 10/1/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

enum SyntaxConstants {
    static let allSeparator = ","
    static let anySeparator = "/"
    static let commentCharacter = "%%"
    static let declarationCharacter = ":="
    static let variableDeclarationSeparator = ","
    static let headerSeparator = "#,#"
}

class RequirementsListStatement: NSObject {
    
    var title: String?
    var contentDescription: String?
    
    enum ConnectionType {
        case all
        case any
    }
    
    enum ThresholdType {
        case lessThanOrEqual
        case lessThan
        case greaterThanOrEqual
        case greaterThan
    }
    
    var connectionType: ConnectionType = .all
    
    var requirements: [RequirementsListStatement]?
    var requirement: String?
    
    var thresholdType: ThresholdType = .greaterThanOrEqual
    var threshold = 0
    
    var thresholdDescription: String {
        if threshold > 1 {
            switch thresholdType {
            case .lessThanOrEqual:
                return "select at most \(threshold)"
            case .lessThan:
                return "select at most \(threshold - 1)"
            case .greaterThanOrEqual:
                return "select any \(threshold)"
            case .greaterThan:
                return "select any \(threshold + 1)"
            }
        }
        if connectionType == .any {
            if let reqs = requirements, reqs.count == 2 {
                return "select either"
            }
            return "select any"
        }
        return ""
    }
    
    override var debugDescription: String {
        let fulfillmentString = fulfillmentProgress > 0 ? "(\(fulfillmentProgress) - \(percentageFulfilled)%) " : ""
        if let req = requirement {
            return "<\(fulfillmentString)\(isFulfilled ? "√ " : "")\(title != nil ? title! + ": " : "")\(req)\(thresholdDescription.characters.count > 0 ? " (" + thresholdDescription + ")" : "")>"
        } else if let reqList = requirements {
            var connectionString = "\(connectionType)"
            if thresholdDescription.characters.count > 0 {
                connectionString += " (\(thresholdDescription))"
            }
            return "<\(fulfillmentString)\(isFulfilled ? "√ " : "")\(title != nil ? title! + ": " : "")\(connectionString) of \n\(reqList.map({ String(reflecting: $0) }).joined(separator: "\n"))>"
        }
        return "<\(fulfillmentString)\(isFulfilled ? "√ " : "")\(title ?? "No title")>"
    }
    
    var shortDescription: String {
        var baseString: String = ""
        if let req = requirement {
            baseString = req
        } else if let reqs = requirements {
            let connectionWord = connectionType == .all ? "and" : "or"
            if reqs.count == 2 {
                baseString = "\(reqs[0].shortDescription) \(connectionWord) \(reqs[1].shortDescription)"
            } else {
                baseString = "\(reqs[0].shortDescription) \(connectionWord) \(reqs.count - 1) others"
            }
        }
        return baseString
    }
    
    /// Gives the minimum number of steps needed to traverse the tree down to a leaf (an individual course).
    var minimumNestDepth: Int {
        if let reqs = requirements {
            return (reqs.map({ $0.minimumNestDepth }).min() ?? -1) + 1
        }
        return 0
    }
    
    /// Gives the maximum number of steps needed to traverse the tree down to a leaf (an individual course).
    var maximumNestDepth: Int {
        if let reqs = requirements {
            return (reqs.map({ $0.maximumNestDepth }).max() ?? -1) + 1
        }
        return 0
    }
    
    override init() {
        super.init()
    }
    
    init(connectionType: ConnectionType, items: [RequirementsListStatement], title: String? = nil) {
        self.title = title
        self.connectionType = connectionType
        if connectionType == .all {
            self.threshold = items.count
        } else {
            self.threshold = 1
        }
        self.requirements = items
    }
    
    init(requirement: String, title: String? = nil) {
        self.title = title
        self.requirement = requirement
    }
    
    init(statement: String, title: String? = nil) {
        self.title = title
        super.init()
        parseStatement(statement)
    }
    
    fileprivate func topLevelSeparatorRegex(for separator: String) -> NSRegularExpression {
        let sepPattern = NSRegularExpression.escapedPattern(for: separator)
        guard let regex = try? NSRegularExpression(pattern: "\(sepPattern)(?![^\\(]*\\))", options: []) else {
            fatalError("Couldn't initialize top level separator regex")
        }
        return regex
    }
    
    fileprivate func separateTopLevelItems(in text: String) -> ([String], ConnectionType) {
        var components: [String] = []
        var connectionType = ConnectionType.all
        var currentIndentLevel = 0
        for characterIndex in text.characters.indices {
            let character = text.characters[characterIndex]
            if String(character) == SyntaxConstants.allSeparator,
                currentIndentLevel == 0 {
                connectionType = .all
                components.append("")
            } else if String(character) == SyntaxConstants.anySeparator,
                currentIndentLevel == 0 {
                connectionType = .any
                components.append("")
            } else {
                if character == "(" {
                    currentIndentLevel += 1
                } else if character == ")" {
                    currentIndentLevel -= 1
                }
                if components.count == 0 {
                    components.append("")
                }
                components[components.count - 1] += String(character)
            }
        }
        return (components.map({ undecoratedComponent($0) }), connectionType)
    }
    
    fileprivate lazy var modifierRegex: NSRegularExpression = {
        guard let regex = try? NSRegularExpression(pattern: "\\{(.*?)\\}(?![^\\(]*\\))", options: []) else {
            fatalError("Couldn't initialize modifier regex")
        }
        return regex
    }()
    
    static var decorationCharacterSet = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'"))
    fileprivate func undecoratedComponent(_ component: String) -> String {
        return component.trimmingCharacters(in: RequirementsListStatement.decorationCharacterSet)
    }
    
    fileprivate func unwrappedComponent(_ component: String) -> String {
        var unwrapping = component.trimmingCharacters(in: .whitespacesAndNewlines)
        while unwrapping.first == Character("("),
            unwrapping.last == Character(")") {
            unwrapping = String(unwrapping[unwrapping.index(after: unwrapping.startIndex)..<unwrapping.index(before: unwrapping.endIndex)])
        }
        return unwrapping
    }
    
    fileprivate func components(in string: String, separatedBy regex: NSRegularExpression) -> [String] {
        var components: [String] = []
        var matchLocation = string.startIndex
        for match in regex.matches(in: string, options: [], range: NSRange(location: 0, length: string.characters.count)) {
            if let range = Range(match.range, in: string) {
                components.append(String(string[matchLocation..<range.lowerBound]))
                matchLocation = range.upperBound
            }
        }
        components.append(String(string[matchLocation..<string.endIndex]))
        return components.map({ undecoratedComponent($0) })
    }
    
    func parseModifier(_ modifier: String) {
        // Of the form >=x, <=x, >x, or <x
        if modifier.contains(">=") {
            thresholdType = .greaterThanOrEqual
        } else if modifier.contains("<=") {
            thresholdType = .lessThanOrEqual
        } else if modifier.contains(">") {
            thresholdType = .greaterThan
        } else if modifier.contains("<") {
            thresholdType = .lessThan
        }
        guard let number = Int(modifier.replacingOccurrences(of: ">", with: "").replacingOccurrences(of: "<", with: "").replacingOccurrences(of: "=", with: "")) else {
            print("Couldn't get number out of modifier string \(modifier)")
            return
        }
        threshold = number
    }
    
    fileprivate func parseStatement(_ statement: String) {
        var filteredStatement = statement
        if let match = modifierRegex.firstMatch(in: filteredStatement, options: [], range: NSRange(location: 0, length: filteredStatement.characters.count)) {
            if let range = Range(match.range(at: 1), in: filteredStatement) {
                parseModifier(String(filteredStatement[range]))
            }
            filteredStatement = modifierRegex.stringByReplacingMatches(in: filteredStatement, options: [], range: NSRange(location: 0, length: filteredStatement.characters.count), withTemplate: "")
        }
        
        let (components, cType) = separateTopLevelItems(in: filteredStatement)
        connectionType = cType
        if connectionType == .any {
            print("Or statement: \(filteredStatement)")
        } else {
            print("And statement: \(filteredStatement)")
        }
        
        if components.count == 1 {
            requirement = components[0]
        } else {
            requirements = components.map({ RequirementsListStatement(statement: unwrappedComponent($0)) })
        }
    }
    
    fileprivate func substituteVariableDefinitions(from dictionary: [String: RequirementsListStatement]) {
        if let req = requirement {
            if dictionary[req] != nil {
                print("Should have substituted variable \(self) earlier")
            }
        } else if let reqList = requirements {
            for (i, statement) in reqList.enumerated() {
                if let statementReq = statement.requirement,
                    let subReq = dictionary[statementReq] {
                    requirements?[i] = subReq
                }
                requirements?[i].substituteVariableDefinitions(from: dictionary)
            }
        }
    }
    
    // MARK: - Requirement Status
    
    var isFulfilled = false
    var fulfillmentProgress: Int = 0
    
    func coursesSatisfyingRequirement(in courses: [Course]) -> [Course] {
        var satisfying: [Course] = []
        if let req = requirement?.replacingOccurrences(of: "GIR:", with: "") {
            let gir = GIRAttribute(rawValue: req)
            let hass = HASSAttribute(rawValue: req)
            let comm = CommunicationAttribute(rawValue: req)
            for course in courses {
                if course.subjectID == req ||
                    course.jointSubjects.contains(req) ||
                    course.equivalentSubjects.contains(req) ||
                    course.girAttribute?.satisfies(gir) == true ||
                    course.hassAttribute?.satisfies(hass) == true ||
                    course.communicationRequirement?.satisfies(comm) == true {
                    satisfying.append(course)
                }
            }
        }
        return satisfying
    }
    
    func computeRequirementStatus(with courses: [Course]) {
        var numSatisfying = 0
        if requirement != nil {
            numSatisfying += coursesSatisfyingRequirement(in: courses).count
        } else if let reqs = requirements {
            for req in reqs {
                req.computeRequirementStatus(with: courses)
                if req.isFulfilled {
                    if connectionType == .any, threshold > 1 {
                        numSatisfying += req.coursesSatisfyingRequirement(in: courses).count
                    } else {
                        numSatisfying += 1
                    }
                }
            }
        }
        
        if connectionType == .any || threshold > 1 {
            switch thresholdType {
            case .greaterThan:
                isFulfilled = (numSatisfying > max(threshold, 1))
            case .greaterThanOrEqual:
                isFulfilled = (numSatisfying >= max(threshold, 1))
            case .lessThan:
                isFulfilled = (numSatisfying < max(threshold, 1))
            case .lessThanOrEqual:
                isFulfilled = (numSatisfying <= max(threshold, 1))
            }
        } else {
            isFulfilled = (numSatisfying >= (requirements?.count ?? 1))
        }
        fulfillmentProgress = numSatisfying
    }
    
    private var fulfilledFraction: (Int, Int) {
        if let reqs = requirements {
            let progresses = reqs.map({ $0.fulfilledFraction })
            if connectionType == .all {
                return progresses.reduce((0, 0), { ($0.0 + min($1.0, $1.1), $0.1 + $1.1) })
            }
            let sortedProgresses = reqs.sorted(by: { $0.percentageFulfilled > $1.percentageFulfilled }).map({ $0.fulfilledFraction })
            let result = sortedProgresses[0..<min(max(threshold, 1), sortedProgresses.count)].reduce((0, 0), { ($0.0 + $1.0, $0.1 + $1.1) })
            return result
        }
        return (fulfillmentProgress, max(threshold, 1))
    }
    
    var percentageFulfilled: Float {
        return min(1.0, Float(fulfilledFraction.0) / Float(fulfilledFraction.1)) * 100.0
    }
}

class RequirementsList: RequirementsListStatement {

    var shortTitle: String?
    var mediumTitle: String?
    
    init(contentsOf file: String) throws {
        let fileText = try String(contentsOfFile: file)
        super.init()
        self.parseRequirementsList(from: fileText)
    }
    
    func parseRequirementsList(from string: String) {
        var lines = string.components(separatedBy: "\n").flatMap { (line) -> String? in
            if let range = line.range(of: SyntaxConstants.commentCharacter) {
                if range.lowerBound == line.startIndex {
                    return nil
                }
                return String(line[line.startIndex..<range.lowerBound])
            }
            return line
        }
        
        // Parse the first two lines
        let headerLine = lines.removeFirst()
        let headerComps = headerLine.components(separatedBy: SyntaxConstants.headerSeparator).map( { undecoratedComponent($0) })
        if headerComps.count > 0 {
            shortTitle = headerComps[0]
            if headerComps.count > 1 {
                mediumTitle = headerComps[1]
            }
            if headerComps.count > 2 {
                title = headerComps[2]
            }
        }
        // Second line is the description of the course
        let descriptionLine = lines.removeFirst().trimmingCharacters(in: .whitespaces)
        if descriptionLine.characters.count > 0 {
            contentDescription = descriptionLine.replacingOccurrences(of: "\\n", with: "\n")
        }
        
        guard lines.count > 0 else {
            print("Reached end of file early!")
            return
        }
        guard lines[0].characters.count == 0 else {
            print("Third line isn't empty")
            return
        }
        lines.removeFirst()
        
        // Parse top-level list
        var topLevelSections: [(varName: String, description: String)] = []
        while lines.count > 0, lines[0].characters.count > 0 {
            guard lines.count > 2 else {
                print("Not enough lines for top-level sections - need variable names and descriptions on two separate lines.")
                return
            }
            let varName = undecoratedComponent(lines.removeFirst())
            let description = undecoratedComponent(lines.removeFirst().replacingOccurrences(of: "\\n", with: "\n"))
            topLevelSections.append((varName, description))
        }
        guard lines.count > 0 else {
            return
        }
        lines.removeFirst()
        
        // Parse variable declarations
        let variableRegex = topLevelSeparatorRegex(for: SyntaxConstants.variableDeclarationSeparator)
        var variables: [String: RequirementsListStatement] = [:]
        while lines.count > 0 {
            let currentLine = lines.removeFirst()
            guard currentLine.characters.count > 0 else {
                continue
            }
            guard currentLine.contains(SyntaxConstants.declarationCharacter) else {
                print("Unexpected line: \(currentLine)")
                continue
            }
            let comps = currentLine.components(separatedBy: SyntaxConstants.declarationCharacter)
            guard comps.count == 2 else {
                print("Can't have more than one occurrence of \"\(SyntaxConstants.declarationCharacter)\" on a line")
                continue
            }
            
            let declarationComps = self.components(in: comps[0], separatedBy: variableRegex)
            var statementTitle: String?
            var variableName = undecoratedComponent(comps[0])
            if declarationComps.count > 1 {
                variableName = declarationComps[0]
                statementTitle = declarationComps[1]
            }
            let statement = RequirementsListStatement(statement: comps[1], title: statementTitle)
            variables[variableName] = statement
        }
        
        var reqs: [RequirementsListStatement] = []
        for (name, description) in topLevelSections {
            guard let req = variables[name] else {
                print("Undefined variable: \(name)")
                return
            }
            req.contentDescription = description
            reqs.append(req)
        }
        
        requirements = reqs
        substituteVariableDefinitions(from: variables)
    }
}
