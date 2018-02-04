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
    
    static let thresholdParameter = "threshold="
}

class RequirementsListStatement: NSObject {
    
    var title: String?
    var contentDescription: String?
    
    weak var parent: RequirementsListStatement?
    
    enum ConnectionType {
        case all
        case any
        case none
    }
    
    enum ThresholdType {
        case lessThanOrEqual
        case lessThan
        case greaterThanOrEqual
        case greaterThan
    }
    
    enum ThresholdCriterion {
        case subjects
        case units
        case statements
    }
    
    struct Threshold {
        var type: ThresholdType
        var cutoff: Int
        var criterion: ThresholdCriterion
        static let defaultUnitCount = 12
        
        init(_ type: ThresholdType, number: Int, of criterion: ThresholdCriterion = .subjects) {
            self.type = type
            self.cutoff = number
            self.criterion = criterion
        }
        
        func cutoff(for criterion: ThresholdCriterion) -> Int {
            var cutoff: Int
            if self.criterion == criterion {
                cutoff = self.cutoff
            } else if self.criterion == .subjects {
                cutoff = self.cutoff * Threshold.defaultUnitCount
            } else {
                cutoff = self.cutoff / Threshold.defaultUnitCount
            }
            return cutoff
        }
    }
    
    var connectionType: ConnectionType = .all
    
    var requirements: [RequirementsListStatement]? {
        didSet {
            if let reqs = requirements {
                for req in reqs {
                    req.parent = self
                }
            }
        }
    }
    var requirement: String?
    
    var threshold = Threshold(.greaterThanOrEqual, number: 1, of: .statements)
    
    var isPlainString = false
    
    /**
     Defines the bound on the number of distinct elements in the requirements list
     that courses must satisfy.
     */
    var distinctThreshold = Threshold(.greaterThanOrEqual, number: 0)
    
    var thresholdDescription: String {
        var ret = ""
        if connectionType == .all, threshold.cutoff <= 1 {
            ret = "select all"
        } else if threshold.cutoff > 1 {
            switch threshold.type {
            case .lessThanOrEqual:
                ret = "select at most \(threshold.cutoff)"
            case .lessThan:
                ret = "select at most \(threshold.cutoff - 1)"
            case .greaterThanOrEqual:
                ret = "select any \(threshold.cutoff)"
            case .greaterThan:
                ret = "select any \(threshold.cutoff + 1)"
            }
            if threshold.criterion == .units {
                ret += " units"
            } else if threshold.criterion == .subjects, connectionType == .all {
                ret += " subjects"
            }
        } else if threshold.cutoff == 0, connectionType == .any {
            ret = "optional – select any"
        } else if connectionType == .any {
            if let reqs = requirements, reqs.count == 2 {
                ret = "select either"
            } else {
                ret = "select any"
            }
        }
        if distinctThreshold.cutoff > 0 {
            switch distinctThreshold.type {
            case .lessThanOrEqual:
                let categoryText = (distinctThreshold.cutoff != 1) ? "categories" : "category"
                ret += " from at most \(distinctThreshold.cutoff) \(categoryText)"
            case .lessThan:
                let categoryText = (distinctThreshold.cutoff + 1 != 1) ? "categories" : "category"
                ret += " from at most \(distinctThreshold.cutoff - 1) \(categoryText)"
            case .greaterThanOrEqual:
                let categoryText = (distinctThreshold.cutoff != 1) ? "categories" : "category"
                ret += " from at least \(distinctThreshold.cutoff) \(categoryText)"
            case .greaterThan:
                let categoryText = (distinctThreshold.cutoff + 1 != 1) ? "categories" : "category"
                ret += " from at least \(distinctThreshold.cutoff + 1) \(categoryText)"
            }
        }
        return ret
    }
    
    override var debugDescription: String {
        let prog = fulfillmentProgress(for: threshold.criterion)
        let fulfillmentString = prog > 0 ? "(\(prog) - \(percentageFulfilled)%) " : ""
        if let req = requirement {
            return "<\(fulfillmentString)\(isFulfilled ? "√ " : "")\(title != nil ? title! + ": " : "")\(req)\(thresholdDescription.count > 0 ? " (" + thresholdDescription + ")" : "")>"
        } else if let reqList = requirements {
            var connectionString = "\(connectionType)"
            if thresholdDescription.count > 0 {
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
            self.threshold = Threshold(.greaterThanOrEqual, number: items.count)
        } else {
            self.threshold = Threshold(.greaterThanOrEqual, number: 1, of: .statements)
        }
        self.requirements = items
        super.init()
        for req in items {
            req.parent = self
        }
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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 4,
            trimmed[trimmed.startIndex..<trimmed.index(trimmed.startIndex, offsetBy: 2)] == "\"\"",
            trimmed[trimmed.index(trimmed.endIndex, offsetBy: -2)..<trimmed.endIndex] == "\"\"" {
            return ([undecoratedComponent(trimmed)], .none)
        }
        var components: [String] = []
        var connectionType = ConnectionType.all
        var currentIndentLevel = 0
        for characterIndex in text.indices {
            let character = text[characterIndex]
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
        for match in regex.matches(in: string, options: [], range: NSRange(location: 0, length: string.count)) {
            if let range = Range(match.range, in: string) {
                components.append(String(string[matchLocation..<range.lowerBound]))
                matchLocation = range.upperBound
            }
        }
        components.append(String(string[matchLocation..<string.endIndex]))
        return components.map({ undecoratedComponent($0) })
    }
    
    fileprivate func parseModifierComponent(_ modifier: String) -> Threshold {
        // Of the form >=x, <=x, >x, or <x
        var threshold = Threshold(.greaterThanOrEqual, number: 1, of: .subjects)
        if modifier.contains(">=") {
            threshold.type = .greaterThanOrEqual
        } else if modifier.contains("<=") {
            threshold.type = .lessThanOrEqual
        } else if modifier.contains(">") {
            threshold.type = .greaterThan
        } else if modifier.contains("<") {
            threshold.type = .lessThan
        }
        var numberString = modifier.replacingOccurrences(of: ">", with: "").replacingOccurrences(of: "<", with: "").replacingOccurrences(of: "=", with: "")
        if numberString.contains("u") {
            threshold.criterion = .units
            numberString = numberString.replacingOccurrences(of: "u", with: "")
        }
        if let number = Int(numberString) {
            threshold.cutoff = number
        } else {
            print("Couldn't get number out of modifier string \(modifier)")
        }
        return threshold
    }
    
    func parseModifier(_ modifier: String) {
        if modifier.contains("|") {
            let comps = modifier.components(separatedBy: "|")
            guard comps.count == 2 else {
                print("Unsupported number of components in modifier string: \(modifier)")
                return
            }
            if comps[0].count > 0 {
                threshold = parseModifierComponent(comps[0])
            }
            if comps[1].count > 0 {
                distinctThreshold = parseModifierComponent(comps[1])
            }
        } else {
            threshold = parseModifierComponent(modifier)
        }
    }
    
    fileprivate func parseStatement(_ statement: String) {
        var filteredStatement = statement
        if let match = modifierRegex.firstMatch(in: filteredStatement, options: [], range: NSRange(location: 0, length: filteredStatement.count)) {
            if let range = Range(match.range(at: 1), in: filteredStatement) {
                parseModifier(String(filteredStatement[range]))
            }
            filteredStatement = modifierRegex.stringByReplacingMatches(in: filteredStatement, options: [], range: NSRange(location: 0, length: filteredStatement.count), withTemplate: "")
        }
        
        let (components, cType) = separateTopLevelItems(in: filteredStatement)
        if threshold.cutoff == 0 && threshold.type == .greaterThanOrEqual {
            connectionType = .any
        } else {
            connectionType = cType
        }
        isPlainString = cType == .none
        
        if components.count == 1 {
            requirement = components[0]
        } else {
            requirements = components.map({ RequirementsListStatement(statement: unwrappedComponent($0)) })
        }
    }
    
    fileprivate func substituteVariableDefinitions(from dictionary: [String: RequirementsListStatement]) {
        if let req = requirement {
            // Turns out this requirement is a variable
            if let subReq = dictionary[req] {
                subReq.substituteVariableDefinitions(from: dictionary)
                requirements = [subReq]
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
    var fulfillmentProgress = (0, 0)
    var satisfyingCourses: Set<Course>?
    
    func coursesSatisfyingRequirement(in courses: [Course]) -> [Course] {
        var satisfying: [Course] = []
        if let req = requirement {
            for course in courses {
                if course.satisfies(requirement: req) {
                    satisfying.append(course)
                }
            }
        }
        return satisfying
    }
    
    func number(_ number: Int, withUnits units: Int, satisfies threshold: Threshold) -> Bool {
        var fulfilledThreshold = false
        let criterion = threshold.criterion == .units ? units : number
        switch threshold.type {
        case .greaterThan:
            fulfilledThreshold = (criterion > threshold.cutoff)
        case .greaterThanOrEqual:
            fulfilledThreshold = (criterion >= threshold.cutoff)
        case .lessThan:
            fulfilledThreshold = (criterion < threshold.cutoff)
        case .lessThanOrEqual:
            fulfilledThreshold = (criterion <= threshold.cutoff)
        }
        return fulfilledThreshold
    }
    
    /**
     - Returns: The number of subjects and units that satisfy this requirement.
     */
    @discardableResult func computeRequirementStatus(with courses: [Course]) -> Set<Course> {
        var satisfyingPerCategory: [Set<Course>] = []
        var distinctNumSatisfying = 0
        if requirement != nil {
            if let manual = manualProgress {
                isFulfilled = manual == threshold.cutoff
                var subjects = 0
                var units = 0
                if threshold.criterion == .units {
                    units = manual
                } else {
                    subjects = manual
                }
                fulfillmentProgress = (subjects, units)
                return Set<Course>()
            }
            
            let satisfiedCourses = Set<Course>(coursesSatisfyingRequirement(in: courses))
            satisfyingCourses = satisfiedCourses
            satisfyingPerCategory.append(satisfiedCourses)
        } else if let reqs = requirements {
            for req in reqs {
                let satisfiedCourses = req.computeRequirementStatus(with: courses)
                if req.isFulfilled {
                    distinctNumSatisfying += 1
                }
                satisfyingPerCategory.append(satisfiedCourses)
            }
        }
        
        let totalSatisfyingCourses = satisfyingPerCategory.reduce(Set<Course>(), { $0.union($1) })
        var numSatisfying = (totalSatisfyingCourses.count, totalSatisfyingCourses.reduce(0, { $0 + $1.totalUnits }))
        if threshold.criterion == .statements {
            numSatisfying = (distinctNumSatisfying, distinctNumSatisfying * Threshold.defaultUnitCount)
            isFulfilled = number(distinctNumSatisfying, withUnits: distinctNumSatisfying, satisfies: threshold)
            fulfillmentProgress = numSatisfying
            return totalSatisfyingCourses
        }
        if threshold.type == .lessThan || threshold.type == .lessThanOrEqual {
            numSatisfying = (min(numSatisfying.0, threshold.cutoff(for: .subjects) - (threshold.type == .lessThan ? 1 : 0)), min(numSatisfying.1, threshold.cutoff(for: .units) - (threshold.type == .lessThan ? 1 : 0)))
        }
        if connectionType == .any, threshold.cutoff == 0 {
            isFulfilled = true
        } else if connectionType == .any || threshold.cutoff > 1 {
            if distinctThreshold.type == .lessThan || distinctThreshold.type == .lessThanOrEqual {
                let satisfyingQuantities = satisfyingPerCategory.map({ item in (item.count, item.reduce(0, { $0 + $1.totalUnits } )) })
                let optimalReqs = satisfyingQuantities.sorted(by: {
                    (distinctThreshold.criterion == .subjects ? $0.0 > $1.0 : $0.1 > $1.1)
                })[0..<min(satisfyingQuantities.count, distinctThreshold.cutoff)]
                numSatisfying = optimalReqs.reduce((0, 0), { ($0.0 + $1.0, $0.1 + $1.1) })
                isFulfilled = number(numSatisfying.0, withUnits: numSatisfying.1, satisfies: threshold) && number(optimalReqs.count, withUnits: 0, satisfies: distinctThreshold)
            } else {
                isFulfilled = number(numSatisfying.0, withUnits: numSatisfying.1, satisfies: threshold) && number(distinctNumSatisfying, withUnits: 0, satisfies: distinctThreshold)
            }
        } else {
            isFulfilled = (distinctNumSatisfying >= (requirements?.count ?? 1))
        }
        fulfillmentProgress = numSatisfying
        return totalSatisfyingCourses
    }
    
    func fulfillmentProgress(for criterion: ThresholdCriterion) -> Int {
        return criterion == .subjects ? fulfillmentProgress.0 : fulfillmentProgress.1
    }
    
    private func fulfilledFraction(for criterion: ThresholdCriterion) -> (Int, Int) {
        if let manual = manualProgress {
            if criterion == threshold.criterion {
                return (manual, threshold.cutoff)
            }
            return (0, 0)
        }
        if let reqs = requirements {
            if distinctThreshold.cutoff > 0 || (connectionType == .all && threshold.cutoff > 1) {
                return (fulfillmentProgress(for: criterion), threshold.cutoff(for: criterion))
            }
            let progresses = reqs.map({ $0.fulfilledFraction(for: criterion) })
            if connectionType == .all {
                return progresses.reduce((0, 0), { ($0.0 + min($1.0, $1.1), $0.1 + $1.1) })
            }
            let sortedProgresses = reqs.sorted(by: { $0.percentageFulfilled > $1.percentageFulfilled }).map({ $0.fulfilledFraction(for: criterion) })
            if threshold.cutoff > 1 {
                if threshold.criterion == .subjects {
                    let tempResult = sortedProgresses[0..<min(threshold.cutoff, sortedProgresses.count)].reduce((0, 0), { ($0.0 + $1.0, $0.1 + $1.1) })
                    return (min(threshold.cutoff(for: criterion), tempResult.0), threshold.cutoff(for: criterion))
                } else {
                    let tempResult = sortedProgresses.reduce((0, 0), { ($0.0 + $1.0, $0.1 + $1.1) })
                    return (min(threshold.cutoff(for: criterion), tempResult.0), threshold.cutoff(for: criterion))
                }
            } else {
                return (min(threshold.cutoff(for: criterion), sortedProgresses.reduce(0, { $0 + $1.0 })), max(threshold.cutoff(for: criterion), 0))
            }
        }
        return (fulfillmentProgress(for: criterion), threshold.cutoff(for: criterion))
    }
    
    var percentageFulfilled: Float {
        if connectionType == .none, manualProgress == nil {
            return 0.0
        }
        let fulfilled = fulfilledFraction(for: threshold.criterion)
        if fulfilled.0 == 0, fulfilled.1 == 0 {
            return 0.0
        }
        return min(1.0, Float(fulfilled.0) / Float(fulfilled.1)) * 100.0
    }
    
    // MARK: - Required Courses
    
    var requiredCourses: Set<Course> {
        if let req = requirement {
            if let course = CourseManager.shared.getCourse(withID: req) {
                return Set<Course>([course])
            }
        } else if let reqs = requirements {
            return reqs.reduce(Set<Course>(), { $0.union($1.requiredCourses) })
        }
        return Set<Course>()
    }
    
    // MARK: - Defaults
    
    var keyPath: String? {
        guard let parent = parent,
            let parentPath = parent.keyPath else {
            return nil
        }
        return parentPath + ".\(parent.requirements?.index(of: self) ?? 0)"
    }
    
    var manualProgress: Int? {
        get {
            guard let path = keyPath else {
                return nil
            }
            let ret = UserDefaults.standard.integer(forKey: path)
            if ret != 0 {
                return ret
            }
            return nil
        } set {
            guard let path = keyPath else {
                return
            }
            UserDefaults.standard.set(newValue, forKey: path)
        }
    }
}

class RequirementsList: RequirementsListStatement {

    var shortTitle: String?
    var mediumTitle: String?
    var titleNoDegree: String?
    var listID: String
    var fileURL: URL?
    
    var isLoaded = false
    
    init(contentsOf file: String) throws {
        let url = URL(fileURLWithPath: file)
        self.listID = url.deletingPathExtension().lastPathComponent
        fileURL = url
        super.init()
        let fileText = try String(contentsOfFile: file)
        self.parseRequirementsList(from: fileText, partial: true)
    }
    
    override var requirements: [RequirementsListStatement]? {
        get {
            if !isLoaded, let file = fileURL?.path {
                isLoaded = true
                do {
                    let fileText = try String(contentsOfFile: file)
                    self.parseRequirementsList(from: fileText)
                } catch {
                    print("Error loading requirements list: \(error)")
                }
            }
            return super.requirements
        } set {
            super.requirements = newValue
        }
    }
    
    func parseRequirementsList(from string: String, partial: Bool = false) {
        var lines = string.components(separatedBy: "\n").flatMap { (line) -> String? in
            if let range = line.range(of: SyntaxConstants.commentCharacter) {
                if range.lowerBound == line.startIndex {
                    return nil
                }
                return String(line[line.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return line.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Parse the first two lines
        let headerLine = lines.removeFirst()
        var headerComps = headerLine.components(separatedBy: SyntaxConstants.headerSeparator).map( { undecoratedComponent($0) })
        if headerComps.count > 0 {
            shortTitle = headerComps.removeFirst()
            if headerComps.count > 0 {
                mediumTitle = headerComps.removeFirst()
            }
            if headerComps.count > 1 {
                titleNoDegree = headerComps.removeFirst()
                title = headerComps.removeFirst()
            } else if headerComps.count > 0 {
                title = headerComps.removeFirst()
            }
            for comp in headerComps {
                let noWhitespaceComp = comp.components(separatedBy: .whitespaces).joined()
                if let thresholdRange = noWhitespaceComp.range(of: SyntaxConstants.thresholdParameter) {
                    if let thresholdValue = Int(noWhitespaceComp[thresholdRange.upperBound..<noWhitespaceComp.endIndex]) {
                        threshold.cutoff = thresholdValue
                    } else {
                        print("\(listID): Invalid threshold parameter declaration: \(noWhitespaceComp)")
                    }
                }
            }
        }
        if partial {
            return
        }
        
        // Second line is the description of the course
        let descriptionLine = lines.removeFirst()
        if descriptionLine.count > 0 {
            contentDescription = descriptionLine.replacingOccurrences(of: "\\n", with: "\n")
        }
        
        guard lines.count > 0 else {
            print("\(listID): Reached end of file early!")
            return
        }
        guard lines[0].count == 0 else {
            print("\(listID): Third line isn't empty (contains \"\(lines[0])\")")
            return
        }
        lines.removeFirst()
        
        // Parse top-level list
        var topLevelSections: [(varName: String, description: String)] = []
        while lines.count > 0, lines[0].count > 0 {
            guard lines.count > 2 else {
                print("\(listID): Not enough lines for top-level sections - need variable names and descriptions on two separate lines.")
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
        var variables: [String: RequirementsListStatement] = [:]
        while lines.count > 0 {
            let currentLine = lines.removeFirst()
            guard currentLine.count > 0 else {
                continue
            }
            guard currentLine.contains(SyntaxConstants.declarationCharacter) else {
                print("\(listID): Unexpected line: \(currentLine)")
                continue
            }
            let comps = currentLine.components(separatedBy: SyntaxConstants.declarationCharacter)
            guard comps.count == 2 else {
                print("\(listID): Can't have more than one occurrence of \"\(SyntaxConstants.declarationCharacter)\" on a line")
                continue
            }
            
            var statementTitle: String?
            var variableName: String
            let declaration = comps[0]
            if let commaRange = declaration.range(of: SyntaxConstants.variableDeclarationSeparator) {
                variableName = undecoratedComponent(String(declaration[declaration.startIndex..<commaRange.lowerBound]))
                statementTitle = undecoratedComponent(String(declaration[commaRange.upperBound..<declaration.endIndex]))
            } else {
                variableName = undecoratedComponent(comps[0])
            }
            let statement = RequirementsListStatement(statement: comps[1], title: statementTitle)
            variables[variableName] = statement
        }
        
        var reqs: [RequirementsListStatement] = []
        for (name, description) in topLevelSections {
            guard let req = variables[name] else {
                print("\(listID): Undefined variable: \(name)")
                return
            }
            req.contentDescription = description
            reqs.append(req)
        }
        
        requirements = reqs
        substituteVariableDefinitions(from: variables)
    }
    
    override var keyPath: String? {
        return listID
    }
}
