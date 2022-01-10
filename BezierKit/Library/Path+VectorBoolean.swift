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
     
    #if os(WASI)
        func subtract(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
            return _subtract(other, accuracy: accuracy)
        }
    #else
        @objc(subtractPath:accuracy:) func subtract(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
            return _subtract(other, accuracy: accuracy)
        }
    #endif

    fileprivate func _subtract(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        return self.performBooleanOperation(.subtract, with: other.reversed(), accuracy: accuracy)
    }
    
    #if os(WASI)
        func `union`(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
            return _union(other, accuracy: accuracy)
        }
    #else
        @objc(unionPath:accuracy:) func `union`(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
            return _union(other, accuracy: accuracy)
        }
    #endif

    fileprivate func `_union`(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        guard self.isEmpty == false else {
            return other
        }
        guard other.isEmpty == false else {
            return self
        }
        return self.performBooleanOperation(.union, with: other, accuracy: accuracy)
    }

    #if os(WASI)
        func intersect(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
            return _intersect(other, accuracy: accuracy)        
        }
    #else
        @objc(intersectPath:accuracy:) func intersect(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
            return _intersect(other, accuracy: accuracy)        
        }
    #endif

    fileprivate func _intersect(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        return self.performBooleanOperation(.intersect, with: other, accuracy: accuracy)
    }
    
    #if os(WASI)
        func crossingsRemoved(accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
            return _crossingsRemoved(accuracy: accuracy)
        }
    #else
        @objc(crossingsRemovedWithAccuracy:) func crossingsRemoved(accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
            return _crossingsRemoved(accuracy: accuracy)
        }
    #endif
    
    fileprivate func _crossingsRemoved(accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
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
