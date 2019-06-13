//
//  BezierCurveTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 12/31/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class BezierCurveTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testEquality() {
        // two lines that are equal
        let l1: BezierCurve = LineSegment(p0: CGPoint(x: 0, y: 1), p1: CGPoint(x: 2, y: 1))
        let l2: BezierCurve = LineSegment(p0: CGPoint(x: 0, y: 1), p1: CGPoint(x: 2, y: 1))
        XCTAssert(l1 == l2)

        // a line that isn't equal
        let l3: BezierCurve = LineSegment(p0: CGPoint(x: 0, y: 1), p1: CGPoint(x: 2, y: 2))
        XCTAssertFalse(l1 == l3)

        // a quadratic made from l1, different order, not equal!
        let q1: BezierCurve = QuadraticBezierCurve(lineSegment: l1 as! LineSegment)
        XCTAssertFalse(l1 == q1)
    }

    func testScaleDistance() {
        // line segment
        let epsilon: CGFloat = 1.0e-5
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 5.0, y: 6.0))
        let ls = l.scale(distance: sqrt(2)) // (moves line up and left by 1,1)
        let expectedLine = LineSegment(p0: CGPoint(x: 0.0, y: 3.0), p1: CGPoint(x: 4.0, y: 7.0))
        XCTAssert(BezierKitTestHelpers.curveControlPointsEqual(curve1: ls, curve2: expectedLine, tolerance: epsilon))
        // quadratic
        let q = QuadraticBezierCurve(p0: CGPoint(x: 1.0, y: 1.0),
                                     p1: CGPoint(x: 2.0, y: 2.0),
                                     p2: CGPoint(x: 3.0, y: 1.0))
        let qs = q.scale(distance: sqrt(2))
        let expectedQuadratic = QuadraticBezierCurve(p0: CGPoint(x: 0.0, y: 2.0),
                                                p1: CGPoint(x: 2.0, y: 4.0),
                                                p2: CGPoint(x: 4.0, y: 2.0))
        XCTAssert(BezierKitTestHelpers.curveControlPointsEqual(curve1: qs, curve2: expectedQuadratic, tolerance: epsilon))
        // cubic
        let c = CubicBezierCurve(p0: CGPoint(x: -4.0, y: +0.0),
                                 p1: CGPoint(x: -2.0, y: +2.0),
                                 p2: CGPoint(x: +2.0, y: +2.0),
                                 p3: CGPoint(x: +4.0, y: +0.0))
        let cs = c.scale(distance: 2.0 * sqrt(2))
        let expectedCubic = CubicBezierCurve(p0: CGPoint(x: -6.0, y: +2.0),
                                p1: CGPoint(x: -3.0, y: +5.0),
                                p2: CGPoint(x: +3.0, y: +5.0),
                                p3: CGPoint(x: +6.0, y: +2.0))
        XCTAssert(BezierKitTestHelpers.curveControlPointsEqual(curve1: cs, curve2: expectedCubic, tolerance: epsilon))

        // ensure that scaling a cubic initialized from a line yields the same thing as the line
        let cFromLine = CubicBezierCurve(lineSegment: l)
        XCTAssert(BezierKitTestHelpers.curveControlPointsEqual(curve1: cFromLine.scale(distance: sqrt(2)), curve2: CubicBezierCurve(lineSegment: expectedLine), tolerance: epsilon))

        // ensure scaling a quadratic from a line yields the same thing as the line
        let qFromLine = QuadraticBezierCurve(lineSegment: l)
        XCTAssert(BezierKitTestHelpers.curveControlPointsEqual(curve1: qFromLine.scale(distance: sqrt(2)),
                                                               curve2: QuadraticBezierCurve(lineSegment: expectedLine),
                                                               tolerance: epsilon))
    }

    func testScaleDistanceEdgeCase() {
        let a = CGPoint(x: 0, y: 0)
        let b = CGPoint(x: 1, y: 0)
        let cubic = CubicBezierCurve(p0: a, p1: a, p2: b, p3: b)
        let result = cubic.scale(distance: 1)
        let offset = CGPoint(x: 0, y: 1)
        let aOffset = a + offset
        let bOffset = b + offset
        let expectedResult = CubicBezierCurve(p0: aOffset, p1: aOffset, p2: bOffset, p3: bOffset)
        XCTAssertEqual(result, expectedResult)
    }

    func testOffsetDistance() {
        // line segments (or isLinear) have a separate codepath, so be sure to test those
        let epsilon: CGFloat = 1.0e-6
        let c1 = CubicBezierCurve(lineSegment: LineSegment(p0: CGPoint(x: 0.0, y: 0.0), p1: CGPoint(x: 1.0, y: 1.0)))
        let c1Offset = c1.offset(distance: sqrt(2))
        let expectedOffset1 = CubicBezierCurve(lineSegment: LineSegment(p0: CGPoint(x: -1.0, y: 1.0), p1: CGPoint(x: 0.0, y: 2.0)))
        XCTAssertEqual(c1Offset.count, 1)
        XCTAssert(BezierKitTestHelpers.curveControlPointsEqual(curve1: c1Offset[0] as! CubicBezierCurve, curve2: expectedOffset1, tolerance: epsilon))
        // next test a non-simple curve
        let c2 = CubicBezierCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 2.0, y: 2.0), p2: CGPoint(x: 3.0, y: 2.0), p3: CGPoint(x: 4.0, y: 1.0))
        let c2Offset = c2.offset(distance: sqrt(2))
        for i in 0..<c2Offset.count {
            let c = c2Offset[i]
            XCTAssert(c.simple)
            if i == 0 {
                // segment starts where un-reduced segment started (after ofsetting)
                XCTAssert(distance(c.startingPoint, CGPoint(x: 0.0, y: 2.0)) < epsilon)
            } else {
                // segment starts where last ended
                XCTAssertEqual(c.startingPoint, c2Offset[i-1].endingPoint)
            }
            if i == c2Offset.count - 1 {
                // segment ends where un-reduced segment ended (after ofsetting)
                XCTAssert(distance(c.endingPoint, CGPoint(x: 5.0, y: 2.0)) < epsilon)
            }
        }
    }

    func testOffsetTimeDistance() {
        let epsilon: CGFloat = 1.0e-6
        let q = QuadraticBezierCurve(p0: CGPoint(x: 1.0, y: 1.0),
                                     p1: CGPoint(x: 2.0, y: 2.0),
                                     p2: CGPoint(x: 3.0, y: 1.0))
        let p0 = q.offset(t: 0.0, distance: sqrt(2))
        let p1 = q.offset(t: 0.5, distance: 1.5)
        let p2 = q.offset(t: 1.0, distance: sqrt(2))
        XCTAssert(distance(p0, CGPoint(x: 0.0, y: 2.0)) < epsilon)
        XCTAssert(distance(p1, CGPoint(x: 2.0, y: 3.0)) < epsilon)
        XCTAssert(distance(p2, CGPoint(x: 4.0, y: 2.0)) < epsilon)
    }

    func testProject() {
        // line segments override the project implementation, so test them specifically
        let epsilon: CGFloat = 2.0e-4
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 5.0, y: 6.0))
        let p1 = l.project(CGPoint(x: 0.0, y: 0.0)) // should project to p0
        XCTAssertEqual(p1.point, CGPoint(x: 1.0, y: 2.0))
        XCTAssertEqual(p1.t, 0.0)
        let p2 = l.project(CGPoint(x: 1.0, y: 4.0), accuracy: epsilon) // should project to l.compute(0.25)
        XCTAssertEqual(p2.point, CGPoint(x: 2.0, y: 3.0))
        XCTAssertEqual(p2.t, 0.25)
        let p3 = l.project(CGPoint(x: 6.0, y: 7.0))
        XCTAssertEqual(p3.point, CGPoint(x: 5.0, y: 6.0)) // should project to p1
        XCTAssertEqual(p3.t, 1.0)
        // test a cubic
        let c = CubicBezierCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 2.0, y: 2.0), p2: CGPoint(x: 4.0, y: 2.0), p3: CGPoint(x: 5.0, y: 1.0))
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
        let pointToProject = c.compute(t) + c.normal(t)
        let expectedAnswer = c.compute(t)
        let p7 = c.project(pointToProject, accuracy: epsilon) // should project back to (roughly) c.compute(0.831211)
        XCTAssert(distance(p7.point, expectedAnswer) < epsilon)
        XCTAssert(abs(p7.t - t) < epsilon)
    }

    static let lineSegmentForOutlining = LineSegment(p0: CGPoint(x: -10, y: -5), p1: CGPoint(x: 20, y: 10))

    private func lineOffsets(_ lineSegment: LineSegment, _ d1: CGFloat, _ d2: CGFloat, _ d3: CGFloat, _ d4: CGFloat) -> (CGPoint, CGPoint, CGPoint, CGPoint) {
        let o0 = lineSegment.startingPoint + d1 * lineSegment.normal(0)
        let o1 = lineSegment.endingPoint + d3 * lineSegment.normal(1)
        let o2 = lineSegment.endingPoint - d4 * lineSegment.normal(1)
        let o3 = lineSegment.startingPoint - d2 * lineSegment.normal(0)
        return (o0, o1, o2, o3)
    }

    func testOutlineDistance() {
        // When only one distance value is given, the outline is generated at distance d on both the normal and anti-normal
        let lineSegment = BezierCurveTests.lineSegmentForOutlining
        let outline: PathComponent = lineSegment.outline(distance: 1)
        XCTAssertEqual(outline.elementCount, 4)

        let (o0, o1, o2, o3) = lineOffsets(lineSegment, 1, 1, 1, 1)

        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 0), matchesCurve: LineSegment(p0: o3, p1: o0)))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 1), matchesCurve: LineSegment(p0: o0, p1: o1)))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 2), matchesCurve: LineSegment(p0: o1, p1: o2)))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 3), matchesCurve: LineSegment(p0: o2, p1: o3)))
    }

    func testOutlineDistanceAlongNormalDistanceOppositeNormal() {
        //  If two distance values are given, the outline is generated at distance d1 on along the normal, and d2 along the anti-normal.
        let lineSegment = BezierCurveTests.lineSegmentForOutlining
        let distanceAlongNormal: CGFloat = 1
        let distanceOppositeNormal: CGFloat = 2
        let outline: PathComponent = lineSegment.outline(distanceAlongNormal: distanceAlongNormal, distanceOppositeNormal: distanceOppositeNormal)
        XCTAssertEqual(outline.elementCount, 4)

        let o0 = lineSegment.startingPoint + distanceAlongNormal * lineSegment.normal(0)
        let o1 = lineSegment.endingPoint + distanceAlongNormal * lineSegment.normal(1)
        let o2 = lineSegment.endingPoint - distanceOppositeNormal * lineSegment.normal(1)
        let o3 = lineSegment.startingPoint - distanceOppositeNormal * lineSegment.normal(0)

        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 0), matchesCurve: LineSegment(p0: o3, p1: o0)))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 1), matchesCurve: LineSegment(p0: o0, p1: o1)))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 2), matchesCurve: LineSegment(p0: o1, p1: o2)))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 3), matchesCurve: LineSegment(p0: o2, p1: o3)))
    }

    func testOutlineFourArguments() {
        // Graduated offsetting is achieved by using four distances measures, where d1 is the initial offset along the normal, d2 the initial distance along the anti-normal, d3 the final offset along the normal, and d4 the final offset along the anti-normal.
        let lineSegment = BezierCurveTests.lineSegmentForOutlining
        let distanceAlongNormal1: CGFloat = 2
        let distanceOppositeNormal1: CGFloat = 4
        let distanceAlongNormal2: CGFloat = 1
        let distanceOppositeNormal2: CGFloat = 2

        let outline: PathComponent = lineSegment.outline(distanceAlongNormalStart: distanceAlongNormal1,
                                                      distanceOppositeNormalStart: distanceOppositeNormal1,
                                                      distanceAlongNormalEnd: distanceAlongNormal2,
                                                      distanceOppositeNormalEnd: distanceOppositeNormal2)

        XCTAssertEqual(outline.elementCount, 4)

        let (o0, o1, o2, o3) = lineOffsets(lineSegment, distanceAlongNormal1, distanceOppositeNormal1, distanceAlongNormal2, distanceOppositeNormal2)

        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 0), matchesCurve: LineSegment(p0: o3, p1: o0)))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 1), matchesCurve: LineSegment(p0: o0, p1: o1)))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 2), matchesCurve: LineSegment(p0: o1, p1: o2)))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 3), matchesCurve: LineSegment(p0: o2, p1: o3)))
    }

    func testOutlineFourArgumentsQuadratic() {
        // we need this special test for quadratics for two reasons:
        // 1. scale has a special case for linear
        // 2. quadratics are upgrade in the outline function (why?)

        let q = QuadraticBezierCurve(p0: CGPoint(x: 0.0, y: 0.0), p1: CGPoint(x: 9.0, y: 11.0), p2: CGPoint(x: 20.0, y: 20.0))
        let outline: PathComponent = q.outline(distanceAlongNormalStart: sqrt(2),
                                               distanceOppositeNormalStart: sqrt(2),
                                               distanceAlongNormalEnd: 2 * sqrt(2),
                                               distanceOppositeNormalEnd: 2 * sqrt(2))

        let expectedSegment1 = LineSegment(p0: CGPoint(x: 1, y: -1), p1: CGPoint(x: -1, y: 1))
        let expectedSegment2 = QuadraticBezierCurve(p0: CGPoint(x: -1, y: 1), p1: CGPoint(x: 7.5, y: 12.5), p2: CGPoint(x: 18, y: 22))
        let expectedSegment3 = LineSegment(p0: CGPoint(x: 18, y: 22), p1: CGPoint(x: 22, y: 18))
        let expectedSegment4 = QuadraticBezierCurve(p0: CGPoint(x: 22, y: 18), p1: CGPoint(x: 10.5, y: 9.5), p2: CGPoint(x: 1, y: -1))

        XCTAssertEqual(outline.elementCount, 4)
        // hard to compute this outline exactly, so just check the computed value roughly equals our estimate of what it should be
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 0), matchesCurve: expectedSegment1, tolerance: 0.33 ))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 1), matchesCurve: expectedSegment2, tolerance: 0.33 ))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 2), matchesCurve: expectedSegment3, tolerance: 0.33 ))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 3), matchesCurve: expectedSegment4, tolerance: 0.33 ))
    }

    func testOutlineQuadraticNormalsParallel() {
        // this tests a special corner case of outlines where endpoint normals are parallel

        let q = QuadraticBezierCurve(p0: CGPoint(x: 0.0, y: 0.0), p1: CGPoint(x: 5.0, y: 0.0), p2: CGPoint(x: 10.0, y: 0.0))
        let outline: PathComponent = q.outline(distance: 1)

        let expectedSegment1 = LineSegment(p0: CGPoint(x: 0, y: -1), p1: CGPoint(x: 0, y: 1))
        let expectedSegment2 = LineSegment(p0: CGPoint(x: 0, y: 1), p1: CGPoint(x: 10, y: 1))
        let expectedSegment3 = LineSegment(p0: CGPoint(x: 10, y: 1), p1: CGPoint(x: 10, y: -1))
        let expectedSegment4 = LineSegment(p0: CGPoint(x: 10, y: -1), p1: CGPoint(x: 0, y: -1))

        XCTAssertEqual(outline.elementCount, 4)
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 0), matchesCurve: expectedSegment1 ))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 1), matchesCurve: expectedSegment2 ))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 2), matchesCurve: expectedSegment3 ))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 3), matchesCurve: expectedSegment4 ))
    }

    func testOutlineFourArgumentsQuadraticNormalsParallel() {
        // this tests a special corner case of tapered outlines where endpoint normals are parallel

        let q = QuadraticBezierCurve(p0: CGPoint(x: 0.0, y: 0.0), p1: CGPoint(x: 10.0, y: 0.0), p2: CGPoint(x: 20.0, y: 0.0))
        let outline: PathComponent = q.outline(distanceAlongNormalStart: 2, distanceOppositeNormalStart: 2, distanceAlongNormalEnd: 1, distanceOppositeNormalEnd: 1)

        let expectedSegment1 = LineSegment(p0: CGPoint(x: 0.0, y: -2.0), p1: CGPoint(x: 0.0, y: 2.0))
        let expectedSegment2 = LineSegment(p0: CGPoint(x: 0.0, y: 2.0), p1: CGPoint(x: 20.0, y: 1.0))
        let expectedSegment3 = LineSegment(p0: CGPoint(x: 20.0, y: 1.0), p1: CGPoint(x: 20.0, y: -1.0))
        let expectedSegment4 = LineSegment(p0: CGPoint(x: 20.0, y: -1.0), p1: CGPoint(x: 0.0, y: -2.0))

        XCTAssertEqual(outline.elementCount, 4)
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 0), matchesCurve: expectedSegment1 ))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 1), matchesCurve: expectedSegment2 ))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 2), matchesCurve: expectedSegment3 ))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 3), matchesCurve: expectedSegment4 ))
    }

    func testOutlineShapesDistance() {
        let lineSegment = BezierCurveTests.lineSegmentForOutlining
        let distanceAlongNormal: CGFloat = 1
        let shapes: [Shape] = lineSegment.outlineShapes(distance: distanceAlongNormal)
        XCTAssertEqual(shapes.count, 1)
        let (o0, o1, o2, o3) = lineOffsets(lineSegment, distanceAlongNormal, distanceAlongNormal, distanceAlongNormal, distanceAlongNormal)
        let expectedShape = Shape(LineSegment(p0: o0, p1: o1), LineSegment(p0: o2, p1: o3), false, false) // shape made from lines with real (non-virtual) caps
        XCTAssertTrue( BezierKitTestHelpers.shape(shapes[0], matchesShape: expectedShape) )
    }

    func testOutlineShapesDistanceAlongNormalDistanceOppositeNormal() {
        let lineSegment = BezierCurveTests.lineSegmentForOutlining
        let distanceAlongNormal: CGFloat = 1
        let distanceOppositeNormal: CGFloat = 2
        let shapes: [Shape] = lineSegment.outlineShapes(distanceAlongNormal: distanceAlongNormal, distanceOppositeNormal: distanceOppositeNormal)
        XCTAssertEqual(shapes.count, 1)
        let (o0, o1, o2, o3) = lineOffsets(lineSegment, distanceAlongNormal, distanceOppositeNormal, distanceAlongNormal, distanceOppositeNormal)
        let expectedShape = Shape(LineSegment(p0: o0, p1: o1), LineSegment(p0: o2, p1: o3), false, false) // shape made from lines with real (non-virtual) caps
        XCTAssertTrue( BezierKitTestHelpers.shape(shapes[0], matchesShape: expectedShape) )
    }

    func testCubicCubicIntersectionEndpoints() {
        // these two cubics intersect only at the endpoints
        let epsilon: CGFloat = 1.0e-3
        let cubic1 = CubicBezierCurve(p0: CGPoint(x: 0.0, y: 0.0),
                                      p1: CGPoint(x: 1.0, y: 1.0),
                                      p2: CGPoint(x: 2.0, y: 1.0),
                                      p3: CGPoint(x: 3.0, y: 0.0))
        let cubic2 = CubicBezierCurve(p0: CGPoint(x: 3.0, y: 0.0),
                                      p1: CGPoint(x: 2.0, y: -1.0),
                                      p2: CGPoint(x: 1.0, y: -1.0),
                                      p3: CGPoint(x: 0.0, y: 0.0))
        let i = cubic1.intersections(with: cubic2, accuracy: epsilon)
        XCTAssertEqual(i.count, 2, "start and end points should intersect!")
        XCTAssertEqual(i[0].t1, 0.0)
        XCTAssertEqual(i[0].t2, 1.0)
        XCTAssertEqual(i[1].t1, 1.0)
        XCTAssertEqual(i[1].t2, 0.0)
    }

    func testCubicSelfIntersection() {
        let epsilon: CGFloat = 1.0e-3
        let curve = CubicBezierCurve(p0: CGPoint(x: 0.0, y: 0.0),
                                     p1: CGPoint(x: 2.0, y: 1.0),
                                     p2: CGPoint(x: -1.0, y: 1.0),
                                     p3: CGPoint(x: 1.0, y: 0.0))
        let i = curve.selfIntersections(accuracy: epsilon)
        XCTAssertEqual(i.count, 1, "wrong number of intersections!")
        XCTAssert( distance(curve.compute(i[0].t1), curve.compute(i[0].t2)) < epsilon, "wrong or inaccurate intersection!" )
    }
}
