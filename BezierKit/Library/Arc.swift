// Arc.swift
// BezierKit
//
// Created by Holmes Futrell

#if canImport(CoreGraphics)
import CoreGraphics
#else
@preconcurrency import Foundation
#endif

// MARK: - Arc struct

/// A circular arc: the portion of a circle from startAngle to endAngle.
internal struct Arc {
    var center: CGPoint
    var radius: CGFloat
    var startAngle: CGFloat  // radians
    var endAngle: CGFloat    // radians

    /// Returns the point on the arc at parameter t in [0, 1].
    func point(at t: CGFloat) -> CGPoint {
        let angle = startAngle + t * (endAngle - startAngle)
        return CGPoint(x: center.x + radius * cos(angle),
                       y: center.y + radius * sin(angle))
    }

    var startingPoint: CGPoint { point(at: 0) }
    var endingPoint: CGPoint { point(at: 1) }
}

// MARK: - Arc detection on CubicCurve

extension CubicCurve {
    /// Returns an Arc approximating this cubic if the curve lies within `accuracy` of a circle, or nil.
    func asArc(accuracy: CGFloat) -> Arc? {
        // Closed-form midpoint at t=0.5 avoids heap allocation from a [point(at:)] array.
        let pMid = CGPoint(
            x: (p0.x + p3.x + 3 * (p1.x + p2.x)) * 0.125,
            y: (p0.y + p3.y + 3 * (p1.y + p2.y)) * 0.125
        )
        guard let (center, radius) = circumcircle(p0, pMid, p3) else { return nil }
        // Standard cubic approximations to circles have max error ≈ 0.0003 * radius.
        // Use a chord-relative floor so those curves are accepted even with tight accuracy.
        let chordX = p3.x - p0.x, chordY = p3.y - p0.y
        let chordSq = chordX * chordX + chordY * chordY
        // Reject nearly-linear curves (R > 5×chord, arc spans < ~11.5°). These are false
        // positives that pass the distance checks but gain nothing from the arc path.
        guard radius * radius <= 25 * chordSq else { return nil }
        let chord = chordSq.squareRoot()
        let arcTol = max(accuracy, chord * 2.0e-3)
        // p0, pMid, p3 lie on the circumcircle by construction; only t=0.25 and t=0.75 can fail.
        let p025 = point(at: 0.25)
        guard abs(distance(p025, center) - radius) <= arcTol else { return nil }
        let p075 = point(at: 0.75)
        guard abs(distance(p075, center) - radius) <= arcTol else { return nil }
        // startAngle is in (-π, π] as returned by atan2.
        let startAngle = atan2(p0.y - center.y, p0.x - center.x)
        var endAngle = atan2(p3.y - center.y, p3.x - center.x)
        // Determine rotation direction from the first tangent (p1 - p0 = derivative direction at t=0).
        // The cross product of the radial vector and tangent is positive for CCW, negative for CW.
        let radial = p0 - center
        let tangent = p1 - p0
        let isCCW = radial.cross(tangent) > 0
        // Adjust endAngle so the arc spans the correct direction.
        // For a CCW arc whose end point is at a smaller atan2 angle than the start (the arc crosses
        // the positive-x axis / atan2 branch cut), endAngle is adjusted to be > startAngle by adding
        // 2π, so it can exceed 2π (e.g. startAngle ≈ π/2, endAngle ≈ 2π+0.1).
        // For a CW arc whose end point is at a larger atan2 angle than the start, endAngle is
        // adjusted to be < startAngle by subtracting 2π, so it can be negative (e.g. < -π).
        let twoPi = 2 * CGFloat.pi
        if isCCW && endAngle < startAngle { endAngle += twoPi }
        else if !isCCW && endAngle > startAngle { endAngle -= twoPi }
        return Arc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle)
    }
}

/// Circumcircle of three points. Returns nil if points are collinear.
private func circumcircle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> (center: CGPoint, radius: CGFloat)? {
    let ax = a.x, ay = a.y, bx = b.x, by = b.y, cx = c.x, cy = c.y
    let d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
    guard abs(d) > 1.0e-10 else { return nil }
    let a2 = ax * ax + ay * ay
    let b2 = bx * bx + by * by
    let c2 = cx * cx + cy * cy
    let ux = (a2 * (by - cy) + b2 * (cy - ay) + c2 * (ay - by)) / d
    let uy = (a2 * (cx - bx) + b2 * (ax - cx) + c2 * (bx - ax)) / d
    let center = CGPoint(x: ux, y: uy)
    let radius = distance(a, center)
    return (center: center, radius: radius)
}

// MARK: - Angle parameter conversion

/// Maps a point to t in [0,1] on the arc if it lies on the arc (within tolerance), else nil.
internal func arcParameter(_ arc: Arc, point: CGPoint, tolerance: CGFloat) -> CGFloat? {
    let dist = distance(point, arc.center)
    guard abs(dist - arc.radius) < tolerance else { return nil }
    let angle = atan2(point.y - arc.center.y, point.x - arc.center.x)
    let span = arc.endAngle - arc.startAngle
    guard abs(span) > 1.0e-10 else { return nil }
    var t = (angle - arc.startAngle) / span
    if t < -1.0e-6 || t > 1.0 + 1.0e-6 {
        let twoPi = 2 * CGFloat.pi
        let adjusted = angle + (span > 0 ? twoPi : -twoPi)
        t = (adjusted - arc.startAngle) / span
    }
    guard t >= -1.0e-6, t <= 1.0 + 1.0e-6 else { return nil }
    return Utils.clamp(t, 0, 1)
}

// MARK: - Arc-Arc intersections

internal func arcArcIntersections(_ arc1: Arc, _ arc2: Arc, accuracy: CGFloat) -> [(t1: CGFloat, t2: CGFloat)] {
    let centerDist = distance(arc1.center, arc2.center)
    let radiusDiff = abs(arc1.radius - arc2.radius)
    let avgRadius = (arc1.radius + arc2.radius) * 0.5
    let coincidenceThreshold = max(accuracy, avgRadius * 1.0e-2)
    if centerDist < coincidenceThreshold && radiusDiff < coincidenceThreshold {
        return arcCoincidenceIntersections(arc1, arc2)
    }
    let r1 = arc1.radius, r2 = arc2.radius
    let d = centerDist
    guard d > 1.0e-10 else { return [] }
    let a = (r1 * r1 - r2 * r2 + d * d) / (2 * d)
    let h2 = r1 * r1 - a * a
    guard h2 >= 0 else { return [] }
    let h = sqrt(h2)
    let dx = (arc2.center.x - arc1.center.x) / d
    let dy = (arc2.center.y - arc1.center.y) / d
    let mx = arc1.center.x + a * dx
    let my = arc1.center.y + a * dy
    let tol = accuracy + arc1.radius * 1.0e-6
    var results: [(t1: CGFloat, t2: CGFloat)] = []
    for sign: CGFloat in [1, -1] {
        if h < 1.0e-10 && sign < 0 { break }
        let pt = CGPoint(x: mx + sign * h * dy, y: my - sign * h * dx)
        guard let t1 = arcParameter(arc1, point: pt, tolerance: tol),
              let t2 = arcParameter(arc2, point: pt, tolerance: tol) else { continue }
        results.append((t1: t1, t2: t2))
    }
    return results
}

private func arcCoincidenceIntersections(_ arc1: Arc, _ arc2: Arc) -> [(t1: CGFloat, t2: CGFloat)] {
    let tol: CGFloat = 1.0e-4
    var results: [(t1: CGFloat, t2: CGFloat)] = []
    for t2 in [CGFloat(0), CGFloat(1)] {
        let pt = arc2.point(at: t2)
        if let t1 = arcParameter(arc1, point: pt, tolerance: tol) {
            results.append((t1: t1, t2: t2))
        }
    }
    for t1 in [CGFloat(0), CGFloat(1)] {
        let pt = arc1.point(at: t1)
        if let t2 = arcParameter(arc2, point: pt, tolerance: tol) {
            if !results.contains(where: { abs($0.t1 - t1) < 1.0e-4 }) {
                results.append((t1: t1, t2: t2))
            }
        }
    }
    return results
}

// MARK: - Arc-Line intersections

internal func arcLineIntersections(_ arc: Arc, _ line: LineSegment, accuracy: CGFloat) -> [(tArc: CGFloat, tLine: CGFloat)] {
    let dx = line.p1.x - line.p0.x
    let dy = line.p1.y - line.p0.y
    let fx = line.p0.x - arc.center.x
    let fy = line.p0.y - arc.center.y
    let aCoeff = dx * dx + dy * dy
    let bCoeff = 2 * (fx * dx + fy * dy)
    let cCoeff = fx * fx + fy * fy - arc.radius * arc.radius
    let tol = accuracy + arc.radius * 1.0e-6
    var results: [(tArc: CGFloat, tLine: CGFloat)] = []
    // Use quadratic formula on the Bernstein form: cCoeff, bCoeff/2+cCoeff, aCoeff+bCoeff+cCoeff
    Utils.droots(cCoeff, bCoeff / 2 + cCoeff, aCoeff + bCoeff + cCoeff) { tLine in
        guard tLine >= -1.0e-6, tLine <= 1.0 + 1.0e-6 else { return }
        let tLineClamped = Utils.clamp(tLine, 0, 1)
        let pt = CGPoint(x: line.p0.x + tLineClamped * dx, y: line.p0.y + tLineClamped * dy)
        if let tArc = arcParameter(arc, point: pt, tolerance: tol) {
            results.append((tArc: tArc, tLine: tLineClamped))
        }
    }
    return results
}

// MARK: - Arc-Quadratic intersections

internal func arcQuadraticIntersections(_ arc: Arc, _ quad: QuadraticCurve, accuracy: CGFloat) -> [(tArc: CGFloat, tQuad: CGFloat)] {
    let q0 = quad.p0 - arc.center
    let q1 = quad.p1 - arc.center
    let q2 = quad.p2 - arc.center
    let bx = quadBernsteinSquaredCoeffs(q0.x, q1.x, q2.x)
    let by = quadBernsteinSquaredCoeffs(q0.y, q1.y, q2.y)
    let r2 = arc.radius * arc.radius
    let poly = BernsteinPolynomial4(b0: bx.0 + by.0 - r2,
                                    b1: bx.1 + by.1 - r2,
                                    b2: bx.2 + by.2 - r2,
                                    b3: bx.3 + by.3 - r2,
                                    b4: bx.4 + by.4 - r2)
    let tol = accuracy + arc.radius * 1.0e-6
    var results: [(tArc: CGFloat, tQuad: CGFloat)] = []
    for tQuad in findDistinctRootsInUnitInterval(of: poly) {
        let pt = quad.point(at: CGFloat(tQuad))
        if let tArc = arcParameter(arc, point: pt, tolerance: tol) {
            results.append((tArc: tArc, tQuad: CGFloat(tQuad)))
        }
    }
    return results
}

/// Bernstein coefficients of the degree-4 polynomial that is the square of a degree-2 Bernstein polynomial.
private func quadBernsteinSquaredCoeffs(_ c0: CGFloat, _ c1: CGFloat, _ c2: CGFloat) -> (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) {
    // Product formula for degree-2 × degree-2 → degree-4
    let b0 = c0 * c0
    let b1 = c0 * c1
    let b2 = (2 * c0 * c2 + 4 * c1 * c1) / 6
    let b3 = c1 * c2
    let b4 = c2 * c2
    return (b0, b1, b2, b3, b4)
}

// MARK: - Arc-Cubic intersections

/// Bernstein coefficients of the degree-6 polynomial that is the square of a degree-3 Bernstein polynomial.
private func cubicBernsteinSquaredCoeffs(_ c0: CGFloat, _ c1: CGFloat, _ c2: CGFloat, _ c3: CGFloat)
    -> (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) {
    let b0 = c0 * c0
    let b1 = c0 * c1
    let b2 = (2 * c0 * c2 + 3 * c1 * c1) / 5
    let b3 = (c0 * c3 + 9 * c1 * c2) / 10
    let b4 = (2 * c1 * c3 + 3 * c2 * c2) / 5
    let b5 = c2 * c3
    let b6 = c3 * c3
    return (b0, b1, b2, b3, b4, b5, b6)
}

internal func arcCubicIntersections(_ arc: Arc, _ cubic: CubicCurve, accuracy: CGFloat) -> [(tArc: CGFloat, tCubic: CGFloat)] {
    let q0 = cubic.p0 - arc.center
    let q1 = cubic.p1 - arc.center
    let q2 = cubic.p2 - arc.center
    let q3 = cubic.p3 - arc.center
    let bx = cubicBernsteinSquaredCoeffs(q0.x, q1.x, q2.x, q3.x)
    let by = cubicBernsteinSquaredCoeffs(q0.y, q1.y, q2.y, q3.y)
    let r2 = arc.radius * arc.radius
    let poly = BernsteinPolynomial6(b0: bx.0 + by.0 - r2, b1: bx.1 + by.1 - r2,
                                    b2: bx.2 + by.2 - r2, b3: bx.3 + by.3 - r2,
                                    b4: bx.4 + by.4 - r2, b5: bx.5 + by.5 - r2,
                                    b6: bx.6 + by.6 - r2)
    let tol = accuracy + arc.radius * 1.0e-6
    var results: [(tArc: CGFloat, tCubic: CGFloat)] = []
    for tCubic in findDistinctRootsInUnitInterval(of: poly) {
        let pt = cubic.point(at: CGFloat(tCubic))
        if let tArc = arcParameter(arc, point: pt, tolerance: tol) {
            results.append((tArc: tArc, tCubic: CGFloat(tCubic)))
        }
    }
    return results
}
