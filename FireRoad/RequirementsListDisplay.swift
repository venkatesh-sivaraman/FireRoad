//
//  RequirementsListDisplayHelper.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 12/14/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import Foundation

protocol RequirementsListDisplay: CourseListCellDelegate, CourseBrowserDelegate, CourseThumbnailCellDelegate {
    
    var allowsProgressAssertions: Bool { get }
    
    func fillCourseListCell(_ courseListCell: CourseListTableCell, with statement: RequirementsListStatement)
    
    func handleCourseListCellSelection(_ courseListCell: CourseListTableCell, of course: Course, with requirement: RequirementsListStatement?)
    
    // Transitioning view controllers
    func selectIndexPath(for tableCell: CourseListTableCell, at courseIndex: Int)
    func showInformationalViewController(_ vc: UIViewController, from cell: UICollectionViewCell)
    func viewDetails(for course: Course, from cell: UICollectionViewCell, showGenericDetails: Bool)
    func pushViewController(_ viewController: UIViewController, animated: Bool)
    
    // Getting view controllers
    func childRequirementsViewController() -> RequirementsListViewController?
    func courseBrowserViewController() -> CourseBrowserViewController?
}

extension RequirementsListDisplay {
    func fillCourseListCell(_ courseListCell: CourseListTableCell, with statement: RequirementsListStatement) {
        let requirementStrings = (statement.requirements?.map({ $0.shortDescription })) ?? [statement.shortDescription]
        courseListCell.courses = requirementStrings.map {
            if let course = CourseManager.shared.getCourse(withID: $0) {
                return course
            } else if let gir = GIRAttribute(rawValue: $0) {
                return Course(courseID: "GIR", courseTitle: gir.descriptionText().replacingOccurrences(of: "GIR", with: "").trimmingCharacters(in: .whitespaces), courseDescription: "")
            }
            if let whitespaceRange = $0.rangeOfCharacter(from: .whitespaces),
                Int(String($0[$0.startIndex..<whitespaceRange.lowerBound])) != nil ||
                    String($0[$0.startIndex..<whitespaceRange.lowerBound]).contains(".") {
                return Course(courseID: String($0[$0.startIndex..<whitespaceRange.lowerBound]), courseTitle: String($0[whitespaceRange.upperBound..<$0.endIndex]), courseDescription: "")
            } else if $0.count > 8 {
                return Course(courseID: "", courseTitle: $0, courseDescription: "")
            }
            return Course(courseID: $0, courseTitle: "", courseDescription: "")
        }
        if let reqs = statement.requirements {
            courseListCell.fulfillmentIndications = reqs.map {
                ($0.fulfillmentProgress.0, $0.fulfillmentProgress.1, $0.threshold?.criterion == .units)
            }
        } else {
            courseListCell.fulfillmentIndications = [(statement.fulfillmentProgress.0, statement.fulfillmentProgress.1, statement.threshold?.criterion == .units)]
        }
        
        courseListCell.delegate = self
        if allowsProgressAssertions {
            let requirements = statement.requirements ?? [statement]
            courseListCell.thumbnailCellCustomizer = { (cell, position) in
                var showMenu = false
                var isPlainString = false
                if let id = cell.course?.subjectID,
                    let actualCourse = CourseManager.shared.getCourse(withID: id),
                    actualCourse == cell.course {
                    showMenu = true
                } else if requirements[min(requirements.count, position)].isPlainString {
                    showMenu = true
                    isPlainString = true
                }
                if showMenu {
                    cell.showsProgressAssertionItems = true
                    cell.requirement = requirements[min(requirements.count, position)]
                    if cell.progressAssertionActive {
                        if let assertion = cell.requirement?.progressAssertion {
                            if let subs = assertion.substitutions, subs.count > 0 {
                                cell.textLabel?.text = "Substituted"
                                if subs.count == 1 {
                                    cell.detailTextLabel?.text = "with \(subs[0])"
                                } else if subs.count == 2 {
                                    cell.detailTextLabel?.text = "with \(subs[0]) and \(subs[1])"
                                } else {
                                    cell.detailTextLabel?.text = "with \(subs[0]) and \(subs.count - 1) others"
                                }
                            } else if assertion.ignore {
                                cell.textLabel?.text = "Ignored"
                                cell.detailTextLabel?.text = cell.requirement?.shortDescription
                            }
                        }
                    }
                    cell.showsAddMenuItem = !isPlainString
                    cell.showsViewMenuItem = !isPlainString
                    cell.showsDeleteMenuItem = false
                    cell.showsRateMenuItem = false
                    cell.delegate = self
                } else {
                    cell.requirement = nil
                }
            }
        }
    }
    
    func handleCourseListCellSelection(_ tableCell: CourseListTableCell, of course: Course, with requirement: RequirementsListStatement?) {
        guard let courseIndex = tableCell.courses.index(of: course),
            let selectedCell = tableCell.collectionView.cellForItem(at: IndexPath(item: courseIndex, section: 0)) else {
                return
        }
        if let id = course.subjectID,
            let actualCourse = CourseManager.shared.getCourse(withID: id),
            actualCourse == course {
            if allowsProgressAssertions {
                // Show menu
            } else {
                viewDetails(for: course, from: selectedCell, showGenericDetails: false)
            }
        } else if let item = requirement {
            let requirements = item.requirements ?? [item]
            
            if requirements[min(requirements.count, courseIndex)].isPlainString {
                // Show context menu
            } else if let reqString = requirements[courseIndex].requirement?.replacingOccurrences(of: "GIR:", with: "") {
                // Configure a browser VC with the appropriate search term and filters to find this
                // requirement (e.g. "GIR:PHY1" or "HASS-A" or "CI-H")
                guard let listVC = courseBrowserViewController() else {
                    return
                }
                listVC.searchTerm = reqString
                if let ciAttribute = CommunicationAttribute(rawValue: reqString) {
                    listVC.searchOptions = SearchOptions.noFilter.filterSearchFields(.searchRequirements).filterCI(ciAttribute == .ciH ? .fulfillsCIH : .fulfillsCIHW)
                } else if let hass = HASSAttribute(rawValue: reqString) {
                    var baseOption: SearchOptions
                    switch hass {
                    case .any, .elective: baseOption = .fulfillsHASS
                    case .arts: baseOption = .fulfillsHASSA
                    case .socialSciences: baseOption = .fulfillsHASSS
                    case .humanities: baseOption = .fulfillsHASSH
                    }
                    listVC.searchOptions = SearchOptions.noFilter.filterSearchFields(.searchRequirements).filterHASS(baseOption)
                } else if GIRAttribute(rawValue: reqString) != nil {
                    listVC.searchOptions = SearchOptions.noFilter.filterSearchFields(.searchRequirements).filterGIR(.fulfillsGIR)
                } else {
                    listVC.searchOptions = SearchOptions.noFilter.filterSearchFields(.searchRequirements)
                }
                listVC.delegate = self
                listVC.showsHeaderBar = false
                listVC.managesNavigation = false
                showInformationalViewController(listVC, from: selectedCell)
            } else {
                guard let listVC = childRequirementsViewController() else {
                    return
                }
                selectIndexPath(for: tableCell, at: courseIndex)
                listVC.requirementsList = requirements[courseIndex]
                pushViewController(listVC, animated: true)
            }
        }

    }
}
