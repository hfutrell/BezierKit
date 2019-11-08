//
//  BezierCurve+Intersection.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/18/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

import Foundation
import CoreGraphics

// MARK: - helpers using generics

public extension BezierCurve {
    func intersects(_ curve: BezierCurve) -> Bool {
        return self.intersects(curve, accuracy: BezierKit.defaultIntersectionAccuracy)
    }
    func intersections(with curve: BezierCurve) -> [Intersection] {
        return self.intersections(with: curve, accuracy: BezierKit.defaultIntersectionAccuracy)
    }
    func selfIntersections() -> [Intersection] {
        return self.selfIntersections(accuracy: BezierKit.defaultIntersectionAccuracy)
    }
    func selfIntersects() -> Bool {
        return self.selfIntersects(accuracy: BezierKit.defaultIntersectionAccuracy)
    }
    func selfIntersects(accuracy: CGFloat) -> Bool {
        return !self.selfIntersections(accuracy: BezierKit.defaultIntersectionAccuracy).isEmpty
    }
    func intersects(_ line: LineSegment) -> Bool {
        return !self.intersections(with: line).isEmpty
    }
    func intersects(_ curve: BezierCurve, accuracy: CGFloat) -> Bool {
        return !self.intersections(with: curve, accuracy: BezierKit.defaultIntersectionAccuracy).isEmpty
    }
}

internal func helperIntersectsCurveCurve<U, T>(_ curve1: Subcurve<U>, _ curve2: Subcurve<T>, accuracy: CGFloat) -> [Intersection] where U: NonlinearBezierCurve, T: NonlinearBezierCurve {
    let lb = curve1.curve.boundingBox
    let rb = curve2.curve.boundingBox
    var intersections: [Intersection] = []
    Utils.pairiteration(curve1, curve2, lb, rb, &intersections, accuracy)
    return intersections.sortedAndUniqued()
}

internal func helperIntersectsCurveLine<U>(_ curve: U, _ line: LineSegment, reversed: Bool = false) -> [Intersection] where U: NonlinearBezierCurve {
    guard line.boundingBox.overlaps(curve.boundingBox) else {
        return []
    }
    let lineDirection = (line.p1 - line.p0)
    let lineLength = lineDirection.lengthSquared
    guard lineLength > 0 else { return [] }
    func align(_ point: CGPoint) -> CGFloat {
        return (point - line.p0).dot(lineDirection.perpendicular)
    }
    var intersections: [Intersection] = []
    func callback(_ t: CGFloat) {
        var t1 = CGFloat(t)
        let smallValue: CGFloat = 1.0e-8
        assert(smallValue < CGFloat(Utils.epsilon))
        guard t1 >= -smallValue, t1 <= 1.0+smallValue else {
            return
        }
        let p = curve.compute(t1) - line.p0
        var t2 = p.dot(lineDirection) / lineLength
        guard t2 >= -smallValue, t2 <= 1.0+smallValue else {
            return
        }
        if Utils.approximately(Double(t1), 0.0, precision: Utils.epsilon) {
            t1 = 0.0
        } else if Utils.approximately(Double(t1), 1.0, precision: Utils.epsilon) {
            t1 = 1.0
        }
        if Utils.approximately(Double(t2), 0.0, precision: Utils.epsilon) {
            t2 = 0.0
        } else if Utils.approximately(Double(t2), 1.0, precision: Utils.epsilon) {
            t2 = 1.0
        }
        intersections.append(reversed ? Intersection(t1: t2, t2: t1) : Intersection(t1: t1, t2: t2))
    }
    switch curve {
    case let q as QuadraticCurve:
        Utils.droots(align(q.p0), align(q.p1), align(q.p2), callback: callback)
    case let c as CubicCurve:
        Utils.droots(align(c.p0), align(c.p1), align(c.p2), align(c.p3), callback: callback)
    default:
        assertionFailure("unexpected curve type.")
    }
    return intersections.sortedAndUniqued()
}

// MARK: - extensions to support intersection

extension NonlinearBezierCurve {
    public func intersections(with line: LineSegment) -> [Intersection] {
        return helperIntersectsCurveLine(self, line)
    }
    public func intersections(with curve: BezierCurve, accuracy: CGFloat) -> [Intersection] {
        switch curve.order {
        case 3:
            return helperIntersectsCurveCurve(Subcurve(curve: self), Subcurve(curve: curve as! CubicCurve), accuracy: accuracy)
        case 2:
            return helperIntersectsCurveCurve(Subcurve(curve: self), Subcurve(curve: curve as! QuadraticCurve), accuracy: accuracy)
        case 1:
            return helperIntersectsCurveLine(self, curve as! LineSegment)
        default:
            fatalError("unsupported")
        }
    }
    public func selfIntersections(accuracy: CGFloat) -> [Intersection] {
        let reduced = self.reduce()
        // "simple" curves cannot intersect with their direct
        // neighbour, so for each segment X we check whether
        // it intersects [0:x-2][x+2:last].
        let len=reduced.count-2
        var results: [Intersection] = []
        if len > 0 {
            for i in 0..<len {
                let left = reduced[i]
                for j in i+2..<reduced.count {
                    results += helperIntersectsCurveCurve(left, reduced[j], accuracy: accuracy)
                }
            }
        }
        return results
    }
}

public extension QuadraticCurve {
    func selfIntersections(accuracy: CGFloat) -> [Intersection] {
        return []
    }
}

public extension LineSegment {
    /// check if two line segments are coincident, and if so return intersections representing the range over which they are coincident, otherwise nil
    /// - Parameter line1: the first line to check for coincidence
    /// - Parameter line2: the second line to check for coincidence
    private static func coincidenceCheck(_ line1: LineSegment, _ line2: LineSegment) -> [Intersection]? {
        func approximateNearEndpointsAndClamp(_ value: CGFloat) -> CGFloat {
            if Utils.approximately(Double(value), 0, precision: Utils.epsilon) {
                return 0
            } else if Utils.approximately(Double(value), 1, precision: Utils.epsilon) {
                return 1
            } else {
                return Utils.clamp(value, 0, 1)
            }
        }
        let delta1 = line1.p1 - line1.p0
        let delta2 = line2.p1 - line2.p0
        let rlb2 = 1.0 / delta2.lengthSquared
        let b = rlb2 * (line1.p0 - line2.p0).dot(delta2)
        let m = rlb2 * delta1.dot(delta2)
        let t21 = approximateNearEndpointsAndClamp(b)
        let t22 = approximateNearEndpointsAndClamp(m + b)
        guard t21 != t22 else { return nil }
        // t2(t1) = m * t1 + b
        // so t1(t2) = (t2 - b) / m
        let t11 = approximateNearEndpointsAndClamp(( t21 - b ) / m)
        let t12 = approximateNearEndpointsAndClamp(( t22 - b ) / m)
        let tinyValue: CGFloat = 1.0e-10
        guard t11 != t12 else { return nil }
        guard distance(line1.compute(t11), line2.compute(t21)) < tinyValue else { return nil }
        guard distance(line1.compute(t12), line2.compute(t22)) < tinyValue else { return nil }
        let i1 = Intersection(t1: t11, t2: t21)
        let i2 = Intersection(t1: t12, t2: t22)
        // compare the t-values to ensure intersections are properly sorted
        return t11 < t12 ? [i1, i2] : [i2, i1]
    }
    func intersections(with curve: BezierCurve, accuracy: CGFloat) -> [Intersection] {
        switch curve.order {
        case 3:
            return helperIntersectsCurveLine(curve as! CubicCurve, self, reversed: true)
        case 2:
            return helperIntersectsCurveLine(curve as! QuadraticCurve, self, reversed: true)
        case 1:
            return self.intersections(with: curve as! LineSegment)
        default:
            fatalError("unsupported")
        }
    }
    func intersections(with line: LineSegment) -> [Intersection] {

        guard self.p1 != self.p0, line.p1 != line.p0 else {
            return []
        }
        guard self.boundingBox.overlaps(line.boundingBox) else {
            return []
        }

        if let intersections = LineSegment.coincidenceCheck(self, line) {
            return intersections
        }

        let a1 = self.p0
        let b1 = self.p1 - self.p0
        let a2 = line.p0
        let b2 = line.p1 - line.p0

        if self.p1 == line.p1 {
            return [Intersection(t1: 1.0, t2: 1.0)]
        } else if self.p1 == line.p0 {
            return [Intersection(t1: 1.0, t2: 0.0)]
        } else if self.p0 == line.p1 {
            return [Intersection(t1: 0.0, t2: 1.0)]
        } else if self.p0 == line.p0 {
            return [Intersection(t1: 0.0, t2: 0.0)]
        }

        let _a = b1.x
        let _b = -b2.x
        let _c = b1.y
        let _d = -b2.y

        // by Cramer's rule we have
        // t1 = ed - bf / ad - bc
        // t2 = af - ec / ad - bc
        let det = _a * _d - _b * _c
        let inv_det = 1.0 / det

        if inv_det.isFinite == false {
            // lines are effectively parallel. Multiplying by inv_det will yield Inf or NaN, neither of which is valid
            return []
        }

        let _e = -a1.x + a2.x
        let _f = -a1.y + a2.y

        var t1 = ( _e * _d - _b * _f ) * inv_det // if inv_det is inf then this is NaN!
        var t2 = ( _a * _f - _e * _c ) * inv_det // if inv_det is inf then this is NaN!

        if Utils.approximately(Double(t1), 0.0, precision: Utils.epsilon) {
            t1 = 0.0
        }
        if Utils.approximately(Double(t1), 1.0, precision: Utils.epsilon) {
            t1 = 1.0
        }
        if Utils.approximately(Double(t2), 0.0, precision: Utils.epsilon) {
            t2 = 0.0
        }
        if Utils.approximately(Double(t2), 1.0, precision: Utils.epsilon) {
            t2 = 1.0
        }

        if t1 > 1.0 || t1 < 0.0 {
            return [] // t1 out of interval [0, 1]
        }
        if t2 > 1.0 || t2 < 0.0 {
            return [] // t2 out of interval [0, 1]
        }
        return [Intersection(t1: t1, t2: t2)]
    }
    func selfIntersections(accuracy: CGFloat) -> [Intersection] {
        return []
    }
}
