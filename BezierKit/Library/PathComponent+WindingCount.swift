//
//  PathComponent+WindingCount.swift
//  BezierKit
//
//  Created by Holmes Futrell on 6/11/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

import CoreGraphics

private func xIntercept<A: BezierCurve>(curve: A, y: CGFloat) -> CGFloat {
    let startingPoint = curve.startingPoint
    let endingPoint   = curve.endingPoint
    guard y != curve.startingPoint.y else { return curve.startingPoint.x }
    guard y != curve.endingPoint.y else { return curve.endingPoint.x }
    let linearSolutionT = ( y - startingPoint.y ) / ( endingPoint.y - startingPoint.y )
    let linearSolution = LineSegment(p0: startingPoint, p1: endingPoint).compute(linearSolutionT).x
    if curve.order > 1 {
        let line = LineSegment(p0: CGPoint(x: 0, y: y), p1: CGPoint(x: 1, y: y))
        guard let t = Utils.roots(points: curve.points, line: line).first(where: { $0 >= 0.0 && $0 <= 1.0 }) else {
            return linearSolution
        }
        return curve.compute(CGFloat(t)).x
    } else {
        return linearSolution
    }
}

private func windingCountAdjustment(_ y: CGFloat, _ startY: CGFloat, _ endY: CGFloat) -> Int {
    if endY < y, y <= startY {
        return 1
    } else if startY < y, y <= endY {
        return -1
    } else {
        return 0
    }
}

private func windingCountIncrementer<A: BezierCurve>(_ curve: A, point: CGPoint) -> Int {
    if curve.boundingBox.min.x > point.x { return 0 }
    // we include the highest point and exclude the lowest point
    // that ensures if the juncture between curves changes direction it's counted twice or not at all
    // and if the juncture between curves does not change direction it's counted exactly once
    let increment = windingCountAdjustment(point.y, curve.startingPoint.y, curve.endingPoint.y)
    guard increment != 0 else { return 0 }
    if curve.boundingBox.max.x >= point.x {
        // slowest path: must determine x intercept and test against it
        let x = xIntercept(curve: curve, y: point.y)
        guard point.x > x else { return 0  }
    }
    return increment
}

internal extension PathComponent {

    private func enumerateYMonotonicComponentsForQuadratic(at index: Int, callback: (_ curve: QuadraticCurve) -> Void) {
        let curve = self.quadratic(at: index)
        let p0 = curve.p0
        let p1 = curve.p1
        let p2 = curve.p2
        let d0 = p1.y - p0.y
        let d1 = p2.y - p1.y
        var last: CGFloat = 0.0
        Utils.droots(d0, d1) { t in
            guard t > 0, t < 1 else { return }
            callback(curve.split(from: last, to: t))
            last = t
        }
        if last < 1.0 {
            callback(curve.split(from: last, to: 1.0))
        }
    }

    private func enumerateYMonotonicComponentsForCubic(at index: Int, callback: (_ curve: CubicCurve) -> Void) {
        let curve = self.cubic(at: index)
        let p0 = curve.p0
        let p1 = curve.p1
        let p2 = curve.p2
        let p3 = curve.p3
        let d0 = p1.y - p0.y
        let d1 = p2.y - p1.y
        let d2 = p3.y - p2.y
        var last: CGFloat = 0.0
        Utils.droots(d0, d1, d2) { t in
            guard t > 0, t < 1 else { return }
            callback(curve.split(from: last, to: t))
            last = t
        }
        if last < 1.0 {
            callback(curve.split(from: last, to: 1.0))
        }
    }

    func windingCount(at point: CGPoint) -> Int {
        guard self.isClosed, self.boundingBox.contains(point) else {
            return 0
        }
        var windingCount: Int = 0
        self.bvh.visit { node, _ in
            let boundingBox = node.boundingBox
            guard boundingBox.min.y <= point.y, boundingBox.max.y >= point.y, boundingBox.min.x <= point.x else {
                // ray cast from point in -x direction does not intersect node's bounding box, nothing to do
                return false
            }
            guard boundingBox.max.x >= point.x else {
                // ray cast from point in -x direction intersects the node's bounding box
                // but we are outside bounding box in +x direction
                // as an optimization we can avoid visiting any of node's children
                // beause we need only adjust the winding count if y coordinate falls between start and end y
                let startingElementIndex: Int
                let endingElementIndex: Int
                switch node.type {
                case .leaf(let index):
                    startingElementIndex = index
                    endingElementIndex = index
                case .internal(let start, let end):
                    startingElementIndex = start
                    endingElementIndex = end
                }
                let startingPoint    = self.startingPointForElement(at: startingElementIndex)
                let endingPoint      = self.endingPointForElement(at: endingElementIndex)
                windingCount         += windingCountAdjustment(point.y, startingPoint.y, endingPoint.y)
                return false
            }
            guard case let .leaf(elementIndex) = node.type else {
                // internal node where point falls within bounding box: recursively visit child nodes
                return true
            }
            // now we are assured that node is a leaf node and point falls within the node's bounding box
            let order = self.orders[elementIndex]
            switch order {
            case 0:
                windingCount += 0
            case 1:
                windingCount += windingCountIncrementer(line(at: elementIndex), point: point)
            case 2:
                self.enumerateYMonotonicComponentsForQuadratic(at: elementIndex) {
                    windingCount += windingCountIncrementer($0, point: point)
                }
            case 3:
                self.enumerateYMonotonicComponentsForCubic(at: elementIndex) {
                    windingCount += windingCountIncrementer($0, point: point)
                }
            default:
                fatalError("unsupported")
            }
            return true
        }
        return windingCount
    }
}
