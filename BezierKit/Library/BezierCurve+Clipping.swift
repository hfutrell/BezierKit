//
//  BezierCurve+Clipping.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/1/26.
//  Copyright © 2026 Holmes Futrell. All rights reserved.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

// Fixed-size control point storage — avoids heap allocation and opaque closure dispatch
// in the bezier-clipping hot path. Holds up to 4 points; count distinguishes order.
struct ControlPolygon {
    let count: Int
    let p0, p1, p2, p3: CGPoint

    init(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint) {
        count = 3; self.p0 = p0; self.p1 = p1; self.p2 = p2; self.p3 = .zero
    }
    init(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) {
        count = 4; self.p0 = p0; self.p1 = p1; self.p2 = p2; self.p3 = p3
    }
    subscript(_ i: Int) -> CGPoint {
        if i == 0 { return p0 }
        if i == 1 { return p1 }
        if i == 2 { return p2 }
        return p3
    }
}

/// Protocol for curves that support bezier clipping via a fixed-size control polygon.
internal protocol BezierClippingCurve: BezierCurve {
    var controlPolygon: ControlPolygon { get }
}

internal extension BezierClippingCurve {
    // Axis-aligned bounding box of the control polygon — always an outer bound of the true
    // curve bounding box (Bézier curves lie within the convex hull of their control points).
    // Cheaper than `boundingBox` because it needs no droots/sqrt computation.
    var controlPolygonBounds: BoundingBox {
        let cp = controlPolygon
        var minX = CGFloat.infinity; var maxX = -CGFloat.infinity
        var minY = CGFloat.infinity; var maxY = -CGFloat.infinity
        for i in 0..<cp.count {
            let p = cp[i]
            if p.x < minX { minX = p.x }; if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }; if p.y > maxY { maxY = p.y }
        }
        return BoundingBox(min: CGPoint(x: minX, y: minY), max: CGPoint(x: maxX, y: maxY))
    }
}

extension CubicCurve: BezierClippingCurve {
    var controlPolygon: ControlPolygon { ControlPolygon(p0, p1, p2, p3) }
}

extension QuadraticCurve: BezierClippingCurve {
    var controlPolygon: ControlPolygon { ControlPolygon(p0, p1, p2) }
}

// MARK: - Bezier Clipping (Sederberg & Nishita, 1990)

// n=4 specialization of convexHullClipInterval (cubic curves — by far the most common case).
// Eliminates the generic loop + withUnsafeTemporaryAllocation overhead by using a
// static branch tree over precomputed cross products. tMin/tMax are passed explicitly
// to avoid captured-var exclusivity overhead even after inlining.
private func convexHullClipIntervalCubic(
    d0: CGFloat, d1: CGFloat, d2: CGFloat, d3: CGFloat,
    dLow: CGFloat, dHigh: CGFloat
) -> (CGFloat, CGFloat)? {
    // Processes one convex hull edge from (ta, da) to (ta+dt, db) against [dLow,dHigh].
    // Returns updated (lo, hi). With @inline(__always), the call sites become pure
    // local-variable arithmetic — no closure captures, no swift_beginAccess overhead.
    @inline(__always) func check(_ da: CGFloat, _ db: CGFloat,
                                 _ ta: CGFloat, _ dt: CGFloat,
                                 _ lo: CGFloat, _ hi: CGFloat) -> (CGFloat, CGFloat) {
        var lo = lo, hi = hi
        if da >= dLow && da <= dHigh { if ta < lo { lo = ta }; if ta > hi { hi = ta } }
        let dDelta = db - da
        if dDelta != 0 {
            // Sign-based crossing detection: avoid division when the edge doesn't cross
            // the boundary (the sign product is positive when both ends are on the same side).
            let dLowA = dLow - da; let dLowB = dLow - db
            if dLowA * dLowB <= 0 { let t = ta + dLowA * dt / dDelta; if t < lo { lo = t }; if t > hi { hi = t } }
            let dHighA = dHigh - da; let dHighB = dHigh - db
            if dHighA * dHighB <= 0 { let t = ta + dHighA * dt / dDelta; if t < lo { lo = t }; if t > hi { hi = t } }
        }
        return (lo, hi)
    }
    var tMin = CGFloat.infinity, tMax = -CGFloat.infinity
    // Cross products proportional to cross2d for the 4 uniformly-spaced points
    // (t ∈ {0, 1/3, 2/3, 1}), sharing sign with the original cross2d formulation:
    //   c012 = cross2d(0,1,2) = d0 - 2·d1 + d2
    //   c023 = cross2d(0,2,3) = d0 - 3·d2 + 2·d3
    //   c123 = cross2d(1,2,3) = d1 - 2·d2 + d3
    //   c013 = cross2d(0,1,3) = 2·d0 - 3·d1 + d3
    let c012 = d0 - 2*d1 + d2
    // Lower hull (pop vertex when cross2d ≤ 0) and upper hull (pop when cross2d ≥ 0)
    // share identical structure; the sign factor flips the inequality.
    // sign=+1 → lower hull, sign=-1 → upper hull.
    func processHull(sign: CGFloat) {
        if sign * c012 <= 0 {
            let c023 = d0 - 3*d2 + 2*d3
            if sign * c023 <= 0 {
                (tMin, tMax) = check(d0, d3, 0, 1, tMin, tMax)
            } else {
                (tMin, tMax) = check(d0, d2, 0, 2.0/3, tMin, tMax)
                (tMin, tMax) = check(d2, d3, 2.0/3, 1.0/3, tMin, tMax)
            }
        } else {
            let c123 = d1 - 2*d2 + d3
            if sign * c123 <= 0 {
                let c013 = 2*d0 - 3*d1 + d3
                if sign * c013 <= 0 {
                    (tMin, tMax) = check(d0, d3, 0, 1, tMin, tMax)
                } else {
                    (tMin, tMax) = check(d0, d1, 0, 1.0/3, tMin, tMax)
                    (tMin, tMax) = check(d1, d3, 1.0/3, 2.0/3, tMin, tMax)
                }
            } else {
                (tMin, tMax) = check(d0, d1, 0, 1.0/3, tMin, tMax)
                (tMin, tMax) = check(d1, d2, 1.0/3, 1.0/3, tMin, tMax)
                (tMin, tMax) = check(d2, d3, 2.0/3, 1.0/3, tMin, tMax)
            }
        }
    }
    processHull(sign: 1)    // lower hull
    processHull(sign: -1)   // upper hull
    // d3 at t=1 is always the final vertex of both hulls.
    if d3 >= dLow && d3 <= dHigh { if tMin > 1 { tMin = 1 }; if tMax < 1 { tMax = 1 } }
    guard tMin <= tMax else { return nil }
    return (max(0, tMin), min(1, tMax))
}

// Given n Bernstein coefficients d0..d3 (curve at t_i = i/(n-1)) and a horizontal band
// [dLow, dHigh], returns the sub-interval [tMin, tMax] of [0,1] where the convex hull
// of {(t_i, d(i))} intersects the band. Returns nil if hull and band are disjoint.
// d2 and d3 are only used when n > 2 and n > 3 respectively.
private func convexHullClipInterval(
    d0: CGFloat, d1: CGFloat, d2: CGFloat, d3: CGFloat, n: Int,
    dLow: CGFloat, dHigh: CGFloat
) -> (CGFloat, CGFloat)? {
    // Early exit: if all d values are on the same side of the band, no intersection possible.
    var dvMin = min(d0, d1)
    var dvMax = max(d0, d1)
    if n > 2 { dvMin = min(dvMin, d2); dvMax = max(dvMax, d2) }
    if n > 3 { dvMin = min(dvMin, d3); dvMax = max(dvMax, d3) }
    guard dvMax >= dLow && dvMin <= dHigh else { return nil }
    // Fast path: all control points inside the band → entire curve is inside.
    if dvMin >= dLow && dvMax <= dHigh { return (0, 1) }

    if n == 4 { return convexHullClipIntervalCubic(d0: d0, d1: d1, d2: d2, d3: d3, dLow: dLow, dHigh: dHigh) }

    // Generic path for n ≠ 4 (quadratic curves, n=3).
    let nf = CGFloat(n - 1)

    func dAt(_ i: Int) -> CGFloat {
        if i == 0 { return d0 }
        if i == 1 { return d1 }
        return d2
    }
    func cross2d(_ a: Int, _ b: Int, _ c: Int) -> CGFloat {
        let da = dAt(a); let db = dAt(b); let dc = dAt(c)
        return CGFloat(b - a) * (dc - da) - (db - da) * CGFloat(c - a)
    }

    return withUnsafeTemporaryAllocation(of: Int.self, capacity: n * 2) { buf in
        let lower = buf.baseAddress!
        let upper = buf.baseAddress! + n
        var lc = 0, uc = 0
        var tMin = CGFloat.infinity
        var tMax = -CGFloat.infinity

        for i in 0..<n {
            while lc >= 2 && cross2d(lower[lc-2], lower[lc-1], i) <= 0 { lc -= 1 }
            lower[lc] = i; lc += 1
            while uc >= 2 && cross2d(upper[uc-2], upper[uc-1], i) >= 0 { uc -= 1 }
            upper[uc] = i; uc += 1
        }
        @inline(__always) func processEdge(_ ai: Int, _ bi: Int) {
            let ta = CGFloat(ai) / nf; let da = dAt(ai)
            let tb = CGFloat(bi) / nf; let db = dAt(bi)
            if da >= dLow && da <= dHigh { tMin = min(tMin, ta); tMax = max(tMax, ta) }
            let dDelta = db - da
            if dDelta != 0 {
                let dt = tb - ta
                let dLowA = dLow - da; let dLowB = dLow - db
                if dLowA * dLowB <= 0 { let t = ta + dLowA * dt / dDelta; if t < tMin { tMin = t }; if t > tMax { tMax = t } }
                let dHighA = dHigh - da; let dHighB = dHigh - db
                if dHighA * dHighB <= 0 { let t = ta + dHighA * dt / dDelta; if t < tMin { tMin = t }; if t > tMax { tMax = t } }
            }
        }
        for i in 0..<lc-1 { processEdge(lower[i], lower[i+1]) }
        if lc > 0 { let last = lower[lc-1]; let dv = dAt(last); if dv >= dLow && dv <= dHigh { let t = CGFloat(last)/nf; tMin = min(tMin, t); tMax = max(tMax, t) } }
        for i in 0..<uc-1 { processEdge(upper[i], upper[i+1]) }
        if uc > 0 { let last = upper[uc-1]; let dv = dAt(last); if dv >= dLow && dv <= dHigh { let t = CGFloat(last)/nf; tMin = min(tMin, t); tMax = max(tMax, t) } }
        guard tMin <= tMax else { return nil }
        return (max(0, tMin), min(1, tMax))
    }
}

// Compute the fat line of `other` and clip `curve`'s [0,1] parameter range
// to where it might intersect `other`. Returns nil if no intersection possible.
private func fatLineClip<C1: BezierClippingCurve, C2: BezierClippingCurve>(curve: C1, fatOf other: C2) -> (CGFloat, CGFloat)? {
    let ocp = other.controlPolygon
    let q0  = ocp.p0
    let dir = ocp[ocp.count - 1] - q0
    guard dir.lengthSquared > 0 else { return (0, 1) }

    // Tight fat-line bounds (Sederberg & Nishita 1990):
    // For a quadratic, the curve lies within ½ of the control point's distance from the chord.
    // For a cubic when both interior points are on the same side, within ¾ of the max.
    // Tighter bounds → fewer bezier clipping iterations.
    let dMin: CGFloat
    let dMax: CGFloat
    if ocp.count == 3 {
        let d = 0.5 * (ocp.p1 - q0).cross(dir)
        dMin = min(0, d); dMax = max(0, d)
    } else if ocp.count == 4 {
        let d1 = (ocp.p1 - q0).cross(dir)
        let d2 = (ocp.p2 - q0).cross(dir)
        let factor: CGFloat = (d1 * d2 > 0) ? 0.75 : 1.0
        dMin = min(0, factor * min(d1, d2)); dMax = max(0, factor * max(d1, d2))
    } else {
        var lo: CGFloat = 0, hi: CGFloat = 0
        for i in 1..<ocp.count - 1 {
            let d = (ocp[i] - q0).cross(dir)
            if d < lo { lo = d } else if d > hi { hi = d }
        }
        dMin = lo; dMax = hi
    }

    let ccp = curve.controlPolygon
    let e0 = (ccp.p0 - q0).cross(dir)
    let e1 = (ccp.p1 - q0).cross(dir)
    let e2: CGFloat = ccp.count > 2 ? (ccp.p2 - q0).cross(dir) : 0
    let e3: CGFloat = ccp.count > 3 ? (ccp.p3 - q0).cross(dir) : 0
    return convexHullClipInterval(d0: e0, d1: e1, d2: e2, d3: e3, n: ccp.count, dLow: dMin, dHigh: dMax)
}

// Bezier clipping main recursive entry.  Returns false if the iteration
// budget was exceeded (caller falls back to implicitization).
func bezierClipping<C1, C2>(
    _ c1: Subcurve<C1>, _ c2: Subcurve<C2>,
    _ results: inout [Intersection],
    _ totalIterations: inout Int
) -> Bool where C1: NonlinearBezierCurve, C2: NonlinearBezierCurve {

    let maximumIterations    = 64
    let maximumIntersections = c1.curve.order * c2.curve.order

    // Quick bounding-box rejection using control polygon bounds (cheap: no root-finding).
    guard c1.curve.controlPolygonBounds.overlaps(c2.curve.controlPolygonBounds) else { return true }

    var c1 = c1
    var c2 = c2

    while true {
        totalIterations += 1
        guard totalIterations  <= maximumIterations    else { return false }
        guard results.count    <= maximumIntersections else { return false }

        // Clip c1 using the fat line of c2.
        guard let clip1 = fatLineClip(curve: c1.curve, fatOf: c2.curve) else { return true }
        let c1Ratio   = clip1.1 - clip1.0
        let c1Reduced = c1.split(from: clip1.0, to: clip1.1)

        // Clip c2 using the fat line of the (possibly narrowed) c1.
        guard let clip2 = fatLineClip(curve: c2.curve, fatOf: c1Reduced.curve) else { return true }
        let c2Ratio   = clip2.1 - clip2.0
        let c2Reduced = c2.split(from: clip2.0, to: clip2.1)

        let c1Range = c1Reduced.t2 - c1Reduced.t1
        let c2Range = c2Reduced.t2 - c2Reduced.t1

        // Sederberg-Nishita convergence: parameter intervals have shrunk to machine precision.
        // Fat-line naturally eliminates non-intersecting regions before this fires.
        if c1Range < 1e-10 && c2Range < 1e-10 {
            results.append(Intersection(t1: (c1Reduced.t1 + c1Reduced.t2) / 2,
                                        t2: (c2Reduced.t1 + c2Reduced.t2) / 2))
            return true
        }

        // Hybrid clipping (Lou & Liu 2011): once both sub-intervals are narrow, switch
        // from fat-line clipping to Newton-Raphson. Newton is O(n) per step vs O(n²) for
        // de Casteljau splits, and both have quadratic convergence — so Newton wins once
        // we are inside its convergence basin.
        if c1Range < 0.25 && c2Range < 0.25 && c1Ratio <= 0.8 && c2Ratio <= 0.8 {
            var u: CGFloat = 0.5, v: CGFloat = 0.5
            for _ in 0 ..< 20 {
                let (q1, d1) = c1Reduced.curve.pointAndDerivative(at: u)
                let (q2, d2) = c2Reduced.curve.pointAndDerivative(at: v)
                let f = q1 - q2
                let denom = d1.cross(d2)
                guard denom != 0 else { break }
                let du = -f.cross(d2) / denom
                let dv =  d1.cross(f) / denom
                u = Utils.clamp(u + du, 0, 1)
                v = Utils.clamp(v + dv, 0, 1)
                guard du * du + dv * dv > CGFloat(1.0e-28) else { break }
            }
            // Only accept if Newton stayed interior — if u or v is clamped to a
            // subcurve boundary the true root is outside the current interval, so
            // let fat-line clipping continue rather than reporting a boundary hit.
            if u > 1.0e-10 && u < 1.0 - 1.0e-10 && v > 1.0e-10 && v < 1.0 - 1.0e-10 {
                let t1Candidate = u * c1Reduced.t2 + (1 - u) * c1Reduced.t1
                let t2Candidate = v * c2Reduced.t2 + (1 - v) * c2Reduced.t1
                // Only accept interior solutions in global parameter space — endpoint
                // intersections are handled more precisely by the existing exact-endpoint path.
                if t1Candidate > 1.0e-6 && t1Candidate < 1.0 - 1.0e-6 &&
                   t2Candidate > 1.0e-6 && t2Candidate < 1.0 - 1.0e-6 {
                    // Verify convergence to a true intersection, not a nearest-approach point
                    // on non-intersecting curves. For a real root |f| ≈ machine-epsilon × scale;
                    // for a phantom |f| ≈ δ (separation). Use chord length as the scale reference.
                    let fFinal = c1Reduced.curve.point(at: u) - c2Reduced.curve.point(at: v)
                    let chord = (c1Reduced.curve.endingPoint - c1Reduced.curve.startingPoint).length
                    let scale = max(chord, CGFloat(1e-10))
                    if fFinal.x * fFinal.x + fFinal.y * fFinal.y < scale * scale * CGFloat(1e-12) {
                        results.append(Intersection(t1: t1Candidate, t2: t2Candidate))
                        return true
                    }
                }
            }
        }

        // If either curve reduced by less than 20 %, convergence is slow — subdivide.
        if c1Ratio > 0.8 || c2Ratio > 0.8 {
            return subdivideBezierClipping(c1Reduced, c2Reduced, &results, &totalIterations)
        }

        // Good convergence — continue alternating clipping passes.
        c1 = c1Reduced
        c2 = c2Reduced
    }
}

// Subdivide the larger-range sub-curve and recurse. Before subdividing, checks for
// exact shared endpoints (handles near-tangent cases that cause slow convergence).
private func subdivideBezierClipping<C1, C2>(
    _ c1: Subcurve<C1>, _ c2: Subcurve<C2>,
    _ results: inout [Intersection],
    _ totalIterations: inout Int
) -> Bool where C1: NonlinearBezierCurve, C2: NonlinearBezierCurve {
    // For tangent intersections at a shared endpoint, fat-line clipping near the
    // endpoint gives ratio ≈ 1.0, causing exponential blowup.  When both sub-curves
    // have already been narrowed to a small parameter range (fast convergence already
    // did its job), detect exact shared endpoints directly rather than continuing to
    // subdivide.  The range threshold is conservative: tangent cases reach this scale
    // quickly via fast convergence, while nearly-coincident cases exhaust their budget
    // long before reaching it.
    let c1Range = c1.t2 - c1.t1
    let c2Range = c2.t2 - c2.t1
    if c1Range < 0.05 && c2Range < 0.05 {
        let p1s = c1.curve.startingPoint; let p1e = c1.curve.endingPoint
        let p2s = c2.curve.startingPoint; let p2e = c2.curve.endingPoint
        if p1e == p2s { results.append(Intersection(t1: c1.t2, t2: c2.t1)); return true }
        if p1e == p2e { results.append(Intersection(t1: c1.t2, t2: c2.t2)); return true }
        if p1s == p2s { results.append(Intersection(t1: c1.t1, t2: c2.t1)); return true }
        if p1s == p2e { results.append(Intersection(t1: c1.t1, t2: c2.t2)); return true }
    }
    // Subdivide whichever has the larger global parameter range.
    if (c1.t2 - c1.t1) >= (c2.t2 - c2.t1) {
        guard c1.canSplit else {
            guard c2.canSplit else { return true }
            let h = c2.split(at: 0.5)
            guard bezierClipping(c1, h.left, &results, &totalIterations) else { return false }
            return bezierClipping(c1, h.right, &results, &totalIterations)
        }
        let h = c1.split(at: 0.5)
        guard bezierClipping(h.left, c2, &results, &totalIterations) else { return false }
        return bezierClipping(h.right, c2, &results, &totalIterations)
    } else {
        guard c2.canSplit else {
            guard c1.canSplit else { return true }
            let h = c1.split(at: 0.5)
            guard bezierClipping(h.left, c2, &results, &totalIterations) else { return false }
            return bezierClipping(h.right, c2, &results, &totalIterations)
        }
        let h = c2.split(at: 0.5)
        guard bezierClipping(c1, h.left, &results, &totalIterations) else { return false }
        return bezierClipping(c1, h.right, &results, &totalIterations)
    }
}
