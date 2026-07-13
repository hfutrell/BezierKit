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

private extension BezierCurve {
    var derivativeBounds: CGFloat {
        let points = self.points
        let speeds: [CGFloat] = (1..<points.count).map { index in
            let point: CGPoint = points[index] - points[index - 1]
            return sqrt(point.dot(point))
        }
        return CGFloat(self.order) * speeds.max()!
    }
}

// Curves that touch only at a shared endpoint are tangent there, so the monotone subdivision's
// leaf solver (which discards near-tangent leaves) can miss the touch at tight accuracy even though
// subdivision otherwise succeeds. Detect coincident endpoints explicitly — matching master, whose
// subdivision leaf does a line-segment solve that always catches a shared endpoint. Each of the four
// corner pairs is added only when the endpoints coincide within `accuracy` and the subdivision did
// not already report a crossing there (point-proximity dedup).
private func addCoincidentEndpoints<U: BezierCurve, T: BezierCurve>(
    _ result: inout [Intersection], _ c1: U, _ c2: T, accuracy: CGFloat
) {
    let accuracySq = accuracy * accuracy
    func consider(_ t1: CGFloat, _ t2: CGFloat, _ corner: CGPoint, _ other: CGPoint) {
        guard distanceSquared(corner, other) < accuracySq else { return }
        guard !result.contains(where: { distanceSquared(c1.point(at: $0.t1), corner) < accuracySq }) else { return }
        result.append(Intersection(t1: t1, t2: t2))
    }
    consider(0, 0, c1.startingPoint, c2.startingPoint)
    consider(0, 1, c1.startingPoint, c2.endingPoint)
    consider(1, 0, c1.endingPoint, c2.startingPoint)
    consider(1, 1, c1.endingPoint, c2.endingPoint)
}

// Curve/curve intersection driver. Splits both curves at their derivative roots so every
// piece is monotone, then runs fast monotone subdivision (Utils.preSplitIntersections) on
// all overlapping pairs. The identical-curve fast path is handled by concrete-type overloads
// in extension CubicCurve / extension QuadraticCurve, which shadow the protocol extension for
// statically-typed receivers, eliminating as? runtime casts entirely.
private func helperIntersectsCurveCurveImpl<U, T>(_ curve1: Subcurve<U>, _ curve2: Subcurve<T>, accuracy: CGFloat) -> [Intersection]
where U: NonlinearBezierCurve, T: NonlinearBezierCurve {
    var pairIntersections: [Intersection] = []
    var subdivisionIterations = 0
    if Utils.preSplitIntersections(curve1.curve, curve2.curve, &pairIntersections, accuracy, &subdivisionIterations) {
        addCoincidentEndpoints(&pairIntersections, curve1.curve, curve2.curve, accuracy: accuracy)
        return pairIntersections.sortedAndUniqued()
    }

    // Subdivision hit its iteration limit (curves are likely coincident, or near-coincident with
    // genuine crossings the bounding-box test cannot separate). Check for geometric coincidence
    // first — the composition polynomial is theoretically zero for coincident curves, so
    // floating-point noise would otherwise produce spurious roots.
    if let coincidence = coincidenceCheck(curve1.curve, curve2.curve, accuracy: 0.1 * accuracy) {
        return coincidence
    }

    // Not coincident — resolve via curve implicitization.
    return implicitizationFallback(curve1.curve, curve2.curve, accuracy: accuracy)
}

// Implicitization fallback (mirrors master). Translate so curve2 starts at the origin (keeps the
// implicit-polynomial coefficients well-conditioned), demote curve2 to its true degree so a
// degree-deficient curve (e.g. a quadratic raised to cubic form, whose implicit polynomial is the
// zero polynomial) is handled, build its implicit polynomial, compose it with curve1's parametric
// x/y polynomials, and root-find the resulting degree-(order × order) polynomial. Each root t1 is
// accepted only if curve1(t1) projects onto curve2 within `accuracy`. The only departure from
// master is the fixed-degree root finder (forEachRootOfComposition) in place of master's
// arbitrary-degree BernsteinPolynomialN.distinctRealRootsInUnitInterval.
private func implicitizationFallback<C1: NonlinearBezierCurve, C2: NonlinearBezierCurve>(
    _ curve1: C1, _ curve2: C2, accuracy: CGFloat
) -> [Intersection] {
    let insignificantDistance = 0.5 * accuracy
    let transform = CGAffineTransform(translationX: -curve2.startingPoint.x, y: -curve2.startingPoint.y)
    let c2 = curve2.downgradedIfPossible(maximumError: insignificantDistance).copy(using: transform)
    let c1 = curve1.copy(using: transform)
    let implicit = c2.implicitPolynomial
    let t1Tolerance = insignificantDistance / c1.derivativeBounds
    let t2Tolerance = insignificantDistance / c2.derivativeBounds

    func intersectionIfCloseEnough(at t1: CGFloat) -> Intersection? {
        let point = c1.point(at: t1)
        guard c2.boundingBox.contains(point) else { return nil }
        var t2 = c2.project(point).t
        if t2 < t2Tolerance {
            t2 = 0
        } else if t2 > 1 - t2Tolerance {
            t2 = 1
        }
        guard distance(point, c2.point(at: t2)) < accuracy else { return nil }
        return Intersection(t1: t1, t2: t2)
    }

    var intersections: [Intersection] = []
    let p = c1.order
    withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 2 * (p + 1)) { coeffs in
        var xi = 0
        c1.xPolynomial.forEachCoefficient { coeffs[xi] = $0; xi += 1 }
        var yi = p + 1
        c1.yPolynomial.forEachCoefficient { coeffs[yi] = $0; yi += 1 }
        implicit.forEachRootOfComposition(xCoeffs: coeffs.baseAddress!,
                                          yCoeffs: coeffs.baseAddress! + (p + 1),
                                          paramOrder: p,
                                          errorThreshold: minimumClippingErrorThreshold) { t1 in
            // t1 near 0 or 1 is handled explicitly below.
            guard t1 >= t1Tolerance, t1 <= 1 - t1Tolerance else { return }
            if let intersection = intersectionIfCloseEnough(at: t1) {
                intersections.append(intersection)
            }
        }
    }
    if intersections.contains(where: { $0.t1 == 0 }) == false,
       let intersection = intersectionIfCloseEnough(at: 0) {
        intersections.append(intersection)
    }
    if intersections.contains(where: { $0.t1 == 1 }) == false,
       let intersection = intersectionIfCloseEnough(at: 1) {
        intersections.append(intersection)
    }
    return intersections.sortedAndUniqued()
}

private func sameGeometryIntersections<C: NonlinearBezierCurve & Equatable>(
    _ curve1: Subcurve<C>, _ curve2: Subcurve<C>
) -> [Intersection]? {
    guard curve1.curve == curve2.curve else { return nil }
    let tLo = max(curve1.t1, curve2.t1)
    let tHi = min(curve1.t2, curve2.t2)
    guard tLo < tHi else { return [] }
    return [Intersection(t1: tLo, t2: tLo), Intersection(t1: tHi, t2: tHi)]
}

internal func helperIntersectsCurveCurve<U, T>(_ curve1: Subcurve<U>, _ curve2: Subcurve<T>, accuracy: CGFloat) -> [Intersection]
where U: NonlinearBezierCurve, T: NonlinearBezierCurve {
    // Detect identical-geometry pairs by casting to concrete types.
    // as? is only used here (not in the hot-path concrete overloads).
    if let c1 = curve1 as? Subcurve<CubicCurve>, let c2 = curve2 as? Subcurve<CubicCurve> {
        if let result = sameGeometryIntersections(c1, c2) { return result }
    } else if let c1 = curve1 as? Subcurve<QuadraticCurve>, let c2 = curve2 as? Subcurve<QuadraticCurve> {
        if let result = sameGeometryIntersections(c1, c2) { return result }
    }
    return helperIntersectsCurveCurveImpl(curve1, curve2, accuracy: accuracy)
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

    // Concrete overload: shadows the NonlinearBezierCurve extension for statically-typed
    // CubicCurve receivers. Uses synthesized struct == (no as? runtime metadata lookup)
    // for the identical-curve fast path; eliminates __swift_instantiateConcreteTypeFromMangledNameV2.
    public func intersections(with curve: CubicCurve, accuracy: CGFloat) -> [Intersection] {
        if self == curve {
            return [Intersection(t1: 0, t2: 0), Intersection(t1: 1, t2: 1)]
        }
        return helperIntersectsCurveCurveImpl(Subcurve(curve: self), Subcurve(curve: curve), accuracy: accuracy)
    }
}

extension QuadraticCurve {
    // Concrete overload: shadows the NonlinearBezierCurve extension for statically-typed
    // QuadraticCurve receivers. Uses synthesized struct == for the identical-curve fast path.
    public func intersections(with curve: QuadraticCurve, accuracy: CGFloat) -> [Intersection] {
        if self == curve {
            return [Intersection(t1: 0, t2: 0), Intersection(t1: 1, t2: 1)]
        }
        return helperIntersectsCurveCurveImpl(Subcurve(curve: self), Subcurve(curve: curve), accuracy: accuracy)
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
