//
//  TransformableTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 12/10/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import XCTest
import BezierKit

class TransformableTests: XCTestCase {

    // rotates by 90 degrees ccw and then shifts (-1, 1)
    let transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: -1, ty: 1)

    override func setUp() {
        // assert(CGPoint(x: 1, y: 0).applying(transform) == CGPoint(x: -1, y: 2))
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testTransformLineSegment() {
        let l = LineSegment(p0: CGPoint(x: -1, y: -1), p1: CGPoint(x: 3, y: 1))
        XCTAssertEqual(l.copy(using: transform), LineSegment(p0: CGPoint(x: 0, y: 0), p1: CGPoint(x: -2, y: 4)))
    }

    func testTransformQuadraticCurve() {
        let q = QuadraticCurve(p0: CGPoint(x: -1, y: -1),
                                     p1: CGPoint(x: 3, y: 1),
                                     p2: CGPoint(x: 7, y: -1))
        XCTAssertEqual(q.copy(using: transform), QuadraticCurve(p0: CGPoint(x: 0, y: 0),
                                                                      p1: CGPoint(x: -2, y: 4),
                                                                      p2: CGPoint(x: 0, y: 8)))
    }

    func testTransformCubicCurve() {
        let c = CubicCurve(p0: CGPoint(x: -1, y: -1),
                                 p1: CGPoint(x: 3, y: 1),
                                 p2: CGPoint(x: 7, y: -1),
                                 p3: CGPoint(x: 8, y: 0))
        XCTAssertEqual(c.copy(using: transform), CubicCurve(p0: CGPoint(x: 0, y: 0),
                                                                  p1: CGPoint(x: -2, y: 4),
                                                                  p2: CGPoint(x: 0, y: 8),
                                                                  p3: CGPoint(x: -1, y: 9)))
    }

    func testTransformPathComponent() {
        let line = LineSegment(p0: CGPoint(x: -1, y: -1), p1: CGPoint(x: 3, y: 1))
        let component = PathComponent(curves: [line])
        let transformedComponent = component.copy(using: transform)
        XCTAssertEqual(transformedComponent.curves.count, 1)
        XCTAssertEqual(transformedComponent.curves.first as? LineSegment, LineSegment(p0: CGPoint(x: 0, y: 0), p1: CGPoint(x: -2, y: 4)))
    }

    func testTransformPath() {

        // just a simple path with two path components made up of line segments

        let l1 = LineSegment(p0: CGPoint(x: -1, y: -1), p1: CGPoint(x: 3, y: 1))
        let l2 = LineSegment(p0: CGPoint(x: 1, y: 1), p1: CGPoint(x: 2, y: 3))

        let path = Path(components: [PathComponent(curves: [l1]), PathComponent(curves: [l2])])

        let transformedPath = path.copy(using: transform)

        let expectedl1 = LineSegment(p0: CGPoint(x: 0, y: 0), p1: CGPoint(x: -2, y: 4))
        let expectedl2 = LineSegment(p0: CGPoint(x: -2, y: 2), p1: CGPoint(x: -4, y: 3))

        XCTAssertEqual(transformedPath.components.count, 2)
        XCTAssertEqual(transformedPath.components[0].numberOfElements, 1)
        XCTAssertEqual(transformedPath.components[0].numberOfElements, 1)
        XCTAssertEqual(transformedPath.components[0].element(at: 0) as! LineSegment, expectedl1)
        XCTAssertEqual(transformedPath.components[1].element(at: 0) as! LineSegment, expectedl2)
    }

}
