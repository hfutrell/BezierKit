//
//  BezierCurve.swift
//  BezierKit
//
//  Created by Holmes Futrell on 2/19/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import CoreGraphics

public typealias DistanceFunction = (_ v: CGFloat) -> CGFloat

private enum ScaleEnum {
    case constant(CGFloat)
    case function(DistanceFunction)
}

public struct Subcurve<CurveType> where CurveType: BezierCurve {
    public let t1: CGFloat
    public let t2: CGFloat
    public let curve: CurveType

    internal var canSplit: Bool {
        let mid = 0.5 * (self.t1 + self.t2)
        return mid > self.t1 && mid < self.t2
    }

    internal init(curve: CurveType) {
        self.t1 = 0.0
        self.t2 = 1.0
        self.curve = curve
    }
    
    internal init(t1: CGFloat, t2: CGFloat, curve: CurveType) {
        self.t1 = t1
        self.t2 = t2
        self.curve = curve
    }
    
    internal func split(from t1: CGFloat, to t2: CGFloat) -> Subcurve<CurveType> {
        let curve: CurveType = self.curve.split(from: t1, to: t2)
        return Subcurve<CurveType>(t1: Utils.map(t1, 0,1, self.t1, self.t2),
                                   t2: Utils.map(t2, 0,1, self.t1, self.t2),
                                   curve: curve)
    }

    internal func split(at t: CGFloat) -> (left: Subcurve<CurveType>, right: Subcurve<CurveType>) {
        let (left, right) = curve.split(at: t)
        let t1 = self.t1
        let t2 = self.t2
        let tSplit = Utils.map(t, 0,1, t1, t2)
        let subcurveLeft = Subcurve<CurveType>(t1: t1, t2: tSplit, curve: left)
        let subcurveRight = Subcurve<CurveType>(t1: tSplit, t2: t2, curve: right)
        return (left: subcurveLeft, right: subcurveRight)
    }
}

extension Subcurve: Equatable where CurveType: Equatable {
    // extension exists for automatic Equatable synthesis
}

// MARK: -

extension BezierCurve {
    
    // MARK: -
    
    private var dpoints: [[CGPoint]] {
        var ret: [[CGPoint]] = []
        var p: [CGPoint] = self.points
        ret.reserveCapacity(p.count-1)
        for d in (2 ... p.count).reversed() {
            let c = d-1
            var list: [CGPoint] = []
            list.reserveCapacity(c)
            for j:Int in 0..<c {
                let dpt: CGPoint = CGFloat(c) * (p[j+1] - p[j])
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
    public func length() -> CGFloat {
        return Utils.length({(_ t: CGFloat) in self.derivative(t)})
    }
    
    // MARK:
    
    // computes the extrema for each dimension
    internal func internalExtrema(includeInflection: Bool) -> [[CGFloat]] {
        var xyz: [[CGFloat]] = []
        xyz.reserveCapacity(CGPoint.dimensions)
        for d in 0..<CGPoint.dimensions {
            let mfn = {(v: CGPoint) in v[d]}
            var p: [CGFloat] = self.dpoints[0].map(mfn)
            xyz.append(Utils.droots(p))
            if includeInflection && self.order >= 3 {
                p = self.dpoints[1].map(mfn)
                xyz[d] += Utils.droots(p)
            }
            xyz[d] = xyz[d].filter({$0 >= 0 && $0 <= 1}).sorted()
        }
        return xyz
    }
    
    public func extrema() -> (xyz: [[CGFloat]], values: [CGFloat] ) {
        let xyz = self.internalExtrema(includeInflection: true)
        var roots = xyz.flatMap{$0}.sorted() // the roots for each dimension, flattened and sorted
        var values: [CGFloat] = []
        if !roots.isEmpty {
            values.reserveCapacity(roots.count)
            var lastInserted: CGFloat = -CGFloat.infinity
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
    public func hull(_ t: CGFloat) -> [CGPoint] {
        return Utils.hull(self.points, t)
    }
        
    public func generateLookupTable(withSteps steps: Int = 100) -> [CGPoint] {
        assert(steps >= 0)
        var table: [CGPoint] = []
        table.reserveCapacity(steps+1)
        for i in 0 ... steps {
            let t = CGFloat(i) / CGFloat(steps)
            table.append(self.compute(t))
        }
        return table
    }
    // MARK: -
    
    /*
     Reduces a curve to a collection of "simple" subcurves, where a simpleness is defined as having all control points on the same side of the baseline (cubics having the additional constraint that the control-to-end-point lines may not cross), and an angle between the end point normals no greater than 60 degrees.
     
     The main reason this function exists is to make it possible to scale curves. As mentioned in the offset function, curves cannot be offset without cheating, and the cheating is implemented in this function. The array of simple curves that this function yields can safely be scaled.
     
     
     */

    public func reduce() -> [Subcurve<Self>] {
        
        let step: CGFloat = BezierKit.reduceStepSize
        var extrema: [CGFloat] = []
        self.extrema().values.forEach {
            if $0 < step {
                return // filter out extreme points very close to 0.0
            } else if (1.0 - $0) < step {
                return // filter out extreme points very close to 1.0
            } else if let last = extrema.last, $0 - last < step {
                return
            }
            return extrema.append($0)
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
        
        func bisectionMethod(min: CGFloat, max: CGFloat, tolerance: CGFloat, callback: (_ value: CGFloat) -> Bool) -> CGFloat {
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
            let adjustedStep = step / (p1.t2 - p1.t1)
            var t1: CGFloat = 0.0
            while t1 < 1.0 {
                let fullSegment = p1.split(from: t1, to: 1.0)
                if (1.0 - t1) <= adjustedStep || fullSegment.curve.simple {
                    // if the step is small or the full segment is simple, use it
                    pass2.append(fullSegment)
                    t1 = 1.0
                }
                else {
                    // otherwise use bisection method to find a suitable step size
                    let t2 = bisectionMethod(min: t1 + adjustedStep, max: 1.0, tolerance: adjustedStep) {
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
    public func scale(distance d: CGFloat) -> Self {
        return internalScale(scaler: .constant(d))
    }
    
    private func scale(distanceFunction distanceFn: @escaping DistanceFunction) -> Self {
        return internalScale(scaler: .function(distanceFn))
    }
    
    private func internalScale(scaler: ScaleEnum) -> Self {
        
        let order = self.order
        guard self.order > 0 else { return self } // undefined behavior for points
        
        let r1: CGFloat
        let r2: CGFloat
        switch scaler {
        case let .constant(distance):
            r1 = distance
            r2 = distance
        case let .function(distanceFunction):
            r1 = distanceFunction(0)
            r2 = distanceFunction(1)
        }
        
        var v = [ self.internalOffset(t: 0, distance: 10), self.internalOffset(t: 1, distance: 10) ]
        // move all points by distance 'd' wrt the origin 'o'
        var points: [CGPoint] = self.points
        var np: [CGPoint] = [CGPoint](repeating: .zero, count: self.order + 1)
        
        // move end points by fixed distance along normal.
        np[0]       = points[0]     + r1 * v[0].n
        np[order]   = points[order] + r2 * v[1].n
        
        guard self.order > 1 else { return Self.init(points: np) } // for line segments nothing left to do
        
        let o = Utils.lli4(v[0].p, v[0].c, v[1].p, v[1].c)
        
        switch scaler {
        case .constant(_):
            // move control points to lie on the intersection of the offset
            // derivative vector, and the origin-through-control vector
            for t in [0,1] {
                if (self.order==2) && (t != 0) {
                    break
                }
                let p = np[t*order] // either the first or last of np
                let d = -self.normal(CGFloat(t)).perpendicular
                let p2 = p + d
                let o2 = o ?? (points[t+1] - self.normal(CGFloat(t)))
                let fallback = points[t+1] + (np[t*order] - points[t*order])
                np[t+1] = Utils.lli4(p, p2, o2, points[t+1]) ?? fallback
            }
        case let .function(distanceFunction):
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
                let ov = (o != nil) ? (p - o!).normalize() : -self.normal(CGFloat(t))
                var rc: CGFloat = distanceFunction(CGFloat(t+1) / CGFloat(self.order))
                if !clockwise {
                    rc = -rc
                }
                np[t+1] = p + rc * ov
            }
        }
        return Self.init(points: np)
    }
    
    // MARK: -
    
    public func offset(distance d: CGFloat) -> [BezierCurve] {
        if self.linear {
            let n = self.normal(0)
            let coords: [CGPoint] = self.points.map({(p: CGPoint) -> CGPoint in
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
    
    public func offset(t: CGFloat, distance d: CGFloat) -> CGPoint {
        return self.internalOffset(t: t, distance: d).p
    }
    
    private func internalOffset(t: CGFloat, distance d: CGFloat) -> (c: CGPoint, n: CGPoint, p: CGPoint) {
        let c = self.compute(t)
        let n = self.normal(t)
        return (c: c, n: n, p: c + d * n)
    }
    
    // MARK: - intersection

    public func project(_ point: CGPoint) -> (point: CGPoint, t: CGFloat) {
        return self.project(point, accuracy: BezierKit.defaultIntersectionAccuracy)
    }

    // MARK: - outlines
    
    public func outline(distance d1: CGFloat) -> PathComponent {
        return internalOutline(d1: d1, d2: d1, d3: 0.0, d4: 0.0, graduated: false)
    }
    
    public func outline(distanceAlongNormal d1: CGFloat, distanceOppositeNormal d2: CGFloat) -> PathComponent {
        return internalOutline(d1: d1, d2: d2, d3: 0.0, d4: 0.0, graduated: false)
    }
    
    public func outline(distanceAlongNormalStart d1: CGFloat,
                        distanceOppositeNormalStart d2: CGFloat,
                        distanceAlongNormalEnd d3: CGFloat,
                        distanceOppositeNormalEnd d4: CGFloat) -> PathComponent {
        return internalOutline(d1: d1, d2: d2, d3: d3, d4: d4, graduated: true)
    }
    
    private func internalOutline(d1: CGFloat, d2: CGFloat, d3: CGFloat, d4: CGFloat, graduated: Bool) -> PathComponent {
        
        let reduced = self.reduce()
        let len = reduced.count
        var fcurves: [BezierCurve] = []
        var bcurves: [BezierCurve] = []
        //        var p
        let tlen = self.length()
        
        let linearDistanceFunction = {(_ s: CGFloat,_ e: CGFloat,_ tlen: CGFloat,_ alen: CGFloat,_ slen: CGFloat) -> DistanceFunction in
            return { (_ v: CGFloat) -> CGFloat in
                let f1: CGFloat = alen / tlen
                let f2: CGFloat = (alen+slen) / tlen
                let d: CGFloat = e-s
                return Utils.map(v, 0,1, s+f1*d, s+f2*d)
            }
        }
        
        // form curve oulines
        var alen: CGFloat = 0.0
        
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

        func cleanupCurves(_ curves: inout [BezierCurve]) {
            // ensures the curves are contiguous
            for i in 0..<curves.count {
                if i > 0 {
                    curves[i].startingPoint = curves[i-1].endingPoint
                }
                if i < curves.count-1 {
                    curves[i].endingPoint = 0.5 * ( curves[i].endingPoint + curves[i+1].startingPoint )
                }
            }
        }

        cleanupCurves(&fcurves)
        cleanupCurves(&bcurves)

        // reverse the "return" outline
        bcurves = bcurves.map({(s: BezierCurve) in
            return s.reversed()
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
        
        return PathComponent(curves: segments)
        
    }
    
    // MARK: shapes
    
    public func outlineShapes(distance d1: CGFloat, accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> [Shape] {
        return self.outlineShapes(distanceAlongNormal: d1, distanceOppositeNormal: d1, accuracy: accuracy)
    }
    
    public func outlineShapes(distanceAlongNormal d1: CGFloat, distanceOppositeNormal d2: CGFloat, accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> [Shape] {
        let outline = self.outline(distanceAlongNormal: d1, distanceOppositeNormal: d2)
        var shapes: [Shape] = []
        let len = outline.elementCount
        for i in 1..<len/2 {
            let shape = Shape(outline.element(at: i), outline.element(at: len-i), i > 1, i < len/2-1)
            shapes.append(shape)
        }
        return shapes
    }
}

public let defaultIntersectionAccuracy = CGFloat(0.5)
internal let reduceStepSize: CGFloat = 0.01

// MARK: factory

internal func createCurve(from points: [CGPoint]) -> BezierCurve? {
    switch points.count {
    case 2:
        return LineSegment(points: points)
    case 3:
        return QuadraticBezierCurve(points: points)
    case 4:
        return CubicBezierCurve(points: points)
    default:
        return nil
    }
}

public func == (left: BezierCurve, right: BezierCurve) -> Bool {
    return left.points == right.points
}

public protocol BoundingBoxProtocol {
    var boundingBox: BoundingBox { get }
}

public protocol Transformable {
    func copy(using: CGAffineTransform) -> Self
}

public protocol Reversible {
    func reversed() -> Self
}

public protocol BezierCurve: BoundingBoxProtocol, Transformable, Reversible {
    var simple: Bool { get }
    var points: [CGPoint] { get }
    var startingPoint: CGPoint { get set }
    var endingPoint: CGPoint { get set }
    var order: Int { get }
    init(points: [CGPoint])
    func derivative(_ t: CGFloat) -> CGPoint
    func normal(_ t: CGFloat) -> CGPoint
    func split(from t1: CGFloat, to t2: CGFloat) -> Self
    func split(at t: CGFloat) -> (left: Self, right: Self)
    func compute(_ t: CGFloat) -> CGPoint
    func length() -> CGFloat
    func extrema() -> (xyz: [[CGFloat]], values: [CGFloat] )
    func generateLookupTable(withSteps steps: Int) -> [CGPoint]
    func project(_ point: CGPoint, accuracy: CGFloat) -> (point: CGPoint, t: CGFloat)
    // intersection routines
    func selfIntersects(accuracy: CGFloat) -> Bool
    func selfIntersections(accuracy: CGFloat) -> [Intersection]
    func intersects(_ line: LineSegment) -> Bool
    func intersects(_ curve: BezierCurve, accuracy: CGFloat) -> Bool
    func intersections(with line: LineSegment) -> [Intersection]
    func intersections(with curve: BezierCurve, accuracy: CGFloat) -> [Intersection]
}

internal protocol NonlinearBezierCurve: BezierCurve {
    // intentionally empty, just declare conformance if you're not a line
}

public protocol Flatness: BezierCurve {
    // the flatness of a curve is defined as the square of the maximum distance it is from a line connecting its endpoints https://jeremykun.com/2013/05/11/bezier-curves-and-picasso/
    var flatnessSquared: CGFloat { get }
    var flatness: CGFloat { get }
}

public extension Flatness {
    var flatness: CGFloat {
        return sqrt(flatnessSquared)
    }
}

extension Flatness {
    public func project(_ point: CGPoint, accuracy: CGFloat) -> (point: CGPoint, t: CGFloat) {

        let maxIterations = 1000

        var list: [Subcurve<Self>] = [Subcurve(curve: self)]

        let distanceStartingPoint = distance(self.startingPoint, point)
        var bestMax = distanceStartingPoint
        var bestPoint = self.startingPoint
        var bestT: CGFloat = 0.0

        let distanceEndingPoint = distance(self.endingPoint, point)
        if distanceEndingPoint < bestMax {
            bestMax = distanceEndingPoint
            bestPoint = self.endingPoint
            bestT = 1.0
        }

        func needCheckSubcurve(_ subcurve: Subcurve<Self>) -> Bool {
            let line = LineSegment(p0: subcurve.curve.startingPoint, p1: subcurve.curve.endingPoint)
            let f = subcurve.curve.flatness
            guard 0.5 * line.length() + f > accuracy else {
                return false
            }
            var lowerBoundOfDistance = distance(point, line.project(point).point) - f
            if lowerBoundOfDistance < 0 { lowerBoundOfDistance = 0 }
            return lowerBoundOfDistance < bestMax
        }

        var iterations = 0
        while !list.isEmpty, iterations < maxIterations {
            var nextList: [Subcurve<Self>] = []
            nextList.reserveCapacity(10)
            // for each item in our list, check the midpoint
            // to try and find a new best
            list.forEach {
                let sampleT: CGFloat = 0.5
                let curvePoint = $0.curve.compute(sampleT)
                let mmax = distance(point, curvePoint)
                if mmax < bestMax {
                    bestMax = mmax
                    bestPoint = curvePoint
                    bestT = (1.0 - sampleT) * $0.t1 + sampleT * $0.t2
                }
            }
            iterations += list.count
            // for each item in our list, if the curve
            // is large enough to be split, do so.
            // add the subcurves to the next list if they are large
            // enough to exceed our error threshold and they are close enough
            // to possibly have a solution
            list.forEach {
                if $0.canSplit, needCheckSubcurve($0) {
                    let (left, right) = $0.split(at: 0.5)
                    if needCheckSubcurve(left) {
                        nextList.append(left)
                    }
                    if needCheckSubcurve(right) {
                        nextList.append(right)
                    }
                }
            }
            list = nextList
        }
        return (point: bestPoint, t: bestT)
    }
}
