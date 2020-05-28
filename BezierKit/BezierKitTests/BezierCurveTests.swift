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
        let q1: BezierCurve = QuadraticCurve(lineSegment: l1 as! LineSegment)
        XCTAssertFalse(l1 == q1)
    }

    func testScaleDistance() {
        // line segment
        let epsilon: CGFloat = 1.0e-5
        let l = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 5.0, y: 6.0))
        let ls = l.scale(distance: sqrt(2))! // (moves line up and left by 1,1)
        let expectedLine = LineSegment(p0: CGPoint(x: 0.0, y: 3.0), p1: CGPoint(x: 4.0, y: 7.0))
        XCTAssert(BezierKitTestHelpers.curveControlPointsEqual(curve1: ls, curve2: expectedLine, tolerance: epsilon))
        // quadratic
        let q = QuadraticCurve(p0: CGPoint(x: 1.0, y: 1.0),
                                     p1: CGPoint(x: 2.0, y: 2.0),
                                     p2: CGPoint(x: 3.0, y: 1.0))
        let qs = q.scale(distance: sqrt(2))!
        let expectedQuadratic = QuadraticCurve(p0: CGPoint(x: 0.0, y: 2.0),
                                                p1: CGPoint(x: 2.0, y: 4.0),
                                                p2: CGPoint(x: 4.0, y: 2.0))
        XCTAssert(BezierKitTestHelpers.curveControlPointsEqual(curve1: qs, curve2: expectedQuadratic, tolerance: epsilon))
        // cubic
        let c = CubicCurve(p0: CGPoint(x: -4.0, y: +0.0),
                                 p1: CGPoint(x: -2.0, y: +2.0),
                                 p2: CGPoint(x: +2.0, y: +2.0),
                                 p3: CGPoint(x: +4.0, y: +0.0))
        let cs = c.scale(distance: 2.0 * sqrt(2))!
        let expectedCubic = CubicCurve(p0: CGPoint(x: -6.0, y: +2.0),
                                p1: CGPoint(x: -3.0, y: +5.0),
                                p2: CGPoint(x: +3.0, y: +5.0),
                                p3: CGPoint(x: +6.0, y: +2.0))
        XCTAssert(BezierKitTestHelpers.curveControlPointsEqual(curve1: cs, curve2: expectedCubic, tolerance: epsilon))

        // ensure that scaling a cubic initialized from a line yields the same thing as the line
        let cFromLine = CubicCurve(lineSegment: l)
        XCTAssert(BezierKitTestHelpers.curveControlPointsEqual(curve1: cFromLine.scale(distance: sqrt(2))!, curve2: CubicCurve(lineSegment: expectedLine), tolerance: epsilon))

        // ensure scaling a quadratic from a line yields the same thing as the line
        let qFromLine = QuadraticCurve(lineSegment: l)
        XCTAssert(BezierKitTestHelpers.curveControlPointsEqual(curve1: qFromLine.scale(distance: sqrt(2))!,
                                                               curve2: QuadraticCurve(lineSegment: expectedLine),
                                                               tolerance: epsilon))
    }

    func testScaleDistanceDegenerate() {
        let p = CGPoint(x: 3.14159, y: 2.71828)
        let curve = CubicCurve(p0: p, p1: p, p2: p, p3: p)
        XCTAssertNil(curve.scale(distance: 2))
    }

    func testScaleDistanceEdgeCase() {
        let a = CGPoint(x: 0, y: 0)
        let b = CGPoint(x: 1, y: 0)
        let cubic = CubicCurve(p0: a, p1: a, p2: b, p3: b)
        let result = cubic.scale(distance: 1)
        let offset = CGPoint(x: 0, y: 1)
        let aOffset = a + offset
        let bOffset = b + offset
        let expectedResult = CubicCurve(p0: aOffset, p1: aOffset, p2: bOffset, p3: bOffset)
        XCTAssertEqual(result, expectedResult)
    }

    func testOffsetDistance() {
        // line segments (or isLinear) have a separate codepath, so be sure to test those
        let epsilon: CGFloat = 1.0e-6
        let c1 = CubicCurve(lineSegment: LineSegment(p0: CGPoint(x: 0.0, y: 0.0), p1: CGPoint(x: 1.0, y: 1.0)))
        let c1Offset = c1.offset(distance: sqrt(2))
        let expectedOffset1 = CubicCurve(lineSegment: LineSegment(p0: CGPoint(x: -1.0, y: 1.0), p1: CGPoint(x: 0.0, y: 2.0)))
        XCTAssertEqual(c1Offset.count, 1)
        XCTAssert(BezierKitTestHelpers.curveControlPointsEqual(curve1: c1Offset[0] as! CubicCurve, curve2: expectedOffset1, tolerance: epsilon))
        // next test a non-simple curve
        let c2 = CubicCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 2.0, y: 2.0), p2: CGPoint(x: 3.0, y: 2.0), p3: CGPoint(x: 4.0, y: 1.0))
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
        let q = QuadraticCurve(p0: CGPoint(x: 1.0, y: 1.0),
                                     p1: CGPoint(x: 2.0, y: 2.0),
                                     p2: CGPoint(x: 3.0, y: 1.0))
        let p0 = q.offset(t: 0.0, distance: sqrt(2))
        let p1 = q.offset(t: 0.5, distance: 1.5)
        let p2 = q.offset(t: 1.0, distance: sqrt(2))
        XCTAssert(distance(p0, CGPoint(x: 0.0, y: 2.0)) < epsilon)
        XCTAssert(distance(p1, CGPoint(x: 2.0, y: 3.0)) < epsilon)
        XCTAssert(distance(p2, CGPoint(x: 4.0, y: 2.0)) < epsilon)
    }

    static let lineSegmentForOutlining = LineSegment(p0: CGPoint(x: -10, y: -5), p1: CGPoint(x: 20, y: 10))

    // swiftlint:disable large_tuple
    private func lineOffsets(_ lineSegment: LineSegment, _ d1: CGFloat, _ d2: CGFloat, _ d3: CGFloat, _ d4: CGFloat) -> (CGPoint, CGPoint, CGPoint, CGPoint) {
        let o0 = lineSegment.startingPoint + d1 * lineSegment.normal(at: 0)
        let o1 = lineSegment.endingPoint + d3 * lineSegment.normal(at: 1)
        let o2 = lineSegment.endingPoint - d4 * lineSegment.normal(at: 1)
        let o3 = lineSegment.startingPoint - d2 * lineSegment.normal(at: 0)
        return (o0, o1, o2, o3)
    }
    // swiftlint:enable large_tuple

    func testOutlineDistance() {
        // When only one distance value is given, the outline is generated at distance d on both the normal and anti-normal
        let lineSegment = BezierCurveTests.lineSegmentForOutlining
        let outline: PathComponent = lineSegment.outline(distance: 1)
        XCTAssertEqual(outline.numberOfElements, 4)

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
        XCTAssertEqual(outline.numberOfElements, 4)

        let o0 = lineSegment.startingPoint + distanceAlongNormal * lineSegment.normal(at: 0)
        let o1 = lineSegment.endingPoint + distanceAlongNormal * lineSegment.normal(at: 1)
        let o2 = lineSegment.endingPoint - distanceOppositeNormal * lineSegment.normal(at: 1)
        let o3 = lineSegment.startingPoint - distanceOppositeNormal * lineSegment.normal(at: 0)

        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 0), matchesCurve: LineSegment(p0: o3, p1: o0)))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 1), matchesCurve: LineSegment(p0: o0, p1: o1)))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 2), matchesCurve: LineSegment(p0: o1, p1: o2)))
        XCTAssert( BezierKitTestHelpers.curve(outline.element(at: 3), matchesCurve: LineSegment(p0: o2, p1: o3)))
    }

    func testOutlineQuadraticNormalsParallel() {
        // this tests a special corner case of outlines where endpoint normals are parallel

        let q = QuadraticCurve(p0: CGPoint(x: 0.0, y: 0.0), p1: CGPoint(x: 5.0, y: 0.0), p2: CGPoint(x: 10.0, y: 0.0))
        let outline: PathComponent = q.outline(distance: 1)

        let expectedSegment1 = LineSegment(p0: CGPoint(x: 0, y: -1), p1: CGPoint(x: 0, y: 1))
        let expectedSegment2 = LineSegment(p0: CGPoint(x: 0, y: 1), p1: CGPoint(x: 10, y: 1))
        let expectedSegment3 = LineSegment(p0: CGPoint(x: 10, y: 1), p1: CGPoint(x: 10, y: -1))
        let expectedSegment4 = LineSegment(p0: CGPoint(x: 10, y: -1), p1: CGPoint(x: 0, y: -1))

        XCTAssertEqual(outline.numberOfElements, 4)
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
        let cubic1 = CubicCurve(p0: CGPoint(x: 0.0, y: 0.0),
                                      p1: CGPoint(x: 1.0, y: 1.0),
                                      p2: CGPoint(x: 2.0, y: 1.0),
                                      p3: CGPoint(x: 3.0, y: 0.0))
        let cubic2 = CubicCurve(p0: CGPoint(x: 3.0, y: 0.0),
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
        let curve = CubicCurve(p0: CGPoint(x: 0.0, y: 0.0),
                                     p1: CGPoint(x: 2.0, y: 1.0),
                                     p2: CGPoint(x: -1.0, y: 1.0),
                                     p3: CGPoint(x: 1.0, y: 0.0))
        let i = curve.selfIntersections(accuracy: epsilon)
        XCTAssertEqual(i.count, 1, "wrong number of intersections!")
        XCTAssert( distance(curve.point(at: i[0].t1), curve.point(at: i[0].t2)) < epsilon, "wrong or inaccurate intersection!" )
    }
}
