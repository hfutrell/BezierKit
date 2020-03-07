//
//  PathComponentTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 1/13/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class PathComponentTests: XCTestCase {

    let line1 = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 5.0, y: 5.0))   // length = 5
    let line2 = LineSegment(p0: CGPoint(x: 5.0, y: 5.0), p1: CGPoint(x: 13.0, y: -1.0)) // length = 10

    func testLength() {
        let p = PathComponent(curves: [line1, line2])
        XCTAssertEqual(p.length, 15.0) // sum of two lengths
    }

    func testBoundingBox() {
        let p = PathComponent(curves: [line1, line2])
        XCTAssertEqual(p.boundingBox, BoundingBox(min: CGPoint(x: 1.0, y: -1.0), max: CGPoint(x: 13.0, y: 5.0))) // just the union of the two bounding boxes
    }

    func testOffset() {
        // construct a PathComponent from a split cubic
        let q = QuadraticCurve(p0: CGPoint(x: 0.0, y: 0.0), p1: CGPoint(x: 2.0, y: 1.0), p2: CGPoint(x: 4.0, y: 0.0))
        let (ql, qr) = q.split(at: 0.5)
        let p = PathComponent(curves: [ql, qr])
        // test that offset gives us the same result as offsetting the split segments
        let pOffset = p.offset(distance: 1)
        XCTAssertNotNil(pOffset)

        for (c1, c2) in zip(pOffset!.curves, ql.offset(distance: 1) + qr.offset(distance: 1)) {
            XCTAssert(c1 == c2)
        }
    }

    private let p1 = CGPoint(x: 0.0, y: 1.0)
    private let p2 = CGPoint(x: 2.0, y: 1.0)
    private let p3 = CGPoint(x: 2.5, y: 0.5)
    private let p4 = CGPoint(x: 2.0, y: 0.0)
    private let p5 = CGPoint(x: 0.0, y: 0.0)
    private let p6 = CGPoint(x: -0.5, y: 0.25)
    private let p7 = CGPoint(x: -0.5, y: 0.75)
    private let p8 = CGPoint(x: 0.0, y: 1.0)

    func testEquatable() {

        let l1 = LineSegment(p0: p1, p1: p2)
        let q1 = QuadraticCurve(p0: p2, p1: p3, p2: p4)
        let l2 = LineSegment(p0: p4, p1: p5)
        let c1 = CubicCurve(p0: p5, p1: p6, p2: p7, p3: p8)

        let pathComponent1 = PathComponent(curves: [l1, q1, l2, c1])
        let pathComponent2 = PathComponent(curves: [l1, q1, l2])
        let pathComponent3 = PathComponent(curves: [l1, q1, l2, c1])

        var altC1 = c1
        altC1.p2.x = -0.25
        let pathComponent4 = PathComponent(curves: [l1, q1, l2, altC1])

        XCTAssertNotEqual(pathComponent1, pathComponent2) // pathComponent2 is missing 4th path element, so not equal
        XCTAssertEqual(pathComponent1, pathComponent3)    // same path elements means equal
        XCTAssertNotEqual(pathComponent1, pathComponent4) // pathComponent4 has an element with a modified path
    }

    func testIsEqual() {

        let l1 = LineSegment(p0: p1, p1: p2)
        let q1 = QuadraticCurve(p0: p2, p1: p3, p2: p4)
        let l2 = LineSegment(p0: p4, p1: p5)
        let c1 = CubicCurve(p0: p5, p1: p6, p2: p7, p3: p8)

        let pathComponent1 = PathComponent(curves: [l1, q1, l2, c1])
        let pathComponent2 = PathComponent(curves: [l1, q1, l2, c1])
        var altC1 = c1
        altC1.p2.x = -0.25
        let pathComponent3 = PathComponent(curves: [l1, q1, l2, altC1])

        let string = "hello!" as NSString

        XCTAssertFalse(pathComponent1.isEqual(string))
        XCTAssertFalse(pathComponent1.isEqual(nil))
        XCTAssertTrue(pathComponent1.isEqual(pathComponent1))
        XCTAssertTrue(pathComponent1.isEqual(pathComponent2))
        XCTAssertFalse(pathComponent1.isEqual(pathComponent3))
    }

    func testIndexedPathComponentLocation() {
        let location1 = IndexedPathComponentLocation(elementIndex: 0, t: 0.5)
        let location2 = IndexedPathComponentLocation(elementIndex: 0, t: 1.0)
        let location3 = IndexedPathComponentLocation(elementIndex: 1, t: 0.0)
        XCTAssert(location1 < location2)
        XCTAssert(location1 < location3)
        XCTAssertFalse(location3 < location1)
        XCTAssertFalse(location2 < location1)
    }

    let pointPathComponent = PathComponent(points: [CGPoint(x: 3.145, y: -8.34)], orders: [0]) // just a single point
    let circlePathComponent = Path(cgPath: CGPath.init(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2), transform: nil)).components[0]

    func testStartingEndingPointAt() {
        XCTAssertEqual(circlePathComponent.startingPointForElement(at: 0), circlePathComponent.curves[0].startingPoint)
        XCTAssertEqual(circlePathComponent.startingPointForElement(at: 2), circlePathComponent.curves[2].startingPoint)
        XCTAssertEqual(circlePathComponent.endingPointForElement(at: 0), circlePathComponent.curves[0].endingPoint)
        XCTAssertEqual(circlePathComponent.endingPointForElement(at: 2), circlePathComponent.curves[2].endingPoint)
    }

    func testSplitFromTo() {
        // corner case, check that splitting a point always yields the same thin
        XCTAssertEqual(pointPathComponent, pointPathComponent.split(from: IndexedPathComponentLocation(elementIndex: 0, t: 0.2),
                                                                      to: IndexedPathComponentLocation(elementIndex: 0, t: 0.8)))

        XCTAssertEqual(circlePathComponent.startingIndexedLocation, IndexedPathComponentLocation(elementIndex: 0, t: 0))
        XCTAssertEqual(circlePathComponent.endingIndexedLocation, IndexedPathComponentLocation(elementIndex: 3, t: 1.0))

        // check case of splitting a single path element
        let split1 = circlePathComponent.split(from: IndexedPathComponentLocation(elementIndex: 1, t: 0.3), to: IndexedPathComponentLocation(elementIndex: 1, t: 0.6))
        let expectedValue1 = PathComponent(curves: [circlePathComponent.element(at: 1).split(from: 0.3, to: 0.6)])
        XCTAssertEqual(split1, expectedValue1)

        // check case of splitting two path elements where neither is the complete element
        let split2 = circlePathComponent.split(from: IndexedPathComponentLocation(elementIndex: 1, t: 0.3), to: IndexedPathComponentLocation(elementIndex: 2, t: 0.6))
        let expectedValue2 = PathComponent(curves: [circlePathComponent.element(at: 1).split(from: 0.3, to: 1.0), circlePathComponent.element(at: 2).split(from: 0.0, to: 0.6)])
        XCTAssertEqual(split2, expectedValue2)

        // check case of splitting where there is a full element in the middle
        let split3StartIndexedLocation = IndexedPathComponentLocation(elementIndex: 1, t: 0.3)
        let split3EndIndexedLocation = IndexedPathComponentLocation(elementIndex: 3, t: 0.6)
        let split3 = circlePathComponent.split(from: IndexedPathComponentLocation(elementIndex: 1, t: 0.3), to: IndexedPathComponentLocation(elementIndex: 3, t: 0.6))
        let expectedValue3 = PathComponent(curves: [circlePathComponent.element(at: 1).split(from: 0.3, to: 1.0), circlePathComponent.element(at: 2), circlePathComponent.element(at: 3).split(from: 0.0, to: 0.6)])
        XCTAssertEqual(split3, expectedValue3)

        // misc cases for all code paths
        let split4 = circlePathComponent.split(from: IndexedPathComponentLocation(elementIndex: 3, t: 0), to: IndexedPathComponentLocation(elementIndex: 3, t: 1))
        let expectedValue4 = PathComponent(curves: [circlePathComponent.element(at: 3)])
        XCTAssertEqual(split4, expectedValue4)

        let split5 = circlePathComponent.split(from: IndexedPathComponentLocation(elementIndex: 1, t: 0), to: IndexedPathComponentLocation(elementIndex: 2, t: 0.5))
        let expectedValue5 = PathComponent(curves: [circlePathComponent.element(at: 1), circlePathComponent.element(at: 2).split(from: 0, to: 0.5)])
        XCTAssertEqual(split5, expectedValue5)

        let split6 = circlePathComponent.split(from: IndexedPathComponentLocation(elementIndex: 1, t: 0.5), to: IndexedPathComponentLocation(elementIndex: 2, t: 1))
        let expectedValue6 = PathComponent(curves: [circlePathComponent.element(at: 1).split(from: 0.5, to: 1), circlePathComponent.element(at: 2)])
        XCTAssertEqual(split6, expectedValue6)

        // check that reversing the order of start and end reverses the split curve
        let split3alt = circlePathComponent.split(from: split3EndIndexedLocation, to: split3StartIndexedLocation)
        XCTAssertEqual(split3alt, expectedValue3.reversed())

        // check that splitting over the entire curve gives the same curve back
        let split7 = circlePathComponent.split(from: circlePathComponent.startingIndexedLocation, to: circlePathComponent.endingIndexedLocation)
        XCTAssertEqual(split7, circlePathComponent)

        // check that if the starting location is at t=1 we do not create degenerate curves of length zero
        let split5alt = circlePathComponent.split(from: IndexedPathComponentLocation(elementIndex: 0, t: 1.0), to: IndexedPathComponentLocation(elementIndex: 2, t: 0.5))
        XCTAssertEqual(split5alt, expectedValue5)

        // check that if the ending location is at t=0 we do not create degenerate curves of length zero
        let split6alt = circlePathComponent.split(from: IndexedPathComponentLocation(elementIndex: 1, t: 0.5), to: IndexedPathComponentLocation(elementIndex: 3, t: 0))
        XCTAssertEqual(split6alt, expectedValue6)
    }

    func testEnumeratePoints() {
        func arrayByEnumerating(component: PathComponent, includeControlPoints: Bool) -> [CGPoint] {
            var points: [CGPoint] = []
            component.enumeratePoints(includeControlPoints: includeControlPoints) { points.append($0) }
            return points
        }
        XCTAssertEqual(arrayByEnumerating(component: pointPathComponent, includeControlPoints: true), [pointPathComponent.startingPoint])
        XCTAssertEqual(arrayByEnumerating(component: pointPathComponent, includeControlPoints: false), [pointPathComponent.startingPoint])

        let expectedCirclePoints = [CGPoint(x: 1, y: 0),
                                    CGPoint(x: 0, y: 1),
                                    CGPoint(x: -1, y: 0),
                                    CGPoint(x: 0, y: -1),
                                    CGPoint(x: 1, y: 0)]

        XCTAssertEqual(arrayByEnumerating(component: circlePathComponent, includeControlPoints: false), expectedCirclePoints)
        XCTAssertEqual(arrayByEnumerating(component: circlePathComponent, includeControlPoints: true), circlePathComponent.points)
    }
}
