//
//  BezierCurve+MonotoneIntersection.swift
//  BezierKit
//
//  Copyright © 2024 Holmes Futrell. All rights reserved.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

extension Utils {

    // Lightweight segment descriptor for the monotonic fast-path.
    // Once a curve's control polygon is monotone in both x and y, its actual curve
    // is also monotone, so its tight bounding box equals [startPoint, endPoint].
    // Sub-curves produced by de Casteljau subdivision inherit monotonicity,
    // so the fast path only needs one point evaluation per split instead of a full
    // split() + boundingBox() recomputation.
    private struct MonoSeg {
        var t1, t2: CGFloat  // curve parameter range (for Intersection output and point(at:))
        var bbox: BoundingBox
        var span: CGFloat { (bbox.max.x - bbox.min.x) + (bbox.max.y - bbox.min.y) }
        var canSplit: Bool {
            let mid = (t1 + t2) * 0.5
            return mid > t1 && mid < t2
        }
        func p1(xFwd: Bool, yFwd: Bool) -> CGPoint {
            CGPoint(x: xFwd ? bbox.min.x : bbox.max.x, y: yFwd ? bbox.min.y : bbox.max.y)
        }
        func p2(xFwd: Bool, yFwd: Bool) -> CGPoint {
            CGPoint(x: xFwd ? bbox.max.x : bbox.min.x, y: yFwd ? bbox.max.y : bbox.min.y)
        }
    }

    @inline(__always)
    private static func monoOverlap(_ a: MonoSeg, _ b: MonoSeg) -> Bool {
        return a.bbox.overlaps(b.bbox)
    }

    // Writes sorted breakpoints for curve into buf[0..<return_value].
    // buf must have capacity >= 4 (max: 2 x-roots + 2 y-roots for a cubic).
    @inline(__always)
    private static func fillBreakpoints<C: BezierCurve>(_ curve: C, _ buf: UnsafeMutablePointer<CGFloat>) -> Int {
        var n = 0
        if let c = curve as? CubicCurve {
            Utils.droots(c.p1.x - c.p0.x, c.p2.x - c.p1.x, c.p3.x - c.p2.x) { t in
                if t > 0 && t < 1 { buf[n] = t; n += 1 }
            }
            Utils.droots(c.p1.y - c.p0.y, c.p2.y - c.p1.y, c.p3.y - c.p2.y) { t in
                if t > 0 && t < 1 { buf[n] = t; n += 1 }
            }
        } else if let q = curve as? QuadraticCurve {
            Utils.droots(q.p1.x - q.p0.x, q.p2.x - q.p1.x) { t in
                if t > 0 && t < 1 { buf[n] = t; n += 1 }
            }
            Utils.droots(q.p1.y - q.p0.y, q.p2.y - q.p1.y) { t in
                if t > 0 && t < 1 { buf[n] = t; n += 1 }
            }
        }
        // Insertion sort — at most 4 elements, so effectively O(1).
        if n > 1 {
            for i in 1..<n {
                let key = buf[i]; var j = i
                while j > 0 && buf[j - 1] > key { buf[j] = buf[j - 1]; j -= 1 }
                buf[j] = key
            }
        }
        return n
    }

    // Intersect two NonlinearBezierCurves by splitting each upfront at its derivative roots
    // to produce monotone pieces, then running monoPairiteration on each overlapping pair.
    // Returns false only if the iteration limit is hit (coincident curves), signalling the caller
    // to fall through to the coincidence check and fallback.
    // All working memory is stack-allocated via withUnsafeTemporaryAllocation — no heap allocation
    // in the hot path except the final bulk copy into the results array.
    static func preSplitIntersections<C1: NonlinearBezierCurve, C2: NonlinearBezierCurve>(
        _ curve1: C1, _ curve2: C2,
        _ results: inout [Intersection],
        _ accuracy: CGFloat,
        _ totalIterations: inout Int
    ) -> Bool {
        guard curve1.boundingBox.overlaps(curve2.boundingBox) else { return true }
        let maxIntersections = curve1.order * curve2.order

        // Splits: [0, ≤4 breakpoints, 1] = ≤6 entries per curve.
        // Stack: 80 × (MonoSeg, MonoSeg). We always split exactly one curve per step (the larger),
        // so stack depth ≤ 2×log2(span/accuracy)+1 ≈ 67 for accuracy=1e-10.
        // Results: collected into a fixed buffer, bulk-copied to output once at the end.
        return withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 6) { s1Buf -> Bool in
        withUnsafeTemporaryAllocation(of: CGPoint.self, capacity: 6) { p1Buf -> Bool in
        withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 6) { s2Buf -> Bool in
        withUnsafeTemporaryAllocation(of: CGPoint.self, capacity: 6) { p2Buf -> Bool in
        withUnsafeTemporaryAllocation(of: (MonoSeg, MonoSeg).self, capacity: 80) { stackBuf -> Bool in
        withUnsafeTemporaryAllocation(of: Intersection.self, capacity: maxIntersections + 1) { resBuf -> Bool in
            var resCount = 0

            s1Buf[0] = 0
            let bk1 = fillBreakpoints(curve1, s1Buf.baseAddress! + 1)
            s1Buf[bk1 + 1] = 1
            let n1 = bk1 + 2
            p1Buf[0] = curve1.startingPoint
            for k in 1..<n1 - 1 { p1Buf[k] = curve1.point(at: s1Buf[k]) }
            p1Buf[n1 - 1] = curve1.endingPoint

            s2Buf[0] = 0
            let bk2 = fillBreakpoints(curve2, s2Buf.baseAddress! + 1)
            s2Buf[bk2 + 1] = 1
            let n2 = bk2 + 2
            p2Buf[0] = curve2.startingPoint
            for k in 1..<n2 - 1 { p2Buf[k] = curve2.point(at: s2Buf[k]) }
            p2Buf[n2 - 1] = curve2.endingPoint

            for i in 0..<n1 - 1 {
                let xFwd1 = p1Buf[i].x <= p1Buf[i + 1].x, yFwd1 = p1Buf[i].y <= p1Buf[i + 1].y
                let seg1 = MonoSeg(t1: s1Buf[i], t2: s1Buf[i + 1], bbox: BoundingBox(
                    min: CGPoint(x: xFwd1 ? p1Buf[i].x : p1Buf[i+1].x, y: yFwd1 ? p1Buf[i].y : p1Buf[i+1].y),
                    max: CGPoint(x: xFwd1 ? p1Buf[i+1].x : p1Buf[i].x, y: yFwd1 ? p1Buf[i+1].y : p1Buf[i].y)))
                for j in 0..<n2 - 1 {
                    let xFwd2 = p2Buf[j].x <= p2Buf[j + 1].x, yFwd2 = p2Buf[j].y <= p2Buf[j + 1].y
                    let seg2 = MonoSeg(t1: s2Buf[j], t2: s2Buf[j + 1], bbox: BoundingBox(
                        min: CGPoint(x: xFwd2 ? p2Buf[j].x : p2Buf[j+1].x, y: yFwd2 ? p2Buf[j].y : p2Buf[j+1].y),
                        max: CGPoint(x: xFwd2 ? p2Buf[j+1].x : p2Buf[j].x, y: yFwd2 ? p2Buf[j+1].y : p2Buf[j].y)))
                    guard monoOverlap(seg1, seg2) else { continue }
                    guard monoPairiteration(curve1, seg1, xFwd1, yFwd1, curve2, seg2, xFwd2, yFwd2,
                                            resBuf, &resCount,
                                            accuracy, maxIntersections,
                                            stackBuf, &totalIterations) else { return false }
                }
            }

            // Bulk-copy accumulated results into the output array (single allocation if needed).
            if resCount > 0 {
                results.reserveCapacity(results.count + resCount)
                for i in 0..<resCount { results.append(resBuf[i]) }
            }
            return true
        }}}}}}
    }

    // Inner split step for monoPairiteration. Splits `splitting` at its midpoint, evaluates
    // overlap of each half against `fixed`, and updates splitting/stack accordingly.
    // splitIsS1 is a compile-time constant at each inlined call site, so the compiler
    // eliminates the stack-ordering branch entirely.
    @inline(__always)
    private static func monoSplitStep<C: BezierCurve>(
        splitting: inout MonoSeg, fixed: MonoSeg,
        curve: C, xFwd: Bool, yFwd: Bool,
        splitIsS1: Bool,
        stackBuf: UnsafeMutableBufferPointer<(MonoSeg, MonoSeg)>,
        top: inout Int
    ) -> Bool {
        let mT = (splitting.t1 + splitting.t2) * 0.5
        let pM = curve.point(at: mT)
        let rsOK = (xFwd ? pM.x <= fixed.bbox.max.x : pM.x >= fixed.bbox.min.x) &&
                   (yFwd ? pM.y <= fixed.bbox.max.y : pM.y >= fixed.bbox.min.y)
        let lsOK = (xFwd ? pM.x >= fixed.bbox.min.x : pM.x <= fixed.bbox.max.x) &&
                   (yFwd ? pM.y >= fixed.bbox.min.y : pM.y <= fixed.bbox.max.y)
        let s = splitting
        let makeLs = { MonoSeg(t1: s.t1, t2: mT, bbox: BoundingBox(
            min: CGPoint(x: xFwd ? s.bbox.min.x : pM.x, y: yFwd ? s.bbox.min.y : pM.y),
            max: CGPoint(x: xFwd ? pM.x : s.bbox.max.x, y: yFwd ? pM.y : s.bbox.max.y))) }
        let makeRs = { MonoSeg(t1: mT, t2: s.t2, bbox: BoundingBox(
            min: CGPoint(x: xFwd ? pM.x : s.bbox.min.x, y: yFwd ? pM.y : s.bbox.min.y),
            max: CGPoint(x: xFwd ? s.bbox.max.x : pM.x, y: yFwd ? s.bbox.max.y : pM.y))) }
        if rsOK && lsOK {
            stackBuf[top] = splitIsS1 ? (makeRs(), fixed) : (fixed, makeRs()); top += 1
            splitting = makeLs()
            return true
        } else if lsOK {
            splitting = makeLs()
            return true
        } else if rsOK {
            splitting = makeRs()
            return true
        }
        return false
    }

    // Iterative intersection for pairs of monotone subcurves.
    // Accepts pre-allocated stack and result buffers from preSplitIntersections so that
    // no heap allocation occurs inside the tight loop.
    // xFwd1/yFwd1/xFwd2/yFwd2 are the monotone directions of s1 and s2; subdivision preserves
    // them so they are constant throughout the call.
    // swiftlint:disable:next function_parameter_count function_body_length
    private static func monoPairiteration<C1: BezierCurve, C2: BezierCurve>(
        _ c1: C1, _ s1initial: MonoSeg, _ xFwd1: Bool, _ yFwd1: Bool,
        _ c2: C2, _ s2initial: MonoSeg, _ xFwd2: Bool, _ yFwd2: Bool,
        _ resBuf: UnsafeMutableBufferPointer<Intersection>,
        _ resCount: inout Int,
        _ accuracy: CGFloat,
        _ maxIntersections: Int,
        _ stackBuf: UnsafeMutableBufferPointer<(MonoSeg, MonoSeg)>,
        _ totalIterations: inout Int
    ) -> Bool {
        let stackCapacity = stackBuf.count
        var top = 0
        var curS1 = s1initial, curS2 = s2initial

        while true {
            #if DEBUG
            // Sanity invariant: every stack pair overlaps. The check is tolerant of floating-point
            // rounding scaled to the platform's precision and the coordinate magnitude — on 32-bit
            // CGFloat (WASM) a midpoint evaluation at large coordinates can shift a child's bbox by
            // a few ULPs, which is harmless (the Cramer's-rule leaf test rejects non-overlap anyway).
            do {
                let a = curS1.bbox, b = curS2.bbox
                let scale = Swift.max(Swift.abs(a.min.x), Swift.abs(a.max.x), Swift.abs(b.min.x), Swift.abs(b.max.x),
                                      Swift.abs(a.min.y), Swift.abs(a.max.y), Swift.abs(b.min.y), Swift.abs(b.max.y), 1)
                let tol = 256 * scale * CGFloat.ulpOfOne
                assert(a.min.x <= b.max.x + tol && b.min.x <= a.max.x + tol &&
                       a.min.y <= b.max.y + tol && b.min.y <= a.max.y + tol,
                       "monoPairiteration invariant: every stack pair must overlap (within FP tolerance)")
            }
            #endif

            totalIterations += 1
            guard totalIterations <= 900 else { return false }
            guard resCount <= maxIntersections else { return false }

            let r1 = curS1.canSplit && curS1.span >= accuracy
            let r2 = curS2.canSplit && curS2.span >= accuracy

            if !r1 && !r2 {
                // Use Cramer's rule directly to avoid false positives from FP-coincident
                // endpoints when both curves are tangent near a shared boundary point.
                let sp1 = curS1.p1(xFwd: xFwd1, yFwd: yFwd1), sp2 = curS1.p2(xFwd: xFwd1, yFwd: yFwd1)
                let tp1 = curS2.p1(xFwd: xFwd2, yFwd: yFwd2), tp2 = curS2.p2(xFwd: xFwd2, yFwd: yFwd2)
                let b1x = sp2.x - sp1.x, b1y = sp2.y - sp1.y
                let b2x = tp2.x - tp1.x, b2y = tp2.y - tp1.y
                let det = b1x * (-b2y) - (-b2x) * b1y
                let scale = (Swift.abs(b1x) + Swift.abs(b1y)) * (Swift.abs(b2x) + Swift.abs(b2y))
                let inv_det = 1.0 / det
                if Swift.abs(det) > CGFloat(Utils.epsilon) * scale {
                    let ex = tp1.x - sp1.x, ey = tp1.y - sp1.y
                    var lt1 = (ex * (-b2y) - (-b2x) * ey) * inv_det
                    var lt2 = (b1x * ey - ex * b1y) * inv_det
                    // When an endpoint snaps, reproject from that exact point so both
                    // adjacent mono-path calls produce bit-identical t values at boundaries.
                    if Utils.approximately(Double(lt1), 0, precision: Utils.epsilon) {
                        lt1 = 0
                        lt2 = Swift.abs(b2x) >= Swift.abs(b2y)
                            ? (sp1.x - tp1.x) / b2x
                            : (sp1.y - tp1.y) / b2y
                    } else if Utils.approximately(Double(lt1), 1, precision: Utils.epsilon) {
                        lt1 = 1
                        lt2 = Swift.abs(b2x) >= Swift.abs(b2y)
                            ? (sp2.x - tp1.x) / b2x
                            : (sp2.y - tp1.y) / b2y
                    }
                    if Utils.approximately(Double(lt2), 0, precision: Utils.epsilon) {
                        lt2 = 0
                        if lt1 != 0 && lt1 != 1 {
                            lt1 = Swift.abs(b1x) >= Swift.abs(b1y)
                                ? (tp1.x - sp1.x) / b1x
                                : (tp1.y - sp1.y) / b1y
                        }
                    } else if Utils.approximately(Double(lt2), 1, precision: Utils.epsilon) {
                        lt2 = 1
                        if lt1 != 0 && lt1 != 1 {
                            lt1 = Swift.abs(b1x) >= Swift.abs(b1y)
                                ? (tp2.x - sp1.x) / b1x
                                : (tp2.y - sp1.y) / b1y
                        }
                    }
                    if lt1 >= 0, lt1 <= 1, lt2 >= 0, lt2 <= 1 {
                        let gt1 = lt1 == 0 ? curS1.t1 : lt1 == 1 ? curS1.t2 : lt1 * curS1.t2 + (1 - lt1) * curS1.t1
                        let gt2 = lt2 == 0 ? curS2.t1 : lt2 == 1 ? curS2.t2 : lt2 * curS2.t2 + (1 - lt2) * curS2.t1
                        resBuf[resCount] = Intersection(t1: gt1, t2: gt2)
                        resCount += 1
                    }
                } else if sp2 == c1.endingPoint && tp1 == c2.startingPoint {
                    // Parallel segments sharing a genuine curve endpoint (e.g. tangent junction).
                    resBuf[resCount] = Intersection(t1: curS1.t2, t2: curS2.t1)
                    resCount += 1
                } else if sp1 == c1.startingPoint && tp2 == c2.endingPoint {
                    resBuf[resCount] = Intersection(t1: curS1.t1, t2: curS2.t2)
                    resCount += 1
                }
                // Pop next pair or exit.
                guard top > 0 else { break }
                top -= 1
                (curS1, curS2) = stackBuf[top]
            } else {
                // Split only the curve with the larger span (or the only splittable one).
                guard top + 1 <= stackCapacity else { return false }
                let hadChild: Bool
                if r1 && (!r2 || curS1.span >= curS2.span) {
                    hadChild = monoSplitStep(splitting: &curS1, fixed: curS2, curve: c1, xFwd: xFwd1, yFwd: yFwd1,
                                             splitIsS1: true, stackBuf: stackBuf, top: &top)
                } else {
                    hadChild = monoSplitStep(splitting: &curS2, fixed: curS1, curve: c2, xFwd: xFwd2, yFwd: yFwd2,
                                             splitIsS1: false, stackBuf: stackBuf, top: &top)
                }
                if !hadChild {
                    // No children: pop next pair or exit.
                    guard top > 0 else { break }
                    top -= 1
                    (curS1, curS2) = stackBuf[top]
                }
            }
        }
        return true
    }
}
