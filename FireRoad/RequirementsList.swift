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
    static let urlParameter = "url="
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
        
        var actualCutoff: Int {
            if type == .greaterThan {
                return cutoff + 1
            } else if type == .lessThan {
                return cutoff - 1
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
    
    var threshold: Threshold?
    
    var isPlainString = false
    
    var currentUser: User? {
        didSet {
            if let reqs = self.requirements {
                for req in reqs {
                    req.currentUser = currentUser
                }
            }
        }
    }
    
    /**
     Defines the bound on the number of distinct elements in the requirements list
     that courses must satisfy.
     */
    var distinctThreshold: Threshold?
    
    var thresholdDescription: String {
        var ret = ""
        if let threshold = threshold, threshold.cutoff != 1 {
            if threshold.cutoff > 1 {
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
            }
        } else if connectionType == .all {
            ret = "select all"
        } else if connectionType == .any {
            if let reqs = requirements, reqs.count == 2 {
                ret = "select either"
            } else {
                ret = "select any"
            }
        }
        if let distinctThreshold = distinctThreshold,
            distinctThreshold.cutoff > 0 {
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
        let prog = fulfillmentProgress.0
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
    
    fileprivate let manualProgressItemRegex = try! NSRegularExpression(pattern: "^\"\"[^\"]*\"\"(\\s*\\{.*\\})?$", options: [])
    
    fileprivate func separateTopLevelItems(in text: String) -> ([String], ConnectionType) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 4,
            manualProgressItemRegex.firstMatch(in: trimmed, options: .anchored, range: NSRange(location: 0, length: trimmed.count)) != nil {
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
        return (/*components.map({ undecoratedComponent($0) })*/ components, connectionType)
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
        outer:
        while unwrapping.first == Character("("),
            unwrapping.last == Character(")") {
                // Make sure these parentheses are not closed within the string
                var indentLevel = 0
                for i in unwrapping.indices {
                    if unwrapping[i] == "(" {
                        indentLevel += 1
                    } else if unwrapping[i] == ")" {
                        indentLevel -= 1
                        if indentLevel == 0, i < unwrapping.index(before: unwrapping.endIndex) {
                            break outer
                        }
                    }
                }
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
        } else if modifier.count > 0 {
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
        if let threshold = threshold,
            threshold.cutoff == 0,
            threshold.type == .greaterThanOrEqual {
            // Force the connection type to be any (there's no way it can be all)
            connectionType = .any
        } else {
            connectionType = cType
        }
        isPlainString = cType == .none
        
        if components.count == 1 {
            requirement = undecoratedComponent(components[0])
        } else {
            requirements = components.map({ RequirementsListStatement(statement: unwrappedComponent($0)) })
        }
    }
    
    fileprivate func substituteVariableDefinitions(from dictionary: [String: RequirementsListStatement]) {
        if let req = requirement {
            // Turns out this requirement is a variable
            if let subReq = dictionary[req] {
                subReq.substituteVariableDefinitions(from: dictionary)
                requirement = nil
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
    var subjectFulfillmentProgress = (0, 0)
    var unitFulfillmentProgress = (0, 0)
    
    /**
     Returns the whole and half classes separately
     */
    func coursesSatisfyingRequirement(in courses: [Course]) -> ([Course], [Course]) {
        var wholeClasses: [Course] = []
        var halfClasses: [Course] = []
        if let req = requirement {
            for course in courses {
                if course.satisfies(requirement: req, allCourses: courses) {
                    wholeClasses.append(course)
                    break
                } else if course.satisfiesGeneralRequirement(req) {
                    if course.isHalfClass {
                        halfClasses.append(course)
                    } else {
                        wholeClasses.append(course)
                    }
                }
            }
        }
        return (wholeClasses, halfClasses)
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
    
    func ceilingThreshold(_ threshold: (Int, Int)) -> (Int, Int) {
        let maxFirstVal = threshold.1 == 0 ? Int.max : threshold.1
        return (min(max(0, threshold.0), maxFirstVal), threshold.1)
    }
    
    /**
     If the requirements status has been successfully computed using
     a progress assertion, returns a non-nil set of courses representing
     the set that satisfies this requirement. This set may be empty if
     the requirement has been ignored. If no assertion is present, returns nil.
     */
    func computeAssertions(with courses: [Course]) -> Set<Course>? {
        guard let assertion = progressAssertion else {
            return nil
        }
        
        if assertion.ignore {
            self.isFulfilled = false
            subjectFulfillmentProgress = (0, 0)
            unitFulfillmentProgress = (0, 0)
            fulfillmentProgress = (0, 0)
            return Set<Course>()
        } else if let subs = assertion.substitutions, subs.count > 0 {
            var satisfiedCourses = Set<Course>()
            var numSatisfied = 0
            for sub in subs {
                for course in courses {
                    if course.satisfies(requirement: sub, allCourses: courses) {
                        numSatisfied += 1
                        satisfiedCourses.insert(course)
                        break
                    }
                }
            }
            if isPlainString, let threshold = threshold {
                // Plain-string requirements can be substituted with a list of courses that will
                // be used to satisfy the requirement. Use the provided threshold as a denominator
                // in this case.
                subjectFulfillmentProgress = (numSatisfied, threshold.cutoff(for: .subjects))
                unitFulfillmentProgress = (satisfiedCourses.reduce(0, { $0 + $1.totalUnits }), threshold.cutoff(for: .units))
                fulfillmentProgress = threshold.criterion == .units ? unitFulfillmentProgress : subjectFulfillmentProgress
                self.isFulfilled = fulfillmentProgress.0 == fulfillmentProgress.1
            } else {
                subjectFulfillmentProgress = (numSatisfied, subs.count)
                self.isFulfilled = numSatisfied == subs.count
                unitFulfillmentProgress = (numSatisfied * Threshold.defaultUnitCount, subs.count * Threshold.defaultUnitCount)
                fulfillmentProgress = subjectFulfillmentProgress
            }
            return satisfiedCourses
        }
        
        return nil
    }
    
    /**
     - Parameter autoManual: whether to automatically count plain strings as fulfilled
     - Returns: The set of courses that satisfy this requirement.
     */
    @discardableResult func computeRequirementStatus(with courses: [Course]) -> Set<Course> {
        // First check for progress assertions
        if let satisfiedCourses = computeAssertions(with: courses) {
            return satisfiedCourses
        }
        
        if requirement != nil {
            var satisfiedCourses = Set<Course>()
            let (whole, half) = coursesSatisfyingRequirement(in: courses)
            satisfiedCourses = Set<Course>(whole + half)
            if let threshold = threshold {
                subjectFulfillmentProgress = ceilingThreshold((whole.count + half.count / 2, threshold.cutoff / (threshold.criterion == .units ? Threshold.defaultUnitCount : 1)))
                unitFulfillmentProgress = ceilingThreshold((satisfiedCourses.reduce(0, { $0 + $1.totalUnits }), threshold.cutoff * (threshold.criterion == .subjects ? Threshold.defaultUnitCount : 1)))
                isFulfilled = number(subjectFulfillmentProgress.0, withUnits: unitFulfillmentProgress.0, satisfies: threshold)
            } else {
                let progress = min(satisfiedCourses.count, 1)
                isFulfilled = satisfiedCourses.count > 0
                subjectFulfillmentProgress = ceilingThreshold((progress, 1))
                unitFulfillmentProgress = ceilingThreshold((satisfiedCourses.first?.totalUnits ?? 0, Threshold.defaultUnitCount))
            }
            fulfillmentProgress = (threshold != nil && threshold?.criterion == .units) ? unitFulfillmentProgress : subjectFulfillmentProgress
            return satisfiedCourses
        }
        
        guard let reqs = requirements else {
            return Set<Course>()
        }
        
        var satisfyingPerCategory: [RequirementsListStatement: Set<Course>] = [:]
        var numRequirementsSatisfied = 0
        var numCoursesSatisfied = 0
        var openRequirements: [RequirementsListStatement] = []
        for req in reqs {
            req.currentUser = currentUser // ensures that children compute manual progresses correctly
            let reqSatisfiedCourses = req.computeRequirementStatus(with: courses)
            // Only continue if the requirement is not ignored
            if let assertion = req.progressAssertion, assertion.ignore {
                continue
            }
            openRequirements.append(req)
            
            if req.isFulfilled, reqSatisfiedCourses.count > 0 {
                numRequirementsSatisfied += 1
            }
            satisfyingPerCategory[req] = reqSatisfiedCourses
            
            // For thresholded ANY statements, children that are ALL statements
            // count as a single satisfied course. ANY children count for
            // all of their satisfied courses.
            if req.connectionType == .all, req.requirement == nil {
                numCoursesSatisfied += (req.isFulfilled && reqSatisfiedCourses.count > 0) ? 1 : 0
            } else {
                numCoursesSatisfied += reqSatisfiedCourses.count
            }
        }
        
        let totalSatisfyingCourses = satisfyingPerCategory.reduce(Set<Course>(), { $0.union($1.value) })
        // Set isFulfilled and fulfillmentProgresses
        var sortedProgresses = openRequirements.sorted(by: { $0.rawPercentageFulfilled > $1.rawPercentageFulfilled })
        if threshold == nil, distinctThreshold == nil {
            // Simple "any" statement
            isFulfilled = (numRequirementsSatisfied > 0)
            if connectionType == .any {
                subjectFulfillmentProgress = sortedProgresses.first?.subjectFulfillmentProgress ?? (0, 0)
                unitFulfillmentProgress = sortedProgresses.first?.unitFulfillmentProgress ?? (0, 0)
            } else {
                subjectFulfillmentProgress = sortedProgresses.reduce((0, 0), { ($0.0 + $1.subjectFulfillmentProgress.0, $0.1 + $1.subjectFulfillmentProgress.1) })
                unitFulfillmentProgress = sortedProgresses.reduce((0, 0), { ($0.0 + $1.unitFulfillmentProgress.0, $0.1 + $1.unitFulfillmentProgress.1) })
            }
        } else {
            if let distinct = distinctThreshold {
                sortedProgresses = [RequirementsListStatement](sortedProgresses[0..<min(distinct.actualCutoff, sortedProgresses.count)])
                // recount the number of courses satisfied
                numCoursesSatisfied = 0
                for req in sortedProgresses {
                    guard let reqSatisfiedCourses = satisfyingPerCategory[req] else {
                        continue
                    }
                    if req.connectionType == .all {
                        numCoursesSatisfied += (req.isFulfilled && reqSatisfiedCourses.count > 0) ? 1 : 0
                    } else {
                        numCoursesSatisfied += reqSatisfiedCourses.count
                    }
                }
            }
            if threshold == nil, let distinct = distinctThreshold {
                // required number of statements
                if distinct.type == .greaterThan || distinct.type == .greaterThanOrEqual {
                    isFulfilled = numRequirementsSatisfied >= distinct.actualCutoff
                } else {
                    isFulfilled = true
                }
                subjectFulfillmentProgress = sortedProgresses.reduce((0, 0), { ($0.0 + $1.subjectFulfillmentProgress.0, $0.1 + max($1.subjectFulfillmentProgress.1, 1)) })
                unitFulfillmentProgress = sortedProgresses.reduce((0, 0), { ($0.0 + $1.unitFulfillmentProgress.0, $0.1 + ($1.unitFulfillmentProgress.1 == 0 ? Threshold.defaultUnitCount : $1.unitFulfillmentProgress.1)) })
                
            } else if let threshold = threshold {
                // required number of subjects or units
                let subjectCutoff = threshold.cutoff / (threshold.criterion == .units ? Threshold.defaultUnitCount : 1)
                let unitCutoff = threshold.cutoff * (threshold.criterion == .subjects ? Threshold.defaultUnitCount : 1)
                
                subjectFulfillmentProgress = (numCoursesSatisfied, subjectCutoff)
                unitFulfillmentProgress = (totalSatisfyingCourses.reduce(0, { $0 + $1.totalUnits }), unitCutoff)
                
                if let distinct = distinctThreshold,
                    distinct.type == .greaterThan || distinct.type == .greaterThanOrEqual {
                    isFulfilled = number(subjectFulfillmentProgress.0, withUnits: unitFulfillmentProgress.0, satisfies: threshold) && numRequirementsSatisfied >= distinct.actualCutoff
                    if numRequirementsSatisfied < distinct.actualCutoff {
                        forceUnfulfillProgresses(with: sortedProgresses, satisfyingPerCategory: satisfyingPerCategory, total: totalSatisfyingCourses)
                    }
                } else {
                    isFulfilled = number(subjectFulfillmentProgress.0, withUnits: unitFulfillmentProgress.0, satisfies: threshold)
                }

            }
        }
        if connectionType == .all {
            // "all" statement
            isFulfilled = isFulfilled && (numRequirementsSatisfied == openRequirements.count)
            if subjectFulfillmentProgress.0 == subjectFulfillmentProgress.1, openRequirements.count > numRequirementsSatisfied {
                subjectFulfillmentProgress = (subjectFulfillmentProgress.0, subjectFulfillmentProgress.1 + (openRequirements.count - numRequirementsSatisfied))
                unitFulfillmentProgress = (unitFulfillmentProgress.0, unitFulfillmentProgress.1 + (openRequirements.count - numRequirementsSatisfied) * Threshold.defaultUnitCount)
            }
        }
        subjectFulfillmentProgress = ceilingThreshold(subjectFulfillmentProgress)
        unitFulfillmentProgress = ceilingThreshold(unitFulfillmentProgress)
        fulfillmentProgress = (threshold != nil && threshold?.criterion == .units) ? unitFulfillmentProgress : subjectFulfillmentProgress
        return totalSatisfyingCourses
    }
    
    /**
     Makes sure that a requirement with a distinct threshold that has not been
     met, but a threshold that *has* been met, is not counted as satisfied.
     
     - Parameter sortedProgresses: the child requirements sorted by their
                fulfillment progress, and clipped to the distinct threshold
     - Parameter satisfyingPerCategory: courses satisfying each child requirement
     - Parameter total: the precomputed set union of satisfyingPerCategory
     */
    func forceUnfulfillProgresses(with sortedProgresses: [RequirementsListStatement], satisfyingPerCategory: [RequirementsListStatement: Set<Course>], total: Set<Course>) {
        guard let threshold = threshold else {
            return
        }
        
        let subjectCutoff = threshold.cutoff / (threshold.criterion == .units ? Threshold.defaultUnitCount : 1)
        let unitCutoff = threshold.cutoff * (threshold.criterion == .subjects ? Threshold.defaultUnitCount : 1)
        
        // Strategy: partition the threshold's worth of subjects/units into two
        // sections: fixed and free. Fixed means we need at least one subject
        // from each child requirement, and free means we can choose any maximally
        // satisfying courses. To fill the fixed portion, we choose the maximum-
        // unit course from each child requirement. To fill the free portion, we
        // choose the maximum-unit courses from any child requirement.
        //   > Example: threshold = 7, distinct = 2, among 3 child requirements
        //   The input to this function would contain the 2 most-fulfilled child
        //   requirements. We would fill 2 subjects worth of progress with the
        //   maximum-unit course for each of those requirements, then fill the
        //   remaining 5 with "free" courses from any requirement.
        
        let maxUnitSubjects = sortedProgresses.map { ($0, satisfyingPerCategory[$0]?.max(by: { $0.totalUnits < $1.totalUnits })) }
        let fixedSubjectProgress = maxUnitSubjects.reduce((0, 0), { ($0.0 + ($1.1 != nil ? 1 : 0), $0.1 + 1)})
        let fixedUnitProgress = maxUnitSubjects.reduce((0, 0), { ($0.0 + ($1.1?.totalUnits ?? 0), $0.1 + ($1.1?.totalUnits ?? Threshold.defaultUnitCount)) })
        let freeCourses = total.subtracting(maxUnitSubjects.compactMap({ $1 }))
        let freeSubjectProgress = (min(freeCourses.count, subjectCutoff - fixedSubjectProgress.1), subjectCutoff - fixedSubjectProgress.1)
        let freeUnitProgress = (min(freeCourses.reduce(0, { $0 + $1.totalUnits }), unitCutoff - fixedUnitProgress.1), unitCutoff - fixedUnitProgress.1)
        
        subjectFulfillmentProgress = (fixedSubjectProgress.0 + freeSubjectProgress.0, fixedSubjectProgress.1 + freeSubjectProgress.1)
        unitFulfillmentProgress = (fixedUnitProgress.0 + freeUnitProgress.0, fixedUnitProgress.1 + freeUnitProgress.1)
    }
    
    var rawPercentageFulfilled: Float {
        if connectionType == .none, progressAssertion == nil {
            return 0.0
        }
        let fulfilled = fulfillmentProgress
        return Float(fulfilled.0) / Float(max(fulfilled.1, threshold?.criterion == .units ? Threshold.defaultUnitCount : 1)) * 100.0
    }
    
    var percentageFulfilled: Float {
        if connectionType == .none, progressAssertion == nil {
            return 0.0
        }
        let fulfilled = fulfillmentProgress
        if fulfilled.1 == 0 {
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
    
    var progressAssertion: ProgressAssertion? {
        guard let user = currentUser, let path = keyPath,
            let assertion = user.progressAssertion(for: path) else {
                return nil
        }
        if (assertion.substitutions == nil || assertion.substitutions?.count == 0), !assertion.ignore {
            return nil
        }
        return assertion
    }
    
    /// Indicates whether any of the descendants of this requirement have an active progress assertion
    var descendantHasProgressAssertion: Bool {
        guard let requirements = requirements else {
            return false
        }
        return requirements.contains(where: { $0.progressAssertion != nil || $0.descendantHasProgressAssertion })
    }
}

class RequirementsList: RequirementsListStatement {

    var shortTitle: String?
    var mediumTitle: String?
    var titleNoDegree: String?
    var listID: String
    var fileURL: URL?
    var webURL: URL?
    
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
        var lines = string.components(separatedBy: "\n").compactMap { (line) -> String? in
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
                        threshold = Threshold(.greaterThanOrEqual, number: thresholdValue, of: .subjects)
                    } else {
                        print("\(listID): Invalid threshold parameter declaration: \(noWhitespaceComp)")
                    }
                } else if let urlRange = noWhitespaceComp.range(of: SyntaxConstants.urlParameter) {
                    let url = String(noWhitespaceComp[urlRange.upperBound..<noWhitespaceComp.endIndex])
                    webURL = URL(string: url)
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
            if varName.contains(":=") || description.contains(":=") {
                print("\(listID): Encountered ':=' symbol in top-level section. Maybe you forgot the required empty line after the last section's description line?")
            }
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
