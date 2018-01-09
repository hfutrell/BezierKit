//
//  LineSegmentTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/14/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import XCTest
import BezierKit

class LineSegmentTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testInitializerArray() {
        let l = LineSegment(points: [BKPoint(x: 1.0, y: 1.0), BKPoint(x: 3.0, y: 2.0)])
        XCTAssertEqual(l.p0, BKPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(l.p1, BKPoint(x: 3.0, y: 2.0))
        XCTAssertEqual(l.startingPoint, BKPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(l.endingPoint, BKPoint(x: 3.0, y: 2.0))
    }

    func testInitializerIndividualPoints() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 3.0, y: 2.0))
        XCTAssertEqual(l.p0, BKPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(l.p1, BKPoint(x: 3.0, y: 2.0))
        XCTAssertEqual(l.startingPoint, BKPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(l.endingPoint, BKPoint(x: 3.0, y: 2.0))
    }
    
    func testBasicProperties() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 2.0, y: 5.0))
        XCTAssert(l.simple)
        XCTAssertEqual(l.order, 1)
        XCTAssertEqual(l.startingPoint, BKPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(l.endingPoint, BKPoint(x: 2.0, y: 5.0))
    }
    
    func testDerivative() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 3.0, y: 2.0))
        XCTAssertEqual(l.derivative(0.23), BKPoint(x: 2.0, y: 1.0))
    }
    
    func testSplitFromTo() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 4.0, y: 7.0))
        let t1: BKFloat = 1.0 / 3.0
        let t2: BKFloat = 2.0 / 3.0
        let s = l.split(from: t1, to: t2)
        XCTAssertEqual(s, LineSegment(p0: BKPoint(x: 2.0, y: 3.0), p1: BKPoint(x: 3.0, y: 5.0)))
    }
    
    func testSplitAt() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 3.0, y: 5.0))
        let (left, right) = l.split(at: 0.5)
        XCTAssertEqual(left, LineSegment(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 2.0, y: 3.0)))
        XCTAssertEqual(right, LineSegment(p0: BKPoint(x: 2.0, y: 3.0), p1: BKPoint(x: 3.0, y: 5.0)))
    }
    
    func testBoundingBox() {
        let l = LineSegment(p0: BKPoint(x: 3.0, y: 5.0), p1: BKPoint(x: 1.0, y: 3.0))
        XCTAssertEqual(l.boundingBox, BoundingBox(min: BKPoint(x: 1.0, y: 3.0), max: BKPoint(x: 3.0, y: 5.0)))
    }
    
    func testCompute() {
        let l = LineSegment(p0: BKPoint(x: 3.0, y: 5.0), p1: BKPoint(x: 1.0, y: 3.0))
        XCTAssertEqual(l.compute(0.0), BKPoint(x: 3.0, y: 5.0))
        XCTAssertEqual(l.compute(0.5), BKPoint(x: 2.0, y: 4.0))
        XCTAssertEqual(l.compute(1.0), BKPoint(x: 1.0, y: 3.0))
    }
    
    func testLength() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 4.0, y: 6.0))
        XCTAssertEqual(l.length(), 5.0)
    }
    
    func testExtrema() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 4.0, y: 6.0))
        let (xyz, values) = l.extrema()
        XCTAssert(xyz.count == 2) // one array for each dimension
        XCTAssertEqual(xyz[0].count, 2)
        XCTAssertEqual(xyz[1].count, 2)
        XCTAssertEqual(values.count, 2) // two extrema total
        XCTAssertEqual(values[0], 0.0)
        XCTAssertEqual(values[1], 1.0)
        XCTAssertEqual(xyz[0][0], 0.0)
        XCTAssertEqual(xyz[0][1], 1.0)
        XCTAssertEqual(xyz[1][0], 0.0)
        XCTAssertEqual(xyz[1][1], 1.0)
    }
    
    func testHull() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 3.0, y: 4.0))
        let h = l.hull(0.5)
        XCTAssert(h.count == 3)
        XCTAssertEqual(h[0], BKPoint(x: 1.0, y: 2.0))
        XCTAssertEqual(h[1], BKPoint(x: 3.0, y: 4.0))
        XCTAssertEqual(h[2], BKPoint(x: 2.0, y: 3.0))
    }
    
    func testNormal() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 5.0, y: 6.0))
        let n1 = l.normal(0.0)
        let n2 = l.normal(0.5)
        let n3 = l.normal(1.0)
        XCTAssertEqual(n1, BKPoint(x: -1.0 / sqrt(2.0), y: 1.0 / sqrt(2.0)))
        XCTAssertEqual(n1, n2)
        XCTAssertEqual(n2, n3)
    }
    
    func testReduce() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 5.0, y: 6.0))
        let r = l.reduce() // reduce should just return the original line back
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].t1, 0.0)
        XCTAssertEqual(r[0].t2, 1.0)
        XCTAssertEqual(r[0].curve, l)
    }
    
//    func testScaleDistance() {
//        // TODO: scale doesn't work with line segments or even higher order curves when they are linear
//        // this is a bug that exists in Bezier.js
//        let l = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 5.0, y: 6.0))
//        let s = l.scale(distance: sqrt(2)) // (moves line up and left by 1,1)
//        XCTAssertEqual(s, LineSegment(p0: BKPoint(x: 0.0, y: 3.0), p1: BKPoint(x: 4.0, y: 7.0)))
//    }

//    TODO: write me ... scale doesn't work for lines
//    func testScaleDistanceFunc {
//        
//    }
    
//    TODO: write me .. offset currently does not work for lines
//    func testOffsetDistance {
//
//    }
    
//    TODO: write me ... offset currently does not work for lines
//    func testOffsetTimeDistance {
//
//    }
    
    func testIntersects() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 5.0, y: 6.0))
        let i = l.intersects()
        XCTAssert(i.count == 0) // lines never self-intersect
    }
    
    // -- MARK: - line-line intersection tests
    
    func testIntersectsLineYesInsideInterval() {
        // a normal line-line intersection that happens in the middle of a line
        let l1 = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 7.0, y: 8.0))
        let l2 = LineSegment(p0: BKPoint(x: 1.0, y: 4.0), p1: BKPoint(x: 5.0, y: 0.0))
        let i = l1.intersects(line: l2)
        XCTAssertEqual(i.count, 1)
        XCTAssertEqual(i[0].t1, 1.0 / 6.0)
        XCTAssertEqual(i[0].t2, 1.0 / 4.0)
    }
    
    func testIntersectsLineNoOutsideInterval1() {
        // two lines that do not intersect because the intersection happens outside the line-segment
        let l1 = LineSegment(p0: BKPoint(x: 1.0, y: 0.0), p1: BKPoint(x: 1.0, y: 2.0))
        let l2 = LineSegment(p0: BKPoint(x: 0.0, y: 2.001), p1: BKPoint(x: 2.0, y: 2.001))
        let i = l1.intersects(line: l2)
        XCTAssertEqual(i.count, 0)
    }
    
    func testIntersectsLineNoOutsideInterval2() {
        // two lines that do not intersect because the intersection happens outside the *other* line segment
        let l1 = LineSegment(p0: BKPoint(x: 1.0, y: 0.0), p1: BKPoint(x: 1.0, y: 2.0))
        let l2 = LineSegment(p0: BKPoint(x: 2.0, y: 1.0), p1: BKPoint(x: 1.001, y: 1.0))
        let i = l1.intersects(line: l2)
        XCTAssertEqual(i.count, 0)
    }
    
    func testIntersectsLineYesEdge1() {
        // two lines that intersect on the 1st line's edge
        let l1 = LineSegment(p0: BKPoint(x: 1.0, y: 0.0), p1: BKPoint(x: 1.0, y: 2.0))
        let l2 = LineSegment(p0: BKPoint(x: 2.0, y: 1.0), p1: BKPoint(x: 1.0, y: 1.0))
        let i = l1.intersects(line: l2)
        XCTAssertEqual(i.count, 1)
        XCTAssertEqual(i[0].t1, 0.5)
        XCTAssertEqual(i[0].t2, 1.0)
    }
    
    func testIntersectsLineYesEdge2() {
        // two lines that intersect on the 2nd line's edge
        let l1 = LineSegment(p0: BKPoint(x: 1.0, y: 0.0), p1: BKPoint(x: 1.0, y: 2.0))
        let l2 = LineSegment(p0: BKPoint(x: 0.0, y: 2.0), p1: BKPoint(x: 2.0, y: 2.0))
        let i = l1.intersects(line: l2)
        XCTAssertEqual(i.count, 1)
        XCTAssertEqual(i[0].t1, 1.0)
        XCTAssertEqual(i[0].t2, 0.5)
    }

    func testIntersectsLineYesLineStart() {
        // two lines that intersect at the start of the first line
        let l1 = LineSegment(p0: BKPoint(x: 1.0, y: 0.0), p1: BKPoint(x: 2.0, y: 1.0))
        let l2 = LineSegment(p0: BKPoint(x: -2.0, y: 2.0), p1: BKPoint(x: 1.0, y: 0.0))
        let i = l1.intersects(line: l2)
        XCTAssertEqual(i.count, 1)
        XCTAssertEqual(i[0].t1, 0.0)
        XCTAssertEqual(i[0].t2, 1.0)
    }
    
    func testIntersectsLineYesLineEnd() {
        // two lines that intersect at the end of the first line
        let l1 = LineSegment(p0: BKPoint(x: 1.0, y: 0.0), p1: BKPoint(x: 2.0, y: 1.0))
        let l2 = LineSegment(p0: BKPoint(x: 2.0, y: 1.0), p1: BKPoint(x: -2.0, y: 2.0))
        let i = l1.intersects(line: l2)
        XCTAssertEqual(i.count, 1)
        XCTAssertEqual(i[0].t1, 1.0)
        XCTAssertEqual(i[0].t2, 0.0)
    }
    
    func testIntersectsLineAsCurve() {
        // ensure that intersects(curve:) calls into the proper implementation
        let l1: LineSegment = LineSegment(p0: BKPoint(x: 0.0, y: 0.0), p1: BKPoint(x: 1.0, y: 1.0))
        let l2: BezierCurve = LineSegment(p0: BKPoint(x: 0.0, y: 1.0), p1: BKPoint(x: 1.0, y: 0.0)) as BezierCurve!
        let i = l1.intersects(curve: l2)
        XCTAssertEqual(i.count, 1)
        XCTAssertEqual(i[0].t1, 0.5)
        XCTAssertEqual(i[0].t2, 0.5)
    }
    
    // -- MARK: - line-curve intersection tests
    
    func testIntersectsQuadratic() {
        // we mostly just care that we call into the proper implementation and that the results are ordered correctly
        // q is a quadratic where y(x) = 2 - 2(x-1)^2
        let epsilon: BKFloat = 0.00001
        let q: QuadraticBezierCurve = QuadraticBezierCurve(start: BKPoint(x: 0.0, y: 0.0),
                                                            end: BKPoint(x: 2.0, y: 0.0),
                                                            mid: BKPoint(x: 1.0, y: 2.0),
                                                                t: 0.5)
        let l1: LineSegment = LineSegment(p0: BKPoint(x: -1.0, y: 1.0), p1: BKPoint(x: 3.0, y: 1.0))
        let l2: LineSegment = LineSegment(p0: BKPoint(x: 3.0, y: 1.0), p1: BKPoint(x: -1.0, y: 1.0)) // same line as l1, but reversed
        // the intersections for both lines occur at x = 1±sqrt(1/2)
        let i1 = l1.intersects(curve: q)
        let r1: BKFloat = 1.0 - sqrt(1.0 / 2.0)
        let r2: BKFloat = 1.0 + sqrt(1.0 / 2.0)
        XCTAssertEqual(i1.count, 2)
        XCTAssertEqual(i1[0].t1, (r1 + 1.0) / 4.0, accuracy: epsilon)
        XCTAssertEqual(i1[0].t2, r1 / 2.0, accuracy: epsilon)
        XCTAssert((l1.compute(i1[0].t1) - q.compute(i1[0].t2)).length < epsilon)
        XCTAssertEqual(i1[1].t1, (r2 + 1.0) / 4.0, accuracy: epsilon)
        XCTAssertEqual(i1[1].t2, r2 / 2.0, accuracy: epsilon)
        XCTAssert((l1.compute(i1[1].t1) - q.compute(i1[1].t2)).length < epsilon)
        // do the same thing as above but using l2
        let i2 = l2.intersects(curve: q)
        XCTAssertEqual(i2.count, 2)
        XCTAssertEqual(i2[0].t1, (r1 + 1.0) / 4.0, accuracy: epsilon)
        XCTAssertEqual(i2[0].t2, r2 / 2.0, accuracy: epsilon)
        XCTAssert((l2.compute(i2[0].t1) - q.compute(i2[0].t2)).length < epsilon)
        XCTAssertEqual(i2[1].t1, (r2 + 1.0) / 4.0, accuracy: epsilon)
        XCTAssertEqual(i2[1].t2, r1 / 2.0, accuracy: epsilon)
        XCTAssert((l2.compute(i2[1].t1) - q.compute(i2[1].t2)).length < epsilon)
    }
    
    func testIntersectsCubic() {
        // we mostly just care that we call into the proper implementation and that the results are ordered correctly
        let epsilon: BKFloat = 0.00001
        let c: CubicBezierCurve = CubicBezierCurve(p0: BKPoint(x: -1, y: 0),
                                                   p1: BKPoint(x: -1, y: 1),
                                                   p2: BKPoint(x:  1, y: -1),
                                                   p3: BKPoint(x:  1, y: 0))
        let l1: LineSegment = LineSegment(p0: BKPoint(x: -2.0, y: 0.0), p1: BKPoint(x: 2.0, y: 0.0))
        let i1 = l1.intersects(curve: c)
      
        XCTAssertEqual(i1.count, 3)
        XCTAssertEqual(i1[0].t1, 0.25, accuracy: epsilon)
        XCTAssertEqual(i1[0].t2, 0.0, accuracy: epsilon)
        XCTAssertEqual(i1[1].t1, 0.5, accuracy: epsilon)
        XCTAssertEqual(i1[1].t2, 0.5, accuracy: epsilon)
        XCTAssertEqual(i1[2].t1, 0.75, accuracy: epsilon)
        XCTAssertEqual(i1[2].t2, 1.0, accuracy: epsilon)
        // l2 is the same line going in the opposite direction
        // by checking this we ensure the intersections are ordered by the line and not the cubic
        let l2: LineSegment = LineSegment(p0: BKPoint(x: 2.0, y: 0.0), p1: BKPoint(x: -2.0, y: 0.0))
        let i2 = l2.intersects(curve: c)
        XCTAssertEqual(i2.count, 3)
        XCTAssertEqual(i2[0].t1, 0.25, accuracy: epsilon)
        XCTAssertEqual(i2[0].t2, 1.0, accuracy: epsilon)
        XCTAssertEqual(i2[1].t1, 0.5, accuracy: epsilon)
        XCTAssertEqual(i2[1].t2, 0.5, accuracy: epsilon)
        XCTAssertEqual(i2[2].t1, 0.75, accuracy: epsilon)
        XCTAssertEqual(i2[2].t2, 0.0, accuracy: epsilon)
    }
        
    func testIntersectsDegenerateCubic1() {
        // a special case where the cubic is degenerate (it can actually be described as a quadratic)
        let epsilon: BKFloat = 0.00001
        let fiveThirds: BKFloat = 5.0 / 3.0
        let sevenThirds: BKFloat = 7.0 / 3.0
        let c: CubicBezierCurve = CubicBezierCurve(p0: BKPoint(x: 1.0, y: 1.0),
                                                   p1: BKPoint(x: fiveThirds, y: fiveThirds),
                                                   p2: BKPoint(x: sevenThirds, y: fiveThirds),
                                                   p3: BKPoint(x: 3.0, y: 1.0))
        let l = LineSegment(p0: BKPoint(x:1.0, y: 1.1), p1: BKPoint(x: 3.0, y: 1.1))
        let i = l.intersects(curve: c)
        XCTAssertEqual(i.count, 2)
        XCTAssert(BezierKitTests.intersections(i, betweenCurve: l, andOtherCurve: c, areWithinTolerance: epsilon))
    }
    
    func testIntersectsDegenerateCubic2() {
        // a special case where the cubic is degenerate (it can actually be described as a line)
        let epsilon: BKFloat = 0.00001
        let c: CubicBezierCurve = CubicBezierCurve(p0: BKPoint(x: 1.0, y: 1.0),
                                                   p1: BKPoint(x: 2.0, y: 2.0),
                                                   p2: BKPoint(x: 3.0, y: 3.0),
                                                   p3: BKPoint(x: 4.0, y: 4.0))
        let l = LineSegment(p0: BKPoint(x:1.0, y: 2.0), p1: BKPoint(x: 4.0, y: 2.0))
        let i = l.intersects(curve: c)
        XCTAssertEqual(i.count, 1)
        XCTAssert(BezierKitTests.intersections(i, betweenCurve: l, andOtherCurve: c, areWithinTolerance: epsilon))
    }

    
    /*
 testOuline
 testOutline2
 testOutline3
 testOutlineShapes
 testOutlinesShapes2
    */

    // MARK: -
    
    func testEquatable() {
        let l1 = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 3.0, y: 4.0))
        let l2 = LineSegment(p0: BKPoint(x: 1.0, y: 3.0), p1: BKPoint(x: 3.0, y: 4.0))
        let l3 = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 3.0, y: 5.0))
        XCTAssertEqual(l1, l1)
        XCTAssertNotEqual(l1, l2)
        XCTAssertNotEqual(l1, l3)
    }
}
