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

private let verbose = false

private extension Interval {
    var middle: CGFloat {
        return 0.5 * (self.start + self.end)
    }
    var extent: CGFloat {
        return self.end - self.start
    }
}

public func findIntersectionsBezierClipping(_ A: BezierCurve, _ B: BezierCurve, precision: CGFloat = 1.0e-6) -> [Intersection] {
    if verbose {
        print("findIntersectionsBezierClipping called")
    }
    let clampedPrecision = precision < MAX_PRECISION ? precision: MAX_PRECISION
    return getSolutions(A.points, B.points, precision: clampedPrecision)
}

private func get_precision(_ I: Interval) -> Int {
    let d: CGFloat = I.extent
    var e: CGFloat = 0.1
    var p: CGFloat = 10
    var n: Int = 0;
    while (n < 16 && d < e) {
        p *= 10
        e = 1.0 / p
        n += 1
    }
    return n
}

private func getSolutions(_ A: [CGPoint], _ B: [CGPoint], precision: CGFloat) -> [Intersection] {
    var domsA = [Interval]()
    var domsB = [Interval]()
    var counter = 0
    
    A.withUnsafeBufferPointer { AA in
        B.withUnsafeBufferPointer { BB in
            iterate(&domsA, &domsB, AA, BB, UNIT_INTERVAL, UNIT_INTERVAL, precision: precision, counter: &counter)
        }
    }
    assert(domsA.count == domsB.count)
    var i = 0
   
    func roundToEnd(_ value: CGFloat) -> CGFloat {
        if Utils.approximately(Double(value), 0.0, precision: Utils.epsilon) {
            return CGFloat(0.0)
        }
        else if Utils.approximately(Double(value), 1.0, precision: Utils.epsilon) {
            return CGFloat(1.0)
        }
        return value
    }
    
    return zip(domsA, domsB).map {
        if verbose {
            print("\(i) : domB : \(domsA[i])")
            print("extent A: \(domsA[i].extent)")
            print("precision A: \(get_precision(domsA[i]))")
            print("\(i) : domB : \(domsB[i])")
            print("extent B: \(domsB[i].extent)")
            print("precision B: \(get_precision(domsB[i]))")
        }
        i += 1
        return Intersection(t1: roundToEnd($0.0.middle), t2: roundToEnd($0.1.middle))
    }
}

func isConstant(_ array: UnsafeBufferPointer<CGPoint>, _ epsilon: CGFloat) -> Bool {
    for i in 1..<array.count {
        if areNear(array[i], array.first!, epsilon) == false {
            return false
        }
    }
    return true
}

private func areNear(_ a: CGPoint, _ b: CGPoint, _ epsilon: CGFloat = EPSILON) -> Bool {
    return (a-b).lengthSquared <= epsilon*epsilon
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

private func portion(_ B: UnsafeMutableBufferPointer<CGPoint>, _ I: Interval) {
    if I.start == 0 {
        if I.end == 1 {
            return
        }
        left_portion(I.end, B)
        return
    }
    right_portion(I.start, B)
    if I.end == 1 {
        return
    }
    let t = I.extent / (1 - I.start)
    left_portion(t, B)
}

/*
 *  Compute the portion of the Bezier curve "B" wrt the interval [0,t]
 */
// portion(Bezier, 0, t)
private func left_portion(_ t: CGFloat, _ B: UnsafeMutableBufferPointer<CGPoint>) {
    let n = B.count
    for i in 1..<n {
        for j in stride(from: n-1, through: i, by: -1) {
            B[j] = Utils.lerp(t, B[j-1], B[j])
        }
    }
}

/*
 *  Compute the portion of the Bezier curve "B" wrt the interval [t,1]
 */
// portion(Bezier, t, 1)
private func right_portion(_ t: CGFloat, _ B: UnsafeMutableBufferPointer<CGPoint>) {
    let n = B.count
    for i in 1..<n {
        for j in 0..<(n-i) {
            B[j] = Utils.lerp(t, B[j], B[j+1])
        }
    }
}

private func angle(_ A: UnsafeBufferPointer<CGPoint>) -> CGFloat {
    let a: CGFloat = atan2(A.last!.y - A.first!.y, A.last!.x - A.first!.x)
    return (180.0 * a / CGFloat.pi)
}

private func iterate(_ domsA: inout [Interval], _ domsB: inout [Interval],
                     _ A: UnsafeBufferPointer<CGPoint>, _ B: UnsafeBufferPointer<CGPoint>,
                     _ domA: Interval, _ domB: Interval,
                     precision: CGFloat,
                     counter: inout Int) {
    
    counter += 1
    if counter > 100 {
        return
    }
    
    if verbose {
        //    std::cerr << std::fixed << std::setprecision(16);
        print(">> curve subdision performed <<")
        print("dom(A) : \(domA)")
        print("dom(B) : \(domB)")
        //    std::cerr << "angle(A) : " << angle(A) << std::endl;
        //    std::cerr << "angle(B) : " << angle(B) << std::endl;
    }
    
    var pA = UnsafeMutableBufferPointer<CGPoint>.allocate(capacity: A.count)
    let _ = pA.initialize(from: A)
    defer { pA.deallocate() }
    
    var pB = UnsafeMutableBufferPointer<CGPoint>.allocate(capacity: B.count)
    let _ = pB.initialize(from: B)
    defer { pB.deallocate() }
    
    // memory used for left / right split of curves
    let pC1 = UnsafeMutableBufferPointer<CGPoint>.allocate(capacity: max(pA.count, pB.count))
    let pC2 = UnsafeMutableBufferPointer<CGPoint>.allocate(capacity: max(pA.count, pB.count))
    defer { pC1.deallocate() }
    defer { pC2.deallocate() }
    
    var C1 = pA
    var C2 = pB

    var dompA = domA
    var dompB = domB
    var dom1 = UnsafeMutablePointer<Interval>(&dompA)
    var dom2 = UnsafeMutablePointer<Interval>(&dompB)

    if (isConstant(A, precision) && isConstant(B, precision)) {
        let M1 = middle_point(C1.first!, C1.last!)
        let M2 = middle_point(C2.first!, C2.last!)
        if areNear(M1, M2) {
            domsA.append(domA)
            domsB.append(domB)
        }
        return
    }

    var iter = 1;
    while iter < 100 && (dompA.extent >= precision || dompB.extent >= precision) {
        if verbose {
            print("iter: \(iter)")
        }
        iter += 1
        guard let dom = clip(UnsafeBufferPointer(C1), UnsafeBufferPointer(C2), precision: precision) else {
            if verbose {
                print("dom: empty")
            }
            return
        }

        // all other cases where dom[0] > dom[1] are invalid
        assert(dom.start <= dom.end)

        map_to(&dom2.pointee, dom)

        portion(C2, dom)

        if isConstant(UnsafeBufferPointer(C2), precision) && isConstant(UnsafeBufferPointer(C1), precision) {
            let M1 = middle_point(C1.first!, C1.last!)
            let M2 = middle_point(C2.first!, C2.last!)
            if verbose {
                print("both curves are constant: \nM1: \(M1)\nM2: \(M2)")
                print("C2\n\(C2)")
                print("C1\n\(C1)")
            }
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
            if verbose {
                print("clipped less than 20% : \(dom.extent)")
                print("angle(pA) : \(angle(UnsafeBufferPointer(pA)))")
                print("angle(pB) : \(angle(UnsafeBufferPointer(pB)))")
            }
            if dompA.extent > dompB.extent {
                let _ = pC1.initialize(from: pA)
                let _ = pC2.initialize(from: pA)
                portion(pC1, H1_INTERVAL)
                portion(pC2, H2_INTERVAL)
                var dompC1 = dompA
                var dompC2 = dompA
                map_to(&dompC1, H1_INTERVAL)
                map_to(&dompC2, H2_INTERVAL)
                iterate(&domsA, &domsB, UnsafeBufferPointer(pC1), UnsafeBufferPointer(pB), dompC1, dompB, precision: precision, counter: &counter)
                iterate(&domsA, &domsB, UnsafeBufferPointer(pC2), UnsafeBufferPointer(pB), dompC2, dompB, precision: precision, counter: &counter)
            }
            else {
                let _ = pC1.initialize(from: pB)
                let _ = pC2.initialize(from: pB)
                portion(pC1, H1_INTERVAL)
                portion(pC2, H2_INTERVAL)
                var dompC1 = dompB
                var dompC2 = dompB
                map_to(&dompC1, H1_INTERVAL)
                map_to(&dompC2, H2_INTERVAL)
                iterate(&domsB, &domsA, UnsafeBufferPointer(pC2), UnsafeBufferPointer(pA), dompC2, dompA, precision: precision, counter: &counter)
                iterate(&domsB, &domsA, UnsafeBufferPointer(pC1), UnsafeBufferPointer(pA), dompC1, dompA, precision: precision, counter: &counter)
            }
            return
        }
        if verbose {
            print("dom(pA) : \(dompA)")
            print("dom(pB) : \(dompB)")
        }

        swap(&C1, &C2)
        swap(&dom1, &dom2)
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

private func clip(_ A:  UnsafeBufferPointer<CGPoint>, _ B:  UnsafeBufferPointer<CGPoint>, precision: CGFloat) -> Interval? {
    var bl: LineSegment = {
        if isConstant(A, precision) {
            let M = middle_point(A.first!, A.last!)
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
private func fat_line_bounds(_ c: UnsafeBufferPointer<CGPoint>, _ l: LineSegment) -> Interval {
    var bound = Interval(start: 0, end: 0)
    for i in 0..<c.count {
        bound.expandTo(signed_distance(c[i], l))
    }
    return bound
}

/*
 * Pick up an orientation line for the Bezier curve "c" and return it in
 * the output parameter "l"
 */
private func pick_orientation_line(_ c: UnsafeBufferPointer<CGPoint>, precision: CGFloat ) -> LineSegment {
    var i = c.count
    repeat {
        i -= 1
    } while i > 0 && areNear(c.first!, c[i], precision)
    
    // this should never happen because when a new curve portion is created
    // we check that it is not constant;
    // however this requires that the precision used in the is_constant
    // routine has to be the same used here in the are_near test
    assert(i != 0);
    
    let line = LineSegment(p0: c.first!, p1: c[i])
    return line
    //std::cerr << "i = " << i << std::endl;
}

/*
 *  Make up an orientation line for constant bezier curve;
 *  the orientation line is made up orthogonal to the other curve base line;
 *  the line is returned in the output parameter "l" in the form of a 3 element
 *  vector : l[0] * x + l[1] * y + l[2] == 0; the line is normalized.
 */
private func orthogonal_orientation_line(_ c: UnsafeBufferPointer<CGPoint>, _ p: CGPoint, precision: CGFloat) -> LineSegment {
    // this should never happen
    assert(!isConstant(c, precision))
    
    let line = LineSegment(p0: p, p1: (c.last! - c.first!).cw() + p)
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
private func clip_interval(_ B: UnsafeBufferPointer<CGPoint>, _ l: LineSegment, _ bound: Interval) -> Interval? {
    let n = CGFloat(B.count-1) // number of sub-intervals
    
    let D = UnsafeMutableBufferPointer<CGPoint>.allocate(capacity: B.count)
    defer {
        D.deallocate()
    }
    for i in 0..<B.count {
        let d: CGFloat = signed_distance(B[i], l)
        D[i] = CGPoint(x: CGFloat(i) / n, y: d)
    }
    
    guard let p = computeConvexHullUnsafe(UnsafeBufferPointer(D)) else {
        return nil
    }
    defer {
        p.deallocate()
    }
    
    let count = p.count

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
    
    for i in 1..<count {
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
            plower = clower
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
    let last = count - 1
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
