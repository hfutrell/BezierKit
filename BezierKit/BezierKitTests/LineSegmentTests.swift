//
//  LineSegmentTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/14/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

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
        let l = LineSegment(points: [CGPoint(x: 1.0, y: 1.0), CGPoint(x: 3.0, y: 2.0)])
        XCTAssertEqual(l.p0, CGPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(l.p1, CGPoint(x: 3.0, y: 2.0))
        XCTAssertEqual(l.startingPoint, CGPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(l.endingPoint, CGPoint(x: 3.0, y: 2.0))
    }

    func testInitializerIndividualPoints() {
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 3.0, y: 2.0))
        XCTAssertEqual(l.p0, CGPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(l.p1, CGPoint(x: 3.0, y: 2.0))
        XCTAssertEqual(l.startingPoint, CGPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(l.endingPoint, CGPoint(x: 3.0, y: 2.0))
    }

    func testBasicProperties() {
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 2.0, y: 5.0))
        XCTAssert(l.simple)
        XCTAssertEqual(l.order, 1)
        XCTAssertEqual(l.startingPoint, CGPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(l.endingPoint, CGPoint(x: 2.0, y: 5.0))
    }

    func testSetStartEndPoints() {
        var l = LineSegment(p0: CGPoint(x: 5.0, y: 6.0), p1: CGPoint(x: 8.0, y: 7.0))
        l.startingPoint = CGPoint(x: 4.0, y: 5.0)
        XCTAssertEqual(l.p0, l.startingPoint)
        XCTAssertEqual(l.startingPoint, CGPoint(x: 4.0, y: 5.0))
        l.endingPoint = CGPoint(x: 9.0, y: 8.0)
        XCTAssertEqual(l.p1, l.endingPoint)
        XCTAssertEqual(l.endingPoint, CGPoint(x: 9.0, y: 8.0))
    }

    func testDerivative() {
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 3.0, y: 2.0))
        XCTAssertEqual(l.derivative(at: 0.23), CGPoint(x: 2.0, y: 1.0))
    }

    func testSplitFromTo() {
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 4.0, y: 7.0))
        let t1: CGFloat = 1.0 / 3.0
        let t2: CGFloat = 2.0 / 3.0
        let s = l.split(from: t1, to: t2)
        XCTAssertEqual(s, LineSegment(p0: CGPoint(x: 2.0, y: 3.0), p1: CGPoint(x: 3.0, y: 5.0)))
    }

    func testSplitAt() {
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 3.0, y: 5.0))
        let (left, right) = l.split(at: 0.5)
        XCTAssertEqual(left, LineSegment(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 2.0, y: 3.0)))
        XCTAssertEqual(right, LineSegment(p0: CGPoint(x: 2.0, y: 3.0), p1: CGPoint(x: 3.0, y: 5.0)))
    }

    func testBoundingBox() {
        let l = LineSegment(p0: CGPoint(x: 3.0, y: 5.0), p1: CGPoint(x: 1.0, y: 3.0))
        XCTAssertEqual(l.boundingBox, BoundingBox(p1: CGPoint(x: 1.0, y: 3.0), p2: CGPoint(x: 3.0, y: 5.0)))
    }

    func testCompute() {
        let l = LineSegment(p0: CGPoint(x: 3.0, y: 5.0), p1: CGPoint(x: 1.0, y: 3.0))
        XCTAssertEqual(l.point(at: 0.0), CGPoint(x: 3.0, y: 5.0))
        XCTAssertEqual(l.point(at: 0.5), CGPoint(x: 2.0, y: 4.0))
        XCTAssertEqual(l.point(at: 1.0), CGPoint(x: 1.0, y: 3.0))
    }

    func testComputeRealWordIssue() {
        let s = CGPoint(x: 0.30901699437494745, y: 0.9510565162951535)
        let e = CGPoint(x: 0.30901699437494723, y: -0.9510565162951536)
        let l = LineSegment(p0: s, p1: e)
        XCTAssertEqual(l.point(at: 0), s)
        XCTAssertEqual(l.point(at: 1), e) // this failed in practice
    }

    func testLength() {
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 4.0, y: 6.0))
        XCTAssertEqual(l.length(), 5.0)
    }

    func testExtrema() {
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 4.0, y: 6.0))
        let (x, y, all) = l.extrema()
        XCTAssertTrue(x.isEmpty)
        XCTAssertTrue(y.isEmpty)
        XCTAssertTrue(all.isEmpty)
    }

    func testProject() {
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 5.0, y: 6.0))
        let p1 = l.project(CGPoint(x: 0.0, y: 0.0)) // should project to p0
        XCTAssertEqual(p1.point, CGPoint(x: 1.0, y: 2.0))
        XCTAssertEqual(p1.t, 0.0)
        let p2 = l.project(CGPoint(x: 1.0, y: 4.0)) // should project to l.compute(0.25)
        XCTAssertEqual(p2.point, CGPoint(x: 2.0, y: 3.0))
        XCTAssertEqual(p2.t, 0.25)
        let p3 = l.project(CGPoint(x: 6.0, y: 7.0))
        XCTAssertEqual(p3.point, CGPoint(x: 5.0, y: 6.0)) // should project to p1
        XCTAssertEqual(p3.t, 1.0)
    }

    func testHull() {
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 3.0, y: 4.0))
        let h = l.hull(0.5)
        XCTAssert(h.count == 3)
        XCTAssertEqual(h[0], CGPoint(x: 1.0, y: 2.0))
        XCTAssertEqual(h[1], CGPoint(x: 3.0, y: 4.0))
        XCTAssertEqual(h[2], CGPoint(x: 2.0, y: 3.0))
    }

    func testNormal() {
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 5.0, y: 6.0))
        let n1 = l.normal(at: 0.0)
        let n2 = l.normal(at: 0.5)
        let n3 = l.normal(at: 1.0)
        XCTAssertEqual(n1, CGPoint(x: -1.0 / sqrt(2.0), y: 1.0 / sqrt(2.0)))
        XCTAssertEqual(n1, n2)
        XCTAssertEqual(n2, n3)
    }

    func testReduce() {
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 5.0, y: 6.0))
        let r = l.reduce() // reduce should just return the original line back
        XCTAssertTrue(BezierKitTestHelpers.isSatisfactoryReduceResult(r, for: l))
    }

    func testSelfIntersects() {
        let l = LineSegment(p0: CGPoint(x: 3.0, y: 4.0), p1: CGPoint(x: 5.0, y: 6.0))
        XCTAssertFalse(l.selfIntersects()) // lines never self-intersect
    }

    func testSelfIntersections() {
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 5.0, y: 6.0))
        XCTAssert(l.selfIntersections().count == 0) // lines never self-intersect
    }

    // -- MARK: - line-line intersection tests

    func testIntersectionsLineYesInsideInterval() {
        // a normal line-line intersection that happens in the middle of a line
        let l1 = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 7.0, y: 8.0))
        let l2 = LineSegment(p0: CGPoint(x: 1.0, y: 4.0), p1: CGPoint(x: 5.0, y: 0.0))
        let i = l1.intersections(with: l2)
        XCTAssertEqual(i.count, 1)
        XCTAssertEqual(i[0].t1, 1.0 / 6.0)
        XCTAssertEqual(i[0].t2, 1.0 / 4.0)
    }

    func testIntersectionsLineNoOutsideInterval1() {
        // two lines that do not intersect because the intersection happens outside the line-segment
        let l1 = LineSegment(p0: CGPoint(x: 1.0, y: 0.0), p1: CGPoint(x: 1.0, y: 2.0))
        let l2 = LineSegment(p0: CGPoint(x: 0.0, y: 2.001), p1: CGPoint(x: 2.0, y: 2.001))
        let i = l1.intersections(with: l2)
        XCTAssert(i.isEmpty)
    }

    func testIntersectionsLineNoOutsideInterval2() {
        // two lines that do not intersect because the intersection happens outside the *other* line segment
        let l1 = LineSegment(p0: CGPoint(x: 1.0, y: 0.0), p1: CGPoint(x: 1.0, y: 2.0))
        let l2 = LineSegment(p0: CGPoint(x: 2.0, y: 1.0), p1: CGPoint(x: 1.001, y: 1.0))
        let i = l1.intersections(with: l2)
        XCTAssert(i.isEmpty)
    }

    func testIntersectionsLineYesEdge1() {
        // two lines that intersect on the 1st line's edge
        let l1 = LineSegment(p0: CGPoint(x: 1.0, y: 0.0), p1: CGPoint(x: 1.0, y: 2.0))
        let l2 = LineSegment(p0: CGPoint(x: 2.0, y: 1.0), p1: CGPoint(x: 1.0, y: 1.0))
        let i = l1.intersections(with: l2)
        XCTAssertEqual(i.count, 1)
        XCTAssertEqual(i[0].t1, 0.5)
        XCTAssertEqual(i[0].t2, 1.0)
    }

    func testIntersectionsLineYesEdge2() {
        // two lines that intersect on the 2nd line's edge
        let l1 = LineSegment(p0: CGPoint(x: 1.0, y: 0.0), p1: CGPoint(x: 1.0, y: 2.0))
        let l2 = LineSegment(p0: CGPoint(x: 0.0, y: 2.0), p1: CGPoint(x: 2.0, y: 2.0))
        let i = l1.intersections(with: l2)
        XCTAssertEqual(i.count, 1)
        XCTAssertEqual(i[0].t1, 1.0)
        XCTAssertEqual(i[0].t2, 0.5)
    }

    func testIntersectionsLineYesLineStart() {
        // two lines that intersect at the start of the first line
        let l1 = LineSegment(p0: CGPoint(x: 1.0, y: 0.0), p1: CGPoint(x: 2.0, y: 1.0))
        let l2 = LineSegment(p0: CGPoint(x: -2.0, y: 2.0), p1: CGPoint(x: 1.0, y: 0.0))
        let i = l1.intersections(with: l2)
        XCTAssertEqual(i.count, 1)
        XCTAssertEqual(i[0].t1, 0.0)
        XCTAssertEqual(i[0].t2, 1.0)
    }

    func testIntersectionsLineYesLineEnd() {
        // two lines that intersect at the end of the first line
        let l1 = LineSegment(p0: CGPoint(x: 1.0, y: 0.0), p1: CGPoint(x: 2.0, y: 1.0))
        let l2 = LineSegment(p0: CGPoint(x: 2.0, y: 1.0), p1: CGPoint(x: -2.0, y: 2.0))
        let i = l1.intersections(with: l2)
        XCTAssertEqual(i.count, 1)
        XCTAssertEqual(i[0].t1, 1.0)
        XCTAssertEqual(i[0].t2, 0.0)
    }

    func testIntersectionsLineAsCurve() {
        // ensure that intersects(curve:) calls into the proper implementation
        let l1: LineSegment = LineSegment(p0: CGPoint(x: 0.0, y: 0.0), p1: CGPoint(x: 1.0, y: 1.0))
        let l2: BezierCurve = LineSegment(p0: CGPoint(x: 0.0, y: 1.0), p1: CGPoint(x: 1.0, y: 0.0)) as BezierCurve
        let i1 = l1.intersections(with: l2)
        XCTAssertEqual(i1.count, 1)
        XCTAssertEqual(i1[0].t1, 0.5)
        XCTAssertEqual(i1[0].t2, 0.5)

        let i2 = l2.intersections(with: l1)
        XCTAssertEqual(i2.count, 1)
        XCTAssertEqual(i2[0].t1, 0.5)
        XCTAssertEqual(i2[0].t2, 0.5)
    }

    func testIntersectionsLineNoParallel() {

        // this is a special case where determinant is zero
        let l1 = LineSegment(p0: CGPoint(x: -2.0, y: -1.0), p1: CGPoint(x: 2.0, y: 1.0))
        let l2 = LineSegment(p0: CGPoint(x: -4.0, y: -1.0), p1: CGPoint(x: 4.0, y: 3.0))
        let i1 = l1.intersections(with: l2)
        XCTAssertTrue(i1.isEmpty)

        // very, very nearly parallel lines
        let l5 = LineSegment(p0: CGPoint(x: 0.0, y: 0.0), p1: CGPoint(x: 1.0, y: 1.0))
        let l6 = LineSegment(p0: CGPoint(x: 0.0, y: 1.0), p1: CGPoint(x: 1.0, y: 2.0 + 1.0e-15))
        let i3 = l5.intersections(with: l6)
        XCTAssertTrue(i3.isEmpty)
    }

    func testIntersectionsLineYesCoincidentBasic() {
        // coincident in the middle
        let l1 = LineSegment(p0: CGPoint(x: -5.0, y: -5.0), p1: CGPoint(x: 5.0, y: 5.0))
        let l2 = LineSegment(p0: CGPoint(x: -1.0, y: -1.0), p1: CGPoint(x: 1.0, y: 1.0))
        let i1 = l1.intersections(with: l2)
        XCTAssertEqual(i1, [Intersection(t1: 0.4, t2: 0), Intersection(t1: 0.6, t2: 1)])

        // coincident at the start
        let l3 = LineSegment(p0: CGPoint(x: 1, y: 1), p1: CGPoint(x: 3, y: 3))
        let l4 = LineSegment(p0: CGPoint(x: 1, y: 1), p1: CGPoint(x: 2, y: 2))
        let i2 = l3.intersections(with: l4)
        XCTAssertEqual(i2, [Intersection(t1: 0, t2: 0), Intersection(t1: 0.5, t2: 1)])

        // coincident but in opposing directions
        let l5 = LineSegment(p0: CGPoint(x: 1, y: 1), p1: CGPoint(x: 3, y: -1))
        let l6 = LineSegment(p0: CGPoint(x: 3, y: -1), p1: CGPoint(x: 2, y: 0))
        let i3 = l5.intersections(with: l6)
        XCTAssertEqual(i3, [Intersection(t1: 0.5, t2: 1), Intersection(t1: 1, t2: 0)])

        // lines should be fully coincident with themselves
        let l7 = LineSegment(p0: CGPoint(x: 1.863, y: 23.812), p1: CGPoint(x: -4.876, y: 3.652))
        let i4 = l7.intersections(with: l7)
        XCTAssertEqual(i4, [Intersection(t1: 0, t2: 0), Intersection(t1: 1, t2: 1)])
    }

    func testIntersectionsLineYesCoincidentRealWorldData() {
        let l1 = LineSegment(p0: CGPoint(x: 134.76833383678579, y: 95.05360294098101),
                             p1: CGPoint(x: 171.33627533401454, y: 102.89462632327792))
        let l2 = LineSegment(p0: CGPoint(x: 111.2, y: 90.0),
                             p1: CGPoint(x: 171.33627533401454, y: 102.89462632327792))
        let i = l1.intersections(with: l2)
        guard i.count == 2 else {
            XCTAssertTrue(false, "expected two intersections, got: \(i)")
            return
        }
        XCTAssertEqual(i[0].t1, 0)
        XCTAssertEqual(i[0].t2, 0.3919154238582343, accuracy: 1.0e-4)
        XCTAssertEqual(i[1].t1, 1)
        XCTAssertEqual(i[1].t2, 1)
    }

    func testIntersectionsLineNotCoincidentRealWorldData() {
        // in practice due to limitations of precision we can come to the wrong conclusion and think we're coincident over a tiny range (eg t=0.9999999999998739 to t=1)
        let line1 = LineSegment(p0: CGPoint(x: 207.15663697593666, y: 105.38213850350812), p1: CGPoint(x: 203.27567019330237, y: 95.49245438213565))
        let line2 = LineSegment(p0: CGPoint(x: 199.5505907010711, y: 85.41166231873908), p1: CGPoint(x: 203.27567019330286, y: 95.4924543821369))
        XCTAssertEqual(line1.intersections(with: line2), [Intersection(t1: 1, t2: 1)], "lines intersect only at their endpoint")
    }

    // -- MARK: - line-curve intersection tests

    func testIntersectionsQuadratic() {
        // we mostly just care that we call into the proper implementation and that the results are ordered correctly
        // q is a quadratic where y(x) = 2 - 2(x-1)^2
        let epsilon: CGFloat = 0.00001
        let q: QuadraticCurve = QuadraticCurve(start: CGPoint(x: 0.0, y: 0.0),
                                                            end: CGPoint(x: 2.0, y: 0.0),
                                                            mid: CGPoint(x: 1.0, y: 2.0),
                                                                t: 0.5)
        let l1: LineSegment = LineSegment(p0: CGPoint(x: -1.0, y: 1.0), p1: CGPoint(x: 3.0, y: 1.0))
        let l2: LineSegment = LineSegment(p0: CGPoint(x: 3.0, y: 1.0), p1: CGPoint(x: -1.0, y: 1.0)) // same line as l1, but reversed
        // the intersections for both lines occur at x = 1±sqrt(1/2)
        let i1 = l1.intersections(with: q)
        let r1: CGFloat = 1.0 - sqrt(1.0 / 2.0)
        let r2: CGFloat = 1.0 + sqrt(1.0 / 2.0)
        XCTAssertEqual(i1.count, 2)
        XCTAssertEqual(i1[0].t1, (r1 + 1.0) / 4.0, accuracy: epsilon)
        XCTAssertEqual(i1[0].t2, r1 / 2.0, accuracy: epsilon)
        XCTAssert((l1.point(at: i1[0].t1) - q.point(at: i1[0].t2)).length < epsilon)
        XCTAssertEqual(i1[1].t1, (r2 + 1.0) / 4.0, accuracy: epsilon)
        XCTAssertEqual(i1[1].t2, r2 / 2.0, accuracy: epsilon)
        XCTAssert((l1.point(at: i1[1].t1) - q.point(at: i1[1].t2)).length < epsilon)
        // do the same thing as above but using l2
        let i2 = l2.intersections(with: q)
        XCTAssertEqual(i2.count, 2)
        XCTAssertEqual(i2[0].t1, (r1 + 1.0) / 4.0, accuracy: epsilon)
        XCTAssertEqual(i2[0].t2, r2 / 2.0, accuracy: epsilon)
        XCTAssert((l2.point(at: i2[0].t1) - q.point(at: i2[0].t2)).length < epsilon)
        XCTAssertEqual(i2[1].t1, (r2 + 1.0) / 4.0, accuracy: epsilon)
        XCTAssertEqual(i2[1].t2, r1 / 2.0, accuracy: epsilon)
        XCTAssert((l2.point(at: i2[1].t1) - q.point(at: i2[1].t2)).length < epsilon)
    }

    func testIntersectionsQuadraticSpecialCase() {
        // this is case that failed in the real-world
        let l = LineSegment(p0: CGPoint(x: -1, y: 0), p1: CGPoint(x: 1, y: 0))
        let q = QuadraticCurve(p0: CGPoint(x: 0, y: 0), p1: CGPoint(x: -1, y: 0), p2: CGPoint(x: -1, y: 1))
        let i = l.intersections(with: q)
        XCTAssertEqual(i.count, 1)
        XCTAssertEqual(i.first?.t1, 0.5)
        XCTAssertEqual(i.first?.t2, 0)
    }

    func testIntersectionsCubic() {
        // we mostly just care that we call into the proper implementation and that the results are ordered correctly
        let epsilon: CGFloat = 0.00001
        let c: CubicCurve = CubicCurve(p0: CGPoint(x: -1, y: 0),
                                                   p1: CGPoint(x: -1, y: 1),
                                                   p2: CGPoint(x: 1, y: -1),
                                                   p3: CGPoint(x: 1, y: 0))
        let l1: LineSegment = LineSegment(p0: CGPoint(x: -2.0, y: 0.0), p1: CGPoint(x: 2.0, y: 0.0))
        let i1 = l1.intersections(with: c)

        XCTAssertEqual(i1.count, 3)
        XCTAssertEqual(i1[0].t1, 0.25, accuracy: epsilon)
        XCTAssertEqual(i1[0].t2, 0.0, accuracy: epsilon)
        XCTAssertEqual(i1[1].t1, 0.5, accuracy: epsilon)
        XCTAssertEqual(i1[1].t2, 0.5, accuracy: epsilon)
        XCTAssertEqual(i1[2].t1, 0.75, accuracy: epsilon)
        XCTAssertEqual(i1[2].t2, 1.0, accuracy: epsilon)
        // l2 is the same line going in the opposite direction
        // by checking this we ensure the intersections are ordered by the line and not the cubic
        let l2: LineSegment = LineSegment(p0: CGPoint(x: 2.0, y: 0.0), p1: CGPoint(x: -2.0, y: 0.0))
        let i2 = l2.intersections(with: c)
        XCTAssertEqual(i2.count, 3)
        XCTAssertEqual(i2[0].t1, 0.25, accuracy: epsilon)
        XCTAssertEqual(i2[0].t2, 1.0, accuracy: epsilon)
        XCTAssertEqual(i2[1].t1, 0.5, accuracy: epsilon)
        XCTAssertEqual(i2[1].t2, 0.5, accuracy: epsilon)
        XCTAssertEqual(i2[2].t1, 0.75, accuracy: epsilon)
        XCTAssertEqual(i2[2].t2, 0.0, accuracy: epsilon)
    }

    func testIntersectionsCubicRealWorldIssue() {
        guard MemoryLayout<CGFloat>.size > 4 else { return } // not enough precision in points for test to be valid
        // this was an issue because if you round t-values that are near zero you will get
        // cubicCurve.compute(intersections[0].t1).x = 309.5496606404184, which corresponds to t = -3.5242468640577755e-06 on the line (negative! outside the line!)
        let cubicCurve = CubicCurve(p0: CGPoint(x: 301.42017404234923, y: 182.42157189005232),
                                          p1: CGPoint(x: 305.9310607601042, y: 182.30247821176928),
                                          p2: CGPoint(x: 309.72232986751203, y: 185.6785144367646),
                                          p3: CGPoint(x: 310.198127403852, y: 190.08736919846973))
        let line = LineSegment(p0: CGPoint(x: 309.54962994198274, y: 187.61824016482512), p1: CGPoint(x: 275.83899279843945, y: 187.61824016482512))
        XCTAssertFalse(cubicCurve.intersects(line))
    }

    func testIntersectionsDegenerateCubic1() {
        // a special case where the cubic is degenerate (it can actually be described as a quadratic)
        let epsilon: CGFloat = 0.00001
        let fiveThirds: CGFloat = 5.0 / 3.0
        let sevenThirds: CGFloat = 7.0 / 3.0
        let c: CubicCurve = CubicCurve(p0: CGPoint(x: 1.0, y: 1.0),
                                                   p1: CGPoint(x: fiveThirds, y: fiveThirds),
                                                   p2: CGPoint(x: sevenThirds, y: fiveThirds),
                                                   p3: CGPoint(x: 3.0, y: 1.0))
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 1.1), p1: CGPoint(x: 3.0, y: 1.1))
        let i = l.intersections(with: c)
        XCTAssertEqual(i.count, 2)
        XCTAssert(BezierKitTestHelpers.intersections(i, betweenCurve: l, andOtherCurve: c, areWithinTolerance: epsilon))
    }

    func testIntersectionsDegenerateCubic2() {
        // a special case where the cubic is degenerate (it can actually be described as a line)
        let epsilon: CGFloat = 0.00001
        let c: CubicCurve = CubicCurve(p0: CGPoint(x: 1.0, y: 1.0),
                                                   p1: CGPoint(x: 2.0, y: 2.0),
                                                   p2: CGPoint(x: 3.0, y: 3.0),
                                                   p3: CGPoint(x: 4.0, y: 4.0))
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 4.0, y: 2.0))
        let i = l.intersections(with: c)
        XCTAssertEqual(i.count, 1)
        XCTAssert(BezierKitTestHelpers.intersections(i, betweenCurve: l, andOtherCurve: c, areWithinTolerance: epsilon))
    }

    func testIntersectionsCubicSpecialCase() {
        // this is case that failed in the real-world
        let l = LineSegment(p0: CGPoint(x: -1, y: 0), p1: CGPoint(x: 1, y: 0))
        let q = CubicCurve(quadratic: QuadraticCurve(p0: CGPoint(x: 0, y: 0), p1: CGPoint(x: -1, y: 0), p2: CGPoint(x: -1, y: 1)))
        let i = l.intersections(with: q)
        XCTAssertEqual(i.count, 1)
        XCTAssertEqual(i.first?.t1, 0.5)
        XCTAssertEqual(i.first?.t2, 0)
    }

    func testIntersectionsCubicRootsEdgeCase1() {
        // this data caused issues in practice because because 'd' in the roots calculation is very near, but not exactly, zero.
        let c = CubicCurve(p0: CGPoint(x: 201.48419096574196, y: 570.7720830272123),
                                 p1: CGPoint(x: 202.27135851996428, y: 570.7720830272123),
                                 p2: CGPoint(x: 202.90948390468964, y: 571.4102084119377),
                                 p3: CGPoint(x: 202.90948390468964, y: 572.1973759661599))
        let l = LineSegment(p0: CGPoint(x: 200.05889802679428, y: 572.1973759661599), p1: CGPoint(x: 201.48419096574196, y: 573.6226689051076))
        let i = l.intersections(with: c)
        XCTAssertEqual(i, [])
    }

    func testIntersectionsCubicRootsEdgeCase2() {
        guard MemoryLayout<CGFloat>.size > 4 else { return } // not enough precision in points for test to be valid
        // this data caused issues in practice because because the discriminant in the roots calculation is very near zero
        let line = LineSegment(p0: CGPoint(x: 503.31162501468725, y: 766.9016671863201),
                               p1: CGPoint(x: 504.2124710211739, y: 767.3358059574488))
        let curve = CubicCurve(p0: CGPoint(x: 505.16132944417086, y: 779.6305912206088),
                                     p1: CGPoint(x: 503.19076843492786, y: 767.0872665416827),
                                     p2: CGPoint(x: 503.3761460381431, y: 766.7563954079359),
                                     p3: CGPoint(x: 503.3060153966664, y: 766.9140612367046))
        let i = line.intersections(with: curve)
        XCTAssertEqual(i.count, 2)
        i.forEach {
            let d = distance(line.point(at: $0.t1), curve.point(at: $0.t2))
            XCTAssertTrue(d < 1.0e-4, "distance line.compute(\($0.t1)) to curve.compute(\($0.t2)) = \(d)")
        }
    }

    func testIntersectionsCubicDegenerate() {
        // this data caused issues in practice because because Utils.align would give an angle of zero for degenerate lines
        let c = CubicCurve(p0: CGPoint(x: -1, y: 1),
                                 p1: CGPoint(x: 0, y: -1),
                                 p2: CGPoint(x: 1, y: -1),
                                 p3: CGPoint(x: 2, y: 1))
        let l = LineSegment(p0: CGPoint(x: -1, y: 0), p1: CGPoint(x: -1, y: 0))
        let i = l.intersections(with: c)
        XCTAssertEqual(i, [])
    }

    // MARK: -

    func testEquatable() {
        let l1 = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 3.0, y: 4.0))
        let l2 = LineSegment(p0: CGPoint(x: 1.0, y: 3.0), p1: CGPoint(x: 3.0, y: 4.0))
        let l3 = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 3.0, y: 5.0))
        XCTAssertEqual(l1, l1)
        XCTAssertNotEqual(l1, l2)
        XCTAssertNotEqual(l1, l3)
    }
}
