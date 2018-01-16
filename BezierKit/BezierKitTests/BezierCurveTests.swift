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
    
    func testScaleDistance() {
        // line segment
        let epsilon: BKFloat = 1.0e-6
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 5.0, y: 6.0))
        let ls = l.scale(distance: sqrt(2)) // (moves line up and left by 1,1)
        let expectedLine = LineSegment(p0: BKPoint(x: 0.0, y: 3.0), p1: BKPoint(x: 4.0, y: 7.0))
        XCTAssert(BezierKitTestHelpers.curveControlPointsEqual(curve1: ls, curve2: expectedLine, tolerance: epsilon))
        // quadratic
        let q = QuadraticBezierCurve(p0: BKPoint(x: 1.0, y: 1.0),
                                     p1: BKPoint(x: 2.0, y: 2.0),
                                     p2: BKPoint(x: 3.0, y: 1.0))
        let qs = q.scale(distance: sqrt(2))
        let expectedQuadratic = QuadraticBezierCurve(p0: BKPoint(x: 0.0, y: 2.0),
                                                p1: BKPoint(x: 2.0, y: 4.0),
                                                p2: BKPoint(x: 4.0, y: 2.0))
        XCTAssert(BezierKitTestHelpers.curveControlPointsEqual(curve1: qs, curve2: expectedQuadratic, tolerance: epsilon))
        // cubic
        let c = CubicBezierCurve(p0: BKPoint(x: -4.0, y: +0.0),
                                 p1: BKPoint(x: -2.0, y: +2.0),
                                 p2: BKPoint(x: +2.0, y: +2.0),
                                 p3: BKPoint(x: +4.0, y: +0.0))
        let cs = c.scale(distance: 2.0 * sqrt(2))
        let expectedCubic = CubicBezierCurve(p0: BKPoint(x: -6.0, y: +2.0),
                                p1: BKPoint(x: -3.0, y: +5.0),
                                p2: BKPoint(x: +3.0, y: +5.0),
                                p3: BKPoint(x: +6.0, y: +2.0))
        XCTAssert(BezierKitTestHelpers.curveControlPointsEqual(curve1: cs, curve2: expectedCubic, tolerance: epsilon))

        // TODO: add special case for quadratic and cubic that are actually linear -- can fail if normals are parallel
    }
    
    func testOffsetDistance() {
        // line segments (or isLinear) have a separate codepath, so be sure to test those
        let epsilon: BKFloat = 1.0e-6
        let c1 = CubicBezierCurve(lineSegment: LineSegment(p0: BKPoint(x: 0.0, y: 0.0), p1: BKPoint(x: 1.0, y: 1.0)))
        let c1Offset = c1.offset(distance: sqrt(2))
        let expectedOffset1 = CubicBezierCurve(lineSegment: LineSegment(p0: BKPoint(x: -1.0, y: 1.0), p1: BKPoint(x: 0.0, y: 2.0)))
        XCTAssertEqual(c1Offset.count, 1)
        XCTAssert(BezierKitTestHelpers.curveControlPointsEqual(curve1: c1Offset[0] as! CubicBezierCurve, curve2: expectedOffset1, tolerance: epsilon))
        // next test a non-simple curve
        let c2 = CubicBezierCurve(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 2.0, y: 2.0), p2: BKPoint(x: 3.0, y: 2.0), p3: BKPoint(x: 4.0, y: 1.0))
        let c2Offset = c2.offset(distance: sqrt(2))
        for i in 0..<c2Offset.count {
            let c = c2Offset[i]
            XCTAssert(c.simple)
            if i == 0 {
                // segment starts where un-reduced segment started (after ofsetting)
                XCTAssert(distance(c.startingPoint, BKPoint(x: 0.0, y: 2.0)) < epsilon)
            }
            else {
                // segment starts where last ended
                XCTAssertEqual(c.startingPoint, c2Offset[i-1].endingPoint)
            }
            if i == c2Offset.count - 1 {
                // segment ends where un-reduced segment ended (after ofsetting)
                XCTAssert(distance(c.endingPoint, BKPoint(x: 5.0, y: 2.0)) < epsilon)
            }
        }
        // TODO: fix reduce behavior for cusps (cannot be simplified because derivative is zero so normal is zero at cusp)
        // let c2 = CubicBezierCurve(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 2.0, y: 2.0), p2: BKPoint(x: 1.0, y: 2.0), p3: BKPoint(x: 2.0, y: 1.0))
    }
    
    func testOffsetTimeDistance() {
        let epsilon: BKFloat = 1.0e-6
        let q = QuadraticBezierCurve(p0: BKPoint(x: 1.0, y: 1.0),
                                     p1: BKPoint(x: 2.0, y: 2.0),
                                     p2: BKPoint(x: 3.0, y: 1.0))
        let p0 = q.offset(t: 0.0, distance: sqrt(2))
        let p1 = q.offset(t: 0.5, distance: 1.5)
        let p2 = q.offset(t: 1.0, distance: sqrt(2))
        XCTAssert(distance(p0, BKPoint(x: 0.0, y: 2.0)) < epsilon)
        XCTAssert(distance(p1, BKPoint(x: 2.0, y: 3.0)) < epsilon)
        XCTAssert(distance(p2, BKPoint(x: 4.0, y: 2.0)) < epsilon)
    }
    
    func testProject() {
        // line segments override the project implementation, so test them specifically
        let epsilon: BKFloat = 1.0e-3 // TODO: notice that this epsilon value is actually pretty big? it's because project uses a fixed number of iterations. See the flatness-project branch for a potential better solution.
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 5.0, y: 6.0))
        let p1 = l.project(point: BKPoint(x: 0.0, y: 0.0)) // should project to p0
        XCTAssertEqual(p1, BKPoint(x: 1.0, y: 2.0))
        let p2 = l.project(point: BKPoint(x: 1.0, y: 4.0)) // should project to l.compute(0.25)
        XCTAssertEqual(p2, BKPoint(x: 2.0, y: 3.0))
        let p3 = l.project(point: BKPoint(x: 6.0, y: 7.0))
        XCTAssertEqual(p3, BKPoint(x: 5.0, y: 6.0)) // should project to p1
        // test a cubic
        let c = CubicBezierCurve(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 2.0, y: 2.0), p2: BKPoint(x: 4.0, y: 2.0), p3: BKPoint(x: 5.0, y: 1.0))
        let p4 = c.project(point: BKPoint(x: 0.95, y: 1.05)) // should project to p0
        XCTAssertEqual(p4, BKPoint(x: 1.0, y: 1.0))
        let p5 = c.project(point: BKPoint(x: 5.05, y: 1.05)) // should project to p3
        XCTAssertEqual(p5, BKPoint(x: 5.0, y: 1.0))
        let p6 = c.project(point: BKPoint(x: 3.0, y: 2.0)) // should project to center of curve
        XCTAssertEqual(p6, BKPoint(x: 3.0, y: 1.75))
        let p7 = c.project(point: c.compute(0.831211) + c.normal(0.831211)) // should project back to (roughly) c.compute(0.831211)
        XCTAssert(distance(p7, c.compute(0.831211)) < epsilon)

    }
    
    static let lineSegmentForOutlining = LineSegment(p0: BKPoint(x: -10, y: -5), p1: BKPoint(x: 20, y: 10))

    private func lineOffsets(_ lineSegment: LineSegment, _ d1: BKFloat, _ d2: BKFloat, _ d3: BKFloat, _ d4: BKFloat) -> (BKPoint, BKPoint, BKPoint, BKPoint) {
        let o0 = lineSegment.startingPoint + d1 * lineSegment.normal(0)
        let o1 = lineSegment.endingPoint + d3 * lineSegment.normal(1)
        let o2 = lineSegment.endingPoint - d4 * lineSegment.normal(1)
        let o3 = lineSegment.startingPoint - d2 * lineSegment.normal(0)
        return (o0, o1, o2, o3)
    }
    
    func testOutlineDistance() {
        // When only one distance value is given, the outline is generated at distance d on both the normal and anti-normal
        let lineSegment = BezierCurveTests.lineSegmentForOutlining
        let outline: PolyBezier = lineSegment.outline(distance: 1)
        XCTAssertEqual(outline.curves.count, 4)
        
        let (o0, o1, o2, o3) = lineOffsets(lineSegment, 1, 1, 1, 1)
        
        XCTAssert( BezierKitTestHelpers.curve(outline.curves[0], matchesCurve: LineSegment(p0: o3, p1: o0)))
        XCTAssert( BezierKitTestHelpers.curve(outline.curves[1], matchesCurve: LineSegment(p0: o0, p1: o1)))
        XCTAssert( BezierKitTestHelpers.curve(outline.curves[2], matchesCurve: LineSegment(p0: o1, p1: o2)))
        XCTAssert( BezierKitTestHelpers.curve(outline.curves[3], matchesCurve: LineSegment(p0: o2, p1: o3)))
    }

    func testOutlineDistanceAlongNormalDistanceOppositeNormal() {
        //  If two distance values are given, the outline is generated at distance d1 on along the normal, and d2 along the anti-normal.
        let lineSegment = BezierCurveTests.lineSegmentForOutlining
        let distanceAlongNormal: BKFloat = 1
        let distanceOppositeNormal: BKFloat = 2
        let outline: PolyBezier = lineSegment.outline(distanceAlongNormal: distanceAlongNormal, distanceOppositeNormal: distanceOppositeNormal)
        XCTAssertEqual(outline.curves.count, 4)
        
        let o0 = lineSegment.startingPoint + distanceAlongNormal * lineSegment.normal(0)
        let o1 = lineSegment.endingPoint + distanceAlongNormal * lineSegment.normal(1)
        let o2 = lineSegment.endingPoint - distanceOppositeNormal * lineSegment.normal(1)
        let o3 = lineSegment.startingPoint - distanceOppositeNormal * lineSegment.normal(0)
        
        XCTAssert( BezierKitTestHelpers.curve(outline.curves[0], matchesCurve: LineSegment(p0: o3, p1: o0)))
        XCTAssert( BezierKitTestHelpers.curve(outline.curves[1], matchesCurve: LineSegment(p0: o0, p1: o1)))
        XCTAssert( BezierKitTestHelpers.curve(outline.curves[2], matchesCurve: LineSegment(p0: o1, p1: o2)))
        XCTAssert( BezierKitTestHelpers.curve(outline.curves[3], matchesCurve: LineSegment(p0: o2, p1: o3)))
    }
    
    func testOutlineFourArguments() {
        // Graduated offsetting is achieved by using four distances measures, where d1 is the initial offset along the normal, d2 the initial distance along the anti-normal, d3 the final offset along the normal, and d4 the final offset along the anti-normal.
        let lineSegment = BezierCurveTests.lineSegmentForOutlining
        let distanceAlongNormal1: BKFloat = 2
        let distanceOppositeNormal1: BKFloat = 4
        let distanceAlongNormal2: BKFloat = 1
        let distanceOppositeNormal2: BKFloat = 2

        let outline: PolyBezier = lineSegment.outline(distanceAlongNormalStart: distanceAlongNormal1,
                                                      distanceOppositeNormalStart: distanceOppositeNormal1,
                                                      distanceAlongNormalEnd: distanceAlongNormal2,
                                                      distanceOppositeNormalEnd: distanceOppositeNormal2)
        
        XCTAssertEqual(outline.curves.count, 4)
        
        let (o0, o1, o2, o3) = lineOffsets(lineSegment, distanceAlongNormal1, distanceOppositeNormal1, distanceAlongNormal2, distanceOppositeNormal2)

        XCTAssert( BezierKitTestHelpers.curve(outline.curves[0], matchesCurve: LineSegment(p0: o3, p1: o0)))
        XCTAssert( BezierKitTestHelpers.curve(outline.curves[1], matchesCurve: LineSegment(p0: o0, p1: o1)))
        XCTAssert( BezierKitTestHelpers.curve(outline.curves[2], matchesCurve: LineSegment(p0: o1, p1: o2)))
        XCTAssert( BezierKitTestHelpers.curve(outline.curves[3], matchesCurve: LineSegment(p0: o2, p1: o3)))
        // TODO: it should be noted that quadratic curves can only be offset as graduated curve by first raising it to a cubic curve and then running through the offsetting algorithm
    }
    
    func testOutlineShapesDistance() {
        let lineSegment = BezierCurveTests.lineSegmentForOutlining
        let distanceAlongNormal: BKFloat = 1
        let shapes: [Shape] = lineSegment.outlineShapes(distance: distanceAlongNormal)
        XCTAssertEqual(shapes.count, 1)
        let (o0, o1, o2, o3) = lineOffsets(lineSegment, distanceAlongNormal, distanceAlongNormal, distanceAlongNormal, distanceAlongNormal)
        let expectedShape = Shape(LineSegment(p0: o0, p1: o1), LineSegment(p0: o2, p1: o3), false, false) // shape made from lines with real (non-virtual) caps
        XCTAssertTrue( BezierKitTestHelpers.shape(shapes[0], matchesShape: expectedShape) )
    }
    
    func testOutlineShapesDistanceAlongNormalDistanceOppositeNormal() {
        let lineSegment = BezierCurveTests.lineSegmentForOutlining
        let distanceAlongNormal: BKFloat = 1
        let distanceOppositeNormal: BKFloat = 2
        let shapes: [Shape] = lineSegment.outlineShapes(distanceAlongNormal: distanceAlongNormal, distanceOppositeNormal: distanceOppositeNormal)
        XCTAssertEqual(shapes.count, 1)
        let (o0, o1, o2, o3) = lineOffsets(lineSegment, distanceAlongNormal, distanceOppositeNormal, distanceAlongNormal, distanceOppositeNormal)
        let expectedShape = Shape(LineSegment(p0: o0, p1: o1), LineSegment(p0: o2, p1: o3), false, false) // shape made from lines with real (non-virtual) caps
        XCTAssertTrue( BezierKitTestHelpers.shape(shapes[0], matchesShape: expectedShape) )
    }
    
    func testCubicCubicIntersectionEndpoints() {
        // these two cubics intersect only at the endpoints
        let epsilon: BKFloat = 1.0e-3
        let cubic1 = CubicBezierCurve(p0: BKPoint(x: 0.0, y: 0.0),
                                      p1: BKPoint(x: 1.0, y: 1.0),
                                      p2: BKPoint(x: 2.0, y: 1.0),
                                      p3: BKPoint(x: 3.0, y: 0.0))
        let cubic2 = CubicBezierCurve(p0: BKPoint(x: 3.0, y: 0.0),
                                      p1: BKPoint(x: 2.0, y: -1.0),
                                      p2: BKPoint(x: 1.0, y: -1.0),
                                      p3: BKPoint(x: 0.0, y: 0.0))
        let i = cubic1.intersects(curve: cubic2, curveIntersectionThreshold: epsilon)
        XCTAssertEqual(i.count, 2, "start and end points should intersect!")
        XCTAssertEqual(i[0].t1, 0.0)
        XCTAssertEqual(i[0].t2, 1.0)
        XCTAssertEqual(i[1].t1, 1.0)
        XCTAssertEqual(i[1].t2, 0.0)
    }
    
    func testCubicSelfIntersection() {
        let epsilon: BKFloat = 1.0e-3
        let curve = CubicBezierCurve(p0: BKPoint(x: 0.0, y: 0.0),
                                     p1: BKPoint(x: 2.0, y: 1.0),
                                     p2: BKPoint(x: -1.0, y: 1.0),
                                     p3: BKPoint(x: 1.0, y: 0.0))
        let i = curve.intersects(curveIntersectionThreshold: epsilon)
        XCTAssertEqual(i.count, 1, "wrong number of intersections!")
        XCTAssert( (curve.compute(i[0].t1) - curve.compute(i[0].t2)).length < epsilon, "wrong or inaccurate intersection!" )
    }
    
}
