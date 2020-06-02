//
//  Utils.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/3/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import CoreGraphics

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

    // float precision significant decimal
    static let epsilon: Double = 1.0e-5
    static let tau: Double = 2.0 * Double.pi
    static let quart: Double = Double.pi / 2.0

    // Legendre-Gauss abscissae with n=24 (x_i values, defined at i=n as the roots of the nth order Legendre polynomial Pn(x))
    static let Tvalues: ContiguousArray<CGFloat> = [
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
        return ( A:A, B:B, C:C )
    }

    static func abcRatio(n: Int, t: CGFloat = 0.5) -> CGFloat {
        // see ratio(t) note on http://pomax.github.io/bezierinfo/#abc
        assert(n == 2 || n == 3)
        if t == 0 || t == 1 {
            return t
        }
        let bottom = pow(t, CGFloat(n)) + pow(1 - t, CGFloat(n))
        let top = bottom - 1
        return abs(top/bottom)
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
        let d1 = de-ds
        let d2 = te-ts
        let v2 = v-ds
        let r = v2/d1
        return ts + d2*r
    }

    static func approximately(_ a: Double, _ b: Double, precision: Double) -> Bool {
        return abs(a-b) <= precision
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
        precondition(b >= a)
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
        let smallValue: Double = 1.0e-8
        guard abs(d) >= smallValue else {
            // solve the quadratic polynomial at^2 + bt + c instead
            let a = (3 * p0 - 6 * p1 + 3 * p2)
            let b = (-3 * p0 + 3 * p1)
            let c = p0
            droots(CGFloat(c), CGFloat(b / 2.0 + c), CGFloat(a + b + c), callback: callback)
            return
        }
        let a = (3 * p0 - 6 * p1 + 3 * p2) / d
        let b = (-3 * p0 + 3 * p1) / d
        let c = p0 / d
        let p = (3 * b - a * a) / 3
        let q = (2 * a * a * a - 9 * a * b + 27 * c) / 27
        let q2 = q/2
        let discriminant = q2 * q2 + p * p * p / 27
        if discriminant < -smallValue {
            let r = sqrt(-p * p * p / 27)
            let t = -q / (2 * r)
            let cosphi = t < -1 ? -1 : t > 1 ? 1 : t
            let phi = acos(cosphi)
            let crtr = crt(r)
            let t1 = 2 * crtr
            let root1 = CGFloat(t1 * cos((phi + tau) / 3) - a / 3)
            let root2 = CGFloat(t1 * cos((phi + 2 * tau) / 3) - a / 3)
            let root3 = CGFloat(t1 * cos(phi / 3) - a / 3)
            assert(root1 < root2 && root2 < root3)
            callback(root1)
            callback(root2)
            callback(root3)
        } else if discriminant > smallValue {
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
        guard abs(d) > epsilon else {
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

    static func droots(_ p: [CGFloat]) -> [CGFloat] {
        // quadratic roots are easy
        var result: [CGFloat] = []
        let callback = { result.append($0) }
        switch p.count {
        case 4:
            droots(p[0], p[1], p[2], p[3], callback: callback)
        case 3:
            droots(p[0], p[1], p[2], callback: callback)
        case 2:
            droots(p[0], p[1], callback: callback)
        default:
            fatalError("unsupported")
        }
        return result
    }

    static func lerp(_ r: CGFloat, _ v1: CGPoint, _ v2: CGPoint) -> CGPoint {
        return v1 + r * (v2 - v1)
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

    // disable this SwiftLint warning about function having more than 5 parameters
    // swiftlint:disable function_parameter_count

    static func pairiteration<C1, C2>(_ c1: Subcurve<C1>, _ c2: Subcurve<C2>,
                                      _ c1b: BoundingBox, _ c2b: BoundingBox,
                                      _ results: inout [Intersection],
                                      _ accuracy: CGFloat) {

        guard results.count < c1.curve.order * c2.curve.order else { return }
        guard c1b.overlaps(c2b) else { return }

        let canSplit1 = c1.canSplit
        let canSplit2 = c2.canSplit
        let size1 = c1b.size
        let size2 = c2b.size
        let shouldRecurse1 = canSplit1 && ((size1.x + size1.y) >= accuracy)
        let shouldRecurse2 = canSplit2 && ((size2.x + size2.y) >= accuracy)

        if shouldRecurse1 == false, shouldRecurse2 == false {
            // subcurves are small enough or we simply cannot recurse any more
            let l1 = LineSegment(p0: c1.curve.startingPoint, p1: c1.curve.endingPoint)
            let l2 = LineSegment(p0: c2.curve.startingPoint, p1: c2.curve.endingPoint)
            guard let intersection = l1.intersections(with: l2, checkCoincidence: false).first else { return }
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
            Utils.pairiteration(cc1.left, cc2.left, cc1lb, cc2lb, &results, accuracy)
            Utils.pairiteration(cc1.left, cc2.right, cc1lb, cc2rb, &results, accuracy)
            Utils.pairiteration(cc1.right, cc2.left, cc1rb, cc2lb, &results, accuracy)
            Utils.pairiteration(cc1.right, cc2.right, cc1rb, cc2rb, &results, accuracy)
        } else if shouldRecurse1 {
            let cc1 = c1.split(at: 0.5)
            let cc1lb = cc1.left.curve.boundingBox
            let cc1rb = cc1.right.curve.boundingBox
            Utils.pairiteration(cc1.left, c2, cc1lb, c2b, &results, accuracy)
            Utils.pairiteration(cc1.right, c2, cc1rb, c2b, &results, accuracy)
        } else if shouldRecurse2 {
            let cc2 = c2.split(at: 0.5)
            let cc2lb = cc2.left.curve.boundingBox
            let cc2rb = cc2.right.curve.boundingBox
            Utils.pairiteration(c1, cc2.left, c1b, cc2lb, &results, accuracy)
            Utils.pairiteration(c1, cc2.right, c1b, cc2rb, &results, accuracy)
        }
    }

    // swiftlint:enable function_parameter_count

    static func hull(_ p: [CGPoint], _ t: CGFloat) -> [CGPoint] {
        let c: Int = p.count
        var q: [CGPoint] = p
        q.reserveCapacity(c * (c+1) / 2) // reserve capacity ahead of time to avoid re-alloc
        // we lerp between all points (in-place), until we have 1 point left.
        var start: Int = 0
        for count in (1 ..< c).reversed() {
            let end: Int = start + count
            for i in start ..< end {
                let pt = Utils.lerp(t, q[i], q[i+1])
                q.append(pt)
            }
            start = end + 1
        }
        return q
    }
}
