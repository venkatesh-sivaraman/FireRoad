//
//  CourseDocument.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/26/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import UIKit

class UserDocument: NSObject {
    var filePath: String? {
        didSet {
            if filePath != oldValue {
                needsSave = true
            }
            if saveTimer?.isValid == true {
                saveTimer?.invalidate()
            }
            if !readOnly {
                saveTimer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: true, block: { _ in
                    self.autosave()
                })
            }
        }
    }
    
    var fileName: String? {
        guard let filePath = filePath else {
            return nil
        }
        return URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
    }
    
    var needsSave = false
    var shouldCloudSync = true
    var readOnly = false
    private var saveInterval = 2.0
    private var saveTimer: Timer?
    
    var isEmpty: Bool {
        return true
    }
    
    init(contentsOfFile path: String, readOnly: Bool = false) throws {
        super.init()
        self.readOnly = readOnly
        try readUserCourses(from: path)
    }

    deinit {
        if saveTimer?.isValid == true {
            saveTimer?.invalidate()
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    override init() {
        super.init()
    }

    // MARK: - File Handling
    
    func setNeedsSave() {
        needsSave = true
    }
    
    func reloadContents() throws {
        if let path = filePath {
            try readUserCourses(from: path)
        }
    }
    
    func readUserCourses(from file: String) throws {
        self.filePath = file
    }
    
    private var currentlyWriting = false
    
    func readCourses(fromJSON json: Any) throws {
        
    }
    
    func writeCoursesToJSON() throws -> Any {
        let ret: [String: Any] = [:]
        return ret
    }
    
    func writeUserCourses(to file: String) throws {

    }
    
    func autosave(cloudSync: Bool = true, sync: Bool = false) {
        guard needsSave, let path = filePath else {
            return
        }
        self.shouldCloudSync = cloudSync
        
        if sync {
            guard !self.currentlyWriting else {
                return
            }
            self.currentlyWriting = true
            do {
                try self.writeUserCourses(to: path)
            } catch {
                print("Error writing file: \(error)")
            }
            self.currentlyWriting = false
            self.needsSave = false
            self.shouldCloudSync = true
        } else {
            DispatchQueue.global().async { [weak self] in
                guard let `self` = self,
                    !self.currentlyWriting else {
                        return
                }
                self.currentlyWriting = true
                do {
                    try self.writeUserCourses(to: path)
                } catch {
                    print("Error writing file: \(error)")
                }
                self.currentlyWriting = false
                self.needsSave = false
                self.shouldCloudSync = true
            }
        }
    }
    
    // MARK: - Thumbnail Generation
    
    var coursesForThumbnail: [Course] {
        return []
    }
    
    private static let thumbnailDimension: CGFloat = 30.0
    
    private func colorProportionsForThumbnail() -> [(UIColor, CGFloat)] {
        var departmentProportions: [String: CGFloat] = [:]
        for course in coursesForThumbnail {
            guard let code = course.subjectCode else {
                continue
            }
            if departmentProportions[code] != nil {
                departmentProportions[code]? += 1.0
            } else {
                departmentProportions[code] = 1.0
            }
        }
        if departmentProportions.count > 4 {
            let newProportions = departmentProportions.filter({ $0.value > 1.0 })
            if newProportions.count > 2 {
                departmentProportions = newProportions
            }
        }
        let total = departmentProportions.values.reduce(CGFloat(0.0), +)
        let props = departmentProportions.sorted(by: { $0.key.lexicographicallyPrecedes($1.key) }).map({ (CourseManager.shared.color(forDepartment: $0.key), $0.value / total) })
        if props.count > 0 {
            return props
        } else {
            return [(UIColor.gray, 1.0)]
        }
    }
    
    func thumbnailCropPath(with bounds: CGRect) -> UIBezierPath {
        return UIBezierPath(roundedRect: bounds, cornerRadius: bounds.size.width * 0.2)
    }
    
    private func cropThumbnailImage(_ image: UIImage) -> UIImage? {
        let size = CGSize(width: UserDocument.thumbnailDimension, height: UserDocument.thumbnailDimension)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        let bounds = CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height)
        defer { UIGraphicsEndImageContext() }
        thumbnailCropPath(with: bounds).addClip()
        image.draw(in: bounds.insetBy(dx: (size.width - image.size.width) / 2.0, dy: (size.height - image.size.height / 2.0)))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func emptyThumbnailImage() -> UIImage? {
        let size = CGSize(width: UserDocument.thumbnailDimension, height: UserDocument.thumbnailDimension)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        let bounds = CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height)
        defer { UIGraphicsEndImageContext() }
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func generateThumbnailImage() -> UIImage? {
        let startImageSize = CGSize(width: UserDocument.thumbnailDimension * 2.0, height: UserDocument.thumbnailDimension * 2.0)
        UIGraphicsBeginImageContextWithOptions(startImageSize, false, 0.0)
        // Draw radial pie slices
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        let radius = startImageSize.width
        let center = CGPoint(x: startImageSize.width / 2.0, y: startImageSize.width / 2.0)
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat.pi / 4.0)
        context.translateBy(x: -center.x, y: -center.y)
        let proportions = colorProportionsForThumbnail()
        var currentAngle: CGFloat = 0.0
        for (color, prop) in proportions {
            context.setFillColor(color.cgColor)
            let newAngle = currentAngle + prop * 2.0 * CGFloat.pi
            if prop < 0.999 {
                context.move(to: center)
                context.addArc(center: center, radius: radius, startAngle: currentAngle, endAngle: newAngle, clockwise: false)
                context.addLine(to: center)
                context.fillPath()
            } else {
                context.fill(CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2.0, height: radius * 2.0))
            }
            currentAngle = newAngle
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard image != nil else {
            return nil
        }
        
        // Blur the gradient
        let imageToBlur = CIImage(image: image!)
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else {
            print("No blur filter")
            return nil
        }
        blurFilter.setValue(imageToBlur, forKey: "inputImage")
        blurFilter.setValue(5.0, forKey: "inputRadius")
        guard let resultImage = blurFilter.value(forKey: "outputImage") as? CIImage else {
            return nil
        }
        let blurredImage = UIImage(ciImage: resultImage)
        
        // Crop to rounded rectangle
        return cropThumbnailImage(blurredImage)
    }
}
