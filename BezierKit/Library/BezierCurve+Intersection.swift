//
//  BezierCurve+Intersection.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/18/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

import CoreGraphics

// MARK: - helpers using generics

let tinyValue = 1.0e-10

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
        return !self.selfIntersections(accuracy: accuracy).isEmpty
    }
    func intersects(_ line: LineSegment) -> Bool {
        return !self.intersections(with: line).isEmpty
    }
    func intersects(_ curve: BezierCurve, accuracy: CGFloat) -> Bool {
        return !self.intersections(with: curve, accuracy: accuracy).isEmpty
    }
}

private func coincidenceCheck<U: BezierCurve, T: BezierCurve>(_ curve1: U, _ curve2: T, accuracy: CGFloat) -> [Intersection]? {
    func pointIsCloseToCurve<X: BezierCurve>(_ point: CGPoint, _ curve: X) -> CGFloat? {
        let (projection, t) = curve.project(point)
        guard distanceSquared(point, projection) < 4.0 * accuracy * accuracy else { return nil }
        return t
    }
    var range1Start: CGFloat    = .infinity
    var range1End: CGFloat      = -.infinity
    var range2Start: CGFloat    = .infinity
    var range2End: CGFloat      = -.infinity
    if range1Start > 0 || range2Start > 0 || range2End < 1 {
        if let t2 = pointIsCloseToCurve(curve1.startingPoint, curve2) {
            range1Start = 0
            range2Start = min(range2Start, t2)
            range2End   = max(range2End, t2)
        }
    }
    if range1End < 1 || range2Start > 0 || range2Start < 1 {
        if let t2 = pointIsCloseToCurve(curve1.endingPoint, curve2) {
            range1End = 1
            range2Start = min(range2Start, t2)
            range2End   = max(range2End, t2)
        }
    }
    if range2Start > 0 || range1Start > 0 || range1End < 1 {
        if let t1 = pointIsCloseToCurve(curve2.startingPoint, curve1) {
            range2Start = 0
            range1Start = min(range1Start, t1)
            range1End   = max(range1End, t1)
        }
    }
    if range2End < 1 || range1Start > 0 || range1End < 1 {
        if let t1 = pointIsCloseToCurve(curve2.endingPoint, curve1) {
            range2End = 1
            range1Start = min(range1Start, t1)
            range1End   = max(range1End, t1)
        }
    }
    guard range1End > range1Start, range2End > range2Start else { return nil }
    let curve1Start = curve1.point(at: range1Start)
    let curve1End   = curve1.point(at: range1End)
    let curve2Start = curve2.point(at: range2Start)
    let curve2End   = curve2.point(at: range2End)
    // if curves do not represent entire range, prevent recognition of coincident sections smaller than `accuracy`
    if range1End - range1Start < 1.0, range2End - range2Start < 1.0 {
        guard distanceSquared(curve1Start, curve1End) >= accuracy * accuracy else { return nil }
        guard distanceSquared(curve2Start, curve2End) >= accuracy * accuracy else { return nil }
    }
    // determine proper ordering of intersections
    let reversed = { () -> Bool in
        let distance1 = distanceSquared(curve1Start, curve2Start)
        let distance2 = distanceSquared(curve1Start, curve2End)
        return distance1 > distance2
    }()
    let firstT1     = range1Start
    let secondT1    = range1End
    let firstT2     = reversed ? range2End : range2Start
    let secondT2    = reversed ? range2Start : range2End
    // ensure curves are actually relatively equal by testing more points
    // for example with a quadratic curve we must test 1 additional point, and cubic two
    let numberOfPointsToTest = max(curve1.order, curve2.order) - 1
    if numberOfPointsToTest > 0 {
        let delta = (secondT1 - firstT1) / CGFloat(numberOfPointsToTest+1)
        for i in 1...numberOfPointsToTest {
            let t = firstT1 + delta * CGFloat(i)
            guard pointIsCloseToCurve(curve1.point(at: t), curve2) != nil else { return nil }
        }
    }
    return [Intersection(t1: firstT1, t2: firstT2), Intersection(t1: secondT1, t2: secondT2)]
}

internal func helperIntersectsCurveCurve<U, T>(_ curve1: Subcurve<U>, _ curve2: Subcurve<T>, accuracy: CGFloat) -> [Intersection] where U: NonlinearBezierCurve, T: NonlinearBezierCurve {
    let lb = curve1.curve.boundingBox
    let rb = curve2.curve.boundingBox
    var intersections: [Intersection] = []
    Utils.pairiteration(curve1, curve2, lb, rb, &intersections, accuracy)
    if intersections.count >= curve1.curve.order * curve2.curve.order {
        if let coincidence = coincidenceCheck(curve1.curve, curve2.curve, accuracy: 0.1 * accuracy) {
            return coincidence
        }
    }
    return intersections.sortedAndUniqued()
}

internal func helperIntersectsCurveLine<U>(_ curve: U, _ line: LineSegment, reversed: Bool = false) -> [Intersection] where U: NonlinearBezierCurve {
    guard line.boundingBox.overlaps(curve.boundingBox) else {
        return []
    }
    if let coincidence = coincidenceCheck(curve, line, accuracy: CGFloat(tinyValue)) {
        return coincidence
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
        let p = curve.point(at: t1) - line.p0
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
        return self.intersections(with: line, checkCoincidence: true)
    }
    internal func intersections(with line: LineSegment, checkCoincidence: Bool) -> [Intersection] {
        guard self.p1 != self.p0, line.p1 != line.p0 else {
            return []
        }
        guard self.boundingBox.overlaps(line.boundingBox) else {
            return []
        }

        if checkCoincidence, let coincidence = coincidenceCheck(self, line, accuracy: CGFloat(tinyValue)) {
            return coincidence
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
