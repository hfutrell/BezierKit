//
//  BezierCurve+Intersection.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/18/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

// MARK: - helpers using generics

let tinyValue = 1.0e-10

public extension BezierCurve {
    func intersects(_ curve: BezierCurve) -> Bool {
        return self.intersects(curve, accuracy: BezierKit.defaultIntersectionAccuracy)
    }
    func intersections(with curve: BezierCurve) -> [Intersection] {
        return self.intersections(with: curve, accuracy: BezierKit.defaultIntersectionAccuracy)
    }
    func intersects(_ line: LineSegment) -> Bool {
        return !self.intersections(with: line).isEmpty
    }
    func intersects(_ curve: BezierCurve, accuracy: CGFloat) -> Bool {
        return !self.intersections(with: curve, accuracy: accuracy).isEmpty
    }
    var selfIntersects: Bool {
        return false
    }
    var selfIntersection: Intersection? {
        return nil
    }
    @available(*, deprecated, renamed: "selfIntersection")
    var selfIntersections: [Intersection] {
        return []
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
    // Sample additional interior points to rule out false coincidence from crossing curves.
    // Crossing near-coincident curves pass the endpoint checks above but diverge from
    // each other between the crossing and the endpoints. Using more samples than
    // (order - 1) catches these divergent regions.
    let numberOfPointsToTest = max(max(curve1.order, curve2.order) - 1, 8)
    if numberOfPointsToTest > 0 {
        let step = (secondT1 - firstT1) / CGFloat(numberOfPointsToTest + 1)
        for i in 1...numberOfPointsToTest {
            let t = firstT1 + step * CGFloat(i)
            guard pointIsCloseToCurve(curve1.point(at: t), curve2) != nil else { return nil }
        }
    }
    return [Intersection(t1: firstT1, t2: firstT2), Intersection(t1: secondT1, t2: secondT2)]
}

// 2D Newton–Raphson on C1(u) = C2(v) starting from (u, v). Returns refined (u, v).
private func newtonRefineCurvePair<C1: NonlinearBezierCurve, C2: NonlinearBezierCurve>(
    _ c1: C1, _ c2: C2, u: CGFloat, v: CGFloat, iterations: Int
) -> (CGFloat, CGFloat) {
    var u = u, v = v
    for _ in 0..<iterations {
        let (q1, d1) = c1.pointAndDerivative(at: u)
        let (q2, d2) = c2.pointAndDerivative(at: v)
        let f = q1 - q2
        let denom = d1.cross(d2)
        let denomSq = denom * denom
        let scaleSq = (d1.x * d1.x + d1.y * d1.y) * (d2.x * d2.x + d2.y * d2.y)
        guard denomSq > scaleSq * CGFloat(1.0e-20) else { break }
        let du = -f.cross(d2) / denom
        let dv = d1.cross(f) / denom
        u = Utils.clamp(u + du, 0, 1)
        v = Utils.clamp(v + dv, 0, 1)
        guard du * du + dv * dv > CGFloat(1.0e-28) else { break }
    }
    return (u, v)
}

// True when |C1(u) − C2(v)| < chord × 1e-6 — distinguishes genuine roots from near-misses.
private func newtonIsGenuineRoot<C1: NonlinearBezierCurve, C2: NonlinearBezierCurve>(
    _ c1: C1, _ c2: C2, u: CGFloat, v: CGFloat
) -> Bool {
    let f = c1.point(at: u) - c2.point(at: v)
    let chordSq = (c1.endingPoint - c1.startingPoint).lengthSquared
    let scaleSq = max(chordSq, CGFloat(1.0e-20))
    return f.lengthSquared < scaleSq * CGFloat(1.0e-12)
}

// Ensures exact curve-endpoint intersections are represented precisely in `result`.
// When Newton refinement nudges a clipping result slightly away from an exact endpoint,
// this replaces the near-endpoint result with the exact (u, v) corner value.
// Also appends any endpoint intersections that bezier clipping missed entirely.
private func addEndpointIntersections<C1: NonlinearBezierCurve, C2: NonlinearBezierCurve>(
    _ result: inout [Intersection], curve1: C1, curve2: C2, accuracy: CGFloat
) {
    for (u, v) in [(CGFloat(0), CGFloat(0)), (CGFloat(0), CGFloat(1)), (CGFloat(1), CGFloat(0)), (CGFloat(1), CGFloat(1))] {
        guard newtonIsGenuineRoot(curve1, curve2, u: u, v: v) else { continue }
        let p1 = curve1.point(at: u)
        if let idx = result.firstIndex(where: { distanceSquared(p1, curve1.point(at: $0.t1)) < accuracy * accuracy }) {
            result[idx] = Intersection(t1: u, t2: v)
        } else {
            result.append(Intersection(t1: u, t2: v))
        }
    }
}

// Compares two concrete Equatable values without going through BezierCurve's global == operator.
// The global `func == (BezierCurve, BezierCurve)` allocates [CGPoint] arrays via .points; this
// helper forces the synthesized struct == (direct field comparison, zero allocation).
private func equatableCurvesMatch<C: Equatable>(_ a: C, _ b: C) -> Bool { a == b }

internal func helperIntersectsCurveCurve<U, T>(_ curve1: Subcurve<U>, _ curve2: Subcurve<T>, accuracy: CGFloat) -> [Intersection] where U: NonlinearBezierCurve, T: NonlinearBezierCurve {
    // Identical full-range curves are fully coincident (CLAUDE.md: self-pair contract).
    // Skip bezier clipping (which exhausts 64 iterations) and coincidenceCheck (expensive
    // point projections). This fires whenever the same curve value appears on both sides,
    // which happens in all-pairs performance tests and any caller passing the same curve twice.
    if curve1.t1 == 0, curve1.t2 == 1, curve2.t1 == 0, curve2.t2 == 1 {
        if let c1 = curve1.curve as? CubicCurve, let c2 = curve2.curve as? CubicCurve,
           equatableCurvesMatch(c1, c2) {
            return [Intersection(t1: 0, t2: 0), Intersection(t1: 1, t2: 1)]
        }
        if let c1 = curve1.curve as? QuadraticCurve, let c2 = curve2.curve as? QuadraticCurve,
           equatableCurvesMatch(c1, c2) {
            return [Intersection(t1: 0, t2: 0), Intersection(t1: 1, t2: 1)]
        }
    }
    // try intersecting using Bezier clipping (Sederberg & Nishita 1990)
    var clipIntersections: [Intersection] = []
    clipIntersections.reserveCapacity(curve1.curve.order * curve2.curve.order)
    var clipIterations = 0
    let clippingConverged = bezierClipping(curve1, curve2, &clipIntersections, &clipIterations)
    if clippingConverged {
        guard !clipIntersections.isEmpty else {
            // Clipping converged to empty: fat-line clips eliminated all overlap.
            // Endpoint-endpoint intersections (tangential approach, equal start/end points)
            // may be missed by pure convergence; check all corner combinations explicitly.
            var result: [Intersection] = []
            addEndpointIntersections(&result, curve1: curve1.curve, curve2: curve2.curve, accuracy: accuracy)
            return result.sortedAndUniqued()
        }
        // Verify each clipping result with Newton and return Newton-refined t values.
        // Near-coincident non-intersecting curves can cause clipping to converge to
        // spurious points; Newton rejection filters these out. When multiple subdivisions
        // converge to nearby parameters of the same genuine crossing, refining to the
        // true (u,v) makes them spatially identical, so deduplication collapses them to one.
        clipIntersections.sort()
        var result: [Intersection] = []
        for ix in clipIntersections {
            let (uV, vV) = newtonRefineCurvePair(curve1.curve, curve2.curve, u: ix.t1, v: ix.t2, iterations: 10)
            guard newtonIsGenuineRoot(curve1.curve, curve2.curve, u: uV, v: vV) else { continue }
            let p1 = curve1.curve.point(at: uV)
            let isDuplicate = result.contains(where: { distanceSquared(p1, curve1.curve.point(at: $0.t1)) < accuracy * accuracy })
            if !isDuplicate {
                result.append(Intersection(t1: uV, t2: vV))
            }
        }
        if !result.isEmpty {
            addEndpointIntersections(&result, curve1: curve1.curve, curve2: curve2.curve, accuracy: accuracy)
            return result.sorted()
        }
        // All clipping results failed Newton verification (near-coincident non-intersecting curves).
        // Fall through to coincidence check and Newton midpoint fallback.
    }

    if let coincidence = coincidenceCheck(curve1.curve, curve2.curve, accuracy: 0.1 * accuracy) {
        return coincidence
    }

    // Newton midpoint fallback: near-coincident crossing curves exhaust bezier clipping
    // because the fat-line of each nearly contains the other. The midpoint (0.5, 0.5) sits
    // at the crossing for symmetric near-coincident pairs (|f| ≈ 0 → accepted). For parallel
    // pairs the tangents are nearly identical (denom ≈ 0), Newton breaks on the robust denom
    // check, and |f| ≈ δ exceeds the threshold, so the fallback produces nothing.
    var fallback: [Intersection] = []
    let (uN, vN) = newtonRefineCurvePair(curve1.curve, curve2.curve, u: 0.5, v: 0.5, iterations: 20)
    if uN > 1.0e-6 && uN < 1.0 - 1.0e-6 && vN > 1.0e-6 && vN < 1.0 - 1.0e-6 &&
       newtonIsGenuineRoot(curve1.curve, curve2.curve, u: uN, v: vN) {
        let t1Candidate = uN * curve1.t2 + (1 - uN) * curve1.t1
        let t2Candidate = vN * curve2.t2 + (1 - vN) * curve2.t1
        fallback.append(Intersection(t1: t1Candidate, t2: t2Candidate))
    }
    addEndpointIntersections(&fallback, curve1: curve1.curve, curve2: curve2.curve, accuracy: accuracy)
    return fallback.sortedAndUniqued()
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

extension CubicCurve {

    private var selfIntersectionInfo: (discriminant: CGFloat, canonicalPoint: CGPoint)? {
        let d1 = self.p1 - self.p0
        let d2 = self.p2 - self.p0
        // https://pomax.github.io/bezierinfo/#canonical
        // we'll use cramer's rule to find a matrix M that maps d1 -> (1, 0) and d2 -> (0, 1)
        // then compute the transform to canonical form as [[0, 1], [1, 1]] * M
        let a = d1.x
        let c = d1.y
        let b = d2.x
        let d = d2.y
        let det = a * d - b * c
        guard det != 0 else { return nil }
        let d3 = self.p3 - self.p0
        // find the coordinates of the last point in canonical form
        let x = (1 / det) * (-c * d3.x + a * d3.y)
        let y = (1 / det) * ((d - c) * d3.x + (a - b) * d3.y)
        // use the coordinates of the last point to determine if any self-intersections exist
        guard x < 1 else { return nil }
        let xSquared = x * x
        let cuspEdge = -3 * xSquared + 6 * x - 12 * y + 9
        guard cuspEdge > 0 else { return nil }
        if x <= 0 {
            let loopAtTZeroEdge = (-xSquared + 3 * x) / 3
            guard y >= loopAtTZeroEdge else { return nil }
        } else {
            let loopAtTOneEdge = (sqrt(3 * (4 * x - xSquared)) - x) / 2
            guard y >= loopAtTOneEdge else { return nil }
        }
        return (discriminant: cuspEdge, canonicalPoint: CGPoint(x: x, y: y))
    }

    public var selfIntersects: Bool {
        return self.selfIntersectionInfo != nil
    }

    public var selfIntersection: Intersection? {
        guard let info = self.selfIntersectionInfo else { return nil }
        let discriminant = info.discriminant
        let x = info.canonicalPoint.x
        let y = info.canonicalPoint.y
        let radical = sqrt(discriminant)
        let denominator = (3 - x - y)
        let t1 = 0.5 * (3 - x - radical) / denominator
        let t2 = 0.5 * (3 - x + radical) / denominator
        return Intersection(t1: Utils.clamp(t1, 0, 1),
                            t2: Utils.clamp(t2, 0, 1))
    }

    @available(*, deprecated, renamed: "selfIntersection")
    public var selfIntersections: [Intersection] {
        guard let i = selfIntersection else { return [] }
        return [i]
    }
}

extension NonlinearBezierCurve {
    public func intersections(with line: LineSegment) -> [Intersection] {
        return helperIntersectsCurveLine(self, line)
    }
    // Concrete overloads avoid heap-boxing the curve argument as a BezierCurve existential.
    // CubicCurve is 64 bytes — larger than Swift's 24-byte existential inline buffer,
    // so passing it as `BezierCurve` causes a heap allocation per call.
    public func intersections(with curve: CubicCurve, accuracy: CGFloat) -> [Intersection] {
        return helperIntersectsCurveCurve(Subcurve(curve: self), Subcurve(curve: curve), accuracy: accuracy)
    }
    public func intersections(with curve: QuadraticCurve, accuracy: CGFloat) -> [Intersection] {
        return helperIntersectsCurveCurve(Subcurve(curve: self), Subcurve(curve: curve), accuracy: accuracy)
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
}
