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

// MARK: Path.swift
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

// MARK: Path+VectorBoolean.swift
@available (*, unavailable)
public extension Path {
    @objc(subtractPath:accuracy:) func _objc_subtract(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        return subtract(other, accuracy: accuracy)
    }
    @objc(unionPath:accuracy:) func `_objc_union`(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        return union(other, accuracy: accuracy)
    }
    @objc(intersectPath:accuracy:) func _objc_intersect(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        return intersect(other, accuracy: accuracy)
    }
    @objc(crossingsRemovedWithAccuracy:) func _objc_crossingsRemoved(accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        return crossingsRemoved(accuracy: accuracy)
    }
}

// MARK: Path+Data.swift
@available (*, unavailable)
public extension Path {
    @objc(initWithData:) convenience init?(_objc_data data: Data) {
        self.init(data: data)
    }
}

// MARK: Path+Projection.swift
@available (*, unavailable)
public extension Path {
    @objc(point:isWithinDistanceOfBoundary:) func _objc_pointIsWithinDistanceOfBoundary(_ point: CGPoint, distance: CGFloat) -> Bool {
        return pointIsWithinDistanceOfBoundary(point, distance: distance)
    }
}

@available(*, unavailable)
public extension PathComponent {
    @objc(point:isWithinDistanceOfBoundary:) func _objc_pointIsWithinDistanceOfBoundary(_ point: CGPoint, distance: CGFloat) -> Bool {
        return pointIsWithinDistanceOfBoundary(point, distance: distance)
    }
}

// MARK: PathComponent.swift
@available(*, unavailable)
@objc(BezierKitPathComponent) public extension PathComponent {
    @objc(startingPoint) var _objc_startingPoint: CGPoint {
        return startingPoint
    }
    @objc(endingPoint) var _objc_endingPoint: CGPoint {
        return endingPoint
    }
    @objc(enumeratePointsIncludingControlPoints:usingBlock:) func _objc_enumeratePoints(includeControlPoints: Bool, using block: (CGPoint) -> Void) {
        return enumeratePoints(includeControlPoints: includeControlPoints, using: block)
    }
}

#endif
