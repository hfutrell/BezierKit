//
//  BezierKit-ObjC.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/11/22.
//  Copyright © 2022 Holmes Futrell. All rights reserved.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif

import Foundation

#if !os(WASI) && !os(Linux)

@available (*, unavailable)
@objc(BezierKitPath) public extension Path {

    @objc(isEmpty) var _objc_isEmpty: Bool {
        return isEmpty
    }

    @objc(components) var _objc_components: [PathComponent] {
        return components
    }

    @objc(selfIntersectsWithAccuracy:) func _objc_selfIntersects(accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
        return selfIntersects(accuracy: accuracy)
    }

    @objc(intersectsPath:accuracy:) func _objc_intersects(_ other: Path, accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
        return intersects(other, accuracy: accuracy)
    }

    @objc(initWithComponents:) convenience init(_objc_components components: [PathComponent]) {
        self.init(components: components)
    }

    #if canImport(CoreGraphics)
    @objc(initWithCGPath:) convenience init(_objc_cgPath cgPath: CGPath) {
        self.init(cgPath: cgPath)
    }
    #endif

    @objc(containsPoint:usingRule:) func _objc_contains(_ point: CGPoint, using rule: PathFillRule = .winding) -> Bool {
        return contains(point, using: rule)
    }

    @objc(containsPath:usingRule:accuracy:) func _objc_contains(_ other: Path, using rule: PathFillRule = .winding, accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
        return contains(other, using: rule, accuracy: accuracy)
    }

    @objc(offsetWithDistance:) func _objc_offset(distance d: CGFloat) -> Path {
        return offset(distance: d)
    }

    @objc(disjointComponents) func _objc_disjointComponents() -> [Path] {
        return disjointComponents()
    }

    @objc(CGPath) var _objc_cgPath: CGPath {
        return cgPath
    }
}

#endif
