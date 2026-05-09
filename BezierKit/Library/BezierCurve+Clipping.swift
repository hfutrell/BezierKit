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
    // Protocol requirements (not extension defaults) so WMO can devirtualize and inline
    // the concrete implementations at call sites where the type is statically known.
    var controlPolygonBounds: BoundingBox { get }
    // Given pre-computed distances d0..d3 from the fat-line chord, returns the
    // parameter sub-interval of [0,1] where the curve might cross [dLow,dHigh].
    // Protocol requirement (not a free function) so WMO devirtualizes to the
    // type-specific implementation, eliminating n-dispatch branches.
    // swiftlint:disable:next function_parameter_count
    func clipInterval(d0: CGFloat, d1: CGFloat, d2: CGFloat, d3: CGFloat,
                      dLow: CGFloat, dHigh: CGFloat) -> (CGFloat, CGFloat)?
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

    // Direct override: avoids the generic loop over ControlPolygon.count, letting the
    // compiler emit fmin/fmax over 4 known fields instead of an unrolled branch chain.
    @inline(__always)
    var controlPolygonBounds: BoundingBox {
        BoundingBox(min: CGPoint(x: min(min(p0.x, p1.x), min(p2.x, p3.x)),
                                 y: min(min(p0.y, p1.y), min(p2.y, p3.y))),
                    max: CGPoint(x: max(max(p0.x, p1.x), max(p2.x, p3.x)),
                                 y: max(max(p0.y, p1.y), max(p2.y, p3.y))))
    }

    // swiftlint:disable:next function_parameter_count
    func clipInterval(d0: CGFloat, d1: CGFloat, d2: CGFloat, d3: CGFloat,
                      dLow: CGFloat, dHigh: CGFloat) -> (CGFloat, CGFloat)? {
        // Bernstein polynomials lie in the convex hull of their control values.
        // If all four are outside the band on the same side, no intersection is possible.
        if d0 > dHigh && d1 > dHigh && d2 > dHigh && d3 > dHigh { return nil }
        if d0 < dLow && d1 < dLow && d2 < dLow && d3 < dLow { return nil }
        // Both curve endpoints inside the band: convex hull trivially spans [0, 1].
        if d0 >= dLow && d0 <= dHigh && d3 >= dLow && d3 <= dHigh { return (0.0, 1.0) }
        return convexHullClipIntervalCubic(d0: d0, d1: d1, d2: d2, d3: d3, dLow: dLow, dHigh: dHigh)
    }
}

extension QuadraticCurve: BezierClippingCurve {
    var controlPolygon: ControlPolygon { ControlPolygon(p0, p1, p2) }

    @inline(__always)
    var controlPolygonBounds: BoundingBox {
        BoundingBox(min: CGPoint(x: min(min(p0.x, p1.x), p2.x),
                                 y: min(min(p0.y, p1.y), p2.y)),
                    max: CGPoint(x: max(max(p0.x, p1.x), p2.x),
                                 y: max(max(p0.y, p1.y), p2.y)))
    }

    // swiftlint:disable:next function_parameter_count
    func clipInterval(d0: CGFloat, d1: CGFloat, d2: CGFloat, d3: CGFloat,
                      dLow: CGFloat, dHigh: CGFloat) -> (CGFloat, CGFloat)? {
        // d3 unused: quadratic has only 3 control points
        // Bernstein polynomials lie in the convex hull of their control values.
        // If all three are outside the band on the same side, no intersection is possible.
        if d0 > dHigh && d1 > dHigh && d2 > dHigh { return nil }
        if d0 < dLow && d1 < dLow && d2 < dLow { return nil }
        // Both curve endpoints inside the band: convex hull trivially spans [0, 1].
        if d0 >= dLow && d0 <= dHigh && d2 >= dLow && d2 <= dHigh { return (0.0, 1.0) }
        return convexHullClipIntervalQuadratic(d0: d0, d1: d1, d2: d2, dLow: dLow, dHigh: dHigh)
    }
}

// MARK: - ClipBuffer

// Stack-allocated result buffer for bezierClipping.
// Capacity 13 covers the worst case: up to order₁×order₂ ≤ 9 Newton-refined intersections
// plus up to 4 endpoint intersections added by addEndpointIntersections.
// Individual stored properties (not a tuple) keep SwiftLint's large_tuple rule satisfied.
struct ClipBuffer {
    private var s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12: Intersection
    private(set) var count: Int

    init() {
        let z = Intersection(t1: 0, t2: 0)
        s0 = z; s1 = z; s2 = z; s3 = z; s4 = z; s5 = z; s6 = z
        s7 = z; s8 = z; s9 = z; s10 = z; s11 = z; s12 = z; count = 0
    }

    var isEmpty: Bool { count == 0 }

    subscript(i: Int) -> Intersection {
        get {
            switch i {
            case 0: return s0
            case 1: return s1
            case 2: return s2
            case 3: return s3
            case 4: return s4
            case 5: return s5
            case 6: return s6
            case 7: return s7
            case 8: return s8
            case 9: return s9
            case 10: return s10
            case 11: return s11
            default: return s12
            }
        }
        set {
            switch i {
            case 0: s0 = newValue
            case 1: s1 = newValue
            case 2: s2 = newValue
            case 3: s3 = newValue
            case 4: s4 = newValue
            case 5: s5 = newValue
            case 6: s6 = newValue
            case 7: s7 = newValue
            case 8: s8 = newValue
            case 9: s9 = newValue
            case 10: s10 = newValue
            case 11: s11 = newValue
            default: s12 = newValue
            }
        }
    }

    mutating func append(_ intersection: Intersection) {
        self[count] = intersection
        count += 1
    }

    func contains(where predicate: (Intersection) -> Bool) -> Bool {
        for i in 0..<count where predicate(self[i]) { return true }
        return false
    }

    func firstIndex(where predicate: (Intersection) -> Bool) -> Int? {
        for i in 0..<count where predicate(self[i]) { return i }
        return nil
    }

    mutating func sort() {
        for i in 1..<count {
            let key = self[i]
            var j = i - 1
            while j >= 0 && self[j] > key { self[j + 1] = self[j]; j -= 1 }
            self[j + 1] = key
        }
    }

    func toSortedArray() -> [Intersection] {
        var copy = self; copy.sort()
        return (0..<copy.count).map { copy[$0] }
    }

    func toSortedAndUniquedArray() -> [Intersection] {
        guard count > 0 else { return [] }
        var copy = self; copy.sort()
        var arr: [Intersection] = []
        arr.reserveCapacity(copy.count)
        arr.append(copy[0])
        for i in 1..<copy.count where copy[i] != copy[i - 1] { arr.append(copy[i]) }
        return arr
    }
}

// MARK: - Bezier Clipping (Sederberg & Nishita, 1990)

// Clips one convex-hull edge (ta, da)→(ta+dt, db) against the fat-line band [dLow, dHigh].
// Returns updated (lo, hi). Accepting (lo, hi) explicitly avoids captured-var exclusivity
// overhead (swift_beginAccess) that the compiler inserts for captured `var` bindings.
@inline(__always)
private func hullEdgeClipInterval(
    _ da: CGFloat, _ db: CGFloat, _ ta: CGFloat, _ dt: CGFloat,
    _ dLow: CGFloat, _ dHigh: CGFloat,
    _ lo: CGFloat, _ hi: CGFloat
) -> (CGFloat, CGFloat) {
    var lo = lo, hi = hi
    if da >= dLow && da <= dHigh { if ta < lo { lo = ta }; if ta > hi { hi = ta } }
    // IEEE-754 safe with no dDelta != 0 guard: when da==db, recip=±inf; crossing tests
    // (dLowA*dLowB<=0) collapse to a perfect square (≥0), which fires only when dLow==da,
    // giving t = ta + 0*±inf = NaN; NaN comparisons are false — no spurious lo/hi update.
    let dDelta = db - da
    let recip = dt / dDelta
    let dLowA = dLow - da; let dLowB = dLow - db
    if dLowA * dLowB <= 0 { let t = ta.addingProduct(dLowA, recip); if t < lo { lo = t }; if t > hi { hi = t } }
    let dHighA = dHigh - da; let dHighB = dHigh - db
    if dHighA * dHighB <= 0 { let t = ta.addingProduct(dHighA, recip); if t < lo { lo = t }; if t > hi { hi = t } }
    return (lo, hi)
}

// Processes one hull (lower or upper) for convexHullClipIntervalCubic.
// File-level rather than nested so the compiler can inline both calls into the outer
// function: nested-func @inline(__always) only inlines one of the two call sites in WMO.
// All dependencies passed explicitly — no closure captures, no swift_beginAccess overhead.
// Cross products: c012 = d0 - 2·d1 + d2  (c023, c123, c013 computed lazily on demand).
@inline(__always)
private func processHullCubic(
    sign: CGFloat, lo: CGFloat, hi: CGFloat,
    d0: CGFloat, d1: CGFloat, d2: CGFloat, d3: CGFloat,
    c012: CGFloat, dLow: CGFloat, dHigh: CGFloat
) -> (CGFloat, CGFloat) {
    var lo = lo, hi = hi
    if sign * c012 <= 0 {
        let c023 = d0 - 3*d2 + 2*d3
        if sign * c023 <= 0 {
            (lo, hi) = hullEdgeClipInterval(d0, d3, 0, 1, dLow, dHigh, lo, hi)
        } else {
            (lo, hi) = hullEdgeClipInterval(d0, d2, 0, 2.0/3, dLow, dHigh, lo, hi)
            (lo, hi) = hullEdgeClipInterval(d2, d3, 2.0/3, 1.0/3, dLow, dHigh, lo, hi)
        }
    } else {
        let c123 = d1 - 2*d2 + d3
        if sign * c123 <= 0 {
            let c013 = 2*d0 - 3*d1 + d3
            if sign * c013 <= 0 {
                (lo, hi) = hullEdgeClipInterval(d0, d3, 0, 1, dLow, dHigh, lo, hi)
            } else {
                (lo, hi) = hullEdgeClipInterval(d0, d1, 0, 1.0/3, dLow, dHigh, lo, hi)
                (lo, hi) = hullEdgeClipInterval(d1, d3, 1.0/3, 2.0/3, dLow, dHigh, lo, hi)
            }
        } else {
            (lo, hi) = hullEdgeClipInterval(d0, d1, 0, 1.0/3, dLow, dHigh, lo, hi)
            (lo, hi) = hullEdgeClipInterval(d1, d2, 1.0/3, 1.0/3, dLow, dHigh, lo, hi)
            (lo, hi) = hullEdgeClipInterval(d2, d3, 2.0/3, 1.0/3, dLow, dHigh, lo, hi)
        }
    }
    return (lo, hi)
}

// n=4 specialization: returns the sub-interval [tMin,tMax] ⊆ [0,1] where d0..d3 might
// lie within [dLow,dHigh]. Includes fast-path early-exit so the caller (clipInterval,
// which @inline(__always) into fatLineClip → bezierClipping) need not duplicate this logic.
// Cross products proportional to cross2d for 4 uniformly-spaced points (t ∈ {0, 1/3, 2/3, 1}):
//   c012 = d0 - 2·d1 + d2
//   c023 = d0 - 3·d2 + 2·d3
//   c123 = d1 - 2·d2 + d3
//   c013 = 2·d0 - 3·d1 + d3
private func convexHullClipIntervalCubic(
    d0: CGFloat, d1: CGFloat, d2: CGFloat, d3: CGFloat,
    dLow: CGFloat, dHigh: CGFloat
) -> (CGFloat, CGFloat)? {
    let c012 = d0 - 2*d1 + d2
    var tMin = CGFloat.infinity, tMax = -CGFloat.infinity
    (tMin, tMax) = processHullCubic(sign: 1, lo: tMin, hi: tMax,
                                    d0: d0, d1: d1, d2: d2, d3: d3,
                                    c012: c012, dLow: dLow, dHigh: dHigh)
    (tMin, tMax) = processHullCubic(sign: -1, lo: tMin, hi: tMax,
                                    d0: d0, d1: d1, d2: d2, d3: d3,
                                    c012: c012, dLow: dLow, dHigh: dHigh)
    // d3 at t=1 is always the final vertex of both hulls.
    if d3 >= dLow && d3 <= dHigh { if tMin > 1 { tMin = 1 }; if tMax < 1 { tMax = 1 } }
    guard tMin <= tMax else { return nil }
    return (max(0, tMin), min(1, tMax))
}

// n=3 specialization (quadratic curves). Early-exit handled by clipInterval thunk.
// c012 alone determines which of the two hull shapes applies:
//   c012 <= 0: lower=[0,2], upper=[0,1,2]   (d1 above chord d0→d2)
//   c012 > 0:  lower=[0,1,2], upper=[0,2]   (d1 below chord d0→d2)
private func convexHullClipIntervalQuadratic(
    d0: CGFloat, d1: CGFloat, d2: CGFloat,
    dLow: CGFloat, dHigh: CGFloat
) -> (CGFloat, CGFloat)? {
    let c012 = d0 - 2*d1 + d2
    var tMin = CGFloat.infinity, tMax = -CGFloat.infinity
    if c012 <= 0 {
        (tMin, tMax) = hullEdgeClipInterval(d0, d2, 0, 1, dLow, dHigh, tMin, tMax) // lower: 0→2
        (tMin, tMax) = hullEdgeClipInterval(d0, d1, 0, 0.5, dLow, dHigh, tMin, tMax) // upper: 0→1
        (tMin, tMax) = hullEdgeClipInterval(d1, d2, 0.5, 0.5, dLow, dHigh, tMin, tMax) // upper: 1→2
    } else {
        (tMin, tMax) = hullEdgeClipInterval(d0, d1, 0, 0.5, dLow, dHigh, tMin, tMax) // lower: 0→1
        (tMin, tMax) = hullEdgeClipInterval(d1, d2, 0.5, 0.5, dLow, dHigh, tMin, tMax) // lower: 1→2
        (tMin, tMax) = hullEdgeClipInterval(d0, d2, 0, 1, dLow, dHigh, tMin, tMax) // upper: 0→2
    }
    // d2 at t=1 is always the final vertex of both hulls.
    if d2 >= dLow && d2 <= dHigh { if tMin > 1 { tMin = 1 }; if tMax < 1 { tMax = 1 } }
    guard tMin <= tMax else { return nil }
    return (max(0, tMin), min(1, tMax))
}

// Compute the fat line of `other` and clip `curve`'s [0,1] parameter range
// to where it might intersect `other`. Returns nil if no intersection possible.
@inline(__always)
private func fatLineClip<C1: BezierClippingCurve, C2: BezierClippingCurve>(curve: C1, fatOf other: C2) -> (CGFloat, CGFloat)? {
    let ocp = other.controlPolygon
    let q0  = ocp.p0
    let dir = ocp[ocp.count - 1] - q0

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
        // Pre-computing lo/hi lets the compiler reuse the same min/max values for both the
        // sign check (lo*hi > 0) and the final multiply, avoiding redundant comparisons.
        // The original (d1*d2>0) form generates 7 branches for random-sign inputs; this
        // version compiles to 18 straight-line instructions (verified by assembly inspection).
        let lo = min(d1, d2); let hi = max(d1, d2)
        let f: CGFloat = lo * hi > 0 ? 0.75 : 1.0
        dMin = min(CGFloat(0), f * lo); dMax = max(CGFloat(0), f * hi)
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
    return curve.clipInterval(d0: e0, d1: e1, d2: e2, d3: e3, dLow: dMin, dHigh: dMax)
}

// Bezier clipping main recursive entry.  Returns false if the iteration
// budget was exceeded (caller falls back to implicitization).
func bezierClipping<C1, C2>(
    _ c1: Subcurve<C1>, _ c2: Subcurve<C2>,
    _ results: inout ClipBuffer,
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

        let c1Range = c1Reduced.t2 - c1Reduced.t1
        // Sederberg-Nishita: if the first clip barely narrows c1 and c1 still spans
        // substantial global range, subdivide immediately without computing the second clip.
        // When c1Ratio ≈ 1, c1Reduced ≈ c1, so the second clip's fat line provides almost
        // no additional narrowing of c2 — computing it is wasted work before subdivision.
        // Guard c1Range >= 1e-10: if c1 is already tiny (degenerate sub-curve), the
        // convergence check below must run to detect simultaneous c1+c2 convergence.
        if c1Ratio > 0.8 && c1Range >= 1e-10 {
            return subdivideBezierClipping(c1Reduced, c2, &results, &totalIterations)
        }

        // Clip c2 using the fat line of the (possibly narrowed) c1.
        guard let clip2 = fatLineClip(curve: c2.curve, fatOf: c1Reduced.curve) else { return true }
        let c2Ratio   = clip2.1 - clip2.0
        let c2Reduced = c2.split(from: clip2.0, to: clip2.1)

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
        // c1Ratio <= 0.8 is guaranteed by the early-subdivision above.
        // 12 iterations: well-conditioned crossings converge in ≈5 steps; near-tangent
        // cases (small Jacobian) need up to ~10; the guard `du²+dv²≤1e-28` exits early.
        if c1Range < 0.25 && c2Range < 0.25 && c2Ratio <= 0.8 {
            var u: CGFloat = 0.5, v: CGFloat = 0.5
            for _ in 0 ..< 16 {
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
            // Require at least one parameter to be interior in its subcurve's local space.
            // If BOTH are clamped the Newton system failed (near-parallel tangents, etc.)
            // and the nearest-approach point is a phantom; skip rather than reporting.
            // One clamped parameter is fine: endpoint-interior intersections have Newton
            // converge to the subcurve boundary that coincides with curve2's actual endpoint.
            if (u > 1.0e-10 && u < 1.0 - 1.0e-10) || (v > 1.0e-10 && v < 1.0 - 1.0e-10) {
                let t1Candidate = u * c1Reduced.t2 + (1 - u) * c1Reduced.t1
                let t2Candidate = v * c2Reduced.t2 + (1 - v) * c2Reduced.t1
                // Accept when at least one global parameter is interior. Endpoint-endpoint
                // cases (both at 0 or 1) are handled by addEndpointIntersections.
                // Endpoint-interior cases (one endpoint, one interior) are valid here;
                // newtonIsGenuineRoot below filters any false positives.
                if (t1Candidate > 1.0e-6 && t1Candidate < 1.0 - 1.0e-6) ||
                   (t2Candidate > 1.0e-6 && t2Candidate < 1.0 - 1.0e-6) {
                    // Verify convergence to a true intersection, not a nearest-approach point
                    // on non-intersecting curves. For a real root |f| ≈ machine-epsilon × scale;
                    // for a phantom |f| ≈ δ (separation). Use chord length as the scale reference.
                    // Compare squared distances to avoid sqrt (max(chord,1e-10)² = max(chord²,1e-20)).
                    let fFinal = c1Reduced.curve.point(at: u) - c2Reduced.curve.point(at: v)
                    // Use lengthSquared to avoid sqrt — the threshold is squared below anyway.
                    let chordSq = (c1Reduced.curve.endingPoint - c1Reduced.curve.startingPoint).lengthSquared
                    let scaleSq = max(chordSq, CGFloat(1e-20))
                    if fFinal.x * fFinal.x + fFinal.y * fFinal.y < scaleSq * CGFloat(1e-12) {
                        let isDuplicate = results.contains {
                            Swift.abs($0.t1 - t1Candidate) < 1e-5 && Swift.abs($0.t2 - t2Candidate) < 1e-5
                        }
                        if !isDuplicate { results.append(Intersection(t1: t1Candidate, t2: t2Candidate)) }
                        // If the window still spans multiple potential intersections, subdivide to
                        // catch nearby crossings that Newton converged away from.
                        guard c1Range > 0.01 || c2Range > 0.01 else { return true }
                        return subdivideBezierClipping(c1Reduced, c2Reduced, &results, &totalIterations)
                    }
                }
            }
        }

        // If c2 reduced by less than 20 %, convergence is slow — subdivide.
        // (c1Ratio > 0.8 was already handled with early return above.)
        if c2Ratio > 0.8 {
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
    _ results: inout ClipBuffer,
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
    if c1Range >= c2Range {
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
