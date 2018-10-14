//
//  FatLine.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/14/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

private let UNIT_INTERVAL = Interval(start: 0.0, end: 1.0)
private let MAX_PRECISION: CGFloat = 1.0e-8
private let MIN_CLIPPED_SIZE_THRESHOLD: CGFloat = 0.8
private let H1_INTERVAL = Interval(start: 0.0, end: 0.5)
private let H2_INTERVAL = Interval(start: nextafter(0.5, 1.0), end: 1.0)
private let EPSILON: CGFloat = 1.0e-6

private extension Interval {
    var middle: CGFloat {
        return 0.5 * (self.start + self.end)
    }
    var extent: CGFloat {
        return self.end - self.start
    }
}

public func findIntersectionsBezierClipping(_ A: BezierCurve, _ B: BezierCurve, precision: CGFloat = 1.0e-6) -> [Intersection] {
    let clampedPrecision = precision < MAX_PRECISION ? precision: MAX_PRECISION
    return getSolutions(A, B, precision: clampedPrecision)
}

private func getSolutions(_ A: BezierCurve, _ B: BezierCurve, precision: CGFloat) -> [Intersection] {
    var domsA = [Interval]()
    var domsB = [Interval]()
    var counter = 0
    iterate(&domsA, &domsB, A, B, UNIT_INTERVAL, UNIT_INTERVAL, precision: precision, counter: &counter)
    assert(domsA.count == domsB.count)
    return zip(domsA, domsB).map {
        return Intersection(t1: $0.0.middle, t2: $0.1.middle)
    }
}

private extension BezierCurve {
    func isConstant(_ epsilon: CGFloat) -> Bool {
        for i in 1...self.order {
            if areNear(self.points[i], self.startingPoint, epsilon) {
                return false
            }
        }
        return true
    }
}

private func areNear(_ a: CGPoint, _ b: CGPoint, _ epsilon: CGFloat = EPSILON) -> Bool {
    return distance(a, b) <= epsilon
}

private func areNear(_ a: CGFloat, _ b: CGFloat, _ epsilon: CGFloat = EPSILON) -> Bool {
    return a-b <= epsilon && a-b >= -epsilon
}

private func middle_point(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
    return 0.5 * (p1 + p2)
}

private extension Interval {
    
    mutating func setEnds(_ a: CGFloat, _ b: CGFloat) {
        if a <= b {
            self.start = a
            self.end = b
        }
        else {
            self.start = b
            self.end = a
        }
    }
    
    mutating func expandTo(_ val: CGFloat) {
        if val < self.start {
            self.start = val
        }
        if val > self.end {
            self.end = val  //no else, as we want to handle NaN
        }
    }

    func valueAt(_ t: CGFloat) -> CGFloat {
        return t * self.end + (1.0 - t) * self.start
    }
}

/*
 * Map the sub-interval I in [0,1] into the interval J and assign it to J
 */
private func map_to(_ J: inout Interval, _ I: Interval) {
    J.setEnds(J.valueAt(I.start), J.valueAt(I.end));
}

private func portion(_ a: inout BezierCurve, _ interval: Interval) {
    a = a.split(from: interval.start, to: interval.end)
}

private func iterate(_ domsA: inout [Interval], _ domsB: inout [Interval], _ A: BezierCurve, _ B: BezierCurve, _ domA: Interval, _ domB: Interval, precision: CGFloat, counter: inout Int) {
    
    counter += 1
    if counter > 100 {
        return
    }
    
    let pA = A
    let pB = B
    var C1 = A
    var C2 = B
    
    let dompA = domA
    let dompB = domB
    var dom1 = dompA
    var dom2 = dompB 
    
    if (A.isConstant(precision) && B.isConstant(precision)) {
        let M1 = middle_point(C1.startingPoint, C1.endingPoint)
        let M2 = middle_point(C1.startingPoint, C1.endingPoint)
        if areNear(M1, M2) {
            domsA.append(domA)
            domsB.append(domB)
        }
        return
    }
    
    var iter = 1;
    while iter < 100 && (dompA.extent >= precision || dompB.extent >= precision) {
        iter += 1

        guard let dom = clip(C1, C2, precision: precision) else {
            return
        }

        // all other cases where dom[0] > dom[1] are invalid
        assert(dom.start <= dom.end)
        
        map_to(&dom2, dom)
        
        portion(&C2, dom)
        
        if C2.isConstant(precision) && C1.isConstant(precision) {
            let M1 = middle_point(C1.startingPoint, C1.endingPoint)
            let M2 = middle_point(C2.startingPoint, C2.endingPoint)
            if areNear(M1,M2) {
                break  // append the new interval
            }
            else {
                return // exit without appending any new interval
            }
        }
        
        // if we have clipped less than 20% than we need to subdive the curve
        // with the largest domain into two sub-curves
        if dom.extent > MIN_CLIPPED_SIZE_THRESHOLD {
            if dompA.extent > dompB.extent {
                var pC1 = pA
                var pC2 = pA
                portion(&pC1, H1_INTERVAL)
                portion(&pC2, H2_INTERVAL)
                var dompC1 = dompA
                var dompC2 = dompA
                map_to(&dompC1, H1_INTERVAL)
                map_to(&dompC2, H2_INTERVAL)
                iterate(&domsA, &domsB, pC1, pB, dompC1, dompB, precision: precision, counter: &counter)
                iterate(&domsA, &domsB, pC2, pB, dompC2, dompB, precision: precision, counter: &counter)
            }
            else {
                var pC1 = pB
                var pC2 = pB
                portion(&pC1, H1_INTERVAL)
                portion(&pC2, H2_INTERVAL)
                var dompC1 = dompB
                var dompC2 = dompB
                map_to(&dompC1, H1_INTERVAL)
                map_to(&dompC2, H2_INTERVAL)
                iterate(&domsB, &domsA, pC1, pA, dompC1, dompA, precision: precision, counter: &counter)
                iterate(&domsB, &domsA, pC2, pA, dompC2, dompA, precision: precision, counter: &counter)
            }
            return
        }
        
        swap(&C1, &C2);
        swap(&dom1, &dom2);
    }
    domsA.append(dompA)
    domsB.append(dompB)
}

private extension LineSegment {
    var coefficients: (CGFloat, CGFloat, CGFloat) {
        let v = (self.endingPoint - self.startingPoint).cw()
        let a = v.x
        let b = v.y
        let c = cross(self.startingPoint, self.endingPoint)
        return (a, b, c)
    }
    func normalized() -> LineSegment {
        // this helps with the nasty case of a line that starts somewhere far
        // and ends very close to the origin
        var line = (self.endingPoint.lengthSquared < self.startingPoint.lengthSquared) ? self.reversed() : self
        let v = (line.endingPoint - line.startingPoint).normalize()
        line.endingPoint = line.startingPoint + v;
        return line
    }
}

private extension CGPoint {
    func cw() -> CGPoint { // Return a point like this point but rotated +90 degrees.
        return CGPoint(x: -self.y, y: self.x)
    }
}

private func clip(_ A: BezierCurve, _ B: BezierCurve, precision: CGFloat) -> Interval? {
    var bl: LineSegment = {
        if A.isConstant(precision) {
            let M = middle_point(A.startingPoint, A.endingPoint)
            return orthogonal_orientation_line(B, M, precision: precision)
        }
        else {
            return pick_orientation_line(A, precision: precision)
        }
    }()
    bl = bl.normalized()
    let bound: Interval = fat_line_bounds(A, bl)
    return clip_interval(B, bl, bound)
}

/*
 * Compute the min and max distance of the control points of the Bezier
 * curve "c" from the normalized orientation line "l".
 * This bounds are returned through the output Interval parameter"bound".
 */
private func fat_line_bounds(_ c: BezierCurve, _ l: LineSegment) -> Interval {
    var bound = Interval(start: 0, end: 0)
    for i in 0...c.order {
        bound.expandTo(signed_distance(c.points[i], l))
    }
    return bound
}

/*
 * Pick up an orientation line for the Bezier curve "c" and return it in
 * the output parameter "l"
 */
private func pick_orientation_line(_ c: BezierCurve, precision: CGFloat ) -> LineSegment {
    var i = c.order + 1
    repeat {
        i -= 1
    } while i > 0 && areNear(c.startingPoint, c.points[i], precision)
    
    // this should never happen because when a new curve portion is created
    // we check that it is not constant;
    // however this requires that the precision used in the is_constant
    // routine has to be the same used here in the are_near test
    assert(i != 0);
    
    let line = LineSegment(p0: c.startingPoint, p1: c.points[i])
    return line
    //std::cerr << "i = " << i << std::endl;
}

/*
 *  Make up an orientation line for constant bezier curve;
 *  the orientation line is made up orthogonal to the other curve base line;
 *  the line is returned in the output parameter "l" in the form of a 3 element
 *  vector : l[0] * x + l[1] * y + l[2] == 0; the line is normalized.
 */
private func orthogonal_orientation_line(_ c: BezierCurve, _ p: CGPoint, precision: CGFloat) -> LineSegment {
    // this should never happen
    assert(!c.isConstant(precision))
    
    let line = LineSegment(p0: p, p1: (c.endingPoint - c.startingPoint).cw() + p)
    return line
}

/*
 *  Compute the signed distance of the point "P" from the normalized line l
 */
private func signed_distance(_ p: CGPoint, _ l: LineSegment) -> CGFloat {
    let (a, b, c) = l.coefficients
    return a * p.x + b * p.y + c
}

/*
 * return the x component of the intersection point between the line
 * passing through points p1, p2 and the line Y = "y"
 */
private func intersect(_ p1: CGPoint,_ p2: CGPoint, _ y: CGFloat) -> CGFloat {
    // we are sure that p2[Y] != p1[Y] because this routine is called
    // only when the lower or the upper bound is crossed
    let dy = (p2.y - p1.y)
    let s = (y - p1.y) / dy
    return (p2.x-p1.x)*s + p1.x
}

/*
 * Clip the Bezier curve "B" wrt the fat line defined by the orientation
 * line "l" and the interval range "bound", the new parameter interval for
 * the clipped curve is returned through the output parameter "dom"
 */
private func clip_interval(_ B: BezierCurve, _ l: LineSegment, _ bound: Interval) -> Interval? {
    let n = CGFloat(B.order) // number of sub-intervals
    let D: [CGPoint] = (0...B.order).map {  // distance curve control points
        let d: CGFloat = signed_distance(B.points[$0], l)
        return CGPoint(x: CGFloat($0) / n, y: d)
    }
    //print(D);
    
    var p = ConvexHull(points: D).boundary
    //print(p);
    
    var tmin: CGFloat = 1
    var tmax: CGFloat = 0
    //    std::cerr << "bound : " << bound << std::endl;
    
    var plower = (p[0].y < bound.start)
    var phigher = (p[0].y > bound.end)
    if !plower && !phigher {  // inside the fat line
        if tmin > p[0].x {
            tmin = p[0].x
        }
        if tmax < p[0].x {
            tmax = p[0].x
        }
        //        std::cerr << "0 : inside " << p[0]
        //                  << " : tmin = " << tmin << ", tmax = " << tmax << std::endl;
    }
    
    for i in 1..<p.count {
        let clower = (p[i].y < bound.start)
        let chigher = (p[i].y > bound.end)
        if !clower && !chigher { // inside the fat line
            if tmin > p[i].x {
               tmin = p[i].x
            }
            if tmax < p[i].x {
                tmax = p[i].x
            }
            //            std::cerr << i << " : inside " << p[i]
            //                      << " : tmin = " << tmin << ", tmax = " << tmax
            //                      << std::endl;
        }
        if clower != plower { // cross the lower bound
            let t = intersect(p[i-1], p[i], bound.start)
            if tmin > t {
                tmin = t
            }
            if tmax < t {
                tmax = t
            }
            plower = clower;
            //            std::cerr << i << " : lower " << p[i]
            //                      << " : tmin = " << tmin << ", tmax = " << tmax
            //                      << std::endl;
        }
        if chigher != phigher {  // cross the upper bound
            let t = intersect(p[i-1], p[i], bound.end)
            if tmin > t {
                tmin = t
            }
            if tmax < t {
                tmax = t
            }
            phigher = chigher
            //            std::cerr << i << " : higher " << p[i]
            //                      << " : tmin = " << tmin << ", tmax = " << tmax
            //                      << std::endl;
        }
    }
    
    // we have to test the closing segment for intersection
    let last = p.count - 1
    let clower = (p[0].y < bound.start)
    let chigher = (p[0].y > bound.end)
    if clower != plower { // cross the lower bound
        let t = intersect(p[last], p[0], bound.start)
        if tmin > t {
             tmin = t
        }
        if tmax < t {
             tmax = t
        }
        //        std::cerr << "0 : lower " << p[0]
        //                  << " : tmin = " << tmin << ", tmax = " << tmax << std::endl;
    }
    if chigher != phigher { // cross the upper bound
        let t = intersect(p[last], p[0], bound.end)
        if tmin > t {
            tmin = t
        }
        if tmax < t {
           tmax = t
        }
        //        std::cerr << "0 : higher " << p[0]
        //                  << " : tmin = " << tmin << ", tmax = " << tmax << std::endl;
    }
    
    if tmin == 1 && tmax == 0 {
        return nil
    }
    else {
        return Interval(start: tmin, end: tmax)
    }
}
