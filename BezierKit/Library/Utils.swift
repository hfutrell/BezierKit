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
        precondition(n >= 0 && k >= 0 && n <= 9 && k <= 9)
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
                .distinctRealRootsInUnitInterval().forEach(callback)
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

    @inline(__always) private static func shouldRecurse<C>(for subcurve: Subcurve<C>, boundingBoxSize: CGPoint, accuracy: CGFloat) -> Bool {
        guard subcurve.canSplit else { return false }
        guard boundingBoxSize.x + boundingBoxSize.y >= accuracy else { return false }
        if MemoryLayout<CGFloat>.size == 4 {
            let curve = subcurve.curve
            // limit recursion when we exceed Float32 precision
            let midPoint = curve.point(at: 0.5)
            if midPoint == curve.startingPoint ||
                midPoint == curve.endingPoint {
                guard curve.selfIntersects else { return false }
            }
        }
        return true
    }

    // MARK: - Bezier Clipping (Sederberg & Nishita, 1990)

    // Given n Bernstein coefficients d0..d3 (curve at t_i = i/(n-1)) and a horizontal band
    // [dLow, dHigh], returns the sub-interval [tMin, tMax] of [0,1] where the convex hull
    // of {(t_i, d(i))} intersects the band. Returns nil if hull and band are disjoint.
    // d2 and d3 are only used when n > 2 and n > 3 respectively.
    internal static func convexHullClipInterval(
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

        // n=4 specialization (cubic curves — by far the most common case).
        // Eliminates the generic loop + withUnsafeTemporaryAllocation overhead by using a
        // static branch tree over precomputed cross products. tMin/tMax are passed explicitly
        // to avoid captured-var exclusivity overhead even after inlining.
        if n == 4 {
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

            // Lower hull: pop vertex when cross2d ≤ 0 (right turn or collinear).
            if c012 <= 0 {
                let c023 = d0 - 3*d2 + 2*d3
                if c023 <= 0 {
                    (tMin, tMax) = check(d0, d3, 0,       1,       tMin, tMax) // hull {0,3}
                } else {
                    (tMin, tMax) = check(d0, d2, 0,       2.0/3,   tMin, tMax) // hull {0,2,3}
                    (tMin, tMax) = check(d2, d3, 2.0/3,   1.0/3,   tMin, tMax)
                }
            } else {
                let c123 = d1 - 2*d2 + d3
                if c123 <= 0 {
                    let c013 = 2*d0 - 3*d1 + d3
                    if c013 <= 0 {
                        (tMin, tMax) = check(d0, d3, 0,       1,       tMin, tMax) // hull {0,3}
                    } else {
                        (tMin, tMax) = check(d0, d1, 0,       1.0/3,   tMin, tMax) // hull {0,1,3}
                        (tMin, tMax) = check(d1, d3, 1.0/3,   2.0/3,   tMin, tMax)
                    }
                } else {
                    (tMin, tMax) = check(d0, d1, 0,       1.0/3,   tMin, tMax) // hull {0,1,2,3}
                    (tMin, tMax) = check(d1, d2, 1.0/3,   1.0/3,   tMin, tMax)
                    (tMin, tMax) = check(d2, d3, 2.0/3,   1.0/3,   tMin, tMax)
                }
            }

            // Upper hull: pop vertex when cross2d ≥ 0 (left turn or collinear).
            if c012 >= 0 {
                let c023 = d0 - 3*d2 + 2*d3
                if c023 >= 0 {
                    (tMin, tMax) = check(d0, d3, 0,       1,       tMin, tMax)
                } else {
                    (tMin, tMax) = check(d0, d2, 0,       2.0/3,   tMin, tMax)
                    (tMin, tMax) = check(d2, d3, 2.0/3,   1.0/3,   tMin, tMax)
                }
            } else {
                let c123 = d1 - 2*d2 + d3
                if c123 >= 0 {
                    let c013 = 2*d0 - 3*d1 + d3
                    if c013 >= 0 {
                        (tMin, tMax) = check(d0, d3, 0,       1,       tMin, tMax)
                    } else {
                        (tMin, tMax) = check(d0, d1, 0,       1.0/3,   tMin, tMax)
                        (tMin, tMax) = check(d1, d3, 1.0/3,   2.0/3,   tMin, tMax)
                    }
                } else {
                    (tMin, tMax) = check(d0, d1, 0,       1.0/3,   tMin, tMax)
                    (tMin, tMax) = check(d1, d2, 1.0/3,   1.0/3,   tMin, tMax)
                    (tMin, tMax) = check(d2, d3, 2.0/3,   1.0/3,   tMin, tMax)
                }
            }

            // d3 at t=1 is always the final vertex of both hulls.
            if d3 >= dLow && d3 <= dHigh { if tMin > 1 { tMin = 1 }; if tMax < 1 { tMax = 1 } }

            guard tMin <= tMax else { return nil }
            return (max(0, tMin), min(1, tMax))
        }

        // Generic path for n ≠ 4 (quadratic curves, n=3).
        let nf = CGFloat(n - 1)

        func dAt(_ i: Int) -> CGFloat {
            switch i { case 0: return d0; case 1: return d1; default: return d2 }
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
    private static func fatLineClip<C1: NonlinearBezierCurve, C2: NonlinearBezierCurve>(curve: C1, fatOf other: C2) -> (CGFloat, CGFloat)? {
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
    // swiftlint:disable function_parameter_count
    static func bezierClipping<C1, C2>(
        _ c1: Subcurve<C1>, _ c2: Subcurve<C2>,
        _ results: inout [Intersection],
        _ accuracy: CGFloat,
        _ totalIterations: inout Int
    ) -> Bool where C1: NonlinearBezierCurve, C2: NonlinearBezierCurve {

        let maximumIterations    = 900
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

            // Geometric convergence check: both subcurves fit inside the accuracy threshold.
            let b1 = c1Reduced.curve.boundingBox
            let b2 = c2Reduced.curve.boundingBox
            if b1.size.x + b1.size.y < accuracy && b2.size.x + b2.size.y < accuracy {
                // Reject false positives: nearby non-intersecting sub-curves can both pass the
                // size threshold. Require the reduced bounding boxes to be spatially close.
                // Expand by `accuracy` to absorb floating-point rounding on degenerate curves.
                guard b1.max.x + accuracy >= b2.min.x && b2.max.x + accuracy >= b1.min.x &&
                      b1.max.y + accuracy >= b2.min.y && b2.max.y + accuracy >= b1.min.y else { return true }
                let p1s = c1Reduced.curve.startingPoint
                let p1e = c1Reduced.curve.endingPoint
                let p2s = c2Reduced.curve.startingPoint
                let p2e = c2Reduced.curve.endingPoint
                var t1: CGFloat
                var t2: CGFloat
                if p1s == p2s {
                    t1 = c1Reduced.t1; t2 = c2Reduced.t1
                } else if p1s == p2e {
                    t1 = c1Reduced.t1; t2 = c2Reduced.t2
                } else if p1e == p2s {
                    t1 = c1Reduced.t2; t2 = c2Reduced.t1
                } else if p1e == p2e {
                    t1 = c1Reduced.t2; t2 = c2Reduced.t2
                } else {
                    // Newton-Raphson from midpoint. Sub-curves are tiny at convergence so
                    // the root is always within 0.5 of the midpoint — first step stays in [0,1].
                    // F(u,v) = c1(u) - c2(v) = 0; J = [d1, -d2].
                    // du = -F.cross(d2) / d1.cross(d2),  dv = d1.cross(F) / d1.cross(d2)
                    var u: CGFloat = 0.5, v: CGFloat = 0.5
                    for _ in 0..<6 {
                        let (q1, d1) = c1Reduced.curve.pointAndDerivative(at: u)
                        let (q2, d2) = c2Reduced.curve.pointAndDerivative(at: v)
                        let f = q1 - q2
                        let denom = d1.cross(d2)
                        guard denom != 0 else { break }
                        let du = -f.cross(d2) / denom
                        let dv = d1.cross(f) / denom
                        u += du; if u < 0 { u = 0 } else if u > 1 { u = 1 }
                        v += dv; if v < 0 { v = 0 } else if v > 1 { v = 1 }
                        guard du * du + dv * dv > CGFloat(1e-28) else { break }
                    }
                    t1 = u * c1Reduced.t2 + (1 - u) * c1Reduced.t1
                    t2 = v * c2Reduced.t2 + (1 - v) * c2Reduced.t1
                }
                results.append(Intersection(t1: t1, t2: t2))
                return true
            }

            // Hybrid clipping (Lou & Liu 2011): once both sub-intervals are narrow, switch
            // from fat-line clipping to Newton-Raphson. Newton is O(n) per step vs O(n²) for
            // de Casteljau splits, and both have quadratic convergence — so Newton wins once
            // we are inside its convergence basin. The distance check rejects false positives.
            let c1Range = c1Reduced.t2 - c1Reduced.t1
            let c2Range = c2Reduced.t2 - c2Reduced.t1
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
                    u += du; if u < 0 { u = 0 } else if u > 1 { u = 1 }
                    v += dv; if v < 0 { v = 0 } else if v > 1 { v = 1 }
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
                        let f = c1Reduced.curve.point(at: u) - c2Reduced.curve.point(at: v)
                        if f.x * f.x + f.y * f.y <= accuracy * accuracy {
                            results.append(Intersection(t1: t1Candidate, t2: t2Candidate))
                            return true
                        }
                    }
                }
            }

            // If either curve reduced by less than 20 %, convergence is slow — subdivide.
            if c1Ratio > 0.8 || c2Ratio > 0.8 {
                // For tangent intersections at a shared endpoint, fat-line clipping near the
                // endpoint gives ratio ≈ 1.0, causing exponential blowup.  When both sub-curves
                // have already been narrowed to a small parameter range (fast convergence already
                // did its job), detect exact shared endpoints directly rather than continuing to
                // subdivide.  The range threshold is conservative: tangent cases reach this scale
                // quickly via fast convergence, while nearly-coincident cases exhaust their budget
                // long before reaching it.
                let c1Range = c1Reduced.t2 - c1Reduced.t1
                let c2Range = c2Reduced.t2 - c2Reduced.t1
                if c1Range < 0.05 && c2Range < 0.05 {
                    let p1s = c1Reduced.curve.startingPoint; let p1e = c1Reduced.curve.endingPoint
                    let p2s = c2Reduced.curve.startingPoint; let p2e = c2Reduced.curve.endingPoint
                    if p1e == p2s { results.append(Intersection(t1: c1Reduced.t2, t2: c2Reduced.t1)); return true }
                    if p1e == p2e { results.append(Intersection(t1: c1Reduced.t2, t2: c2Reduced.t2)); return true }
                    if p1s == p2s { results.append(Intersection(t1: c1Reduced.t1, t2: c2Reduced.t1)); return true }
                    if p1s == p2e { results.append(Intersection(t1: c1Reduced.t1, t2: c2Reduced.t2)); return true }
                }
                // Subdivide whichever has the larger global parameter range.
                if (c1Reduced.t2 - c1Reduced.t1) >= (c2Reduced.t2 - c2Reduced.t1) {
                    guard c1Reduced.canSplit else {
                        guard c2Reduced.canSplit else { return true }
                        let h = c2Reduced.split(at: 0.5)
                        guard bezierClipping(c1Reduced, h.left,  &results, accuracy, &totalIterations) else { return false }
                        return  bezierClipping(c1Reduced, h.right, &results, accuracy, &totalIterations)
                    }
                    let h = c1Reduced.split(at: 0.5)
                    guard bezierClipping(h.left,  c2Reduced, &results, accuracy, &totalIterations) else { return false }
                    return  bezierClipping(h.right, c2Reduced, &results, accuracy, &totalIterations)
                } else {
                    guard c2Reduced.canSplit else {
                        guard c1Reduced.canSplit else { return true }
                        let h = c1Reduced.split(at: 0.5)
                        guard bezierClipping(h.left,  c2Reduced, &results, accuracy, &totalIterations) else { return false }
                        return  bezierClipping(h.right, c2Reduced, &results, accuracy, &totalIterations)
                    }
                    let h = c2Reduced.split(at: 0.5)
                    guard bezierClipping(c1Reduced, h.left,  &results, accuracy, &totalIterations) else { return false }
                    return  bezierClipping(c1Reduced, h.right, &results, accuracy, &totalIterations)
                }
            }

            // Good convergence — continue alternating clipping passes.
            c1 = c1Reduced
            c2 = c2Reduced
        }
    }
    // swiftlint:enable function_parameter_count

    // disable this SwiftLint warning about function having more than 5 parameters
    // swiftlint:disable function_parameter_count

    static func pairiteration<C1, C2>(_ c1: Subcurve<C1>, _ c2: Subcurve<C2>,
                                      _ c1b: BoundingBox, _ c2b: BoundingBox,
                                      _ results: inout [Intersection],
                                      _ accuracy: CGFloat,
                                      _ totalIterations: inout Int) -> Bool {

        let maximumIterations = 900
        let maximumIntersections = c1.curve.order * c2.curve.order

        totalIterations += 1
        guard totalIterations <= maximumIterations else { return false }
        guard results.count <= maximumIntersections else { return false }
        guard c1b.overlaps(c2b) else { return true }

        let shouldRecurse1 = shouldRecurse(for: c1, boundingBoxSize: c1b.size, accuracy: accuracy)
        let shouldRecurse2 = shouldRecurse(for: c2, boundingBoxSize: c2b.size, accuracy: accuracy)

        if shouldRecurse1 == false, shouldRecurse2 == false {
            // subcurves are small enough or we simply cannot recurse any more
            let l1 = LineSegment(p0: c1.curve.startingPoint, p1: c1.curve.endingPoint)
            let l2 = LineSegment(p0: c2.curve.startingPoint, p1: c2.curve.endingPoint)
            guard let intersection = l1.intersections(with: l2, checkCoincidence: false).first else { return true }
            let t1 = intersection.t1
            let t2 = intersection.t2
            results.append(Intersection(t1: t1 * c1.t2 + (1.0 - t1) * c1.t1,
                                        t2: t2 * c2.t2 + (1.0 - t2) * c2.t1))
        } else if shouldRecurse1, shouldRecurse2 {
            let cc1 = c1.split(at: 0.5)
            let cc2 = c2.split(at: 0.5)
            let cc1lb = cc1.left.curve.boundingBox
            let cc1rb = cc1.right.curve.boundingBox
            let cc2lb = cc2.left.curve.boundingBox
            let cc2rb = cc2.right.curve.boundingBox
            guard Utils.pairiteration(cc1.left, cc2.left, cc1lb, cc2lb, &results, accuracy, &totalIterations) else { return false }
            guard Utils.pairiteration(cc1.left, cc2.right, cc1lb, cc2rb, &results, accuracy, &totalIterations) else { return false }
            guard Utils.pairiteration(cc1.right, cc2.left, cc1rb, cc2lb, &results, accuracy, &totalIterations) else { return false }
            guard Utils.pairiteration(cc1.right, cc2.right, cc1rb, cc2rb, &results, accuracy, &totalIterations) else { return false }
        } else if shouldRecurse1 {
            let cc1 = c1.split(at: 0.5)
            let cc1lb = cc1.left.curve.boundingBox
            let cc1rb = cc1.right.curve.boundingBox
            guard Utils.pairiteration(cc1.left, c2, cc1lb, c2b, &results, accuracy, &totalIterations) else { return false }
            guard Utils.pairiteration(cc1.right, c2, cc1rb, c2b, &results, accuracy, &totalIterations) else { return false }
        } else if shouldRecurse2 {
            let cc2 = c2.split(at: 0.5)
            let cc2lb = cc2.left.curve.boundingBox
            let cc2rb = cc2.right.curve.boundingBox
            guard Utils.pairiteration(c1, cc2.left, c1b, cc2lb, &results, accuracy, &totalIterations) else { return false }
            guard Utils.pairiteration(c1, cc2.right, c1b, cc2rb, &results, accuracy, &totalIterations) else { return false }
        }
        return true
    }

    // swiftlint:enable function_parameter_count

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
