//
//  CubicCurveTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/23/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit
#if !os(WASI)
class CubicCurveTests: XCTestCase {

    override func setUp() {
        self.continueAfterFailure = false
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testInitializerArray() {
        let c = CubicCurve(points: [CGPoint(x: 1.0, y: 1.0), CGPoint(x: 3.0, y: 2.0), CGPoint(x: 5.0, y: 3.0), CGPoint(x: 7.0, y: 4.0)])
        XCTAssertEqual(c.p0, CGPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(c.p1, CGPoint(x: 3.0, y: 2.0))
        XCTAssertEqual(c.p2, CGPoint(x: 5.0, y: 3.0))
        XCTAssertEqual(c.p3, CGPoint(x: 7.0, y: 4.0))
        XCTAssertEqual(c.startingPoint, CGPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(c.endingPoint, CGPoint(x: 7.0, y: 4.0))
    }

    func testInitializerIndividualPoints() {
        let c = CubicCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 3.0, y: 2.0), p2: CGPoint(x: 5.0, y: 3.0), p3: CGPoint(x: 7.0, y: 4.0))
        XCTAssertEqual(c.p0, CGPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(c.p1, CGPoint(x: 3.0, y: 2.0))
        XCTAssertEqual(c.p2, CGPoint(x: 5.0, y: 3.0))
        XCTAssertEqual(c.p3, CGPoint(x: 7.0, y: 4.0))
        XCTAssertEqual(c.startingPoint, CGPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(c.endingPoint, CGPoint(x: 7.0, y: 4.0))
    }

    func testInitializerLineSegment() {
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 2.0, y: 3.0))
        let c = CubicCurve(lineSegment: l)
        XCTAssertEqual(c.p0, l.p0)
        let oneThird: CGFloat = 1.0 / 3.0
        let twoThirds: CGFloat = 2.0 / 3.0
        XCTAssertEqual(c.p1, twoThirds * l.p0 + oneThird * l.p1)
        XCTAssertEqual(c.p2, oneThird * l.p0 + twoThirds * l.p1)
        XCTAssertEqual(c.p3, l.p1)
    }

    func testInitializerQuadratic() {
        let q = QuadraticCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 2.0, y: 2.0), p2: CGPoint(x: 3.0, y: 1.0))
        let c = CubicCurve(quadratic: q)
        let epsilon: CGFloat = 1.0e-6
        // check for equality via lookup table
        let steps = 10
        for (p1, p2) in zip(q.lookupTable(steps: steps), c.lookupTable(steps: steps)) {
            XCTAssert((p1 - p2).length < epsilon)
        }
        // check for proper values in control points
        let fiveThirds: CGFloat = 5.0 / 3.0
        let sevenThirds: CGFloat = 7.0 / 3.0
        XCTAssert((c.p0 - CGPoint(x: 1.0, y: 1.0)).length < epsilon)
        XCTAssert((c.p1 - CGPoint(x: fiveThirds, y: fiveThirds)).length < epsilon)
        XCTAssert((c.p2 - CGPoint(x: sevenThirds, y: fiveThirds)).length < epsilon)
        XCTAssert((c.p3 - CGPoint(x: 3.0, y: 1.0)).length < epsilon)
    }

    func testInitializerStartEndMidTStrutLength() {

        let epsilon: CGFloat = 0.00001

        let start = CGPoint(x: 1.0, y: 1.0)
        let mid = CGPoint(x: 2.0, y: 2.0)
        let end = CGPoint(x: 4.0, y: 0.0)

        // first test passing without passing a t or d paramter
        var c = CubicCurve(start: start, end: end, mid: mid)
        XCTAssertEqual(c.point(at: 0.0), start)
        XCTAssert((c.point(at: 0.5) - mid).length < epsilon)
        XCTAssertEqual(c.point(at: 1.0), end)

        // now test passing in a manual t and length d
        let t: CGFloat = 7.0 / 9.0
        let d: CGFloat = 1.5
        c = CubicCurve(start: start, end: end, mid: mid, t: t, d: d)
        XCTAssertEqual(c.point(at: 0.0), start)
        XCTAssert((c.point(at: t) - mid).length < epsilon)
        XCTAssertEqual(c.point(at: 1.0), end)
        // make sure our solution has the proper strut length
        let e1 = c.hull(t)[7]
        let e2 = c.hull(t)[8]
        let l = (e2 - e1).length
        XCTAssertEqual(l, d * 1.0 / t, accuracy: epsilon)
    }

    func testBasicProperties() {
        let c = CubicCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 3.0, y: 2.0), p2: CGPoint(x: 4.0, y: 2.0), p3: CGPoint(x: 6.0, y: 1.0))
        XCTAssert(c.simple)
        XCTAssertEqual(c.order, 3)
        XCTAssertEqual(c.startingPoint, CGPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(c.endingPoint, CGPoint(x: 6.0, y: 1.0))
    }

    func testSetStartEndPoints() {
        var c = CubicCurve(p0: CGPoint(x: 5.0, y: 6.0), p1: CGPoint(x: 6.0, y: 5.0), p2: CGPoint(x: 7.0, y: 8.0), p3: CGPoint(x: 8.0, y: 7.0))
        c.startingPoint = CGPoint(x: 4.0, y: 5.0)
        XCTAssertEqual(c.p0, c.startingPoint)
        XCTAssertEqual(c.startingPoint, CGPoint(x: 4.0, y: 5.0))
        c.endingPoint = CGPoint(x: 9.0, y: 8.0)
        XCTAssertEqual(c.p3, c.endingPoint)
        XCTAssertEqual(c.endingPoint, CGPoint(x: 9.0, y: 8.0))
    }

    func testSimple() {
        // create a simple cubic curve (very simple, because it's equal to a line segment)
        let c1 = CubicCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 2.0, y: 2.0), p2: CGPoint(x: 3.0, y: 3.0), p3: CGPoint(x: 4.0, y: 4.0))
        XCTAssertTrue(c1.simple)
        // a non-trivial example of a simple curve -- almost a straight line
        let c2 = CubicCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 2.0, y: 1.05), p2: CGPoint(x: 3.0, y: 1.05), p3: CGPoint(x: 4.0, y: 1.0))
        XCTAssertTrue(c2.simple)
        // non-simple curve, control points fall on different sides of the baseline
        let c3 = CubicCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 2.0, y: 1.05), p2: CGPoint(x: 3.0, y: 0.95), p3: CGPoint(x: 4.0, y: 1.0))
        XCTAssertFalse(c3.simple)
        // non-simple curve, angle between end point normals > 60 degrees (pi/3) -- in this case the angle is 45 degrees (pi/2)
        let c4 = CubicCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 1.0, y: 2.0), p2: CGPoint(x: 2.0, y: 3.0), p3: CGPoint(x: 3.0, y: 3.0))
        XCTAssertFalse(c4.simple)
        // ensure that points-as-cubics pass (otherwise callers might try to subdivide them further)
        let p = CGPoint(x: 1.234, y: 5.689)
        let c5 = CubicCurve(p0: p, p1: p, p2: p, p3: p)
        XCTAssertTrue(c5.simple)
    }

    func testDerivative() {
        let epsilon: CGFloat = 0.00001
        let p0 = CGPoint(x: 1.0, y: 1.0)
        let p1 = CGPoint(x: 3.0, y: 2.0)
        let p2 = CGPoint(x: 5.0, y: 2.0)
        let p3 = CGPoint(x: 7.0, y: 1.0)
        let c = CubicCurve(p0: p0, p1: p1, p2: p2, p3: p3)
        XCTAssert(distance(c.derivative(at: 0.0), 3.0 * (p1 - p0)) < epsilon)
        XCTAssert(distance(c.derivative(at: 0.5), CGPoint(x: 6.0, y: 0.0)) < epsilon)
        XCTAssert(distance(c.derivative(at: 1.0), 3.0 * (p3 - p2)) < epsilon)
    }

    func testSplitFromTo() {
        let epsilon: CGFloat = 0.00001
        let c = CubicCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 3.0, y: 2.0), p2: CGPoint(x: 4.0, y: 2.0), p3: CGPoint(x: 6.0, y: 1.0))
        let t1: CGFloat = 1.0 / 3.0
        let t2: CGFloat = 2.0 / 3.0
        let s = c.split(from: t1, to: t2)
        XCTAssert(BezierKitTestHelpers.curve(s, matchesCurve: c, overInterval: Interval(start: t1, end: t2), tolerance: epsilon))
    }

    func testSplitFromToSameLocation() {
        // when splitting with same `from` and `to` parameter, we should get a point back.
        // but if we aren't careful round-off error will give us something slightly different.
        let cubic = CubicCurve(p0: CGPoint(x: 0.041630344771878214, y: 0.45449244472862915),
                               p1: CGPoint(x: 0.8348172181669149, y: 0.33598603014520023),
                               p2: CGPoint(x: 0.5654894035661364, y: 0.001766912391744313),
                               p3: CGPoint(x: 0.18758951699996018, y: 0.9904340799376641))
        let t: CGFloat = 0.920134
        let result = cubic.split(from: t, to: t)
        let expectedPoint = cubic.point(at: t)
        XCTAssertEqual(result.p0, expectedPoint)
        XCTAssertEqual(result.p1, expectedPoint)
        XCTAssertEqual(result.p2, expectedPoint)
        XCTAssertEqual(result.p3, expectedPoint)
    }

    func testSplitContinuous() {
        // if I call split(from: a, to: b) and split(from: b, to: c)
        // then the two subcurves should be continuous. However, from lack of precision that might not happen unless we are careful!
        let a: CGFloat = 0.65472931005125345
        let b: CGFloat = 0.73653845530600293
        let c: CGFloat = 1.0
        let curve = CubicCurve(p0: CGPoint(x: 286.8966218087201, y: 69.11759651620365),
                               p1: CGPoint(x: 285.7845542083973, y: 69.84970485476842),
                               p2: CGPoint(x: 284.6698515652002, y: 70.60114443784359),
                               p3: CGPoint(x: 283.5560914830615, y: 71.34238971309229))
        let split1 = curve.split(from: a, to: b)
        let split2 = curve.split(from: b, to: c)
        XCTAssertEqual(split1.endingPoint, split2.startingPoint)

        let (left, right) = curve.split(at: b)
        XCTAssertEqual(left.endingPoint, right.startingPoint)

        XCTAssertEqual(curve.split(from: 1, to: 0), curve.reversed())
        XCTAssertTrue(BezierKitTestHelpers.curveControlPointsEqual(curve1: curve.split(from: b, to: a),
                                                                   curve2: curve.split(from: a, to: b).reversed(),
                                                                   tolerance: 1.0e-5))
    }

    func testSplitAt() {
        let epsilon: CGFloat = 0.00001
        let c = CubicCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 3.0, y: 2.0), p2: CGPoint(x: 4.0, y: 2.0), p3: CGPoint(x: 6.0, y: 1.0))
        let t: CGFloat = 0.25
        let (left, right) = c.split(at: t)
        XCTAssert(BezierKitTestHelpers.curve(left, matchesCurve: c, overInterval: Interval(start: 0, end: t), tolerance: epsilon))
        XCTAssert(BezierKitTestHelpers.curve(right, matchesCurve: c, overInterval: Interval(start: t, end: 1), tolerance: epsilon))
    }

    func testBoundingBox() {
        // hits codepath where midpoint pushes up y coordinate of bounding box
        let c1 = CubicCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 3.0, y: 2.0), p2: CGPoint(x: 5.0, y: 2.0), p3: CGPoint(x: 7.0, y: 1.0))
        let expectedBoundingBox1 = BoundingBox(p1: CGPoint(x: 1.0, y: 1.0),
                                              p2: CGPoint(x: 7.0, y: 1.75))
        XCTAssertEqual(c1.boundingBox, expectedBoundingBox1)
        // hits codepath where midpoint pushes down x coordinate of bounding box
        let c2 = CubicCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: -3.0, y: 2.0), p2: CGPoint(x: -3.0, y: 3.0), p3: CGPoint(x: 1.0, y: 4.0))
        let expectedBoundingBox2 = BoundingBox(p1: CGPoint(x: -2.0, y: 1.0),
                                               p2: CGPoint(x: 1.0, y: 4.0))
        XCTAssertEqual(c2.boundingBox, expectedBoundingBox2)
        // this one is designed to hit an unusual codepath: c3 has an extrema that would expand the bounding box,
        // but it falls outside of the range 0<=t<=1, and therefore must be excluded
        let c3 = c1.split(at: 0.25).left
        let expectedBoundingBox3 = BoundingBox(p1: CGPoint(x: 1.0, y: 1.0),
                                               p2: CGPoint(x: 2.5, y: 1.5625))
        XCTAssertEqual(c3.boundingBox, expectedBoundingBox3)

        // bounding box of a degenerate curve made out of a single point
        let p = CGPoint(x: 1.234, y: 2.394)
        let degenerate = CubicCurve(p0: p, p1: p, p2: p, p3: p)
        XCTAssertEqual(degenerate.boundingBox, BoundingBox(p1: p, p2: p))
    }

    func testCompute() {
        let c = CubicCurve(p0: CGPoint(x: 3.0, y: 5.0),
                                 p1: CGPoint(x: 4.0, y: 6.0),
                                 p2: CGPoint(x: 6.0, y: 6.0),
                                 p3: CGPoint(x: 7.0, y: 5.0))
        XCTAssertEqual(c.point(at: 0.0), CGPoint(x: 3.0, y: 5.0))
        XCTAssertEqual(c.point(at: 0.5), CGPoint(x: 5.0, y: 5.75))
        XCTAssertEqual(c.point(at: 1.0), CGPoint(x: 7.0, y: 5.0))
    }

// -- MARK: - methods for which default implementations provided by protocol

    func testLength() {
        let epsilon: CGFloat = 0.00001
        let c1 = CubicCurve(p0: CGPoint(x: 1.0, y: 2.0),
                                  p1: CGPoint(x: 7.0 / 3.0, y: 3.0),
                                  p2: CGPoint(x: 11.0 / 3.0, y: 4.0),
                                  p3: CGPoint(x: 5.0, y: 5.0)
        ) // represents a straight line of length 5 -- most curves won't have an easy reference solution
        XCTAssertEqual(c1.length(), 5.0, accuracy: epsilon)
    }

    func testProject() {
        let epsilon: CGFloat = 1.0e-5
        // test a cubic
        let c = CubicCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 2.0, y: 2.0), p2: CGPoint(x: 4.0, y: 2.0), p3: CGPoint(x: 5.0, y: 1.0))
        let p4 = c.project(CGPoint(x: 0.95, y: 1.05)) // should project to p0
        XCTAssertEqual(p4.point, CGPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(p4.t, 0.0)
        let p5 = c.project(CGPoint(x: 5.05, y: 1.05)) // should project to p3
        XCTAssertEqual(p5.point, CGPoint(x: 5.0, y: 1.0))
        XCTAssertEqual(p5.t, 1.0)
        let p6 = c.project(CGPoint(x: 3.0, y: 2.0)) // should project to center of curve
        XCTAssertEqual(p6.point, CGPoint(x: 3.0, y: 1.75))
        XCTAssertEqual(p6.t, 0.5)

        let t: CGFloat = 0.831211
        let pointToProject = c.point(at: t) + c.normal(at: t)
        let expectedAnswer = c.point(at: t)
        let p7 = c.project(pointToProject) // should project back to (roughly) c.compute(0.831211)
        XCTAssert(distance(p7.point, expectedAnswer) < epsilon)
        XCTAssertEqual(p7.t, t, accuracy: epsilon)
    }

    func testProjectRealWorldIssue() {
        // this issue occurred when using the Bezier Clipping approach
        // to root solving due to some kind of issue with the limits of precision
        // one idea is to look at the .split() functions and make sure there are no cracks
        // another idea is to look at the start and end points and actually require the call to produce a solution
        let epsilon: CGFloat = 1.0e-5
        let c = CubicCurve(p0: CGPoint(x: 100, y: 25),
                           p1: CGPoint(x: 10, y: 90),
                           p2: CGPoint(x: 50, y: 185),
                           p3: CGPoint(x: 170, y: 175))
        let t = c.project(CGPoint(x: 8.3359375, y: -49.10546875)).t
        XCTAssertEqual(t, 0.0575491, accuracy: epsilon)
    }

// TODO: we still have some missing unit tests for CubicCurve's API entry points

//    func testHull() {
//        let l = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 3.0, y: 4.0))
//        let h = l.hull(0.5)
//        XCTAssert(h.count == 3)
//        XCTAssertEqual(h[0], CGPoint(x: 1.0, y: 2.0))
//        XCTAssertEqual(h[1], CGPoint(x: 3.0, y: 4.0))
//        XCTAssertEqual(h[2], CGPoint(x: 2.0, y: 3.0))
//    }
//    
//    func testNormal() {
//        let l = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 5.0, y: 6.0))
//        let n1 = l.normal(0.0)
//        let n2 = l.normal(0.5)
//        let n3 = l.normal(1.0)
//        XCTAssertEqual(n1, CGPoint(x: -1.0 / sqrt(2.0), y: 1.0 / sqrt(2.0)))
//        XCTAssertEqual(n1, n2)
//        XCTAssertEqual(n2, n3)
//    }

    func testNormalDegenerate() {
        let maxError: CGFloat = 0.01
        let a = CGPoint(x: 2, y: 3)
        let b = CGPoint(x: 3, y: 3)
        let c = CGPoint(x: 4, y: 4)
        let cubic1 = CubicCurve(p0: a, p1: a, p2: b, p3: c)
        XCTAssertTrue( distance(cubic1.normal(at: 0), CGPoint(x: 0, y: 1)) < maxError )
        let cubic2 = CubicCurve(p0: a, p1: b, p2: c, p3: c)
        XCTAssertTrue( distance(cubic2.normal(at: 1), CGPoint(x: -sqrt(2)/2, y: sqrt(2)/2)) < maxError )
        let cubic3 = CubicCurve(p0: a, p1: a, p2: a, p3: b)
        XCTAssertTrue( distance(cubic3.normal(at: 0), CGPoint(x: 0, y: 1)) < maxError )
        let cubic4 = CubicCurve(p0: a, p1: b, p2: b, p3: b)
        XCTAssertTrue( distance(cubic4.normal(at: 1), CGPoint(x: 0, y: 1)) < maxError )
    }

    func testNormalCusp() {
        // c has a cusp at t = 0.5, the normal vector *cannot* be defined
        let c = CubicCurve(p0: CGPoint(x: 1, y: 1),
                                 p1: CGPoint(x: 2, y: 2),
                                 p2: CGPoint(x: 1, y: 2),
                                 p3: CGPoint(x: 2, y: 1))
        XCTAssertEqual(c.derivative(at: 0.5), CGPoint.zero)
        XCTAssertTrue(c.normal(at: 0.5).x.isNaN)
        XCTAssertTrue(c.normal(at: 0.5).y.isNaN)
    }

    func testReduce() {
        // curve with both tangents above the baseline, difference in angles just under pi / 3
        let c1 = CubicCurve(p0: CGPoint(x: 0.0, y: 0.0),
                                  p1: CGPoint(x: 1.0, y: 2.0),
                                  p2: CGPoint(x: 2.0, y: 3.0),
                                  p3: CGPoint(x: 4.0, y: 4.0))
        let result1 = c1.reduce()
        XCTAssertEqual([Subcurve(t1: 0, t2: 1, curve: c1)], result1)

        // angle between vectors is nearly pi / 2, so it must be split
        let c2 = CubicCurve(p0: CGPoint(x: 0.0, y: 0.0),
                                  p1: CGPoint(x: 0.0, y: 2.0),
                                  p2: CGPoint(x: 2.0, y: 4.0),
                                  p3: CGPoint(x: 4.0, y: 4.0))
        let result2 = c2.reduce()
        XCTAssertTrue(BezierKitTestHelpers.isSatisfactoryReduceResult(result2, for: c2))

        // ensure it works for degenerate case
        let p = CGPoint(x: 5.3451, y: -1.2345)
        let c3 = CubicCurve(p0: p, p1: p, p2: p, p3: p)
        let result3 = c3.reduce()
        XCTAssertTrue(BezierKitTestHelpers.isSatisfactoryReduceResult(result3, for: c3))
    }

    func testReduceExtremaCloseby() {
        // the x coordinates are f(t) = (t-0.5)^2 = t^2 - t + 0.25, which has a minima at t=0.5
        // the y coordinates are f(t) = 1/3t^3 - 1/2t^2 + 3/16t, which has an inflection at t=0.5
        // adding `smallValue` to one of the y coordinates gives us two extrema very close to t=0.5
        let smallValue: CGFloat = 1.0e-3
        let c = BezierKitTestHelpers.cubicCurveFromPolynomials([0, 1, -1, 0.25], [CGFloat(1.0 / 3.0), CGFloat(-1.0 / 2.0) + smallValue, CGFloat(3.0 / 16.0), 0])
        let result1 = c.reduce()
        XCTAssertTrue(BezierKitTestHelpers.isSatisfactoryReduceResult(result1, for: c))
    }
//
//    //    func testScaleDistanceFunc {
//    //
//    //    }
//    
//    func testIntersects() {
//        let l = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 5.0, y: 6.0))
//        let i = l.intersects()
//        XCTAssert(i.count == 0) // lines never self-intersect
//    }
//        
//    // -- MARK: - line-curve intersection tests
//    
//    func testIntersectsQuadratic() {
//        // we mostly just care that we call into the proper implementation and that the results are ordered correctly
//        // q is a quadratic where y(x) = 2 - 2(x-1)^2
//        let epsilon: CGFloat = 0.00001
//        let q: QuadraticCurve = QuadraticCurve.init(p0: CGPoint(x: 0.0, y: 0.0),
//                                                                p1: CGPoint(x: 1.0, y: 2.0),
//                                                                p2: CGPoint(x: 2.0, y: 0.0),
//                                                                t: 0.5)
//        let l1: LineSegment = LineSegment(p0: CGPoint(x: -1.0, y: 1.0), p1: CGPoint(x: 3.0, y: 1.0))
//        let l2: LineSegment = LineSegment(p0: CGPoint(x: 3.0, y: 1.0), p1: CGPoint(x: -1.0, y: 1.0)) // same line as l1, but reversed
//        // the intersections for both lines occur at x = 1±sqrt(1/2)
//        let i1 = l1.intersects(curve: q)
//        let r1: CGFloat = 1.0 - sqrt(1.0 / 2.0)
//        let r2: CGFloat = 1.0 + sqrt(1.0 / 2.0)
//        XCTAssertEqual(i1.count, 2)
//        XCTAssertEqualWithAccuracy(i1[0].t1, (r1 + 1.0) / 4.0, accuracy: epsilon)
//        XCTAssertEqualWithAccuracy(i1[0].t2, r1 / 2.0, accuracy: epsilon)
//        XCTAssert((l1.compute(i1[0].t1) - q.compute(i1[0].t2)).length < epsilon)
//        XCTAssertEqualWithAccuracy(i1[1].t1, (r2 + 1.0) / 4.0, accuracy: epsilon)
//        XCTAssertEqualWithAccuracy(i1[1].t2, r2 / 2.0, accuracy: epsilon)
//        XCTAssert((l1.compute(i1[1].t1) - q.compute(i1[1].t2)).length < epsilon)
//        // do the same thing as above but using l2
//        let i2 = l2.intersects(curve: q)
//        XCTAssertEqual(i2.count, 2)
//        XCTAssertEqualWithAccuracy(i2[0].t1, (r1 + 1.0) / 4.0, accuracy: epsilon)
//        XCTAssertEqualWithAccuracy(i2[0].t2, r2 / 2.0, accuracy: epsilon)
//        XCTAssert((l2.compute(i2[0].t1) - q.compute(i2[0].t2)).length < epsilon)
//        XCTAssertEqualWithAccuracy(i2[1].t1, (r2 + 1.0) / 4.0, accuracy: epsilon)
//        XCTAssertEqualWithAccuracy(i2[1].t2, r1 / 2.0, accuracy: epsilon)
//        XCTAssert((l2.compute(i2[1].t1) - q.compute(i2[1].t2)).length < epsilon)
//    }
//    
//    func testIntersectsCubic() {
//        // we mostly just care that we call into the proper implementation and that the results are ordered correctly
//        let epsilon: CGFloat = 0.00001
//        let c: CubicCurve = CubicCurve(p0: CGPoint(x: -1, y: 0),
//                                                   p1: CGPoint(x: -1, y: 1),
//                                                   p2: CGPoint(x:  1, y: -1),
//                                                   p3: CGPoint(x:  1, y: 0))
//        let l1: LineSegment = LineSegment(p0: CGPoint(x: -2.0, y: 0.0), p1: CGPoint(x: 2.0, y: 0.0))
//        let i1 = l1.intersects(curve: c)
//        
//        XCTAssertEqual(i1.count, 3)
//        XCTAssertEqualWithAccuracy(i1[0].t1, 0.25, accuracy: epsilon)
//        XCTAssertEqualWithAccuracy(i1[0].t2, 0.0, accuracy: epsilon)
//        XCTAssertEqualWithAccuracy(i1[1].t1, 0.5, accuracy: epsilon)
//        XCTAssertEqualWithAccuracy(i1[1].t2, 0.5, accuracy: epsilon)
//        XCTAssertEqualWithAccuracy(i1[2].t1, 0.75, accuracy: epsilon)
//        XCTAssertEqualWithAccuracy(i1[2].t2, 1.0, accuracy: epsilon)
//        // l2 is the same line going in the opposite direction
//        // by checking this we ensure the intersections are ordered by the line and not the cubic
//        let l2: LineSegment = LineSegment(p0: CGPoint(x: 2.0, y: 0.0), p1: CGPoint(x: -2.0, y: 0.0))
//        let i2 = l2.intersects(curve: c)
//        XCTAssertEqual(i2.count, 3)
//        XCTAssertEqualWithAccuracy(i2[0].t1, 0.25, accuracy: epsilon)
//        XCTAssertEqualWithAccuracy(i2[0].t2, 1.0, accuracy: epsilon)
//        XCTAssertEqualWithAccuracy(i2[1].t1, 0.5, accuracy: epsilon)
//        XCTAssertEqualWithAccuracy(i2[1].t2, 0.5, accuracy: epsilon)
//        XCTAssertEqualWithAccuracy(i2[2].t1, 0.75, accuracy: epsilon)
//        XCTAssertEqualWithAccuracy(i2[2].t2, 0.0, accuracy: epsilon)
//    }
//

    func testIntersectionsCubicMaxIntersections() {
        let epsilon: CGFloat = 1.0e-5
        let a = 4.0
        let c1 = CubicCurve(p0: CGPoint(x: 0, y: 0),
                                  p1: CGPoint(x: 0.33, y: a),
                                  p2: CGPoint(x: 0.66, y: 1-a),
                                  p3: CGPoint(x: 1, y: 1))
        let c2 = CubicCurve(p0: CGPoint(x: 0, y: 1),
                                  p1: CGPoint(x: a, y: 0.66),
                                  p2: CGPoint(x: 1-a, y: 0.33),
                                  p3: CGPoint(x: 1, y: 0))
        let intersections = c1.intersections(with: c2, accuracy: epsilon)
        let expectedResults = [CGPoint(x: 0.009867618966216286, y: 0.11635072599233257),
                               CGPoint(x: 0.03530531425481719, y: 0.3869680057368261),
                               CGPoint(x: 0.11629483697722519, y: 0.9898413631716166),
                               CGPoint(x: 0.38725276058371816, y: 0.9636332023660762),
                               CGPoint(x: 0.49721796591086287, y: 0.495633320355362),
                               CGPoint(x: 0.6056909589337255, y: 0.036054034343778435),
                               CGPoint(x: 0.880590710796587, y: 0.010134637339461294),
                               CGPoint(x: 0.9628624913661753, y: 0.6053986189382927),
                               CGPoint(x: 0.9895666738958517, y: 0.8806493722540778)]
        XCTAssertEqual(intersections.count, 9)
        for i in 0..<intersections.count {
            XCTAssertTrue(distance(c1.point(at: intersections[i].t1), expectedResults[i]) < epsilon)
            XCTAssertTrue(distance(c2.point(at: intersections[i].t2), expectedResults[i]) < epsilon)
        }
    }

    func testIntersectionsCoincident() {
        let c = CubicCurve(p0: CGPoint(x: -1, y: -1),
                           p1: CGPoint(x: 0, y: 0),
                           p2: CGPoint(x: 2, y: 0),
                           p3: CGPoint(x: 3, y: -1))
        XCTAssertEqual(c.intersections(with: c.reversed()), [Intersection(t1: 0, t2: 1), Intersection(t1: 1, t2: 0)], "curves should be fully coincident with themselves.")
        // now, a tricky case, overlap from t = 1/3, to t=3/5 on the original curve
        let c1 = c.split(from: 1.0 / 3.0, to: 2.0 / 3.0)
        let c2 = c.split(from: 1.0 / 5.0, to: 3.0 / 5.0)
        let accuracy: CGFloat = 1.0e-4
        let intersections = c1.intersections(with: c2, accuracy: accuracy) // (t1: 0, t2: 1/3), (t1: 4/5, t2: 1)
        XCTAssertEqual(intersections.count, 2)
        if intersections.count == 2 {
            let i1 = intersections[0]
            XCTAssertTrue(distance(c1.point(at: i1.t1), c2.point(at: i1.t2)) < accuracy)
            let i2 = intersections[1]
            XCTAssertTrue(distance(c1.point(at: i2.t1), c2.point(at: i2.t2)) < accuracy)
        }
    }

    func testBasicTangentIntersection() {
        let c1 = CubicCurve(p0: CGPoint(x: 0, y: 0),
                            p1: CGPoint(x: 0, y: 3),
                            p2: CGPoint(x: 6, y: 9),
                            p3: CGPoint(x: 9, y: 9))
        let c2 = CubicCurve(p0: CGPoint(x: 9, y: 9),
                            p1: CGPoint(x: 8, y: 9),
                            p2: CGPoint(x: 6, y: 7),
                            p3: CGPoint(x: 6, y: 6))
        let expectedIntersections = [Intersection(t1: 1, t2: 0)]
        XCTAssertEqual(c1.intersections(with: c2, accuracy: 1.0e-5), expectedIntersections)
        XCTAssertEqual(c1.intersections(with: c2, accuracy: 1.0e-8), expectedIntersections)
    }

    func testRealWorldNearlyCoincidentCurvesIntersection() {
        // these curves are nearly coincident over from c1's t = 0.278 to 1.0
        // staying roughly 0.0002 distance of eachother
        // but they do actually appear to have real interesctions also
        let c1 = CubicCurve(p0: CGPoint(x: 0.9435597332840757, y: 0.16732142729460975),
                            p1: CGPoint(x: 0.6459474292317964, y: 0.22174990722896837),
                            p2: CGPoint(x: 0.3434479689753971, y: 0.2624874219291087),
                            p3: CGPoint(x: 0.036560070230819974, y: 0.28765861655756453))
        let c2 = CubicCurve(p0: CGPoint(x: 0.036560070230819974, y: 0.28765861655756453),
                            p1: CGPoint(x: 0.25665707912767743, y: 0.26960608118315577),
                            p2: CGPoint(x: 0.4760155370276209, y: 0.24346330678827144),
                            p3: CGPoint(x: 0.6941905032971079, y: 0.20928332065477662))
        let intersections = c1.intersections(with: c2, accuracy: 1.0e-5)
        XCTAssertEqual(intersections.count, 2)
        XCTAssertEqual(intersections[0].t1, 0.73204, accuracy: 1.0e-5)
        XCTAssertEqual(intersections[0].t2, 0.37268, accuracy: 1.0e-5)
        XCTAssertEqual(intersections[1].t1, 1)
        XCTAssertEqual(intersections[1].t2, 0)
    }

    func testIntersectionsCubicButActuallyLinear() {
        // this test presents a challenge for an implicitization based approach
        // if the linearity of the so-called "cubic" is not detected
        // the implicit equation will be f(x, y) = 0 and no intersections will be found
        let epsilon: CGFloat = 1.0e-5
        let cubicButActuallyLinear = CubicCurve(p0: CGPoint(x: 3, y: 2),
                                                p1: CGPoint(x: 4, y: 3),
                                                p2: CGPoint(x: 5, y: 4),
                                                p3: CGPoint(x: 6, y: 5))
        let cubic = CubicCurve(p0: CGPoint(x: 1, y: 0),
                               p1: CGPoint(x: 3, y: 6),
                               p2: CGPoint(x: 5, y: 2),
                               p3: CGPoint(x: 7, y: 0))
        let intersections = cubic.intersections(with: cubicButActuallyLinear, accuracy: epsilon)
        XCTAssertEqual(intersections.count, 1)
        XCTAssertEqual(intersections[0].t1, 0.5, accuracy: epsilon)
        XCTAssertEqual(intersections[0].t2, 1.0 / 3.0, accuracy: epsilon)
    }

    func testIntersectionsCubicButActuallyQuadratic() {
        // this test presents a challenge for an implicitization based approach
        // if the quadratic nature of the so-called "cubic" is not detected
        // the implicit equation will be f(x, y) = 0 and no intersections will be found
        let epsilon: CGFloat = 1.0e-5
        let cubicButActuallyQuadratic = CubicCurve(p0: CGPoint(x: 1, y: 1),
                                                   p1: CGPoint(x: 2, y: 4),
                                                   p2: CGPoint(x: 3, y: 4),
                                                   p3: CGPoint(x: 4, y: 1))
        let cubic = CubicCurve(p0: CGPoint(x: 0, y: 0),
                               p1: CGPoint(x: 2, y: 4),
                               p2: CGPoint(x: 4, y: 3),
                               p3: CGPoint(x: 6, y: 3))
        let intersections = cubic.intersections(with: cubicButActuallyQuadratic, accuracy: epsilon)
        XCTAssertEqual(intersections.count, 2)
        XCTAssertEqual(intersections[0].t1, 0.23607, accuracy: epsilon)
        XCTAssertEqual(intersections[0].t2, 0.13880, accuracy: epsilon)
        XCTAssertEqual(intersections[1].t1, 0.5, accuracy: epsilon)
        XCTAssertEqual(intersections[1].t2, 2.0 / 3.0, accuracy: epsilon)
    }

    func testRealWorldPrecisionIssue() {
        // this issue seems to happen because the implicit equation of c2
        // says f(x, y) = -8.177[...]e-10 for c1's starting point (instead of zero)
        // for a t1 = 0.000012060505980311977
        // the inverse expression says t2 = 1.0000005567957639 which gets rounded back to 1
        let c1 = CubicCurve(p0: CGPoint(x: 94.9790542640437, y: 96.49280906706511),
                            p1: CGPoint(x: 94.53950656843848, y: 97.22786538484215),
                            p2: CGPoint(x: 93.58730187717677, y: 97.46742245525438),
                            p3: CGPoint(x: 92.85224555939973, y: 97.02787475964917))
        let c2 = CubicCurve(p0: CGPoint(x: 123.54200084128175, y: 48.71908399606449),
            p1: CGPoint(x: 114.021065782688, y: 64.64877149606448),
            p2: CGPoint(x: 104.49998932263745, y: 80.57093406706511),
            p3: CGPoint(x: 94.9790542640437, y: 96.49280906706511))
        let intersections = c1.intersections(with: c2, accuracy: 1.0e-5)
        XCTAssertEqual(intersections, [Intersection(t1: 0, t2: 1)])
    }

    func testRealWorldInversionIssue() {
        // this issue appears / appeared to occur because the inverse method
        // was unstable when c2 was downgraded to a cubic with nearly parallel control points
        let c1 = CubicCurve(p0: CGPoint(x: 314.9306297035616, y: 2211.1494686514056),
                            p1: CGPoint(x: 315.4305682688995, y: 2211.87791339535),
                            p2: CGPoint(x: 315.24532741089774, y: 2212.8737148198643),
                            p3: CGPoint(x: 314.5168826669535, y: 2213.373653385202))
        let c2 = CubicCurve(p0: CGPoint(x: 314.8254662024578, y: 2210.9959498495646),
                            p1: CGPoint(x: 314.8606224524578, y: 2211.0472193808146),
                            p2: CGPoint(x: 314.89544293598345, y: 2211.0981991201556),
                            p3: CGPoint(x: 314.9306297035616, y: 2211.1494686514056))
        let intersections = c1.intersections(with: c2, accuracy: 1.0e-4)
        XCTAssertEqual(intersections, [Intersection(t1: 0, t2: 1)])
    }

    func testCubicIntersectsLine() {
        let epsilon: CGFloat = 0.00001
        let c: CubicCurve = CubicCurve(p0: CGPoint(x: -1, y: 0),
                                                   p1: CGPoint(x: -1, y: 1),
                                                   p2: CGPoint(x: 1, y: -1),
                                                   p3: CGPoint(x: 1, y: 0))
        let l: BezierCurve = LineSegment(p0: CGPoint(x: -2.0, y: 0.0), p1: CGPoint(x: 2.0, y: 0.0))
        let i = c.intersections(with: l)

        XCTAssertEqual(i.count, 3)
        XCTAssertEqual(i[0].t2, 0.25, accuracy: epsilon)
        XCTAssertEqual(i[0].t1, 0.0, accuracy: epsilon)
        XCTAssertEqual(i[1].t2, 0.5, accuracy: epsilon)
        XCTAssertEqual(i[1].t1, 0.5, accuracy: epsilon)
        XCTAssertEqual(i[2].t2, 0.75, accuracy: epsilon)
        XCTAssertEqual(i[2].t1, 1.0, accuracy: epsilon)
    }

    func testCubicIntersectsLineEdgeCase() {
        // this example caused issues in practice because it has a discriminant that is nearly equal to zero (but not exactly)
        let c = CubicCurve(p0: CGPoint(x: 3, y: 1),
                                 p1: CGPoint(x: 3, y: 1.5522847498307932),
                                 p2: CGPoint(x: 2.5522847498307932, y: 2),
                                 p3: CGPoint(x: 2, y: 2))
        let l = LineSegment(p0: CGPoint(x: 2, y: 2), p1: CGPoint(x: 0, y: 2))
        let i = c.intersections(with: l)
        XCTAssertEqual(i.count, 1)
        XCTAssertEqual(i[0].t1, 1)
        XCTAssertEqual(i[0].t2, 0)
    }

    func testCubicIntersectsLineCoincident() {
        let line = LineSegment(p0: CGPoint(x: -4, y: 7), p1: CGPoint(x: 10, y: 3))
        let curve = CubicCurve(lineSegment: line)
        XCTAssertEqual(line.intersections(with: curve), [Intersection(t1: 0, t2: 0), Intersection(t1: 1, t2: 1)], "curve and line should be fully coincident")
    }

    // MARK: -

    func testEquatable() {
        let p0 = CGPoint(x: 1.0, y: 2.0)
        let p1 = CGPoint(x: 2.0, y: 3.0)
        let p2 = CGPoint(x: 3.0, y: 3.0)
        let p3 = CGPoint(x: 4.0, y: 2.0)

        let c1 = CubicCurve(p0: p0, p1: p1, p2: p2, p3: p3)
        let c2 = CubicCurve(p0: CGPoint(x: 5.0, y: 6.0), p1: p1, p2: p2, p3: p3)
        let c3 = CubicCurve(p0: p0, p1: CGPoint(x: 1.0, y: 3.0), p2: p2, p3: p3)
        let c4 = CubicCurve(p0: p0, p1: p1, p2: CGPoint(x: 3.0, y: 6.0), p3: p3)
        let c5 = CubicCurve(p0: p0, p1: p1, p2: p2, p3: CGPoint(x: -4.0, y: 2.0))

        XCTAssertEqual(c1, c1)
        XCTAssertNotEqual(c1, c2)
        XCTAssertNotEqual(c1, c3)
        XCTAssertNotEqual(c1, c4)
        XCTAssertNotEqual(c1, c5)
    }
}
#endif
