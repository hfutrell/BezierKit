//
//  Utils.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/3/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

internal extension Array where Element: Comparable {
    func sortedAndUniqued() -> [Element] {
        guard self.count > 1 else { return self }
        return self.sorted().duplicatesRemovedFromSorted()
    }
    func duplicatesRemovedFromSorted() -> [Element] {
        return self.indices.compactMap {
            let element = self[$0]
            guard $0 > self.startIndex else { return element }
            guard element != self[$0 - 1] else { return nil }
            return element
        }
    }
}

internal extension Array where Element == Intersection {
    func sortedAndUniqued() -> [Intersection] {
        guard self.count > 1 else { return self }
        let sorted = self.sorted()
        return sorted.indices.compactMap { i -> Intersection? in
            let element = sorted[i]
            guard i > sorted.startIndex else { return element }
            let prev = sorted[i - 1]
            // Use approximate equality to handle near-duplicate boundary intersections
            // that arise when adjacent monotone segments independently find the same point.
            guard !Utils.approximately(Double(element.t1), Double(prev.t1), precision: Utils.epsilon)
               || !Utils.approximately(Double(element.t2), Double(prev.t2), precision: Utils.epsilon)
            else { return nil }
            return element
        }
    }
}

internal class Utils {

    // Flat 10×10 table (row-major, stride 10) avoids the double heap indirection of [[CGFloat]].
    // swiftlint:disable comma
    private static let binomialTable: [CGFloat] = [
        1,  0,   0,   0,   0,   0,  0,  0, 0, 0,  // n=0
        1,  1,   0,   0,   0,   0,  0,  0, 0, 0,  // n=1
        1,  2,   1,   0,   0,   0,  0,  0, 0, 0,  // n=2
        1,  3,   3,   1,   0,   0,  0,  0, 0, 0,  // n=3
        1,  4,   6,   4,   1,   0,  0,  0, 0, 0,  // n=4
        1,  5,  10,  10,   5,   1,  0,  0, 0, 0,  // n=5
        1,  6,  15,  20,  15,   6,  1,  0, 0, 0,  // n=6
        1,  7,  21,  35,  35,  21,  7,  1, 0, 0,  // n=7
        1,  8,  28,  56,  70,  56, 28,  8, 1, 0,  // n=8
        1,  9,  36,  84, 126, 126, 84, 36, 9, 1   // n=9
    ]
    // swiftlint:enable comma

    static func binomialCoefficient(_ n: Int, choose k: Int) -> CGFloat {
        assert(n >= 0 && k >= 0 && n <= 9 && k <= 9)
        return binomialTable[n &* 10 &+ k]
    }

    // float precision significant decimal
    static let epsilon: Double = 1.0e-5
    static let tau: Double = 2.0 * Double.pi

    // Legendre-Gauss abscissae with n=24 (x_i values, defined at i=n as the roots of the nth order Legendre polynomial Pn(x))
    private static let Tvalues: ContiguousArray<CGFloat> = [
        -0.0640568928626056260850430826247450385909,
        0.0640568928626056260850430826247450385909,
        -0.1911188674736163091586398207570696318404,
        0.1911188674736163091586398207570696318404,
        -0.3150426796961633743867932913198102407864,
        0.3150426796961633743867932913198102407864,
        -0.4337935076260451384870842319133497124524,
        0.4337935076260451384870842319133497124524,
        -0.5454214713888395356583756172183723700107,
        0.5454214713888395356583756172183723700107,
        -0.6480936519369755692524957869107476266696,
        0.6480936519369755692524957869107476266696,
        -0.7401241915785543642438281030999784255232,
        0.7401241915785543642438281030999784255232,
        -0.8200019859739029219539498726697452080761,
        0.8200019859739029219539498726697452080761,
        -0.8864155270044010342131543419821967550873,
        0.8864155270044010342131543419821967550873,
        -0.9382745520027327585236490017087214496548,
        0.9382745520027327585236490017087214496548,
        -0.9747285559713094981983919930081690617411,
        0.9747285559713094981983919930081690617411,
        -0.9951872199970213601799974097007368118745,
        0.9951872199970213601799974097007368118745
    ]

    // Legendre-Gauss weights with n=24 (w_i values, defined by a function linked to in the Bezier primer article)
    static let Cvalues: ContiguousArray<CGFloat> = [
        0.1279381953467521569740561652246953718517,
        0.1279381953467521569740561652246953718517,
        0.1258374563468282961213753825111836887264,
        0.1258374563468282961213753825111836887264,
        0.1216704729278033912044631534762624256070,
        0.1216704729278033912044631534762624256070,
        0.1155056680537256013533444839067835598622,
        0.1155056680537256013533444839067835598622,
        0.1074442701159656347825773424466062227946,
        0.1074442701159656347825773424466062227946,
        0.0976186521041138882698806644642471544279,
        0.0976186521041138882698806644642471544279,
        0.0861901615319532759171852029837426671850,
        0.0861901615319532759171852029837426671850,
        0.0733464814110803057340336152531165181193,
        0.0733464814110803057340336152531165181193,
        0.0592985849154367807463677585001085845412,
        0.0592985849154367807463677585001085845412,
        0.0442774388174198061686027482113382288593,
        0.0442774388174198061686027482113382288593,
        0.0285313886289336631813078159518782864491,
        0.0285313886289336631813078159518782864491,
        0.0123412297999871995468056670700372915759,
        0.0123412297999871995468056670700372915759
    ]

    static func getABC(n: Int, S: CGPoint, B: CGPoint, E: CGPoint, t: CGFloat = 0.5) -> (A: CGPoint, B: CGPoint, C: CGPoint) {
        let u = Utils.projectionRatio(n: n, t: t)
        let um = 1-u
        let C = CGPoint(
            x: u*S.x + um*E.x,
            y: u*S.y + um*E.y
        )
        let s = Utils.abcRatio(n: n, t: t)
        let A = CGPoint(
            x: B.x + (B.x-C.x)/s,
            y: B.y + (B.y-C.y)/s
        )
        return (A: A, B: B, C: C)
    }

    static func abcRatio(n: Int, t: CGFloat = 0.5) -> CGFloat {
        // see ratio(t) note on http://pomax.github.io/bezierinfo/#abc
        assert(n == 2 || n == 3)
        if t == 0 || t == 1 {
            return t
        }
        let bottom = pow(t, CGFloat(n)) + pow(1 - t, CGFloat(n))
        let top = bottom - 1
        return Swift.abs(top/bottom)
    }

    static func projectionRatio(n: Int, t: CGFloat = 0.5) -> CGFloat {
        // see u(t) note on http://pomax.github.io/bezierinfo/#abc
        assert(n == 2 || n == 3)
        if t == 0 || t == 1 {
            return t
        }
        let top = pow(1.0 - t, CGFloat(n))
        let bottom = pow(t, CGFloat(n)) + top
        return top/bottom
    }

    static func map(_ v: CGFloat, _ ds: CGFloat, _ de: CGFloat, _ ts: CGFloat, _ te: CGFloat) -> CGFloat {
        let t = (v - ds) / (de - ds)
        return t * te + (1 - t) * ts
    }

    static func approximately(_ a: Double, _ b: Double, precision: Double) -> Bool {
        return Swift.abs(a-b) <= precision
    }

    static func linesIntersection(_ line1p1: CGPoint, _ line1p2: CGPoint, _ line2p1: CGPoint, _ line2p2: CGPoint) -> CGPoint? {
        let x1 = line1p1.x; let y1 = line1p1.y
        let x2 = line1p2.x; let y2 = line1p2.y
        let x3 = line2p1.x; let y3 = line2p1.y
        let x4 = line2p2.x; let y4 = line2p2.y
        let d = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
        guard d != 0, d.isFinite else { return nil }
        let a = x1 * y2 - y1 * x2
        let b = x3 * y4 - y3 * x4
        let n = a * (line2p1 - line2p2) - b * (line1p1 - line1p2)
        return (1.0 / d) * n
    }

    // cube root function yielding real roots
    static private func crt(_ v: Double) -> Double {
        return (v < 0) ? -pow(-v, 1.0/3.0) : pow(v, 1.0/3.0)
    }

    static func clamp(_ x: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
        if x < a {
            return a
        } else if x > b {
            return b
        } else {
            return x
        }
    }

    static func droots(_ p0: CGFloat, _ p1: CGFloat, _ p2: CGFloat, _ p3: CGFloat, callback: (CGFloat) -> Void) {
        // convert the points p0, p1, p2, p3 to a cubic polynomial at^3 + bt^2 + ct + 1 and solve
        // see http://www.trans4mind.com/personal_development/mathematics/polynomials/cubicAlgebra.htm
        let p0 = Double(p0)
        let p1 = Double(p1)
        let p2 = Double(p2)
        let p3 = Double(p3)
        let d = -p0 + 3 * p1 - 3 * p2 + p3
        guard Swift.abs(d) > 0 else {
            // solve the quadratic polynomial at^2 + bt + c instead
            let a = (3 * p0 - 6 * p1 + 3 * p2)
            let b = (-3 * p0 + 3 * p1)
            let c = p0
            droots(CGFloat(c), CGFloat(b / 2.0 + c), CGFloat(a + b + c), callback: callback)
            return
        }
        let scale = Swift.abs(p0) + 3 * Swift.abs(p1) + 3 * Swift.abs(p2) + Swift.abs(p3)
        // When `d` is small relative to coefficient magnitudes, dividing by it amplifies rounding errors.
        guard Swift.abs(d) >= 1.0e-4 * scale else {
            BernsteinPolynomialN(coefficients: [CGFloat(p0), CGFloat(p1), CGFloat(p2), CGFloat(p3)])
                .distinctRootsAberth().forEach(callback)
            return
        }
        let a = (3 * p0 - 6 * p1 + 3 * p2) / d
        let b = (-3 * p0 + 3 * p1) / d
        let c = p0 / d
        let p = (3 * b - a * a) / 3
        let q = (2 * a * a * a - 9 * a * b + 27 * c) / 27
        let q2 = q/2
        let discriminant = q2 * q2 + p * p * p / 27
        let tinyValue = 1.0e-14
        if discriminant < -tinyValue {
            let r = sqrt(-p * p * p / 27)
            let t = -q / (2 * r)
            let cosphi = t < -1 ? -1 : t > 1 ? 1 : t
            let phi = acos(cosphi)
            let crtr = crt(r)
            let t1 = 2 * crtr
            let root1 = CGFloat(t1 * cos((phi + tau) / 3) - a / 3)
            let root2 = CGFloat(t1 * cos((phi + 2 * tau) / 3) - a / 3)
            let root3 = CGFloat(t1 * cos(phi / 3) - a / 3)
            callback(root1)
            if root2 > root1 {
                callback(root2)
            }
            if root3 > root2 {
                callback(root3)
            }
        } else if discriminant > tinyValue {
            let sd = sqrt(discriminant)
            let u1 = crt(-q2 + sd)
            let v1 = crt(q2 + sd)
            callback(CGFloat(u1 - v1 - a / 3))
        } else if discriminant.isNaN == false {
            let u1 = q2 < 0 ? crt(-q2) : -crt(q2)
            let root1 = CGFloat(2 * u1 - a / 3)
            let root2 = CGFloat(-u1 - a / 3)
            if root1 < root2 {
                callback(root1)
                callback(root2)
            } else if root1 > root2 {
                callback(root2)
                callback(root1)
            } else {
                callback(root1)
            }
        }
    }

    static func droots(_ p0: CGFloat, _ p1: CGFloat, _ p2: CGFloat, callback: (CGFloat) -> Void) {
        // quadratic roots are easy
        // do something with each root
        let p0 = Double(p0)
        let p1 = Double(p1)
        let p2 = Double(p2)
        let d = p0 - 2.0 * p1 + p2
        guard d.isFinite else { return }
        guard Swift.abs(d) > epsilon else {
            if p0 != p1 {
                callback(CGFloat(0.5 * p0 / (p0 - p1)))
            }
            return
        }
        let radical = p1 * p1 - p0 * p2
        guard radical >= 0 else { return }
        let m1 = sqrt(radical)
        let m2 = p0 - p1
        let v1 = CGFloat((m2 + m1) / d)
        let v2 = CGFloat((m2 - m1) / d)
        if v1 < v2 {
            callback(v1)
            callback(v2)
        } else if v1 > v2 {
            callback(v2)
            callback(v1)
        } else {
            callback(v1)
        }
    }

    static func droots(_ p0: CGFloat, _ p1: CGFloat, callback: (CGFloat) -> Void) {
        guard p0 != p1 else { return }
        callback(p0 / (p0 - p1))
    }

    static func linearInterpolate(_ v1: CGPoint, _ v2: CGPoint, _ t: CGFloat) -> CGPoint {
        return v1 + t * (v2 - v1)
    }

    static func linearInterpolate(_ first: CGFloat, _ second: CGFloat, _ t: CGFloat) -> CGFloat {
        return (1 - t) * first + t * second
    }

    static func arcfn(_ t: CGFloat, _ derivativeFn: (_ t: CGFloat) -> CGPoint) -> CGFloat {
        let d = derivativeFn(t)
        return d.length
    }

    static func length(_ derivativeFn: (_ t: CGFloat) -> CGPoint) -> CGFloat {
        let z: CGFloat = 0.5
        let len = Utils.Tvalues.count
        var sum: CGFloat = 0.0
        for i in 0..<len {
            let t = z * Utils.Tvalues[i] + z
            sum += Utils.Cvalues[i] * Utils.arcfn(t, derivativeFn)
        }
        return z * sum
    }

    static func angle(o: CGPoint, v1: CGPoint, v2: CGPoint) -> CGFloat {
        let d1 = v1 - o
        let d2 = v2 - o
        return atan2(d1.cross(d2), d1.dot(d2))
    }

    // Lightweight segment descriptor for the monotonic fast-path.
    // Once a curve's control polygon is monotone in both x and y, its actual curve
    // is also monotone, so its tight bounding box equals [startPoint, endPoint].
    // Sub-curves produced by de Casteljau subdivision inherit monotonicity,
    // so the fast path only needs one point evaluation per split instead of a full
    // split() + boundingBox() recomputation.
    private struct MonoSeg {
        var t1, t2: CGFloat  // curve parameter range (for Intersection output and point(at:))
        var p1, p2: CGPoint  // curve(t1), curve(t2)
        var span: CGFloat { Swift.abs(p2.x - p1.x) + Swift.abs(p2.y - p1.y) }
        var canSplit: Bool {
            let mid = (t1 + t2) * 0.5
            return mid > t1 && mid < t2
        }
    }

    @inline(__always)
    private static func monoOverlap(_ a: MonoSeg, _ b: MonoSeg) -> Bool {
        let aMinX = Swift.min(a.p1.x, a.p2.x), aMaxX = Swift.max(a.p1.x, a.p2.x)
        let bMinX = Swift.min(b.p1.x, b.p2.x), bMaxX = Swift.max(b.p1.x, b.p2.x)
        guard aMinX <= bMaxX, bMinX <= aMaxX else { return false }
        let aMinY = Swift.min(a.p1.y, a.p2.y), aMaxY = Swift.max(a.p1.y, a.p2.y)
        let bMinY = Swift.min(b.p1.y, b.p2.y), bMaxY = Swift.max(b.p1.y, b.p2.y)
        return aMinY <= bMaxY && bMinY <= aMaxY
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
    // to fall through to curve implicitization.
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
        // Stack: 64 × (MonoSeg, MonoSeg). Max depth ≈ 3×log2(1/accuracy)+1: for accuracy=1e-10, ~100.
        // Results: collected into a fixed buffer, bulk-copied to output once at the end.
        return withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 6) { s1Buf -> Bool in
        withUnsafeTemporaryAllocation(of: CGPoint.self, capacity: 6) { p1Buf -> Bool in
        withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 6) { s2Buf -> Bool in
        withUnsafeTemporaryAllocation(of: CGPoint.self, capacity: 6) { p2Buf -> Bool in
        withUnsafeTemporaryAllocation(of: (MonoSeg, MonoSeg).self, capacity: 64) { stackBuf -> Bool in
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
                let seg1 = MonoSeg(t1: s1Buf[i], t2: s1Buf[i + 1], p1: p1Buf[i], p2: p1Buf[i + 1])
                for j in 0..<n2 - 1 {
                    let seg2 = MonoSeg(t1: s2Buf[j], t2: s2Buf[j + 1], p1: p2Buf[j], p2: p2Buf[j + 1])
                    guard monoOverlap(seg1, seg2) else { continue }
                    guard monoPairiteration(curve1, seg1, curve2, seg2,
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

    // Iterative intersection for pairs of monotone subcurves.
    // Accepts pre-allocated stack and result buffers from preSplitIntersections so that
    // no heap allocation occurs inside the tight loop.
    // swiftlint:disable:next function_parameter_count
    private static func monoPairiteration<C1: BezierCurve, C2: BezierCurve>(
        _ c1: C1, _ s1initial: MonoSeg,
        _ c2: C2, _ s2initial: MonoSeg,
        _ resBuf: UnsafeMutableBufferPointer<Intersection>,
        _ resCount: inout Int,
        _ accuracy: CGFloat,
        _ maxIntersections: Int,
        _ stackBuf: UnsafeMutableBufferPointer<(MonoSeg, MonoSeg)>,
        _ totalIterations: inout Int
    ) -> Bool {
        let stackCapacity = stackBuf.count
        var top = 0
        stackBuf[top] = (s1initial, s2initial)
        top = 1

        while top > 0 {
            top -= 1
            let (s1, s2) = stackBuf[top]

            totalIterations += 1
            guard totalIterations <= 900 else { return false }
            guard resCount <= maxIntersections else { return false }

            let r1 = s1.canSplit && s1.span >= accuracy
            let r2 = s2.canSplit && s2.span >= accuracy

            if !r1 && !r2 {
                // Use Cramer's rule directly to avoid false positives from FP-coincident
                // endpoints when both curves are tangent near a shared boundary point.
                let b1x = s1.p2.x - s1.p1.x, b1y = s1.p2.y - s1.p1.y
                let b2x = s2.p2.x - s2.p1.x, b2y = s2.p2.y - s2.p1.y
                let det = b1x * (-b2y) - (-b2x) * b1y
                let scale = (Swift.abs(b1x) + Swift.abs(b1y)) * (Swift.abs(b2x) + Swift.abs(b2y))
                let inv_det = 1.0 / det
                if Swift.abs(det) > CGFloat(Utils.epsilon) * scale {
                    let ex = s2.p1.x - s1.p1.x, ey = s2.p1.y - s1.p1.y
                    var lt1 = (ex * (-b2y) - (-b2x) * ey) * inv_det
                    var lt2 = (b1x * ey - ex * b1y) * inv_det
                    // When an endpoint snaps, reproject from that exact point so both
                    // adjacent mono-path calls produce bit-identical t values at boundaries.
                    if Utils.approximately(Double(lt1), 0, precision: Utils.epsilon) {
                        lt1 = 0
                        lt2 = Swift.abs(b2x) >= Swift.abs(b2y)
                            ? (s1.p1.x - s2.p1.x) / b2x
                            : (s1.p1.y - s2.p1.y) / b2y
                    } else if Utils.approximately(Double(lt1), 1, precision: Utils.epsilon) {
                        lt1 = 1
                        lt2 = Swift.abs(b2x) >= Swift.abs(b2y)
                            ? (s1.p2.x - s2.p1.x) / b2x
                            : (s1.p2.y - s2.p1.y) / b2y
                    }
                    if Utils.approximately(Double(lt2), 0, precision: Utils.epsilon) {
                        lt2 = 0
                        if lt1 != 0 && lt1 != 1 {
                            lt1 = Swift.abs(b1x) >= Swift.abs(b1y)
                                ? (s2.p1.x - s1.p1.x) / b1x
                                : (s2.p1.y - s1.p1.y) / b1y
                        }
                    } else if Utils.approximately(Double(lt2), 1, precision: Utils.epsilon) {
                        lt2 = 1
                        if lt1 != 0 && lt1 != 1 {
                            lt1 = Swift.abs(b1x) >= Swift.abs(b1y)
                                ? (s2.p2.x - s1.p1.x) / b1x
                                : (s2.p2.y - s1.p1.y) / b1y
                        }
                    }
                    if lt1 >= 0, lt1 <= 1, lt2 >= 0, lt2 <= 1 {
                        let gt1 = lt1 == 0 ? s1.t1 : lt1 == 1 ? s1.t2 : lt1 * s1.t2 + (1 - lt1) * s1.t1
                        let gt2 = lt2 == 0 ? s2.t1 : lt2 == 1 ? s2.t2 : lt2 * s2.t2 + (1 - lt2) * s2.t1
                        resBuf[resCount] = Intersection(t1: gt1, t2: gt2)
                        resCount += 1
                    }
                } else if s1.p2 == c1.endingPoint && s2.p1 == c2.startingPoint {
                    // Parallel segments sharing a genuine curve endpoint (e.g. tangent junction).
                    resBuf[resCount] = Intersection(t1: s1.t2, t2: s2.t1)
                    resCount += 1
                } else if s1.p1 == c1.startingPoint && s2.p2 == c2.endingPoint {
                    resBuf[resCount] = Intersection(t1: s1.t1, t2: s2.t2)
                    resCount += 1
                }
            } else if r1 && r2 {
                guard top + 4 <= stackCapacity else { return false }
                let mT1 = (s1.t1 + s1.t2) * 0.5, pM1 = c1.point(at: mT1)
                let ls1 = MonoSeg(t1: s1.t1, t2: mT1, p1: s1.p1, p2: pM1)
                let rs1 = MonoSeg(t1: mT1, t2: s1.t2, p1: pM1, p2: s1.p2)
                let mT2 = (s2.t1 + s2.t2) * 0.5, pM2 = c2.point(at: mT2)
                let ls2 = MonoSeg(t1: s2.t1, t2: mT2, p1: s2.p1, p2: pM2)
                let rs2 = MonoSeg(t1: mT2, t2: s2.t2, p1: pM2, p2: s2.p2)
                if monoOverlap(rs1, rs2) { stackBuf[top] = (rs1, rs2); top += 1 }
                if monoOverlap(ls1, rs2) { stackBuf[top] = (ls1, rs2); top += 1 }
                if monoOverlap(rs1, ls2) { stackBuf[top] = (rs1, ls2); top += 1 }
                if monoOverlap(ls1, ls2) { stackBuf[top] = (ls1, ls2); top += 1 }
            } else if r1 {
                guard top + 2 <= stackCapacity else { return false }
                let mT1 = (s1.t1 + s1.t2) * 0.5, pM1 = c1.point(at: mT1)
                let ls1 = MonoSeg(t1: s1.t1, t2: mT1, p1: s1.p1, p2: pM1)
                let rs1 = MonoSeg(t1: mT1, t2: s1.t2, p1: pM1, p2: s1.p2)
                if monoOverlap(rs1, s2) { stackBuf[top] = (rs1, s2); top += 1 }
                if monoOverlap(ls1, s2) { stackBuf[top] = (ls1, s2); top += 1 }
            } else {
                guard top + 2 <= stackCapacity else { return false }
                let mT2 = (s2.t1 + s2.t2) * 0.5, pM2 = c2.point(at: mT2)
                let ls2 = MonoSeg(t1: s2.t1, t2: mT2, p1: s2.p1, p2: pM2)
                let rs2 = MonoSeg(t1: mT2, t2: s2.t2, p1: pM2, p2: s2.p2)
                if monoOverlap(s1, rs2) { stackBuf[top] = (s1, rs2); top += 1 }
                if monoOverlap(s1, ls2) { stackBuf[top] = (s1, ls2); top += 1 }
            }
        }
        return true
    }

    static func hull(_ p: [CGPoint], _ t: CGFloat) -> [CGPoint] {
        let c: Int = p.count
        var q: [CGPoint] = p
        q.reserveCapacity(c * (c+1) / 2) // reserve capacity ahead of time to avoid re-alloc
        // we linearInterpolate between all points (in-place), until we have 1 point left.
        var start: Int = 0
        for count in (1 ..< c).reversed() {
            let end: Int = start + count
            for i in start ..< end {
                let pt = Utils.linearInterpolate(q[i], q[i+1], t)
                q.append(pt)
            }
            start = end + 1
        }
        return q
    }
}

#if !canImport(CoreGraphics)
public typealias NSInteger = Int
public typealias CGAffineTransform = AffineTransform

extension CGPoint {
    func applying(_ t: CGAffineTransform) -> CGPoint {
        t.transform(self)
    }
}

extension CGAffineTransform {
    init(scaleX sx: CGFloat, y sy: CGFloat) {
        self.init(scaleByX: sx, byY: sy)
    }

    init(translationX tx: CGFloat, y ty: CGFloat) {
        self.init(translationByX: tx, byY: ty)
    }

    init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat) {
        self.init(m11: a, m12: b, m21: c, m22: d, tX: tx, tY: ty)
    }
}
#endif
