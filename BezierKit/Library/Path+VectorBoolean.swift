//
//  Path+VectorBoolean.swift
//  BezierKit
//
//  Created by Holmes Futrell on 2/8/21.
//  Copyright © 2021 Holmes Futrell. All rights reserved.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

public extension Path {
     
    #if !os(WASI)
    @objc(subtractPath:accuracy:) func _subtract(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        return subtract(other, accuracy: accuracy)
    }
    #endif

    func subtract(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        return self.performBooleanOperation(.subtract, with: other.reversed(), accuracy: accuracy)
    }
    
    #if !os(WASI)
    @objc(unionPath:accuracy:) func `_union`(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        return union(other, accuracy: accuracy)
    }
    #endif

    func `union`(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        guard self.isEmpty == false else {
            return other
        }
        guard other.isEmpty == false else {
            return self
        }
        return self.performBooleanOperation(.union, with: other, accuracy: accuracy)
    }

    #if !os(WASI)
    @objc(intersectPath:accuracy:) func _intersect(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        return intersect(other, accuracy: accuracy)        
    }    
    #endif

    func intersect(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        return self.performBooleanOperation(.intersect, with: other, accuracy: accuracy)
    }
    
    #if !os(WASI)
    @objc(crossingsRemovedWithAccuracy:) func _crossingsRemoved(accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        return crossingsRemoved(accuracy: accuracy)
    }
    #endif
    
    func crossingsRemoved(accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        let intersections = self.selfIntersections(accuracy: accuracy)
        let augmentedGraph = AugmentedGraph(path1: self, path2: self, intersections: intersections, operation: .removeCrossings)
        return augmentedGraph.performOperation()
    }
}

private extension Path {
    func performBooleanOperation(_ operation: BooleanPathOperation, with other: Path, accuracy: CGFloat) -> Path {
        let intersections = self.intersections(with: other, accuracy: accuracy)
        let augmentedGraph = AugmentedGraph(path1: self, path2: other, intersections: intersections, operation: operation)
        return augmentedGraph.performOperation()
    }
}
