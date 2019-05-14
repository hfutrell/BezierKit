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

private func sortedAndUniquifiedIntersections(_ intersections: [Intersection]) -> [Intersection] {
    let sortedIntersections = intersections.sorted(by: <)
    return sortedIntersections.reduce([Intersection]()) { (intersection: [Intersection], next: Intersection) in
        return (intersection.isEmpty || (intersection.last!) != next) ? intersection + [next] : intersection
    }
}

internal func helperIntersectsCurveCurve<U, T>(_ curve1: Subcurve<U>, _ curve2: Subcurve<T>, accuracy: CGFloat) -> [Intersection] where U: NonlinearBezierCurve, T: NonlinearBezierCurve {
    let lb = curve1.curve.boundingBox
    let rb = curve2.curve.boundingBox
    var intersections: [Intersection] = []
    Utils.pairiteration(curve1, curve2, lb, rb, &intersections, accuracy)
    return sortedAndUniquifiedIntersections(intersections)
}

internal func helperIntersectsCurveLine<U>(_ curve: U, _ line: LineSegment, reversed: Bool = false) -> [Intersection] where U: NonlinearBezierCurve {
    guard line.boundingBox.overlaps(curve.boundingBox) else {
        return []
    }
    let lineDirection = (line.p1 - line.p0)
    let lineLength = lineDirection.lengthSquared
    let intersections = Utils.roots(points: curve.points, line: line).compactMap({t -> Intersection? in
        let p = curve.compute(t) - line.p0
        var t2 = p.dot(lineDirection) / lineLength
        if Utils.approximately(Double(t2), 0.0, precision: Utils.epsilon) {
            t2 = 0.0
        }
        if Utils.approximately(Double(t2), 1.0, precision: Utils.epsilon) {
            t2 = 1.0
        }
        guard t2 >= 0.0, t2 <= 1.0 else {
            return nil
        }
        return reversed ? Intersection(t1: t2, t2: t) : Intersection(t1: t, t2: t2)
    })
    return sortedAndUniquifiedIntersections(intersections)
}

// MARK: - extensions to support intersection

extension NonlinearBezierCurve {
    public func intersections(with line: LineSegment) -> [Intersection] {
        return helperIntersectsCurveLine(self, line)
    }
    public func intersections(with curve: BezierCurve, accuracy: CGFloat) -> [Intersection] {
        switch curve.order {
        case 3:
            return helperIntersectsCurveCurve(Subcurve(curve: self), Subcurve(curve: curve as! CubicBezierCurve), accuracy: accuracy)
        case 2:
            return helperIntersectsCurveCurve(Subcurve(curve: self), Subcurve(curve: curve as! QuadraticBezierCurve), accuracy: accuracy)
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

public extension QuadraticBezierCurve {
    func selfIntersections(accuracy: CGFloat) -> [Intersection] {
        return []
    }
}

public extension LineSegment {
    func intersections(with curve: BezierCurve, accuracy: CGFloat) -> [Intersection] {
        switch curve.order {
        case 3:
            return helperIntersectsCurveLine(curve as! CubicBezierCurve, self, reversed: true)
        case 2:
            return helperIntersectsCurveLine(curve as! QuadraticBezierCurve, self, reversed: true)
        case 1:
            return self.intersections(with: curve as! LineSegment)
        default:
            fatalError("unsupported")
        }
    }
    func intersections(with line: LineSegment) -> [Intersection] {

        guard self.boundingBox.overlaps(line.boundingBox) else {
            return []
        }
        if self.p0 == line.p0 {
            return [Intersection(t1: 0.0, t2: 0.0)]
        } else if self.p0 == line.p1 {
            return [Intersection(t1: 0.0, t2: 1.0)]
        } else if self.p1 == line.p0 {
            return [Intersection(t1: 1.0, t2: 0.0)]
        } else if self.p1 == line.p1 {
            return [Intersection(t1: 1.0, t2: 1.0)]
        }

        let a1 = self.p0
        let b1 = self.p1 - self.p0
        let a2 = line.p0
        let b2 = line.p1 - line.p0

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
