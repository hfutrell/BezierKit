//
//  CubicBezier.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import AppKit

typealias DistanceFunction = (_ v: BKFloat) -> BKFloat

// todo: get rid of this whole stupid struct
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
        let left_t1  = Utils.map(0,  0,1, self._t1, self._t2)
        let left_t2  = Utils.map(t1, 0,1, self._t1, self._t2)
        let right_t1 = Utils.map(t1, 0,1, self._t1, self._t2)
        let right_t2 = Utils.map(1,  0,1, self._t1, self._t2)
        
        // no shortcut: use "de Casteljau" iteration.
        var q = self.curve.hull(t1);

        let left = self.curve.order == 2 ? CubicBezier(points: [q[0],q[3],q[5]]) : CubicBezier(points: [q[0],q[4],q[7],q[9]])
        let right = self.curve.order == 2 ? CubicBezier(points: [q[0],q[3],q[5]]) : CubicBezier(points: [q[9],q[8],q[6],q[3]])

        let taggedLeft = TimeTaggedCurve(_t1: left_t1, _t2: left_t2, curve: left)
        let taggedRight = TimeTaggedCurve(_t1: right_t1, _t2: right_t2, curve: right)
        
        // if we have no t2, we're done
        if t2 == nil {
            let result = SplitResult.multipleCurves(left: taggedLeft,
                                                    right: taggedRight,
                                                    span: q
            )
            return result
        }
        
        // if we have a t2, split again:
        let t2Prime = Utils.map(t2!,t1,1,0,1);
        let subsplit = taggedRight.split(t2Prime);
        if case let SplitResult.multipleCurves(left, _, _) = subsplit {
            return SplitResult.singleCurve(curve: left)
        }
        else {
            assert(false, "what?")
            return SplitResult.singleCurve(curve: self) // TODO: fix
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
    let dims: [Int] = [0, 1, 2] // todo: improve

    var p0: BKPoint {
        return self.points[0]
    }
    var p1: BKPoint {
        return self.points[1]
    }
    var p2: BKPoint {
        return self.points[2]
    }
    var p3: BKPoint {
        return self.points[3]
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
    
    lazy var linear: Bool = {
        let order = self.order
        let points = self.points
        var a = Utils.align(points, p1:points[0], p2:points[order])
        for i in 0..<a.count {
            // TODO: investigate horrible magic number usage
            if abs(a[i].y) > 0.0001 {
                return false
            }
        }
        return true
    }()
    
    /*
        Calculates the length of this Bezier curve. Length is calculated using numerical approximation, specifically the Legendre-Gauss quadrature algorithm.
     */
    func length() -> BKFloat {
        return Utils.length({(_ t: BKFloat) in self.derivative(t)})
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
    
    lazy var dpoints: [[BKPoint]] = self.update()
    lazy var clockwise: Bool = self.computeDirection()
    
    private func computeDirection() -> Bool {
        let points = self.points
        let angle = Utils.angle(o: points[0], v1: points[self.order], v2: points[1])
        return angle > 0;
    }
    
    private func update() -> [[BKPoint]] {
        // todo: is this function correct? :(
        var ret: [[BKPoint]] = [];
        var p: [BKPoint] = self.points
        for d in (2 ... p.count).reversed() {
            let c = d-1
            var list: [BKPoint] = [];
            for j:Int in 0..<c {
                let dpt: BKPoint = (p[j+1] - p[j]) * BKFloat(c)
                list.append(dpt)
            }
            ret.append(list)
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
        var p: [BKPoint] = self.dpoints[0] // todo: more efficient way of doing this?
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
    
    func extrema() -> (xyz: [[BKFloat]], values: [BKFloat] ) { // todo: is xyz used normally? can we stick it in an optional inout?
        let dims = [0, 1, 2] // todo: cleanup
        var result: (xyz: [[BKFloat]], values: [BKFloat]) = (xyz: [[],[],[]], values: [])
        var roots: [BKFloat] = []
        for dim in dims {
            let mfn = {(v: BKPoint) -> BKFloat in
                switch(dim) {
                    case 0:
                        return v.x
                    case 1:
                        return v.y
                    case 2:
                        return v.z
                    default:
                        assert(false, "nope!")
                        return 0.0 // TODO: fix
                }
            }
            var p: [BKFloat] = self.dpoints[0].map(mfn)
            result.xyz[dim] = Utils.droots(p);
            if self.order == 3 {
                p = self.dpoints[1].map(mfn);
                result.xyz[dim] += Utils.droots(p);
            }
            result.xyz[dim] = result.xyz[dim].filter(
                {(t) in
                    return (t >= 0 && t <= 1)
                }
            )
            roots += (result.xyz[dim].sorted())
        }
        // todo: cleanup, what was this ugly code even doing in the javascript?
        var rootsPrime: [BKFloat] = []
        let sortedRoots = roots.sorted()
        for idx in 0..<sortedRoots.count {
            let v: BKFloat = sortedRoots[idx]
            if sortedRoots.index(of: v) == idx {
                rootsPrime.append(v)
            }
        }
        result.values = rootsPrime
        return result
    }
        
    lazy var boundingBox: BoundingBox = {
        // todo: this function is fugly
        let extrema = self.extrema()
        var result: BoundingBox = BoundingBox(min: BKPointZero, max: BKPointZero)
        for d in self.dims {
            let computeDimension = { (t: BKFloat) -> BKFloat in
                let p = self.compute(t)
                if ( d == 0 ) {
                    return p.x
                }
                else if ( d == 1 ) {
                    return p.y
                }
                else if ( d == 2 ) {
                    return p.z
                }
                else {
                    assert(false, "what?")
                    return 0
                }
            }
            let (min, max) = Utils.getminmax(list: extrema.xyz[d], computeDimension: computeDimension )
            if ( d == 0 ) {
                result.min.x = min
                result.max.x = max
            }
            if ( d == 1 ) {
                result.min.y = min
                result.max.y = max
            }
            if ( d == 2 ) {
                result.min.z = min
                result.max.z = max
            }
        }
        return result;
    }()
    
    private func split(_ t1: BKFloat, _ t2: BKFloat? = nil) -> SplitResult {
        let taggedSelf = TimeTaggedCurve(_t1: 0, _t2: 1, curve: self)
        return taggedSelf.split(t1, t2)
    }
    
    func split(at t1: BKFloat) -> (left: CubicBezier, right: CubicBezier) {
        assert(t1 > 0)
        assert(t1 < 1)
        let taggedSelf = TimeTaggedCurve(_t1: 0, _t2: 1, curve: self)
        if case let .multipleCurves(left, right, _) = taggedSelf.split(t1) {
            return (left: left.curve, right: right.curve)
        }
        else {
            assert(false, "what?")
            return (left: self, right: self) // TODO: fix
        }
    }
    
    func split(from t1: BKFloat, to t2: BKFloat) -> CubicBezier {
        assert( t2 > t1 )
        let taggedSelf = TimeTaggedCurve(_t1: 0, _t2: 1, curve: self)
        switch taggedSelf.split(t1, t2) {
            case .multipleCurves(_, let right, _):
                return right.curve
            case .singleCurve(let curve):
                return curve.curve
        }
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
        // TODO: this loop is INSANELY SLOW
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
        return internalScale(distance: d, distanceFunction: nil)
    }
    
    func scale(distanceFunction distanceFn: @escaping DistanceFunction) -> CubicBezier {
        return internalScale(distance: nil, distanceFunction: distanceFn)
    }
    
    private func internalScale(distance d: BKFloat?, distanceFunction distanceFn: DistanceFunction?) -> CubicBezier {
        
        assert((d != nil && distanceFn == nil) || (d == nil && distanceFn != nil))
        
        let order = self.order
        
        if distanceFn != nil && self.order == 2 {
            // for quadratics we must raise to cubics prior to scaling
            // todo: implement raise() function an enable this
//            return self.raise().scale(distance: nil, distanceFunction: distanceFn);
        }
        
        // TODO: add special handling for degenerate (=linear) curves.
        let r1 = (distanceFn != nil) ? distanceFn!(0) : d!
        let r2 = (distanceFn != nil) ? distanceFn!(1) : d!
        var v = [ self.internalOffset(t: 0, distance: 10), self.internalOffset(t: 1, distance: 10) ]
        let o = Utils.lli4(v[0].p, v[0].c, v[1].p, v[1].c)
        if o == nil { // todo: replace with guard let
            // todo: WE CAN HIT THIS IN THE OUTLINES EXAMPLE! what is wrong?
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
        
        if d != nil {
            // move control points to lie on the intersection of the offset
            // derivative vector, and the origin-through-control vector
            for t in [0,1] {
                if (self.order==2) && (t != 0) {
                    break
                }
                let p = np[t*order]
                let d = self.derivative(BKFloat(t))
                let p2 = p + d
                np[t+1] = Utils.lli4(p, p2, o!, points[t+1])!
            }
            return CubicBezier(points: np);
        }
        else {
            
            let clockwise = self.clockwise;
            for t in [0,1] {
                if (self.order==2) && (t != 0) {
                    break
                }
                let p = self.points[t+1]
                let ov = (p - o!).normalize()
                var rc: BKFloat = distanceFn!(BKFloat(t+1) / BKFloat(self.order))
                if !clockwise {
                   rc = -rc
                }
                np[t+1] = p + ov * rc
            }
            return CubicBezier(points: np);
        }
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
    
    func project(point: BKPoint) -> BKPoint {
        // step 1: coarse check
        let LUT = self.generateLookupTable()
        let l = LUT.count-1
        let closest = Utils.closest(LUT, point)
        var mdist = closest.mdist
        let mpos = closest.mpos
        if (mpos == 0) || (mpos == l) {
            let t = BKFloat(mpos) / BKFloat(l)
            let pt = self.compute(t)
//            pt.t = t
//            pt.d = mdist
            return pt
        }
        
        // step 2: fine check
        let t1 = BKFloat(mpos-1) / BKFloat(l)
        let t2 = BKFloat(mpos+1) / BKFloat(l)
        let step = 0.1 / BKFloat(l)
        mdist += 1;
        var ft = t1
        for t in stride(from: t1, to: t2+step, by: step) {
            let p = self.compute(t);
            let d = Utils.dist(point, p);
            if d<mdist {
                mdist = d
                ft = t
            }
        }
        let p = self.compute(ft)
//        p.t = ft
//        p.d = mdist
        return p
    }
    
    private func overlaps(curve: CubicBezier) -> Bool {
        let lbbox = self.boundingBox
        let tbbox = curve.boundingBox
        return lbbox.overlaps(tbbox);
    }
    
    static let defaultCurveIntersectionThreshold: BKFloat = 0.5
    
    func intersects(line: Line, curveIntersectionThreshold: BKFloat = defaultCurveIntersectionThreshold) -> [BKFloat] {
        let mx = min(line.p1.x, line.p2.x)
        let my = min(line.p1.y, line.p2.y)
        let MX = max(line.p1.x, line.p2.x)
        let MY = max(line.p1.y, line.p2.y)
        return Utils.roots(points: self.points, line: line).filter({(t: BKFloat) in
            let p = self.compute(t);
            return Utils.between(p.x, mx, MX) && Utils.between(p.y, my, MY);
        })
    }
    
    func intersects(curveIntersectionThreshold: BKFloat = defaultCurveIntersectionThreshold) -> [Intersection] {
        let reduced = self.reduce();
        // "simple" curves cannot intersect with their direct
        // neighbour, so for each segment X we check whether
        // it intersects [0:x-2][x+2:last].
        let len=reduced.count-2
        var results: [Intersection] = []
        if len > 0 {
            for i in 0..<len {
                let left = [reduced[i]]
                let right = Array(reduced.suffix(from: i+2))
                let result = self.curveIntersects(c1: left, c2: right, curveIntersectionThreshold: curveIntersectionThreshold)
                results += result
            }
        }
        return results
    }
    
    func intersects(curve: CubicBezier, curveIntersectionThreshold: BKFloat = defaultCurveIntersectionThreshold) -> [Intersection] {
        
        return self.curveIntersects(c1: self.reduce(),
                                    c2: [TimeTaggedCurve(_t1: 0.0, _t2: 1.0, curve: curve)],
                                    curveIntersectionThreshold: curveIntersectionThreshold);
    }
    
    private func curveIntersects(c1: [TimeTaggedCurve], c2: [TimeTaggedCurve], curveIntersectionThreshold: BKFloat) -> [Intersection] {
        var pairs: [(left: TimeTaggedCurve, right: TimeTaggedCurve)] = []
        // step 1: pair off any overlapping segments
        for l in c1 {
            for r in c2 {
                if l.curve.overlaps(curve: r.curve) {
                    pairs.append((left: l, right: r))
                }
            }
        }
        // step 2: for each pairing, run through the convergence algorithm.
        var intersections: [Intersection] = [];
        for pair in pairs {
            intersections += Utils.pairiteration(pair.left, pair.right, curveIntersectionThreshold)
        }
        return intersections
    }

    
    private func internalOffset(t: BKFloat, distance d: BKFloat) -> (c: BKPoint, n: BKPoint, p: BKPoint) {
        let c = self.compute(t);
        let n = self.normal(t);
        return (c: c, n: n, p: c + n * d)
    }
    
    func outline(distance d1: BKFloat) -> PolyBezier {
        return internalOutline(d1: d1, d2: d1, d3: 0.0, d4: 0.0, graduated: false)
    }
    
    func outline(distance d1: BKFloat, d2: BKFloat) -> PolyBezier {
        return internalOutline(d1: d1, d2: d2, d3: 0.0, d4: 0.0, graduated: false)
    }
    
    func outline(d1: BKFloat, d2: BKFloat, d3: BKFloat, d4: BKFloat) -> PolyBezier {
        return internalOutline(d1: d1, d2: d2, d3: d3, d4: d4, graduated: true)
    }

    func outlineShapes(distance d1: BKFloat, curveIntersectionThreshold: BKFloat = defaultCurveIntersectionThreshold) -> [Shape] {
        return self.outlineShapes(distance: d1, d2: d1, curveIntersectionThreshold: curveIntersectionThreshold)
    }
    
    func outlineShapes(distance d1: BKFloat, d2: BKFloat, curveIntersectionThreshold: BKFloat = defaultCurveIntersectionThreshold) -> [Shape] {
        var outline = self.outline(distance: d1, d2: d2).curves
        var shapes: [Shape] = []
        let len = outline.count
        for i in 1..<len/2 {
            var shape = Utils.makeshape(outline[i], outline[len-i], curveIntersectionThreshold)
            shape.startcap.virtual = (i > 1)
            shape.endcap.virtual = (i < len/2-1)
            shapes.append(shape)
        }
        return shapes
    }

    
    func internalOutline(d1: BKFloat, d2: BKFloat, d3: BKFloat, d4: BKFloat, graduated: Bool) -> PolyBezier {

        let reduced = self.reduce()
        let len = reduced.count
        var fcurves: [CubicBezier] = []
        var bcurves: [CubicBezier] = []
//        var p
        var alen: BKFloat = 0.0 // WTF why is this always zero? what is the point?
        let tlen = self.length()
        
        let linearDistanceFunction = {(_ s: BKFloat,_ e: BKFloat,_ tlen: BKFloat,_ alen: BKFloat,_ slen: BKFloat) -> DistanceFunction in
            return { (_ v: BKFloat) -> BKFloat in
                let f1: BKFloat = alen / tlen
                let f2: BKFloat = (alen+slen) / tlen
                let d: BKFloat = e-s
                return Utils.map(v, 0,1, s+f1*d, s+f2*d)
            }
        }
        
        // form curve oulines
        for segment in reduced {
            let slen = segment.curve.length();
            if graduated {
                fcurves.append(segment.curve.scale(distanceFunction: linearDistanceFunction( d1,  d3, tlen, alen, slen)  ));
                bcurves.append(segment.curve.scale(distanceFunction: linearDistanceFunction(-d2, -d4, tlen, alen, slen)  ));
            }
            else {
                fcurves.append(segment.curve.scale(distance: d1))
                bcurves.append(segment.curve.scale(distance: -d2))
            }
            alen += slen
        }
        
        // reverse the "return" outline
        bcurves = bcurves.map({(s: CubicBezier) in
            let p = s.points
            if p.count == 4 {
                return CubicBezier(points: [p[3],p[2],p[1],p[0]])
            }
            else if p.count == 3 {
                return CubicBezier(points: [p[2],p[1],p[0]])
            }
            else {
                assert(false, "crud")
                return s
            }
        }).reversed();
        
        // form the endcaps as lines
        let fs = fcurves[0].points[0]
        let fe = fcurves[len-1].points[fcurves[len-1].points.count-1]
        let bs = bcurves[len-1].points[bcurves[len-1].points.count-1]
        let be = bcurves[0].points[0]
        let ls = Utils.makeline(bs,fs)
        let le = Utils.makeline(fe,be)
        let segments = [ls] + fcurves + [le] + bcurves
//        let slen = segments.count
        
        return PolyBezier(curves: segments)

    }
    
    func arcs(errorThreshold: BKFloat = 0.5) -> [Arc] {
        let circles: [Arc] = [];
        return self.iterate(errorThreshold: errorThreshold, circles: circles)
    }
    
    private func iterate(errorThreshold: BKFloat, circles: [Arc]) -> [Arc] {
    
        var result: [Arc] = circles
        var s: BKFloat = 0.0
        var e: BKFloat = 1.0
        var safety: Int = 0
        // we do a binary search to find the "good `t` closest to no-longer-good"
        
        let error = {(pc: BKPoint, np1: BKPoint, s: BKFloat, e: BKFloat) -> BKFloat in
            let q = (e - s) / 4.0
            let c1 = self.compute(s + q)
            let c2 = self.compute(e - q)
            let ref = Utils.dist(pc, np1)
            let d1  = Utils.dist(pc, c1)
            let d2  = Utils.dist(pc, c2)
            return fabs(d1-ref) + fabs(d2-ref)
        }
        
        repeat {
            safety=0
            
            // step 1: start with the maximum possible arc
            e = 1.0
            
            // points:
            let np1 = self.compute(s)
            var prev_arc: Arc? = nil
            var arc: Arc? = nil
            
            // booleans:
            var curr_good = false
            var prev_good = false
            var done = false
            
            // numbers:
            var m = e
            var prev_e: BKFloat = 1.0
            
            // step 2: find the best possible arc
            repeat {
                prev_good = curr_good
                prev_arc = arc
                m = (s + e)/2.0
                
                let np2 = self.compute(m)
                let np3 = self.compute(e)
                
                arc = Utils.getccenter(np1, np2, np3, Arc.Interval(start: s, end: e))
                
                let errorAmount = error(arc!.origin, np1, s, e);
                curr_good = errorAmount <= errorThreshold
                
                done = prev_good && !curr_good
                if !done {
                  prev_e = e
                }
                
                // this arc is fine: we can move 'e' up to see if we can find a wider arc
                if curr_good {
                    // if e is already at max, then we're done for this arc.
                    if e >= 1.0 {
                        prev_e = 1.0
                        prev_arc = arc
                        break;
                    }
                    // if not, move it up by half the iteration distance
                    e = e + (e-s)/2.0
                }
                else {
                    // this is a bad arc: we need to move 'e' down to find a good arc
                    e = m
                }
                safety += 1
            } while !done && safety <= 100
            
            if safety >= 100 {
                NSLog("arc abstraction somehow failed...");
                break;
            }
            
            // console.log("[F] arc found", s, prev_e, prev_arc.x, prev_arc.y, prev_arc.s, prev_arc.e);
            
            prev_arc = prev_arc != nil ? prev_arc : arc
            result.append(prev_arc!)
            s = prev_e
        } while e < 1.0
        
        return result
    }


}
