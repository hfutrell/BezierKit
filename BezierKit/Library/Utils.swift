//
//  Utils.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/3/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import Foundation

#if os(iOS)
import CoreGraphics
#endif

internal class Utils {

    // float precision significant decimal
    static let epsilon: CGFloat = 0.000001
    static let tau: CGFloat = 2.0 * CGFloat.pi
    static let quart: CGFloat = CGFloat.pi / 2.0
    
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
        if ( t == 0 || t == 1) {
            return t
        }
        let bottom = pow(t, CGFloat(n)) + pow(1 - t, CGFloat(n))
        let top = bottom - 1
        return abs(top/bottom)
    }
    
    static func projectionRatio(n: Int, t: CGFloat = 0.5) -> CGFloat {
        // see u(t) note on http://pomax.github.io/bezierinfo/#abc
        assert(n == 2 || n == 3)
        if (t == 0 || t == 1) {
            return t
        }
        let top = pow(1.0 - t, CGFloat(n))
        let bottom = pow(t, CGFloat(n)) + top
        return top/bottom
    }
    
    static func map(_ v: CGFloat,_ ds: CGFloat,_ de: CGFloat,_ ts: CGFloat,_ te: CGFloat) -> CGFloat {
        let d1 = de-ds
        let d2 = te-ts
        let v2 =  v-ds
        let r = v2/d1
        return ts + d2*r        
    }
    
    static func lli8(_ x1: CGFloat,_ y1: CGFloat,_ x2: CGFloat,_ y2: CGFloat,_ x3: CGFloat,_ y3: CGFloat,_ x4: CGFloat,_ y4: CGFloat) -> CGPoint? {
        let nx = (x1*y2-y1*x2)*(x3-x4)-(x1-x2)*(x3*y4-y3*x4)
        let ny = (x1*y2-y1*x2)*(y3-y4)-(y1-y2)*(x3*y4-y3*x4)
        let d = (x1-x2)*(y3-y4)-(y1-y2)*(x3-x4)
        if d == 0 {
            return nil
        }
        return CGPoint( x: nx/d, y: ny/d )
    }
    
    static func lli4(_ p1: CGPoint,_ p2: CGPoint,_ p3: CGPoint,_ p4: CGPoint) -> CGPoint? {
        let x1 = p1.x; let y1 = p1.y
        let x2 = p2.x; let y2 = p2.y
        let x3 = p3.x; let y3 = p3.y
        let x4 = p4.x; let y4 = p4.y
        return Utils.lli8(x1,y1,x2,y2,x3,y3,x4,y4)
    }
    
    static func approximately(_ a: CGFloat,_ b: CGFloat, precision: CGFloat = epsilon) -> Bool {
        return abs(a-b) <= precision
    }
    
    static func between(_ v: CGFloat,_ m: CGFloat,_ M: CGFloat) -> Bool {
        return (m <= v && v <= M) || Utils.approximately(v, m) || Utils.approximately(v, M)
    }
    
    // cube root function yielding real roots
    static func crt(_ v: CGFloat) -> CGFloat {
        return (v < 0) ? -pow(-v,1.0/3.0) : pow(v,1.0/3.0)
    }
    
    static func clamp(_ x: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
        // note that if x is NaN all comparisons fail so we return NaN
        // TODO: this is purposeful behavior, should probably have unit test
        precondition(b >= a)
        if x < a {
            return a
        }
        else if x > b {
            return b
        }
        else {
            return x
        }
    }
    
    static func roots(points: [CGPoint], line: LineSegment = LineSegment(p0: CGPoint(x: 0.0, y: 0.0), p1: CGPoint(x: 1.0, y: 0.0))) -> [CGFloat] {
        let order = points.count - 1
        let p = Utils.align(points, p1: line.p0, p2: line.p1)
        
        let epsilon: CGFloat = 1.0e-6
        let reduce: (CGFloat) -> Bool = { (-epsilon) <= $0 && $0 <= (1 + epsilon) }
        let clamp: (CGFloat) -> CGFloat = {
            if $0 < 0.0 { return 0.0 }
            else if $0 > 1.0 { return 1.0 }
            else { return $0 }
        }
        
        if order == 2 {
            let a = p[0].y
            let b = p[1].y
            let c = p[2].y
            let d = a - 2*b + c
            if abs(d) > epsilon {
                let m1 = -sqrt(b*b-a*c)
                let m2 = -a+b
                let v1: CGFloat = -( m1+m2)/d
                let v2: CGFloat = -(-m1+m2)/d
                return [v1, v2].filter(reduce).map(clamp)
            }
            else if a != b {
                // TODO: also fix in droots!
                return [CGFloat(0.5 * a / (a-b))].filter(reduce).map(clamp)
            }
            else {
                return []
            }
        }
        else if order == 3 {
            // see http://www.trans4mind.com/personal_development/mathematics/polynomials/cubicAlgebra.htm
            let pa = p[0].y
            let pb = p[1].y
            let pc = p[2].y
            let pd = p[3].y
            let temp1 = -pa
            let temp2 = 3*pb
            let temp3 = -3*pc
            let d = temp1 + temp2 + temp3 + pd
            if d == 0.0 {
                // TODO: epsilon testing ... use demos upgrade the quadratic to a cubic!
                let temp1 = 3*points[0]
                let temp2 = -6*points[1]
                let temp3 = 3*points[2]
                let a = (temp1 + temp2 + temp3)
                let temp4 = -3*points[0]
                let temp5 = 3*points[1]
                let b = (temp4 + temp5)
                let c = points[0]
                return roots(points: [c, b / 2.0 + c, a + b + c], line: line)
            }
            let a = (3*pa - 6*pb + 3*pc) / d
            let b = (-3*pa + 3*pb) / d
            let c = pa / d
            let p = (3*b - a*a)/3
            let p3 = p/3
            let q = (2*a*a*a - 9*a*b + 27*c)/27
            let q2 = q/2
            let discriminant = q2*q2 + p3*p3*p3
            if discriminant < 0 {
                let mp3 = -p/3
                let mp33 = mp3*mp3*mp3
                let r = sqrt( mp33 )
                let t = -q/(2*r)
                let cosphi = t < -1 ? -1 : t > 1 ? 1 : t
                let phi = acos(cosphi)
                let crtr = crt(r)
                let t1 = 2*crtr
                let x1 = t1 * cos(phi/3) - a/3
                let x2 = t1 * cos((phi+tau)/3) - a/3
                let x3 = t1 * cos((phi+2*tau)/3) - a/3
                return [x1, x2, x3].filter(reduce).map(clamp)
            }
            else if discriminant == 0 {
                let u1 = q2 < 0 ? crt(-q2) : -crt(q2)
                let x1 = 2*u1-a/3
                let x2 = -u1 - a/3
                return [x1,x2].filter(reduce).map(clamp)
            }
            else {
                let sd = sqrt(discriminant)
                let u1 = crt(-q2+sd)
                let v1 = crt(q2+sd)
                return [u1-v1-a/3].filter(reduce).map(clamp)
            }
        }
        else {
            fatalError("unsupported")
        }
    }
    
    static func droots(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, callback:((CGFloat)->())) {
        // quadratic roots are easy
        // do something with each root
        let d: CGFloat = a - 2.0*b + c
        if d != 0 {
            let m1 = -sqrt(b*b-a*c)
            let m2 = -a+b
            let v1 = -( m1+m2)/d
            let v2 = -(-m1+m2)/d
            callback(v1)
            callback(v2)
        }
        else if (b != c) && (d == 0) {
            callback((2*b-c)/(2*(b-c)))
        }
    }
    
    static func droots(_ a: CGFloat, _ b: CGFloat, callback:((CGFloat)->())) {
        // linear roots are super easy
        // do something with the root, if it exists
        if a != b {
            callback(a/(a-b))
        }
    }
    
    static func droots(_ p: [CGFloat]) -> [CGFloat] {
        // quadratic roots are easy
        var result: [CGFloat] = []
        if p.count == 3 {
            droots(p[0], p[1], p[2]) {
                result.append($0)
            }
        }
        else if p.count == 2 {
            droots(p[0], p[1]) {
                result.append($0)
            }
        }
        else {
            fatalError("unsupported")
        }
        return result
    }

    
    static func lerp(_ r: CGFloat, _ v1: CGPoint, _ v2: CGPoint) -> CGPoint {
        return v1 + r * (v2 - v1)
    }
    
    static func dist(_ p1: CGPoint,_ p2: CGPoint) -> CGFloat {
        return (p1 - p2).length
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
        let dx1 = v1.x - o.x
        let dy1 = v1.y - o.y
        let dx2 = v2.x - o.x
        let dy2 = v2.y - o.y
        let cross = dx1*dy2 - dy1*dx2
        let dot = dx1*dx2 + dy1*dy2
        return atan2(cross, dot)
    }
    
    static func align(_ points: [CGPoint], p1: CGPoint, p2: CGPoint) -> [CGPoint] {
        let tx = p1.x
        let ty = p1.y
        let a = -atan2(p2.y-ty, p2.x-tx)
        let d =  {( v: CGPoint) in
            return CGPoint(
                x: (v.x-tx)*cos(a) - (v.y-ty)*sin(a),
                y: (v.x-tx)*sin(a) + (v.y-ty)*cos(a)
            )
        }
        return points.map(d)
    }
    
    static func closest(_ LUT: [CGPoint],_ point: CGPoint) -> (mdist: CGFloat, mpos: Int) {
        assert(LUT.count > 0)
        var mdist = CGFloat.infinity
        var mpos: Int? = nil
        for i in 0..<LUT.count {
            let p = LUT[i]
            let d = Utils.dist(point, p)
            if d<mdist {
                mdist = d
                mpos = i
            }
        }
        return ( mdist:mdist, mpos:mpos! )
    }
    
    static func pairiteration<C1, C2>(_ c1: Subcurve<C1>, _ c2: Subcurve<C2>, _ results: inout [Intersection], _ threshold: CGFloat = BezierKit.defaultIntersectionThreshold) {
        let c1b = c1.curve.boundingBox
        let c2b = c2.curve.boundingBox
        if c1b.overlaps(c2b) == false {
            return
        }
        else if ((c1b.size.x + c1b.size.y) < threshold && (c2b.size.x + c2b.size.y) < threshold) {
            
            let a1 = c1.curve.startingPoint
            let b1 = c1.curve.endingPoint - c1.curve.startingPoint
            let a2 = c2.curve.startingPoint
            let b2 = c2.curve.endingPoint - c2.curve.startingPoint
            
            let _a = b1.x
            let _b = -b2.x
            let _c = b1.y
            let _d = -b2.y
            
            // by Cramer's rule we have
            // t1 = ed - bf / ad - bc
            // t2 = af - ec / ad - bc
            let det = _a * _d - _b * _c
            
            let _e = -a1.x + a2.x
            let _f = -a1.y + a2.y
            
            let inv_det = 1.0 / det
            let t1 = ( _e * _d - _b * _f ) * inv_det
            if t1 > 1.0 || t1 < 0.0  {
                return // t1 out of interval [0, 1]
            }
            let t2 = ( _a * _f - _e * _c ) * inv_det
            if t2 > 1.0 || t2 < 0.0 {
                return // t2 out of interval [0, 1]
            }
            // segments intersect at t1, t2
            results.append(Intersection(t1: t1 * c1.t2 + (1.0 - t1) * c1.t1,
                                        t2: t2 * c2.t2 + (1.0 - t2) * c2.t1))
        }
        else {
            let cc1 = c1.split(at: 0.5)
            let cc2 = c2.split(at: 0.5)
            Utils.pairiteration(cc1.left, cc2.left, &results, threshold)
            Utils.pairiteration(cc1.left, cc2.right, &results, threshold)
            Utils.pairiteration(cc1.right, cc2.left, &results, threshold)
            Utils.pairiteration(cc1.right, cc2.right, &results, threshold)
        }
    }
            
    static func getccenter( _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ interval: Interval) -> Arc {
        let d1 = p2 - p1
        let d2 = p3 - p2
        let d1p = CGPoint(x: d1.x * cos(quart) - d1.y * sin(quart),
                          y: d1.x * sin(quart) + d1.y * cos(quart))
        let d2p = CGPoint(x: d2.x * cos(quart) - d2.y * sin(quart),
                          y: d2.x * sin(quart) + d2.y * cos(quart))
        // chord midpoints
        let m1 = 0.5 * (p1 + p2)
        let m2 = 0.5 * (p2 + p3)
        // midpoint offsets
        let m1n = m1 + d1p
        let m2n = m2 + d2p
        // intersection of these lines:
        let oo = Utils.lli8(m1.x, m1.y, m1n.x, m1n.y, m2.x, m2.y, m2n.x, m2n.y)
        
        assert(oo != nil)
        
        let o: CGPoint = oo!
        let r = Utils.dist(o, p1)
        // arc start/end values, over mid point:
        var s = atan2(p1.y - o.y, p1.x - o.x)
        let m = atan2(p2.y - o.y, p2.x - o.x)
        var e = atan2(p3.y - o.y, p3.x - o.x)
        // determine arc direction (cw/ccw correction)
        if s<e {
            // if s<m<e, arc(s, e)
            // if m<s<e, arc(e, s + tau)
            // if s<e<m, arc(e, s + tau)
            if s>m || m>e {
                s += tau
            }
            if s>e {
                swap(&s, &e)
            }
        }
        else {
            // if e<m<s, arc(e, s)
            // if m<e<s, arc(s, e + tau)
            // if e<s<m, arc(s, e + tau)
            if e<m && m<s {
                swap(&s, &e)
            }
            else {
                e += tau
            }
        }
        return Arc(origin: o, radius: r, startAngle: s, endAngle: e, interval: interval)
    }
    
    static func hull(_ p: [CGPoint],_ t: CGFloat) -> [CGPoint] {
        let c: Int = p.count
        var q: [CGPoint] = p
        q.reserveCapacity(c * (c+1) / 2) // reserve capacity ahead of time to avoid re-alloc
        // we lerp between all points (in-place), until we have 1 point left.
        var start: Int = 0
        for count in (1 ..< c).reversed()  {
            let end: Int = start + count
            for i in start ..< end {
                let pt = Utils.lerp(t,q[i],q[i+1])
                q.append(pt)
            }
            start = end + 1
        }
        return q
    }
}
