//
//  Utils.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/3/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import Foundation

class Utils {
    
    // Legendre-Gauss abscissae with n=24 (x_i values, defined at i=n as the roots of the nth order Legendre polynomial Pn(x))
    static let Tvalues: [BKFloat] = [
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
    static let Cvalues: [BKFloat] = [
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
    
    static func abcRatio(n: Int, t: CGFloat = 0.5) -> BKFloat {
        // see ratio(t) note on http://pomax.github.io/bezierinfo/#abc
        assert(n == 2 || n == 3)
        if ( t == 0 || t == 1) {
            return t
        }
        let bottom = pow(t, CGFloat(n)) + pow(1 - t, CGFloat(n))
        let top = bottom - 1
        return abs(top/bottom);
    }
    
    static func projectionRatio(n: Int, t: CGFloat = 0.5) -> BKFloat {
        // see u(t) note on http://pomax.github.io/bezierinfo/#abc
        assert(n == 2 || n == 3)
        if (t == 0 || t == 1) {
            return t
        }
        let top = pow(1.0 - t, CGFloat(n))
        let bottom = pow(t, CGFloat(n)) + top
        return top/bottom;

    }
    
    static func map(_ v: BKFloat,_ ds: BKFloat,_ de: BKFloat,_ ts: BKFloat,_ te: BKFloat) -> BKFloat {
        let d1 = de-ds
        let d2 = te-ts
        let v2 =  v-ds
        let r = v2/d1
        return ts + d2*r
    }
    
    static func lli8(_ x1: BKFloat,_ y1: BKFloat,_ x2: BKFloat,_ y2: BKFloat,_ x3: BKFloat,_ y3: BKFloat,_ x4: BKFloat,_ y4: BKFloat) -> BKPoint? {
        let nx = (x1*y2-y1*x2)*(x3-x4)-(x1-x2)*(x3*y4-y3*x4)
        let ny = (x1*y2-y1*x2)*(y3-y4)-(y1-y2)*(x3*y4-y3*x4)
        let d = (x1-x2)*(y3-y4)-(y1-y2)*(x3-x4)
        if d == 0 {
            return nil
        }
        return BKPoint( x: nx/d, y: ny/d );
    }
    
    static func lli4(_ p1: BKPoint,_ p2: BKPoint,_ p3: BKPoint,_ p4: BKPoint) -> BKPoint? {
        let x1 = p1.x; let y1 = p1.y
        let x2 = p2.x; let y2 = p2.y
        let x3 = p3.x; let y3 = p3.y
        let x4 = p4.x; let y4 = p4.y
        return Utils.lli8(x1,y1,x2,y2,x3,y3,x4,y4)
    }
    
//    static func lli(_ v1: BKFloat,_ v2: BKFloat) -> BKPoint? {
//        return Utils.lli4(v1,v1.c,v2,v2.c)
//    }

    static func getminmax(list: [BKFloat], computeDimension: (BKFloat) -> BKFloat) -> (min: BKFloat, max: BKFloat) {
        var min = BKFloat.infinity
        var max = -BKFloat.infinity
        var listPrime = list
        if listPrime.index(of: 0) == nil {
            listPrime.insert(0, at: 0)
        }
        if listPrime.index(of :1) == nil {
            listPrime.append(1)
        }
        for t in listPrime {
            let c = computeDimension(t);
            if c < min {
                min = c
            }
            if c > max {
                max = c
            }
        }
        return ( min:min, max: max );
    }
    
    static func droots(_ p: [BKFloat]) -> [BKFloat] {
        // quadratic roots are easy
        if p.count == 3 {
            let a = p[0]
            let b = p[1]
            let c = p[2]
            let d = a - 2*b + c;
            if d != 0 {
                let m1 = -sqrt(b*b-a*c)
                let m2 = -a+b
                let v1 = -( m1+m2)/d
                let v2 = -(-m1+m2)/d
                return [v1, v2]
            }
            else if (b != c) && (d == 0) {
                return [(2*b-c)/(2*(b-c))]
            }
            return []
        }
        
        // linear roots are even easier
        if p.count == 2 {
            let a = p[0]
            let b = p[1]
            if a != b {
                return [a/(a-b)];
            }
            return []
        }

        assert(false, "nope!")
        return []
    }
    
    static func lerp(_ r: BKFloat, _ v1: BKPoint, _ v2: BKPoint) -> BKPoint {
        return v1 + (v2 - v1) * r;
    }
    
    static func dist(_ p1: BKPoint,_ p2: BKPoint) -> BKFloat {
        return (p1 - p2).length
    }
    
    static func arcfn(_ t: BKFloat, _ derivativeFn: (_ t: BKFloat) -> BKPoint) -> BKFloat {
        let d = derivativeFn(t);
        return d.length
    }
    
    static func length(_ derivativeFn: (_ t: BKFloat) -> BKPoint) -> BKFloat {
        let z: BKFloat = 0.5
        let len = Utils.Tvalues.count
        var sum: BKFloat = 0.0
        for i in 0..<len {
            let t = z * Utils.Tvalues[i] + z;
            sum += Utils.Cvalues[i] * Utils.arcfn(t, derivativeFn)
        }
        return z * sum
    }
    
    static func angle(o: BKPoint, v1: BKPoint, v2: BKPoint) -> BKFloat {
        var dx1 = v1.x - o.x
        var dy1 = v1.y - o.y
        var dx2 = v2.x - o.x
        var dy2 = v2.y - o.y
        let cross = dx1*dy2 - dy1*dx2
        let m1 = sqrt(dx1*dx1+dy1*dy1)
        let m2 = sqrt(dx2*dx2+dy2*dy2)
        dx1 /= m1
        dy1 /= m1
        dx2 /= m2
        dy2 /= m2
        let dot = dx1*dx2 + dy1*dy2;
        return atan2(cross, dot)
    }
    
    static func align(_ points: [BKPoint], p1: BKPoint, p2: BKPoint) -> [BKPoint] {
        let tx = p1.x
        let ty = p1.y
        let a = -atan2(p2.y-ty, p2.x-tx)
        let d =  {( v: BKPoint) in
            return BKPoint(
                x: (v.x-tx)*cos(a) - (v.y-ty)*sin(a),
                y: (v.x-tx)*sin(a) + (v.y-ty)*cos(a)
            )
        }
        return points.map(d)
    }
    
    static func closest(_ LUT: [BKPoint],_ point: BKPoint) -> (mdist: BKFloat, mpos: Int) {
        assert(LUT.count > 0)
        var mdist = BKFloat.infinity
        var mpos: Int? = nil
        for i in 0..<LUT.count {
            let p = LUT[i]
            let d = Utils.dist(point, p);
            if d<mdist {
                mdist = d;
                mpos = i;
            }
        }
        return ( mdist:mdist, mpos:mpos! );
    }
    
    static func makeline(_ p1: BKPoint,_ p2: BKPoint) -> CubicBezier {
        let x1 = p1.x
        let y1 = p1.y
        let x2 = p2.x
        let y2 = p2.y
        let dx = (x2-x1) / 3.0
        let dy = (y2-y1) / 3.0
        return CubicBezier(p0: BKPoint(x: x1, y: y1),
                           p1: BKPoint(x: x1+dx, y: y1+dy),
                           p2: BKPoint(x: x1+2.0*dx, y: y1+2.0*dy),
                           p3: BKPoint(x: x2, y: y2)
        )
    }
    
    static func pairiteration(_ c1: TimeTaggedCurve, _ c2: TimeTaggedCurve, _ threshold: BKFloat = 0.5) -> [Intersection] {
        let c1b = c1.curve.boundingBox
        let c2b = c2.curve.boundingBox
        if ((c1b.size.x + c1b.size.y) < threshold && (c2b.size.x + c2b.size.y) < threshold) {
            return [ Intersection(t1: (c1._t1+c1._t2) / 2.0, t2: (c2._t1+c2._t2) / 2.0) ]
        }
        
        
        let cc1 = c1.split(0.5)
        let cc2 = c2.split(0.5)
        
        var cc1left: TimeTaggedCurve
        var cc1right: TimeTaggedCurve
        var cc2left: TimeTaggedCurve
        var cc2right: TimeTaggedCurve

        if case let SplitResult.multipleCurves(left, right, _) = cc1 {
            cc1left = left
            cc1right = right
        }
        else {
            assert(false, "???")
            return []
        }
        if case let SplitResult.multipleCurves(left, right, _) = cc2 {
            cc2left = left
            cc2right = right
        }
        else {
            assert(false, "???")
            return []
        }

        var pairs = [
        (left: cc1left, right: cc2left ),
        (left: cc1left, right: cc2right ),
        (left: cc1right, right: cc2right ),
        (left: cc1right, right: cc2left )]
        pairs = pairs.filter( {(pair) in
            return pair.left.curve.boundingBox.overlaps(pair.right.curve.boundingBox)
        })
        var results: [Intersection] = []
        if pairs.count == 0 {
            return results
        }
        for pair in pairs {
            results += Utils.pairiteration(pair.left, pair.right, threshold)
        }
// TODO: remove duplicates
        //        results = results.filter({(v,i) in
//            return results.index(of: v) == i
//        })
        return uniques
    }


    
}
