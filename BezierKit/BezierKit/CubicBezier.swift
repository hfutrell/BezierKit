//
//  CubicBezier.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import AppKit

struct TimeTaggedCurve {
    let _t1: BKFloat
    let _t2: BKFloat
    let curve: CubicBezier
    
    func split(_ t1: BKFloat, _ t2: BKFloat? = nil) -> SplitResult {
        // shortcuts
        if (t1 == 0.0) && (t2 != nil) && (t2 != 0.0) {
            if case let SplitResult.multipleCurves(left, _, _) = self.split(t2!) {
                return SplitResult.singleCurve(curve: left)
            }
            else {
                assert(false, "what?")
            }
        }
        if t2 == 1.0 {
            if case let SplitResult.multipleCurves(_, right, _) = self.split(t1) {
                return SplitResult.singleCurve(curve: right)
            }
            else {
                assert(false, "what?")
            }
        }
        
        
        // make sure we bind _t1/_t2 information!
        let left_t1  = Utils.map(0,  0,1, self._t1, self._t2);
        let left_t2  = Utils.map(t1, 0,1, self._t1, self._t2);
        let right_t1 = Utils.map(t1, 0,1, self._t1, self._t2);
        let right_t2 = Utils.map(1,  0,1, self._t1, self._t2);
        
        // no shortcut: use "de Casteljau" iteration.
        var q = self.curve.hull(t1);

        let left = self.curve.order == 2 ? CubicBezier(points: [q[0],q[3],q[5]]) : CubicBezier(points: [q[0],q[4],q[7],q[9]])
        let right = self.curve.order == 2 ? CubicBezier(points: [q[0],q[3],q[5]]) : CubicBezier(points: [q[0],q[4],q[7],q[9]])

        let taggedLeft = TimeTaggedCurve(_t1: left_t1, _t2: left_t2, curve: left)
        let taggedRight = TimeTaggedCurve(_t1: right_t1, _t2: right_t2, curve: right)
        
        // if we have no t2, we're done
        if t2 == nil {
            let result = SplitResult.multipleCurves(left: taggedLeft,
                                                    right: taggedRight,
                                                    span: q
            )
            return result;
        }
        
        // if we have a t2, split again:
        let t2Prime = Utils.map(t2!,t1,1,0,1);
        let subsplit = taggedRight.split(t2Prime);
        if case let SplitResult.multipleCurves(left, _, _) = subsplit {
            return SplitResult.singleCurve(curve: left)
        }
        else {
            assert(false, "what?")
        }
    }

}

enum SplitResult {
    case singleCurve(curve: TimeTaggedCurve)
    case multipleCurves(left: TimeTaggedCurve, right: TimeTaggedCurve, span: [BKPoint])
}

class CubicBezier {
    
    let points: [BKPoint]
    let order: Int = 3
    private let threeD: Bool = false // todo: fix this
    private let linear: Bool = false // todo: fix this
    
    var p0: BKPoint {
        get {
            return self.points[0]
        }
    }
    var p1: BKPoint {
        get {
            return self.points[1]
        }
    }
    var p2: BKPoint {
        get {
            return self.points[2]
        }
    }
    var p3: BKPoint {
        get {
            return self.points[3]
        }
    }

    
    init(points: [BKPoint]) {
        self.points = points
    }
    
    init(p0: BKPoint, p1: BKPoint, p2: BKPoint, p3: BKPoint) {
        points = [p0, p1, p2, p3]
    }
 
    private static func getABC(n: Int, S: BKPoint, B: BKPoint, E: BKPoint, t: BKFloat = 0.5) -> (A: BKPoint, B: BKPoint, C: BKPoint) {
        let u = Utils.projectionRatio(n: n, t: t)
        let um = 1-u
        let C = BKPoint(
            x: u*S.x + um*E.x,
            y: u*S.y + um*E.y
        )
        let s = Utils.abcRatio(n: n, t: t)
        let A = BKPoint(
            x: B.x + (B.x-C.x)/s,
            y: B.y + (B.y-C.y)/s
        )
        return ( A:A, B:B, C:C );
    }

    convenience init(fromPointsWithS S: BKPoint, B: BKPoint, E: BKPoint, t: BKFloat = 0.5, d1 tempD1: BKFloat? = nil) {
        
        let abc = CubicBezier.getABC(n: 3, S: S, B: B, E: E, t: t);

        let d1 = (tempD1 != nil) ? tempD1! : Utils.dist(B,abc.C)
        let d2 = d1 * (1-t) / t
        
        let selen = Utils.dist(S,E)
        let lx = (E.x-S.x) / selen
        let ly = (E.y-S.y) / selen
        let bx1 = d1 * lx
        let by1 = d1 * ly
        let bx2 = d2 * lx
        let by2 = d2 * ly
        
        // derivation of new hull coordinates
        let e1  = BKPoint( x: B.x - bx1, y: B.y - by1 )
        let e2  = BKPoint( x: B.x + bx2, y: B.y + by2 )
        let A   = abc.A
        let v1  = BKPoint( x: A.x + (e1.x-A.x)/(1-t), y: A.y + (e1.y-A.y)/(1-t) )
        let v2  = BKPoint( x: A.x + (e2.x-A.x)/(t), y: A.y + (e2.y-A.y)/(t) )
        let nc1 = BKPoint( x: S.x + (v1.x-S.x)/(t), y: S.y + (v1.y-S.y)/(t) )
        let nc2 = BKPoint( x: E.x + (v2.x-E.x)/(1-t), y: E.y + (v2.y-E.y)/(1-t) )
        // ...done
        self.init(p0:S, p1: nc1, p2: nc2, p3: E);
        
    }
    
    /*
        Calculates the length of this Bezier curve. Length is calculated using numerical approximation, specifically the Legendre-Gauss quadrature algorithm.
     */
    func length() -> BKFloat {
        return 0.0
    }
    
    func compute(_ t: BKFloat) -> BKPoint {
        // shortcuts
        if t==0 {
            return self.points[0]
        }
        if t==1 {
            return self.points[self.order]
        }
        
        var p = self.points
        let mt = 1-t;
        
        // linear?
        if self.order == 1 {
            var value = BKPoint(
                x: mt*p[0].x + t*p[1].x,
                y: mt*p[0].y + t*p[1].y
            )
            if self.threeD {
                value.z = mt*p[0].z + t*p[1].z
            }
            return value
        }
        
        // quadratic/cubic curve?
        if self.order < 4 {
            let mt2: BKFloat = mt*mt
            let t2: BKFloat = t*t
            var a: BKFloat = 0
            var b: BKFloat = 0
            var c: BKFloat = 0
            var d: BKFloat = 0
            if self.order == 2 {
                p = [p[0], p[1], p[2], BKPointZero]
                a = mt2
                b = mt * t*2
                c = t2
            }
            else if self.order == 3 {
                a = mt2 * mt
                b = mt2 * t * 3.0
                c = mt * t2 * 3.0
                d = t * t2
            }
            var ret = BKPoint(
                x: a*p[0].x + b*p[1].x + c*p[2].x + d*p[3].x,
                y: a*p[0].y + b*p[1].y + c*p[2].y + d*p[3].y
            )
            if self.threeD {
                ret.z = a*p[0].z + b*p[1].z + c*p[2].z + d*p[3].z;
            }
            return ret
        }
        
// todo: implement me
        // higher order curves: use de Casteljau's computation
//        var dCpts = JSON.parse(JSON.stringify(this.points));
//        while dCpts.length > 1 {
//            for (var i=0; i<dCpts.length-1; i++) {
//                dCpts[i] = {
//                    x: dCpts[i].x + (dCpts[i+1].x - dCpts[i].x) * t,
//                    y: dCpts[i].y + (dCpts[i+1].y - dCpts[i].y) * t
//                };
//                if (typeof dCpts[i].z !== "undefined") {
//                    dCpts[i] = dCpts[i].z + (dCpts[i+1].z - dCpts[i].z) * t
//                }
//            }
//            dCpts.splice(dCpts.length-1, 1);
//        }
//        return dCpts[0];
        assert(false)  // todo: higher order unsupported for now
        return BKPointZero
    }
    
    lazy var dpoints: [BKPoint] = self.update()
    lazy var clockwise: Bool = self.computeDirection()
    
    private func computeDirection() -> Bool {
        let points = self.points
        let angle = Utils.angle(o: points[0], v1: points[self.order], v2: points[1])
        return angle > 0;
    }
    
    private func update() -> [BKPoint] {
        // todo: is this function correct? :(
        var ret: [BKPoint] = [];
        var p: [BKPoint] = self.points
        for d in (2 ... p.count).reversed() {
            let c = d-1
            var list: [BKPoint] = [];
            for j:Int in 0..<c {
                let dpt: BKPoint = (p[j+1] - p[j]) * BKFloat(c)
                list.append(dpt)
            }
            ret += list
            p = list
        }
        return ret
    }
    
    func generateLookupTable(withSteps steps: Int = 100) -> [BKPoint] {
        assert(steps >= 0)
        var table: [BKPoint] = []
        for i in 0 ... steps {
            let t = BKFloat(i) / BKFloat(steps)
            table.append(self.compute(t))
        }
        
        return table
    }
    
    func derivative(_ t: BKFloat) -> BKPoint {
        let mt: BKFloat = 1-t
        var a: BKFloat = 0.0
        var b: BKFloat = 0.0
        var c: BKFloat = 0.0
        var p: [BKPoint] = self.dpoints // todo: more efficient way of doing this?
        if self.order == 2 {
            p = [p[0], p[1], BKPointZero]
            a = mt
            b = t
        }
        else if self.order == 3 {
            a = mt*mt
            b = mt*t*2
            c = t*t
        }
        let ret = BKPoint(
            x: a*p[0].x + b*p[1].x + c*p[2].x,
            y: a*p[0].y + b*p[1].y + c*p[2].y,
            z: a*p[0].z + b*p[1].z + c*p[2].z
        )
        return ret;
    }
    
    func hull(_ t: BKFloat) -> [BKPoint] {
        var p = self.points
        var q: [BKPoint] = [BKPoint](repeating: BKPointZero, count: self.order + 1)
        q[0] = p[0]
        q[1] = p[1]
        q[2] = p[2]
        if self.order == 3 {
            q[3] = p[3]
        }
        // we lerp between all points at each iteration, until we have 1 point left.
        while p.count > 1 {
            var _p: [BKPoint] = []
            let l = p.count-1
            for i in 0..<l {
                let pt = Utils.lerp(t,p[i],p[i+1])
                q.append(pt)
                _p.append(pt)
            }
            p = _p;
        }
        return q;
    }


    func normal(_ t: BKFloat) -> BKPoint {
        return self.threeD ? self.normal3(t) : self.normal2(t);
    }
    
    private func normal2(_ t: BKFloat) -> BKPoint {
        let d = self.derivative(t)
        let q = d.length
        return BKPoint( x: -d.y/q, y: d.x/q )
    }
    
    private func normal3(_ t: BKFloat) -> BKPoint {
        
        let r1 = self.derivative(t).normalize()
        let r2 = self.derivative(t+0.01).normalize()
        // cross product
        let c = BKPoint(
            x: r2.y*r1.z - r2.z*r1.y,
            y: r2.z*r1.x - r2.x*r1.z,
            z: r2.x*r1.y - r2.y*r1.x
        ).normalize()
        // rotation matrix
        let R = [   c.x*c.x,   c.x*c.y-c.z, c.x*c.z+c.y,
                    c.x*c.y+c.z,   c.y*c.y,   c.y*c.z-c.x,
                    c.x*c.z-c.y, c.y*c.z+c.x,   c.z*c.z    ]
        // normal vector:
        let n = BKPoint(
            x: R[0] * r1.x + R[1] * r1.y + R[2] * r1.z,
            y: R[3] * r1.x + R[4] * r1.y + R[5] * r1.z,
            z: R[6] * r1.x + R[7] * r1.y + R[8] * r1.z
        )
        return n
    }
    
    func extrema() -> (x: [BKFloat], y: [BKFloat], z: [BKFloat]?, values: [BKFloat] ) {
//        let dims = [0,1,2] // todo: fix this
//        var result = {}
//        var roots = []
//        for dim in dims {
//            let mfn = {(v: BKPoint) -> BKFloat in
//                switch(dim) {
//                    case 0:
//                        return v.x
//                    case 1:
//                        return v.y
//                    case 2:
//                        return v.z
//                }
//            }
//            let p: [BKFloat] = self.dpoints[0].map(mfn);
//            result[dim] = Utils.droots(p);
//            if self.order == 3 {
//                p = self.dpoints[1].map(mfn);
//                result[dim] = result[dim].concat(Utils.droots(p));
//            }
//            result[dim] = result[dim].filter(
//                {(t) in
//                    return (t >= 0 && t <= 1)
//                }
//            )
//            roots += result[dim].sort();
//        }
//        roots = roots.sort().filter({(v, idx) in
//            return (roots.indexOf(v) == idx);
//        })
//        result.values = roots
//        return result
        
        return (x: [], y: [], z: [], values: [])
    }
    
    func split(_ t1: BKFloat, _ t2: BKFloat? = nil) -> SplitResult {
        let taggedSelf = TimeTaggedCurve(_t1: 0, _t2: 1, curve: self)
        return taggedSelf.split(t1, t2)
    }
    
    lazy var simple: Bool =  {
        if self.order == 3 {
            var a1 = Utils.angle(o: self.points[0], v1: self.points[3], v2: self.points[1]);
            var a2 = Utils.angle(o: self.points[0], v1: self.points[3], v2: self.points[2]);
            if a1>0 && a2<0 || a1<0 && a2>0 {
              return false;
            }
        }
        var n1 = self.normal(0);
        var n2 = self.normal(1);
        var s = n1.x*n2.x + n1.y*n2.y + n1.z*n2.z;
        var angle = abs(acos(s));
        return angle < (BKFloat.pi / 3.0);
    }()

    
    /*
        Reduces a curve to a collection of "simple" subcurves, where a simpleness is defined as having all control points on the same side of the baseline (cubics having the additional constraint that the control-to-end-point lines may not cross), and an angle between the end point normals no greater than 60 degrees.
     
        The main reason this function exists is to make it possible to scale curves. As mentioned in the offset function, curves cannot be offset without cheating, and the cheating is implemented in this function. The array of simple curves that this function yields can safely be scaled.
     

    */
    func reduce() -> [TimeTaggedCurve] {
        let step: BKFloat = 0.01
        var pass1: [TimeTaggedCurve] = []
        var pass2: [TimeTaggedCurve] = []
        // first pass: split on extrema
        var extrema: [BKFloat] = self.extrema().values;
        if extrema.index(of: 0) == nil {
            extrema.insert(0, at: 0)
        }
        if extrema.index(of: 1) == nil {
            extrema.append(1)
        }
        
        var t1 = extrema[0]
        for i in 1..<extrema.count {
            let t2 = extrema[i]
            if case let SplitResult.singleCurve(curve) = self.split(t1,t2) {
                let taggedSegment = TimeTaggedCurve(_t1: t1, _t2: t2, curve: curve.curve)
                pass1.append(taggedSegment)
                t1 = t2
            }
            else {
                assert(false, "fuck")
            }
        }
        
        // second pass: further reduce these segments to simple segments
        for p1 in pass1 {
            var t1: BKFloat = 0.0
            var t2: BKFloat = 0.0
            while t2 <= 1.0 {
                t2 = t1+step
                while t2 <= (1.0+step) {
                    if case let SplitResult.singleCurve(segment) = p1.curve.split(t1,t2) {

                        if segment.curve.simple == false {
                            t2 -= step
                            if abs(t1-t2) < step {
                                // we can never form a reduction
                                return [];
                            }
                            if case let SplitResult.singleCurve(segment) = p1.curve.split(t1,t2) {
                                let taggedSegment = TimeTaggedCurve(_t1: Utils.map(t1,0,1,p1._t1,p1._t2),
                                                                    _t2: Utils.map(t2,0,1,p1._t1,p1._t2),
                                                                    curve: segment.curve)
                                pass2.append(taggedSegment);
                                t1 = t2;
                                break;
                            }
                            else {
                                assert(false, "fuck")
                            }
                        }
                    }
                    else {
                        assert(false, "fuck")
                    }
                    t2 += step
                }
            }
            if t1 < 1.0 {
                if case let SplitResult.singleCurve(segment) = p1.curve.split(t1,t2) {
                    let taggedSegment = TimeTaggedCurve(_t1: Utils.map(t1,0,1,p1._t1,p1._t2),
                                                        _t2: p1._t2,
                                                        curve: segment.curve)
                    pass2.append(taggedSegment);
                }
                else {
                    assert(false, "fuck")
                }
            }
        }
        return pass2;
    }
    
    /*
        Scales a curve with respect to the intersection between the end point normals. Note that this will only work if that point exists, which is only guaranteed for simple segments.
     */
    func scale(distance d: BKFloat) -> CubicBezier {
        let order = self.order
//        var distanceFn = false
//        if(typeof d === "function") { distanceFn = d; }
//        if(distanceFn && order === 2) { return this.raise().scale(distanceFn); }
        
        // TODO: add special handling for degenerate (=linear) curves.
//        let clockwise = self.clockwise;
        let r1 = /*distanceFn ? distanceFn(0) :*/ d
        let r2 = /*distanceFn ? distanceFn(1) :*/ d
        var v = [ self.internalOffset(t: 0, distance: 10), self.internalOffset(t: 1, distance: 10) ]
        let o = Utils.lli4(v[0].p, v[0].c, v[1].p, v[0].c)
        if(o == nil) { // todo: replace with guard let
            assert(false, "cannot scale this curve. Try reducing it first.")
        }
        // move all points by distance 'd' wrt the origin 'o'
        var points: [BKPoint] = self.points
        var np: [BKPoint] = [BKPoint](repeating: BKPointZero, count: self.order + 1); // todo: is this length correct?
        
        // move end points by fixed distance along normal.
        for t in [0,1] {
            let p: BKPoint = points[t*order]
            np[t*order] = p + (v[t].n * ((t != 0) ? r2 : r1))
        }
        
        // move control points to lie on the intersection of the offset
        // derivative vector, and the origin-through-control vector
        for t in [0,1] {
            if (self.order==2) && (t != 0) {
                break
            }
            let p = np[t*order]
            let d = self.derivative(BKFloat(t))
            let p2 = BKPoint( x: p.x + d.x, y: p.y + d.y )
            np[t+1] = Utils.lli4(p, p2, o!, points[t+1])!
        }
        return CubicBezier(points: np);
        
        // todo: javascript supported distance function as argument
    }
    
    func offset(distance d: BKFloat) -> [CubicBezier] {
        if self.linear {
            let n = self.normal(0);
            let coords: [BKPoint] = self.points.map({(p: BKPoint) -> BKPoint in
                return p + n * d
            })
            return [CubicBezier(points: coords)]
        }
        // for non-linear curves we need to create a set of curves
        let reduced: [TimeTaggedCurve] = self.reduce()
        return reduced.map({(s: TimeTaggedCurve) -> CubicBezier in
            return s.curve.scale(distance: d)
        })
    }
    
    func offset(t: BKFloat, distance d: BKFloat) -> BKPoint {
        return self.internalOffset(t: t, distance: d).p
    }
    
    private func internalOffset(t: BKFloat, distance d: BKFloat) -> (c: BKPoint, n: BKPoint, p: BKPoint) {
        let c = self.compute(t);
        let n = self.normal(t);
        return (c: c, n: n, p: c + n * d)
    }

    
//    func derivative(t: BKFloat) -> BKPoint {
//    /*
//        Calculates the curve tangent at the specified t value. Note that this yields a not-normalized vector {x: dx, y: dy}.
//     */
//        return BKPoint(x: 0.0, y: 0.0)
//    }
    
//    func normal(t: BKFloat) -> BKPoint {
//        
//    }
//    
//    func split(t: BKFloat) -> (b1: CubicBezier, b2: CubicBezier) {
//        
//    }
//    
//    func horizontalExtrema() -> BKPoint {
//        
//    }
//    
//    func verticalExtrema() -> BKPoint {
//        
//    }
//    
//    func boundingRect() -> BKRect {
//        
//    }
//    
//    func project(p: BKPoint) -> (t: BKFloat, p: BKPoint) {
//        
//    }
    
}
