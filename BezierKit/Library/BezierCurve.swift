//
//  BezierCurve.swift
//  BezierKit
//
//  Created by Holmes Futrell on 2/19/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import Foundation

public typealias DistanceFunction = (_ v: BKFloat) -> BKFloat

public struct Subcurve<CurveType> where CurveType: BezierCurve {
    public let t1: BKFloat
    public let t2: BKFloat
    public let curve: CurveType
    
    internal init(curve: CurveType) {
        self.t1 = 0.0
        self.t2 = 1.0
        self.curve = curve
    }
    
    internal init(t1: BKFloat, t2: BKFloat, curve: CurveType) {
        self.t1 = t1
        self.t2 = t2
        self.curve = curve
    }
    
    internal func split(from t1: BKFloat, to t2: BKFloat) -> Subcurve<CurveType> {
        let curve: CurveType = self.curve.split(from: t1, to: t2)
        return Subcurve<CurveType>(t1: Utils.map(t1, 0,1, self.t1, self.t2),
                                   t2: Utils.map(t2, 0,1, self.t1, self.t2),
                                   curve: curve)
    }

    internal func split(at t: BKFloat) -> (left: Subcurve<CurveType>, right: Subcurve<CurveType>) {
        let (left, right) = curve.split(at: t)
        let t1 = self.t1
        let t2 = self.t2
        let subcurveLeft = Subcurve<CurveType>(t1: Utils.map(0, 0,1, t1, t2),
                                    t2: Utils.map(t, 0,1, t1, t2),
                                    curve: left)
        let subcurveRight = Subcurve<CurveType>(t1: Utils.map(t, 0,1, t1, t2),
                                     t2: Utils.map(1, 0,1, t1, t2),
                                     curve: right)
        return (left: subcurveLeft, right: subcurveRight)
    }
}

// MARK: -

extension BezierCurve {
    
    // MARK: -
    
    private var dpoints: [[BKPoint]] {
        var ret: [[BKPoint]] = []
        var p: [BKPoint] = self.points
        ret.reserveCapacity(p.count-1)
        for d in (2 ... p.count).reversed() {
            let c = d-1
            var list: [BKPoint] = []
            list.reserveCapacity(c)
            for j:Int in 0..<c {
                let dpt: BKPoint = BKFloat(c) * (p[j+1] - p[j])
                list.append(dpt)
            }
            ret.append(list)
            p = list
        }
        return ret
    }
    
    private var linear: Bool {
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
    }
    
    /*
     Calculates the length of this Bezier curve. Length is calculated using numerical approximation, specifically the Legendre-Gauss quadrature algorithm.
     */
    public func length() -> BKFloat {
        return Utils.length({(_ t: BKFloat) in self.derivative(t)})
    }
    
    // MARK:
    
    // computes the extrema for each dimension
    internal func internalExtrema(includeInflection: Bool) -> [[BKFloat]] {
        var xyz: [[BKFloat]] = []
        xyz.reserveCapacity(BKPoint.dimensions)
        // TODO: this code can be made a lot faster through inlining the droots computation such that allocations need not occur
        for d in 0..<BKPoint.dimensions {
            let mfn = {(v: BKPoint) in v[d]}
            var p: [BKFloat] = self.dpoints[0].map(mfn)
            xyz.append(Utils.droots(p))
            if includeInflection && self.order >= 3 {
                p = self.dpoints[1].map(mfn)
                xyz[d] += Utils.droots(p)
            }
            xyz[d] = xyz[d].filter({$0 >= 0 && $0 <= 1}).sorted()
        }
        return xyz
    }
    
    public func extrema() -> (xyz: [[BKFloat]], values: [BKFloat] ) {
        let xyz = self.internalExtrema(includeInflection: true)
        var roots = xyz.flatMap{$0}.sorted() // the roots for each dimension, flattened and sorted
        var values: [BKFloat] = []
        if roots.count > 0 {
            values.reserveCapacity(roots.count)
            var lastInserted: BKFloat = -BKFloat.infinity
            for i in 0..<roots.count { // loop ensures (pre-sorted) roots are unique when added to values
                let v = roots[i]
                if v > lastInserted {
                    values.append(v)
                    lastInserted = v
                }
            }
        }
        return (xyz: xyz, values: values)
    }
    
    // MARK: -
    public func hull(_ t: BKFloat) -> [BKPoint] {
        return Utils.hull(self.points, t)
    }
    
    public func generateLookupTable(withSteps steps: Int = 100) -> [BKPoint] {
        assert(steps >= 0)
        var table: [BKPoint] = []
        table.reserveCapacity(steps+1)
        for i in 0 ... steps {
            let t = BKFloat(i) / BKFloat(steps)
            table.append(self.compute(t))
        }
        return table
    }
    // MARK: -
        
    public func normal(_ t: BKFloat) -> BKPoint {
        func normal2(_ t: BKFloat) -> BKPoint {
            let d = self.derivative(t)
            let q = d.length
            return BKPoint( x: -d.y/q, y: d.x/q )
        }
        /*func normal3(_ t: BKFloat) -> BKPoint {
            let r1 = self.derivative(t).normalize()
            let r2 = self.derivative(t+0.01).normalize()
            // cross product
            var c = BKPointZero
            c[0] = r2[1] * r1[2] - r2[2] * r1[1]
            c[1] = r2[2] * r1[0] - r2[0] * r1[2]
            c[2] = r2[0] * r1[1] - r2[1] * r1[0]
            c = c.normalize()
            // rotation matrix
            let R00 = c[0]*c[0]
            let R01 = c[0]*c[1]-c[2]
            let R02 = c[0]*c[2]+c[1]
            let R10 = c[0]*c[1]+c[2]
            let R11 = c[1]*c[1]
            let R12 = c[1]*c[2]-c[0]
            let R20 = c[0]*c[2]-c[1]
            let R21 = c[1]*c[2]+c[0]
            let R22 = c[2]*c[2]
            // normal vector:
            var n = BKPointZero
            n[0] = R00 * r1[0] + R01 * r1[1] + R02 * r1[2]
            n[1] = R10 * r1[0] + R11 * r1[1] + R12 * r1[2]
            n[2] = R20 * r1[0] + R21 * r1[1] + R22 * r1[2]
            return n
        }*/
        return /*(BKPoint.dimensions == 3) ? normal3(t) : */ normal2(t)
    }
    
    // MARK: -
    
    /*
     Reduces a curve to a collection of "simple" subcurves, where a simpleness is defined as having all control points on the same side of the baseline (cubics having the additional constraint that the control-to-end-point lines may not cross), and an angle between the end point normals no greater than 60 degrees.
     
     The main reason this function exists is to make it possible to scale curves. As mentioned in the offset function, curves cannot be offset without cheating, and the cheating is implemented in this function. The array of simple curves that this function yields can safely be scaled.
     
     
     */
    public func reduce() -> [Subcurve<Self>] {
        
        // todo: handle degenerate case of Cubic with all zero points better!
        
        let step: BKFloat = 0.01
        var extrema: [BKFloat] = self.extrema().values
        extrema = extrema.filter {
            if $0 < step {
                return false // filter out extreme points very close to 0.0
            }
            else if (1.0 - $0) < step {
                return false // filter out extreme points very close to 1.0
            }
            else {
                return true
            }
        }
        // aritifically add 0.0 and 1.0 to our extreme points
        extrema.insert(0.0, at: 0)
        extrema.append(1.0)
        
        // first pass: split on extrema
        var pass1: [Subcurve<Self>] = []
        pass1.reserveCapacity(extrema.count-1)
        for i in 0..<extrema.count-1 {
            let t1 = extrema[i]
            let t2 = extrema[i+1]
            let curve = self.split(from: t1, to: t2)
            pass1.append(Subcurve(t1: t1, t2: t2, curve: curve))
        }
        
        func bisectionMethod(min: BKFloat, max: BKFloat, tolerance: BKFloat, callback: (_ value: BKFloat) -> Bool) -> BKFloat {
            var lb = min // lower bound (callback(x <= lb) should return true
            var ub = max // upper bound (callback(x >= ub) should return false
            while (ub - lb) > tolerance {
                let val = 0.5 * (lb + ub)
                if callback(val) {
                    lb = val
                }
                else {
                    ub = val
                }
            }
            return lb
        }
        
        // second pass: further reduce these segments to simple segments
        var pass2: [Subcurve<Self>] = []
        pass2.reserveCapacity(pass1.count)
        pass1.forEach({(p1: Subcurve<Self>) in
            var t1: BKFloat = 0.0
            while t1 < 1.0 {
                let fullSegment = p1.split(from: t1, to: 1.0)
                if (1.0 - t1) <= step || fullSegment.curve.simple {
                    // if the step is small or the full segment is simple, use it
                    pass2.append(fullSegment)
                    t1 = 1.0
                }
                else {
                    // otherwise use bisection method to find a suitable step size
                    let t2 = bisectionMethod(min: t1 + step, max: 1.0, tolerance: step) {
                        return p1.split(from: t1, to: $0).curve.simple
                    }
                    let partialSegment = p1.split(from: t1, to: t2)
                    pass2.append(partialSegment)
                    t1 = t2
                }
            }
        })
        return pass2
    }
    
    // MARK: -
    
    /*
     Scales a curve with respect to the intersection between the end point normals. Note that this will only work if that point exists, which is only guaranteed for simple segments.
     */
    public func scale(distance d: BKFloat) -> Self {
        return internalScale(distance: d, distanceFunction: nil)
    }
    
    private func scale(distanceFunction distanceFn: @escaping DistanceFunction) -> Self {
        return internalScale(distance: nil, distanceFunction: distanceFn)
    }
    
//    private enum ScaleEnum {
//        case d(BKFloat)
//        case distanceFunction(DistanceFunction)
//    }
    
    private func internalScale(distance d: BKFloat?, distanceFunction distanceFn: DistanceFunction?) -> Self {
        // TODO: this is a good candidate for enum, d is EITHER constant or a function
        precondition((d != nil && distanceFn == nil) || (d == nil && distanceFn != nil))
        
        let order = self.order
        
        if distanceFn != nil && self.order == 2 {
            // for quadratics we must raise to cubics prior to scaling
            // TODO: implement raise() function an enable this
            //            return self.raise().scale(distance: nil, distanceFunction: distanceFn);
        }
        
        // TODO: add special handling for degenerate (=linear) curves.
        let r1 = (distanceFn != nil) ? distanceFn!(0) : d!
        let r2 = (distanceFn != nil) ? distanceFn!(1) : d!
        var v = [ self.internalOffset(t: 0, distance: 10), self.internalOffset(t: 1, distance: 10) ]
        // move all points by distance 'd' wrt the origin 'o'
        var points: [BKPoint] = self.points
        var np: [BKPoint] = [BKPoint](repeating: BKPointZero, count: self.order + 1)
        
        // move end points by fixed distance along normal.
        for t in [0,1] {
            let p: BKPoint = points[t*order]
            np[t*order] = p + ((t != 0) ? r2 : r1) * v[t].n
        }
        
        if self.order < 2 {
            // for offsetting line segments, we are done
            return Self.init(points: np)
        }
        
        let o = Utils.lli4(v[0].p, v[0].c, v[1].p, v[1].c)
        
        if d != nil {
            // move control points to lie on the intersection of the offset
            // derivative vector, and the origin-through-control vector
            for t in [0,1] {
                if (self.order==2) && (t != 0) {
                    break
                }
                let p = np[t*order] // either the first or last of np
                let d = self.derivative(BKFloat(t))
                let p2 = p + d
                let o2 = (o != nil) ? o! : points[t+1] - self.normal(BKFloat(t))
                np[t+1] = Utils.lli4(p, p2, o2, points[t+1])!
            }
            return Self.init(points: np)
        }
        else {
            let clockwise: Bool = {
                let points = self.points
                let angle = Utils.angle(o: points[0], v1: points[self.order], v2: points[1])
                return angle > 0
            }()
            for t in [0,1] {
                if (self.order==2) && (t != 0) {
                    break
                }
                let p = self.points[t+1]
                let ov = ((o != nil) ? (p - o!) : (p - self.normal(BKFloat(t)))).normalize()
                var rc: BKFloat = distanceFn!(BKFloat(t+1) / BKFloat(self.order))
                if !clockwise {
                    rc = -rc
                }
                np[t+1] = p + rc * ov
            }
            return Self.init(points: np)
        }
    }
    
    // MARK: -
    
    public func offset(distance d: BKFloat) -> [BezierCurve] {
        if self.linear {
            let n = self.normal(0)
            let coords: [BKPoint] = self.points.map({(p: BKPoint) -> BKPoint in
                return p + d * n
            })
            return [Self.init(points: coords)]
        }
        // for non-linear curves we need to create a set of curves
        let reduced: [Subcurve<Self>] = self.reduce()
        return reduced.map({
            return $0.curve.scale(distance: d)
        })
    }
    
    public func offset(t: BKFloat, distance d: BKFloat) -> BKPoint {
        return self.internalOffset(t: t, distance: d).p
    }
    
    private func internalOffset(t: BKFloat, distance d: BKFloat) -> (c: BKPoint, n: BKPoint, p: BKPoint) {
        let c = self.compute(t)
        let n = self.normal(t)
        return (c: c, n: n, p: c + d * n)
    }
    
    // MARK: - intersection
    
    public func project(point: BKPoint) -> BKPoint {
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
        mdist = mdist + 1
        var ft = t1
        for t in stride(from: t1, to: t2+step, by: step) {
            let p = self.compute(t)
            let d = Utils.dist(point, p)
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
    
    public func intersects(line: LineSegment) -> [Intersection] {
        let lineDirection = (line.p1 - line.p0).normalize()
        let lineLength = (line.p1 - line.p0).length
        return Utils.roots(points: self.points, line: line).map({(t: BKFloat) -> Intersection in
            let p = self.compute(t) - line.p0
            let t2 = p.dot(lineDirection) / lineLength
            return Intersection(t1: t, t2: t2)
        }).filter({$0.t2 >= 0.0 && $0.t2 <= 1.0}).sorted()
    }
    
    public func intersects(curveIntersectionThreshold: BKFloat = Self.defaultCurveIntersectionThreshold) -> [Intersection] {
        let reduced = self.reduce()
        // "simple" curves cannot intersect with their direct
        // neighbour, so for each segment X we check whether
        // it intersects [0:x-2][x+2:last].
        let len=reduced.count-2
        var results: [Intersection] = []
        if len > 0 {
            for i in 0..<len {
                let left = [reduced[i]]
                let right = Array(reduced.suffix(from: i+2))
                let result = Self.internalCurvesIntersect(c1: left, c2: right, curveIntersectionThreshold: curveIntersectionThreshold)
                results += result
            }
        }
        return results
    }
    
    public func intersects(curve: BezierCurve, curveIntersectionThreshold: BKFloat = Self.defaultCurveIntersectionThreshold) -> [Intersection] {
//        precondition(curve !== self, "unsupported: use intersects() method for self-intersection")
        
        let s = Subcurve<Self>(curve: self)
        
        if let c = curve as? CubicBezierCurve {
            return Self.internalCurvesIntersect(c1: [s], c2: [Subcurve(curve: c)], curveIntersectionThreshold: curveIntersectionThreshold)
        }
        else if let q = curve as? QuadraticBezierCurve {
            return Self.internalCurvesIntersect(c1: [s], c2: [Subcurve(curve: q)], curveIntersectionThreshold: curveIntersectionThreshold)
        }
        else if let l = curve as? LineSegment {
            return self.intersects(line: l)
        }
        else {
            fatalError("unsupported")
        }
        
    }
    
    private static func internalCurvesIntersect<C1, C2>(c1: [Subcurve<C1>], c2: [Subcurve<C2>], curveIntersectionThreshold: BKFloat) -> [Intersection] {

        var intersections: [Intersection] = []
        for l in c1 {
            for r in c2 {
                Utils.pairiteration(l, r, &intersections, curveIntersectionThreshold)
            }
        }
        // TODO: you should probably have a unit test that ensures de-duping actually works
        
        // sort the results by t1 (and by t2 if t1 equal)
        intersections = intersections.sorted(by: <)
        // de-dupe the sorted array
        intersections = intersections.reduce(Array<Intersection>(), {(intersection: [Intersection], next: Intersection) in
            return (intersection.count == 0 || intersection[intersection.count-1] != next) ? intersection + [next] : intersection
        })

        return intersections
    }
    
    // MARK: - outlines
    
    public func outline(distance d1: BKFloat) -> PolyBezier {
        return internalOutline(d1: d1, d2: d1, d3: 0.0, d4: 0.0, graduated: false)
    }
    
    public func outline(distance d1: BKFloat, d2: BKFloat) -> PolyBezier {
        return internalOutline(d1: d1, d2: d2, d3: 0.0, d4: 0.0, graduated: false)
    }
    
    public func outline(d1: BKFloat, d2: BKFloat, d3: BKFloat, d4: BKFloat) -> PolyBezier {
        return internalOutline(d1: d1, d2: d2, d3: d3, d4: d4, graduated: true)
    }
    
    private func internalOutline(d1: BKFloat, d2: BKFloat, d3: BKFloat, d4: BKFloat, graduated: Bool) -> PolyBezier {
        
        let reduced = self.reduce()
        let len = reduced.count
        var fcurves: [BezierCurve] = []
        var bcurves: [BezierCurve] = []
        //        var p
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
        var alen: BKFloat = 0.0
        
        for segment in reduced {
            let slen = segment.curve.length()
            if graduated {
                fcurves.append(segment.curve.scale(distanceFunction: linearDistanceFunction( d1,  d3, tlen, alen, slen)  ))
                bcurves.append(segment.curve.scale(distanceFunction: linearDistanceFunction(-d2, -d4, tlen, alen, slen)  ))
            }
            else {
                fcurves.append(segment.curve.scale(distance: d1))
                bcurves.append(segment.curve.scale(distance: -d2))
            }
            alen = alen + slen
        }
        
        // reverse the "return" outline
        bcurves = bcurves.map({(s: BezierCurve) in
            let p = s.points
            return type(of: s).init(points: p.reversed())
        }).reversed()
        
        // form the endcaps as lines
        let fs = fcurves[0].points[0]
        let fe = fcurves[len-1].points[fcurves[len-1].points.count-1]
        let bs = bcurves[len-1].points[bcurves[len-1].points.count-1]
        let be = bcurves[0].points[0]
        let ls = LineSegment(p0: bs, p1: fs)
        let le = LineSegment(p0: fe, p1: be)
        let segments = [ls] + fcurves + [le] + bcurves
        //        let slen = segments.count
        
        return PolyBezier(curves: segments)
        
    }
    
    // MARK: shapes
    
    public func outlineShapes(distance d1: BKFloat, curveIntersectionThreshold: BKFloat = Self.defaultCurveIntersectionThreshold) -> [Shape] {
        return self.outlineShapes(distance: d1, d2: d1, curveIntersectionThreshold: curveIntersectionThreshold)
    }
    
    public func outlineShapes(distance d1: BKFloat, d2: BKFloat, curveIntersectionThreshold: BKFloat = Self.defaultCurveIntersectionThreshold) -> [Shape] {
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
    
    public static var defaultCurveIntersectionThreshold: BKFloat {
        return 0.5
    }
}

public protocol BezierCurve {
    var simple: Bool { get }
    var points: [BKPoint] { get }
    var startingPoint: BKPoint { get }
    var endingPoint: BKPoint { get }
    var order: Int { get }
    init(points: [BKPoint])
    func derivative(_ t: BKFloat) -> BKPoint
    func split(from t1: BKFloat, to t2: BKFloat) -> Self
    func split(at t: BKFloat) -> (left: Self, right: Self)
    var boundingBox: BoundingBox { get }
    func compute(_ t: BKFloat) -> BKPoint
    func length() -> BKFloat
    func extrema() -> (xyz: [[BKFloat]], values: [BKFloat] )
    func generateLookupTable(withSteps steps: Int) -> [BKPoint]
    func intersects(curve: BezierCurve, curveIntersectionThreshold: BKFloat) -> [Intersection]
}
