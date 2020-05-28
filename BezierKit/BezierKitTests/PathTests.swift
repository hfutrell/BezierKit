//
//  PathTest.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/1/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import XCTest
import CoreGraphics
@testable import BezierKit

private extension Path {
    /// copies the path in such a way that it's impossible that optimizations would allow the copy to share the same underlying storage
    func independentCopy() -> Path {
        return self.copy(using: CGAffineTransform(translationX: 1, y: 0)).copy(using: CGAffineTransform(translationX: -1, y: 0))
    }
}

class PathTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testInitCGPathEmpty() {
        // trivial test of an empty path
        let path = Path(cgPath: CGMutablePath())
        XCTAssert(path.components.isEmpty)
    }

    func testInitCGPathRect() {

        // simple test of a rectangle (note that this CGPath uses a moveTo())
        let rect = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 1, height: 2))
        let cgPath1 = CGPath(rect: rect, transform: nil)
        let path1 = Path(cgPath: cgPath1)

        let p1 = CGPoint(x: 0.0, y: 0.0)
        let p2 = CGPoint(x: 1.0, y: 0.0)
        let p3 = CGPoint(x: 1.0, y: 2.0)
        let p4 = CGPoint(x: 0.0, y: 2.0)

        XCTAssertEqual(path1.components.count, 1)
        XCTAssertEqual(path1.components[0].element(at: 0) as! LineSegment, LineSegment(p0: p1, p1: p2))
        XCTAssertEqual(path1.components[0].element(at: 1) as! LineSegment, LineSegment(p0: p2, p1: p3))
        XCTAssertEqual(path1.components[0].element(at: 2) as! LineSegment, LineSegment(p0: p3, p1: p4))
        XCTAssertEqual(path1.components[0].element(at: 3) as! LineSegment, LineSegment(p0: p4, p1: p1))
    }

    func testInitCGPathEllipse() {
        // test of a ellipse (4 cubic curves)
        let rect = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 1, height: 2))
        let cgPath2 = CGPath(ellipseIn: rect, transform: nil)
        let path2 = Path(cgPath: cgPath2)

        let p1 = CGPoint(x: 1.0, y: 1.0)
        let p2 = CGPoint(x: 0.5, y: 2.0)
        let p3 = CGPoint(x: 0.0, y: 1.0)
        let p4 = CGPoint(x: 0.5, y: 0.0)

        XCTAssertEqual(path2.components.count, 1)
        XCTAssertEqual(path2.components[0].numberOfElements, 4)
        XCTAssertEqual(path2.components[0].element(at: 0).startingPoint, p1)
        XCTAssertEqual(path2.components[0].element(at: 1).startingPoint, p2)
        XCTAssertEqual(path2.components[0].element(at: 2).startingPoint, p3)
        XCTAssertEqual(path2.components[0].element(at: 3).startingPoint, p4)
        XCTAssertEqual(path2.components[0].element(at: 0).endingPoint, p2)
        XCTAssertEqual(path2.components[0].element(at: 1).endingPoint, p3)
        XCTAssertEqual(path2.components[0].element(at: 2).endingPoint, p4)
        XCTAssertEqual(path2.components[0].element(at: 3).endingPoint, p1)
    }

    func testInitCGPathQuads() {
        // test of a rect with some quad curves
        let cgPath3 = CGMutablePath()

        let p1 = CGPoint(x: 0.0, y: 1.0)
        let p2 = CGPoint(x: 2.0, y: 1.0)
        let p3 = CGPoint(x: 3.0, y: 0.5)
        let p4 = CGPoint(x: 2.0, y: 0.0)
        let p5 = CGPoint(x: 0.0, y: 0.0)
        let p6 = CGPoint(x: -1.0, y: 0.5)

        cgPath3.move(to: p1)
        cgPath3.addLine(to: p2)
        cgPath3.addQuadCurve(to: p4, control: p3)
        cgPath3.addLine(to: p5)
        cgPath3.addQuadCurve(to: p1, control: p6)
        cgPath3.closeSubpath()

        let path3 = Path(cgPath: cgPath3)
        XCTAssertEqual(path3.components.count, 1)
        XCTAssertEqual(path3.components[0].numberOfElements, 4)
        XCTAssertEqual(path3.components[0].element(at: 1) as! QuadraticCurve, QuadraticCurve(p0: p2, p1: p3, p2: p4))
    }

    func testInitCGPathMultiplecomponents() {
        // test of 2 line segments where each segment is started with a moveTo
        // this tests multiple components and starting new paths with moveTo instead of closePath
        let cgPath4 = CGMutablePath()
        let p1 = CGPoint(x: 1.0, y: 2.0)
        let p2 = CGPoint(x: 3.0, y: 5.0)
        let p3 = CGPoint(x: -4.0, y: -1.0)
        let p4 = CGPoint(x: 5.0, y: 3.0)

        cgPath4.move(to: p1)
        cgPath4.addLine(to: p2)
        cgPath4.move(to: p3)
        cgPath4.addLine(to: p4)

        let path4 = Path(cgPath: cgPath4)
        XCTAssertEqual(path4.components.count, 2)
        XCTAssertEqual(path4.components[0].numberOfElements, 1)
        XCTAssertEqual(path4.components[1].numberOfElements, 1)
        XCTAssertEqual(path4.components[0].element(at: 0) as! LineSegment, LineSegment(p0: p1, p1: p2))
        XCTAssertEqual(path4.components[1].element(at: 0) as! LineSegment, LineSegment(p0: p3, p1: p4))
    }

    func testIntersections() {
        let circleCGPath = CGPath(ellipseIn: CGRect(x: 2.0, y: 3.0, width: 2.0, height: 2.0), transform: nil)
        let circlePath = Path(cgPath: circleCGPath) // a circle centered at (3, 4) with radius 2

        let rectangleCGPath = CGPath(rect: CGRect(x: 3.0, y: 4.0, width: 2.0, height: 2.0), transform: nil)
        let rectanglePath = Path(cgPath: rectangleCGPath)

        let intersections = rectanglePath.intersections(with: circlePath).map { rectanglePath.point(at: $0.indexedPathLocation1 ) }

        XCTAssertEqual(intersections.count, 2)
        XCTAssert(intersections.contains(CGPoint(x: 4.0, y: 4.0)))
        XCTAssert(intersections.contains(CGPoint(x: 3.0, y: 5.0)))
    }

    func testSelfIntersectsEmptyPath() {
        let emptyPath = Path()
        XCTAssertEqual(emptyPath.selfIntersections(), [])
        XCTAssertFalse(emptyPath.selfIntersects())
    }

    func testSelfIntersectionsSingleComponentPath() {
        let singleComponentPath = { () -> Path in
            let points: [CGPoint] = [
                CGPoint(x: -1, y: 0),
                CGPoint(x: 1, y: 0),
                CGPoint(x: 1, y: 1),
                CGPoint(x: 0, y: 1),
                CGPoint(x: 0, y: -1),
                CGPoint(x: -1, y: -1)
            ]
            let cgPath = CGMutablePath()
            cgPath.addLines(between: points)
            cgPath.closeSubpath()
            return Path(cgPath: cgPath)
        }()
        let expectedIntersection = PathIntersection(indexedPathLocation1: IndexedPathLocation(componentIndex: 0, elementIndex: 0, t: 0.5),
                                                    indexedPathLocation2: IndexedPathLocation(componentIndex: 0, elementIndex: 3, t: 0.5))
        XCTAssertEqual(singleComponentPath.selfIntersections(), [expectedIntersection])
    }

    func testSelfIntersectsMultiComponentPath() {
        let multiComponentPath = { () -> Path in
            let cgPath = CGMutablePath()
            cgPath.addRect(CGRect(x: 0, y: 0, width: 2, height: 4))
            cgPath.addRect(CGRect(x: 1, y: 2, width: 2, height: 1))
            return Path(cgPath: cgPath)
        }()
        let expectedIntersection1 = PathIntersection(indexedPathLocation1: IndexedPathLocation(componentIndex: 0, elementIndex: 1, t: 0.5),
                                                     indexedPathLocation2: IndexedPathLocation(componentIndex: 1, elementIndex: 0, t: 0.5))
        let expectedIntersection2 = PathIntersection(indexedPathLocation1: IndexedPathLocation(componentIndex: 0, elementIndex: 1, t: 0.75),
                                                     indexedPathLocation2: IndexedPathLocation(componentIndex: 1, elementIndex: 2, t: 0.5))
        XCTAssertEqual(multiComponentPath.selfIntersections(), [expectedIntersection1, expectedIntersection2])
    }

    func testIntersectsOpenPathEdgeCase() {

        let openPath1 = Path(components: [PathComponent(curves: [LineSegment(p0: CGPoint(x: 1, y: 3), p1: CGPoint(x: 2, y: 5))])])
        let openPath2 = Path(components: [PathComponent(curves: [LineSegment(p0: CGPoint(x: 2, y: 5), p1: CGPoint(x: 9, y: 7))])])

        XCTAssertEqual(openPath1.intersections(with: openPath2), [PathIntersection(indexedPathLocation1: IndexedPathLocation(componentIndex: 0, elementIndex: 0, t: 1),
                                                                                  indexedPathLocation2: IndexedPathLocation(componentIndex: 0, elementIndex: 0, t: 0))])
        XCTAssertEqual(openPath2.intersections(with: openPath1), [PathIntersection(indexedPathLocation1: IndexedPathLocation(componentIndex: 0, elementIndex: 0, t: 0),
                                                                                   indexedPathLocation2: IndexedPathLocation(componentIndex: 0, elementIndex: 0, t: 1))])

        let closedPath1 = Path(cgPath: CGPath(rect: CGRect(x: 2, y: 5, width: 1, height: 1), transform: nil))
        XCTAssertEqual(openPath1.intersections(with: closedPath1), [PathIntersection(indexedPathLocation1: IndexedPathLocation(componentIndex: 0, elementIndex: 0, t: 1),
                                                                                     indexedPathLocation2: IndexedPathLocation(componentIndex: 0, elementIndex: 3, t: 1))])

    }

    func testSelfIntersectsOpenPathEdgeCase() {

        let cgPath = CGMutablePath()
        cgPath.addLines(between: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 0, y: -1)])
        let openPath = Path(cgPath: cgPath)
        XCTAssertFalse(openPath.components.first!.isClosed)
        XCTAssertEqual(openPath.selfIntersections(), [PathIntersection(indexedPathLocation1: IndexedPathLocation(componentIndex: 0, elementIndex: 0, t: 0),
                                                                       indexedPathLocation2: IndexedPathLocation(componentIndex: 0, elementIndex: 2, t: 0.5))])
    }

    func testPointIsWithinDistanceOfBoundary() {

        let circleCGPath = CGMutablePath()
        circleCGPath.addEllipse(in: CGRect(origin: CGPoint(x: -1.0, y: -1.0), size: CGSize(width: 2.0, height: 2.0)))

        let circlePath = Path(cgPath: circleCGPath) // a circle centered at origin with radius 1

        let d = CGFloat(0.1)
        let p1 = CGPoint(x: -3.0, y: 0.0)
        let p2 = CGPoint(x: -0.9, y: 0.9)
        let p3 = CGPoint(x: 0.75, y: 0.75)
        let p4 = CGPoint(x: 0.5, y: 0.5)

        XCTAssertFalse(circlePath.pointIsWithinDistanceOfBoundary(point: p1, distance: d)) // no, path bounding box isn't even within that distance
        XCTAssertFalse(circlePath.pointIsWithinDistanceOfBoundary(point: p2, distance: d)) // no, within bounding box, but no individual curves are within that distance
        XCTAssertTrue(circlePath.pointIsWithinDistanceOfBoundary(point: p3, distance: d))  // yes, one of the curves that makes up the circle is within that distance
        XCTAssertTrue(circlePath.pointIsWithinDistanceOfBoundary(point: p3, distance: CGFloat(10.0)))  // yes, so obviously within that distance implementation should early return yes
        XCTAssertFalse(circlePath.pointIsWithinDistanceOfBoundary(point: p4, distance: d)) // no, we are inside the path but too far from the boundary

    }

    func testEquatable() {
        let rect = CGRect(origin: CGPoint(x: -1, y: -1), size: CGSize(width: 2, height: 2))
        let path1 = Path(cgPath: CGPath(rect: rect, transform: nil))
        let path2 = Path(cgPath: CGPath(ellipseIn: rect, transform: nil))
        let path3 = Path(cgPath: CGPath(rect: rect, transform: nil))
        XCTAssertNotEqual(path1, path2)
        XCTAssertEqual(path1, path3)
    }

    func testIsEqual() {
        let rect = CGRect(origin: CGPoint(x: -1, y: -1), size: CGSize(width: 2, height: 2))
        let path1 = Path(cgPath: CGPath(rect: rect, transform: nil))
        let path2 = Path(cgPath: CGPath(ellipseIn: rect, transform: nil))
        let path3 = Path(cgPath: CGPath(rect: rect, transform: nil))

        let string = "hello" as NSString

        XCTAssertFalse(path1.isEqual(nil))
        XCTAssertFalse(path1.isEqual(string))
        XCTAssertFalse(path1.isEqual(path2))
        XCTAssertTrue(path1.isEqual(path3))
    }

    func testEncodeDecode() {
        let rect = CGRect(origin: CGPoint(x: -1, y: -1), size: CGSize(width: 2, height: 2))
        let path = Path(cgPath: CGPath(rect: rect, transform: nil))
        let data = NSKeyedArchiver.archivedData(withRootObject: path)
        let decodedPath = NSKeyedUnarchiver.unarchiveObject(with: data) as! Path
        XCTAssertEqual(decodedPath, path)
    }

    // MARK: - contains

    func testWindingCountBasic() {
        let rect1 = Path(cgPath: CGPath(rect: CGRect(origin: CGPoint(x: -1, y: -1), size: CGSize(width: 2, height: 2)), transform: nil))
        let rect2 = Path(cgPath: CGPath(rect: CGRect(origin: CGPoint(x: -2, y: -2), size: CGSize(width: 4, height: 4)), transform: nil))
        let path = Path(components: rect1.components + rect2.components)
        // outside of both rects
        XCTAssertEqual(path.windingCount(CGPoint(x: -3, y: 0)), 0)
        // inside rect1 but outside rect2
        XCTAssertEqual(path.windingCount(CGPoint(x: -1.5, y: 0)), 1)
        // inside both rects
        XCTAssertEqual(path.windingCount(CGPoint(x: 0, y: 0)), 2)
    }

    func testWindingCountCornersNoAdjust() {
        // test cases where winding count involves corners which should neither increment nor decrement the count
        let path1 = Path(cgPath: {
            let temp = CGMutablePath()
            temp.addLines(between: [CGPoint(x: 0, y: 0),
                                    CGPoint(x: 2, y: 0),
                                    CGPoint(x: 2, y: 2),
                                    CGPoint(x: 1, y: 1),
                                    CGPoint(x: 0, y: 2)])
            temp.closeSubpath()
            return temp
        }())
        XCTAssertEqual(path1.windingCount(CGPoint(x: 1.5, y: 1)), 1)
        XCTAssertEqual(path1.reversed().windingCount(CGPoint(x: 1.5, y: 1)), -1)
        let path2 = Path(cgPath: {
            let temp = CGMutablePath()
            temp.addLines(between: [CGPoint(x: 0, y: 0),
                                    CGPoint(x: 2, y: 0),
                                    CGPoint(x: 2, y: 3),
                                    CGPoint(x: 1, y: 1),
                                    CGPoint(x: 0, y: 2)])
            temp.closeSubpath()
            return temp
        }())
        XCTAssertEqual(path2.windingCount(CGPoint(x: 1, y: 2)), 0)
        XCTAssertEqual(path2.reversed().windingCount(CGPoint(x: 1, y: 2)), 0)
        // getting trickier ...
        let path3 = Path(cgPath: {
            let temp = CGMutablePath()
            temp.addLines(between: [CGPoint(x: 0, y: 0),
                                    CGPoint(x: 4, y: 0),
                                    CGPoint(x: 4, y: 2),
                                    CGPoint(x: 1, y: 1),
                                    CGPoint(x: 2, y: 4),
                                    CGPoint(x: 0, y: 4)])
            temp.closeSubpath()
            return temp
        }())
        XCTAssertEqual(path3.windingCount(CGPoint(x: 3, y: 1)), 1)
        XCTAssertEqual(path3.reversed().windingCount(CGPoint(x: 3, y: 1)), -1)
        let path4 = Path(cgPath: {
            let temp = CGMutablePath()
            temp.addLines(between: [CGPoint(x: 2, y: 0),
                                    CGPoint(x: 4, y: 0),
                                    CGPoint(x: 4, y: 4),
                                    CGPoint(x: 2, y: 2),
                                    CGPoint(x: 0, y: 3)])
            temp.closeSubpath()
            return temp
        }())
        XCTAssertEqual(path4.windingCount(CGPoint(x: 2, y: 3)), 0)
        XCTAssertEqual(path4.reversed().windingCount(CGPoint(x: 2, y: 3)), 0)
    }

    func testWindingCountCornersYesAdjust() {
        // test case(s) where winding count involves corners which should increment or decrement the count
        let path1 = Path(cgPath: {
            let temp = CGMutablePath()
            temp.addLines(between: [CGPoint(x: 0, y: 0),
                                    CGPoint(x: 4, y: 0),
                                    CGPoint(x: 2, y: 2),
                                    CGPoint(x: 4, y: 4),
                                    CGPoint(x: 0, y: 4)])
            temp.closeSubpath()
            return temp
        }())
        XCTAssertEqual(path1.windingCount(CGPoint(x: 1, y: 2)), 1)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 3, y: 2)), 0)
        XCTAssertEqual(path1.reversed().windingCount(CGPoint(x: 3, y: 2)), 0)
    }

    func testWindingCountExactlyParallel() {
        let path1 = Path(cgPath: {
            let temp = CGMutablePath()
            temp.addLines(between: [CGPoint(x: 1, y: 0),
                                    CGPoint(x: 2, y: 0),
                                    CGPoint(x: 2, y: 2),
                                    CGPoint(x: 0, y: 2),
                                    CGPoint(x: 0, y: 1),
                                    CGPoint(x: 1, y: 1)])
            temp.closeSubpath()
            return temp
        }())
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.5, y: 0)), 0)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 3, y: 0)), 0)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 1.5, y: 1)), 1)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 3, y: 1)), 0)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 3, y: 2)), 0)
        let path2 = path1.copy(using: CGAffineTransform(scaleX: 1, y: -1)).reversed()
        XCTAssertEqual(path2.windingCount(CGPoint(x: 0.5, y: 0)), 0)
        XCTAssertEqual(path2.windingCount(CGPoint(x: 3, y: 0)), 0)
        XCTAssertEqual(path2.windingCount(CGPoint(x: 1.5, y: -1)), 1)
        XCTAssertEqual(path2.windingCount(CGPoint(x: 3, y: -1)), 0)
        XCTAssertEqual(path2.windingCount(CGPoint(x: 3, y: -2)), 0)
    }

    func testWindingCountCusp() {
        let path1 = Path(cgPath: {
            let temp = CGMutablePath()
            temp.move(to: CGPoint(x: 0, y: 0))
            temp.addCurve(to: CGPoint(x: 1, y: -1),
                          control1: CGPoint(x: 2, y: 2),
                          control2: CGPoint(x: -1, y: 1))
            temp.closeSubpath()
            return temp
        }())
        // at the bottom
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.5, y: -1)), 0)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 1.5, y: -1)), 0)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 4, y: -1)), 0)
        // between the y-coordinates of start and end
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.49, y: -0.5)), 0)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.57, y: -0.5)), -1)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 1, y: -0.5)), 0)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 5, y: -0.5)), 0)
        // near the starting point
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.01, y: -0.02)), 0)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.01, y: 0)), -1)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.01, y: 0.02)), 0)
        // around the self-intersection (0.280, 0.296) t = 0.053589836, 0.74641013
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.279, y: 0.295)), 0)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.280, y: 0.295)), -1)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.281, y: 0.295)), 0)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.279, y: 0.296)), 0)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.280, y: 0.2961)), 1)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.280, y: 0.2959)), -1)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.281, y: 0.296)), 0)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.279, y: 0.297)), 0)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.280, y: 0.297)), 1)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.281, y: 0.297)), 0)
        // intersecting the middle of the loop
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.9, y: 0.856)), 0)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.6, y: 0.856)), 1)
        XCTAssertEqual(path1.windingCount(CGPoint(x: 0.1, y: 0.856)), 0)
        // around the y extrema (x : 0.6606065, y : 1.09017)
        let yExtrema = CGPoint(x: 0.6606065, y: 1.09017)
        let smallValue = 1.0e-5
        XCTAssertEqual(path1.windingCount(yExtrema - CGPoint(x: 0, y: smallValue)), 1)
        XCTAssertEqual(path1.windingCount(yExtrema - CGPoint(x: smallValue, y: 0)), 0)
        XCTAssertEqual(path1.windingCount(yExtrema), 0)
        XCTAssertEqual(path1.windingCount(yExtrema + CGPoint(x: smallValue, y: 0)), 0)
        XCTAssertEqual(path1.windingCount(yExtrema + CGPoint(x: 4, y: 0)), 0)
        XCTAssertEqual(path1.windingCount(yExtrema + CGPoint(x: 0, y: smallValue)), 0)
    }

    func testWindingCountQuadratic() {
        let path = Path(cgPath: {
            let temp = CGMutablePath()
            temp.move(to: CGPoint(x: 2, y: 1))
            temp.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: 3, y: 4))
            temp.closeSubpath()
            return temp
        }())
        // curve has an x-extrema at t=0.75 (2.25, 2.0625)
        // curve has a y-extrema at t=0.5714286 (2.1224489, 2.285714285)
        // near the ending point
        XCTAssertEqual(path.windingCount(CGPoint(x: 0.1, y: 0)), 0)
        XCTAssertEqual(path.windingCount(CGPoint(x: 3, y: 0)), 0)
        XCTAssertEqual(path.windingCount(CGPoint(x: 0.99, y: 0.5)), 1)
        XCTAssertEqual(path.windingCount(CGPoint(x: 1.01, y: 0.5)), 0)
        // near the starting point
        XCTAssertEqual(path.windingCount(CGPoint(x: 1.99, y: 1)), 1)
        XCTAssertEqual(path.windingCount(CGPoint(x: 2.01, y: 1)), 0)
        // near the X extrema
        XCTAssertEqual(path.windingCount(CGPoint(x: 2.26, y: 2.0625)), 0)
        XCTAssertEqual(path.windingCount(CGPoint(x: 2.24, y: 2.0625)), 1)
        // near the Y extrema
        XCTAssertEqual(path.windingCount(CGPoint(x: 2.122449, y: 2.285713)), 1)
        XCTAssertEqual(path.windingCount(CGPoint(x: 2.121, y: 2.285714)), 0)
        XCTAssertEqual(path.windingCount(CGPoint(x: 2.123, y: 2.285714)), 0)
        XCTAssertEqual(path.windingCount(CGPoint(x: 2.122449, y: 2.285715)), 0)
    }

    func testWindingCountCornerCase() {
        // tests a case where Utils.roots returns a root just slightly out of the range [0, 1]
        let path = Path(cgPath: {
            let temp = CGMutablePath()
            temp.move(to: CGPoint(x: 268.44162129797564, y: 24.268753616441533))
            temp.addCurve(to: CGPoint(x: 259.9693035427533, y: 32.74107137166386),
                          control1: CGPoint(x: 268.44162129797564, y: 28.94788550837148),
                          control2: CGPoint(x: 264.6484354346833, y: 32.74107137166386))
            temp.addLine(to: CGPoint(x: 259.9693035427533, y: 24.268753616441533))
            temp.closeSubpath()
            return temp
        }())
        let y = CGFloat(24.268753616441533).nextUp // next higher floating point from bottom of path
        XCTAssertEqual(path.windingCount(CGPoint(x: 268.5, y: y)), 0)
        XCTAssertEqual(path.windingCount(CGPoint(x: 268.3, y: y)), 1)
    }

    func testWindingCountRealWorldIssue() {
        // real world data from a failure where droots was returning the roots in the wrong order
        // one of the curves has multiple y extrema so the ordering was important
        let path = Path(cgPath: {
            let temp = CGMutablePath()
            temp.move(to: CGPoint(x: 605.6715730157109, y: 281.5666590956511))
            temp.addCurve(to: CGPoint(x: 599.1474827500521, y: 284.46530470516404),
                          control1: CGPoint(x: 604.6704341182384, y: 284.16867575842156),
                          control2: CGPoint(x: 601.7494994128225, y: 285.4664436026365))
            temp.addCurve(to: CGPoint(x: 596.2488371405391, y: 277.9412144395052),
                          control1: CGPoint(x: 596.5454660872816, y: 283.4641658076916),
                          control2: CGPoint(x: 595.2476982430667, y: 280.5432311022756))
            temp.addCurve(to: CGPoint(x: 606.4428758077357, y: 278.5450072177784),
                          control1: CGPoint(x: 596.0062816538538, y: 278.3028101006893),
                          control2: CGPoint(x: 598.025956346426, y: 275.00488126164095))
            temp.addCurve(to: CGPoint(x: 602.1001649013623, y: 284.89151472375136),
                          control1: CGPoint(x: 606.9962089595965, y: 281.49675337615315),
                          control2: CGPoint(x: 605.051911059737, y: 284.3381815718906))
            temp.addCurve(to: CGPoint(x: 595.7536573953893, y: 280.5488038173779),
                          control1: CGPoint(x: 599.1484187429876, y: 285.44484787561214),
                          control2: CGPoint(x: 596.30699054725, y: 283.5005499757526))
            temp.addCurve(to: CGPoint(x: 605.6715730157109, y: 281.5666590956511),
                          control1: CGPoint(x: 604.099776075449, y: 283.7112442266403),
                          control2: CGPoint(x: 606.0305835805212, y: 280.9023900946232))
            return temp
        }())
        let y = 281.4941677630135
        XCTAssertEqual(path.windingCount(CGPoint(x: 595.8, y: y)), 0)
        XCTAssertEqual(path.windingCount(CGPoint(x: 596.1, y: y)), 1)
        XCTAssertEqual(path.windingCount(CGPoint(x: 597, y: y)), 2)
        XCTAssertEqual(path.windingCount(CGPoint(x: 603.9411804326238, y: y)), 1) // the point that was failing (reported 2 instead of 1)
        XCTAssertEqual(path.windingCount(CGPoint(x: 606, y: y)), 1)
        XCTAssertEqual(path.windingCount(CGPoint(x: 607, y: y)), 0)
    }

    func testContainsSimple1() {
        let rect = CGRect(origin: CGPoint(x: -1, y: -1), size: CGSize(width: 2, height: 2))
        let path = Path(cgPath: CGPath(rect: rect, transform: nil))
        XCTAssertFalse(path.contains(CGPoint(x: -2, y: 0))) // the first point is outside the rectangle on the left
        XCTAssertTrue(path.contains(CGPoint(x: 0, y: 0)))  // the second point falls inside the rectangle
        XCTAssertFalse(path.contains(CGPoint(x: 3, y: 0))) // the third point falls outside the rectangle on the right
        XCTAssertTrue(path.contains(CGPoint(x: -0.99999, y: 0)))  // just *barely* in the rectangle
    }

    func testContainsSimple2() {
        let rect = CGRect(origin: CGPoint(x: -1, y: -1), size: CGSize(width: 2, height: 2))
        let path = Path(cgPath: CGPath(ellipseIn: rect, transform: nil))
        XCTAssertFalse(path.contains(CGPoint(x: 5, y: 5)))       // the first point is way outside the circle
        XCTAssertFalse(path.contains(CGPoint(x: -0.8, y: -0.8))) // the second point is outside the circle, but within the bounding rect
        XCTAssertTrue(path.contains(CGPoint(x: 0.3, y: 0.3)))    // the third point falls inside the circle

        // the 4th point falls inside the and is a tricky case when using the evenOdd fill mode because it aligns with two path elements exactly at y = 0
        XCTAssertTrue(path.contains(CGPoint(x: 0.5, y: 0.0), using: .evenOdd))
        XCTAssertTrue(path.contains(CGPoint(x: 0.5, y: 0.0), using: .winding))

        // the 5th point falls outside the circle, but drawing a horizontal line has a glancing blow with it
        XCTAssertFalse(path.contains(CGPoint(x: 0.1, y: 1.0), using: .evenOdd))
        XCTAssertFalse(path.contains(CGPoint(x: 0.1, y: -1.0), using: .winding))
    }

    func testContainsStar() {
        let starPoints = stride(from: 0.0, to: 2.0 * Double.pi, by: 0.4 * Double.pi).map { CGPoint(x: cos($0), y: sin($0)) }
        let cgPath = CGMutablePath()

        cgPath.move(to: starPoints[0])
        cgPath.addLine(to: starPoints[3])
        cgPath.addLine(to: starPoints[1])
        cgPath.addLine(to: starPoints[4])
        cgPath.addLine(to: starPoints[2])
        cgPath.closeSubpath()

        let path = Path(cgPath: cgPath)

        // check a point outside of the star
        let outsidePoint = CGPoint(x: 0.5, y: -0.5)
        XCTAssertFalse(path.contains(outsidePoint, using: .evenOdd))
        XCTAssertFalse(path.contains(outsidePoint, using: .winding))

        // using the winding rule, the center of the star is in the path, but with even-odd it's not
        XCTAssertTrue(path.contains(CGPoint.zero, using: .winding))
        XCTAssertFalse(path.contains(CGPoint.zero, using: .evenOdd))

        // check a point inside one of the star's arms
        let armPoint = CGPoint(x: 0.9, y: 0.0)
        XCTAssertTrue(path.contains(armPoint, using: .winding))
        XCTAssertTrue(path.contains(armPoint, using: .evenOdd))

        // check the edge case of the star's corners
        for i in 0..<5 {
            let point = starPoints[i] + CGPoint(x: 0.1, y: 0.0)
            XCTAssertFalse(path.contains(point, using: .evenOdd), "point \(i)")
            XCTAssertFalse(path.contains(point, using: .winding), "point \(i)")
        }
    }

    func testContainsCircleWithHole() {
        let rect1 = CGRect(origin: CGPoint(x: -3, y: -3), size: CGSize(width: 6, height: 6))
        let circlePath = Path(cgPath: CGPath(ellipseIn: rect1, transform: nil))
        let rect2 = CGRect(origin: CGPoint(x: -1, y: -1), size: CGSize(width: 2, height: 2))
        let reversedCirclePath = Path(cgPath: CGPath(ellipseIn: rect2, transform: nil)).reversed()
        let circleWithHole = Path(components: circlePath.components + reversedCirclePath.components)
        XCTAssertFalse(circleWithHole.contains(CGPoint(x: 0.0, y: 0.0), using: .evenOdd))
        XCTAssertFalse(circleWithHole.contains(CGPoint(x: 0.0, y: 0.0), using: .winding))
        XCTAssertTrue(circleWithHole.contains(CGPoint(x: 2.0, y: 0.0), using: .evenOdd))
        XCTAssertTrue(circleWithHole.contains(CGPoint(x: 2.0, y: 0.0), using: .winding))
        XCTAssertFalse(circleWithHole.contains(CGPoint(x: 4.0, y: 0.0), using: .evenOdd))
        XCTAssertFalse(circleWithHole.contains(CGPoint(x: 4.0, y: 0.0), using: .winding))
    }

    func testContainsCornerCase() {
        let cgPath = CGMutablePath()
        let points = [CGPoint(x: 0, y: 0),
                      CGPoint(x: 2, y: 1),
                      CGPoint(x: 1, y: 3),
                      CGPoint(x: -1, y: 2)]
        cgPath.addLines(between: points)
        cgPath.closeSubpath()
        let rotatedSquare = Path(cgPath: cgPath)
        // the square is rotated such that a horizontal line extended from `point1` or `point2` intersects the square
        // at an edge on one side but a corner on the other. If corners aren't handled correctly things can go wrong
        let squareCenter = CGPoint(x: 0.5, y: 0.5)
        let point1 = CGPoint(x: -0.75, y: 1)
        let point2 = CGPoint(x: 1.75, y: 2)
        XCTAssertTrue(rotatedSquare.contains(squareCenter))
        XCTAssertFalse(rotatedSquare.contains(point1))
        XCTAssertFalse(rotatedSquare.contains(point2))
    }

    func testContainsRealWorldEdgeCase() {
        // an edge case which caused errors in practice because (rare!) line-curve intersections are found when bounding boxes do not even overlap
        let point = CGPoint(x: 281.2936999253952, y: 221.7262912473492)
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 210.32116840649363, y: 106.4029658046467))
        cgPath.addLine(to: CGPoint(x: 195.80672765188274, y: 106.4029658046467))
        cgPath.addLine(to: CGPoint(x: 195.80672765188274, y: 221.7262912473492))
        cgPath.addLine(to: CGPoint(x: 273.5510327577471, y: 221.72629124734914)) // !!! precision issues comes from fact line is almost, but not perfectly horizontal
        cgPath.addCurve(to: CGPoint(x: 271.9933072984535, y: 214.38053683325302),
                        control1: CGPoint(x: 273.05768924540223, y: 219.26088569867528),
                        control2: CGPoint(x: 272.5391291486813, y: 216.81119916319818))
        cgPath.addCurve(to: CGPoint(x: 252.80681257385964, y: 162.18313232371986),
                        control1: CGPoint(x: 267.39734333475377, y: 195.3589483577662),
                        control2: CGPoint(x: 260.947626989152, y: 177.936810624913))
        cgPath.addCurve(to: CGPoint(x: 215.4444979991486, y: 111.76311400605556),
                        control1: CGPoint(x: 242.1552743057946, y: 142.6678463672315),
                        control2: CGPoint(x: 229.03183407884012, y: 126.09450622380493))
        cgPath.addCurve(to: CGPoint(x: 210.32116840649363, y: 106.4029658046467),
                        control1: CGPoint(x: 213.72825408056033, y: 109.93389850557801),
                        control2: CGPoint(x: 212.02163105179878, y: 108.14905966376985))
        let path = Path(cgPath: cgPath)

        XCTAssertFalse(path.boundingBox.contains(point)) // the point is not even in the bounding box of the path!
        XCTAssertFalse(path.contains(point, using: .evenOdd))
        XCTAssertFalse(path.contains(point, using: .winding))
    }

    func testContainsRealWorldEdgeCase2() {
        // this tests a real-world issue with contains. The y-coordinate of the point we are testing
        // is very close to one of our control points, which causes an intersection at t=1 *however*
        // there would be corresponding intersection with the next element at t=0
        let circlePath = Path(cgPath: {() -> CGPath in
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 388.21266053072026, y: 461.1978951725547))
            path.addCurve(to: CGPoint(x: 368.8204391162164, y: 479.3753548709112),
                          control1: CGPoint(x: 387.87721334546706, y: 471.5724761398741),
                          control2: CGPoint(x: 379.1950200835358, y: 479.7108020561644))

            path.addCurve(to: CGPoint(x: 350.64297941785986, y: 459.98313345640736),
                          control1: CGPoint(x: 358.445858148897, y: 479.039907685658),
                          control2: CGPoint(x: 350.30753223260666, y: 470.35771442372675))
            path.addCurve(to: CGPoint(x: 370.0352008323637, y: 441.80567375805083),
                          control1: CGPoint(x: 350.97842660311306, y: 449.60855248908797),
                          control2: CGPoint(x: 359.66061986504434, y: 441.4702265727976))
            path.addCurve(to: CGPoint(x: 388.21266053072026, y: 461.1978951725547),
                          control1: CGPoint(x: 380.4097817996831, y: 442.14112094330403),
                          control2: CGPoint(x: 388.54810771597346, y: 450.8233142052353))
            return path
        }())

        XCTAssertTrue(circlePath.contains( CGPoint(x: 369, y: 459), using: .evenOdd))
        XCTAssertTrue(circlePath.contains( CGPoint(x: 369, y: 459.9832416054124), using: .evenOdd)) // this is one that would fail in practice
        XCTAssertTrue(circlePath.contains( CGPoint(x: 369, y: 458.9832416054124), using: .evenOdd))
    }

    func testContainsRealWorldEdgeCase3() {
        let point = CGPoint(x: 207, y: 60.09055464612847) // point has to be chosen carefully to fall inside path bounding box or else it's excluded trivially
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 156.96601717963904, y: 61.6108671143393))
        cgPath.addCurve(to: CGPoint(x: 158.48632964784989, y: 60.090554646128446),
                        control1: CGPoint(x: 156.96601717963904, y: 60.77122172316883),
                        control2: CGPoint(x: 157.6466842566794, y: 60.090554646128446))
        cgPath.addLine(to: CGPoint(x: 206.74971723237456, y: 60.09055464612845))
        cgPath.addCurve(to: CGPoint(x: 207.35854749702355, y: 63.13117958255016),
                        control1: CGPoint(x: 206.9591702677613, y: 61.099707571074404),
                        control2: CGPoint(x: 207.16199497250045, y: 62.11301125588949))
        cgPath.closeSubpath()
        let path = Path(cgPath: cgPath)
        XCTAssertFalse( path.contains(point, using: .evenOdd) )
    }

    func testContainsEdgeCaseParallelDerivative() {
        // this is a real-world edge case that can happen with round-rects
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 0.0, y: 1.0))
        cgPath.addQuadCurve(to: CGPoint(x: 1.0, y: 0.0), control: CGPoint(x: 0, y: 0)) // quad curve has derivative exactly horizontal at t=1
        cgPath.addLine(to: CGPoint(x: 2.0, y: -1.0e-5))
        cgPath.addLine(to: CGPoint(x: 4.0, y: 1))
        cgPath.closeSubpath()
        let path = Path(cgPath: cgPath)
        XCTAssertTrue(path.contains(CGPoint(x: 0.5, y: 0.5)))
        XCTAssertFalse(path.contains(CGPoint(x: 3.0, y: 0.0)))
    }

    func testContainsPath() {
        let rect1 = Path(cgPath: CGPath(rect: CGRect(x: 1, y: 1, width: 5, height: 5), transform: nil))
        let rect2 = Path(cgPath: CGPath(rect: CGRect(x: 2, y: 2, width: 3, height: 3), transform: nil)) // fully contained inside rect1
        let rect3 = Path(cgPath: CGPath(rect: CGRect(x: 2, y: 2, width: 5, height: 3), transform: nil)) // starts inside, but not contained in rect1
        let rect4 = Path(cgPath: CGPath(rect: CGRect(x: 7, y: 1, width: 5, height: 5), transform: nil)) // fully outside rect1
        XCTAssertTrue(rect1.contains(rect2))
        XCTAssertFalse(rect1.contains(rect3))
        XCTAssertFalse(rect1.contains(rect4))
    }

    // TODO: more tests of contains path using .winding rule and where intersections are not crossings

    // MARK: - vector boolean operations

    private func componentsEqualAsideFromElementOrdering(_ component1: PathComponent, _ component2: PathComponent) -> Bool {
        let curves1 = component1.curves
        let curves2 = component2.curves
        guard curves1.count == curves2.count else {
            return false
        }
        if curves1.isEmpty {
            return true
        }
        guard let offset = curves2.firstIndex(where: { $0 == curves1.first! }) else {
            return false
        }
        let count = curves1.count
        for i in 0..<count {
            guard curves1[i] == curves2[(i+offset) % count] else {
                return false
            }
        }
        return true
    }

    // points on the first square
    let p0 = CGPoint(x: 0.0, y: 0.0)
    let p1 = CGPoint(x: 1.0, y: 0.0) // intersection 1
    let p2 = CGPoint(x: 2.0, y: 0.0)
    let p3 = CGPoint(x: 2.0, y: 1.0) // intersection 2
    let p4 = CGPoint(x: 2.0, y: 2.0)
    let p5 = CGPoint(x: 0.0, y: 2.0)

    // points on the second square
    let p6 = CGPoint(x: 1.0, y: -1.0)
    let p7 = CGPoint(x: 3.0, y: -1.0)
    let p8 = CGPoint(x: 3.0, y: 1.0)
    let p9 = CGPoint(x: 1.0, y: 1.0)

    private func createSquare1() -> Path {
        return Path(components: [PathComponent(curves:
            [
                LineSegment(p0: p0, p1: p2),
                LineSegment(p0: p2, p1: p4),
                LineSegment(p0: p4, p1: p5),
                LineSegment(p0: p5, p1: p0)
            ]
        )])
    }

    private func createSquare2() -> Path {
        return Path(components: [PathComponent(curves:
        [
            LineSegment(p0: p6, p1: p7),
            LineSegment(p0: p7, p1: p8),
            LineSegment(p0: p8, p1: p9),
            LineSegment(p0: p9, p1: p6)
        ]
    )])
    }

    func testSubtracting() {
        let expectedResult = Path(components: [PathComponent(curves:
            [
                LineSegment(p0: p1, p1: p9),
                LineSegment(p0: p9, p1: p3),
                LineSegment(p0: p3, p1: p4),
                LineSegment(p0: p4, p1: p5),
                LineSegment(p0: p5, p1: p0),
                LineSegment(p0: p0, p1: p1)
            ]
        )])
        let square1 = createSquare1()
        let square2 = createSquare2()
        let subtracted = square1.subtract(square2)
        XCTAssertEqual(subtracted.components.count, 1)
        XCTAssert(
            componentsEqualAsideFromElementOrdering(subtracted.components[0], expectedResult.components[0])
        )
    }

    func testSubtractingWinding() {
        // subtracting should use .evenOdd fill, if it doesn't this test can *add* an inner square instead of doing nothing
        let path = Path(cgPath: {
            let cgPath = CGMutablePath()
            cgPath.addRect(CGRect(x: 0, y: 0, width: 5, height: 5))
            cgPath.addRect(CGRect(x: 1, y: 1, width: 3, height: 3))
            return cgPath
        }())
        let subtractionPath = Path(cgPath: CGPath(rect: CGRect(x: 2, y: 2, width: 1, height: 1), transform: nil))
        XCTAssertFalse(path.contains(subtractionPath, using: .evenOdd)) // subtractionPath exists in the path's hole, path doesn't contain it
        XCTAssertTrue(path.contains(subtractionPath, using: .winding)) // but it *does* contain it using .winding rule
        let result = path.subtract(subtractionPath) // since `subtract` uses .evenOdd rule it does nothing
        XCTAssertEqual(result, path)
    }

    func testUnion() {
        let expectedResult = Path(components: [PathComponent(curves:
            [
                LineSegment(p0: p0, p1: p1),
                LineSegment(p0: p1, p1: p6),
                LineSegment(p0: p6, p1: p7),
                LineSegment(p0: p7, p1: p8),
                LineSegment(p0: p8, p1: p3),
                LineSegment(p0: p3, p1: p4),
                LineSegment(p0: p4, p1: p5),
                LineSegment(p0: p5, p1: p0)
            ]
        )])
        let square1 = createSquare1()
        let square2 = createSquare2()
        let unioned = square1.union(square2)
        XCTAssertEqual(unioned.components.count, 1)
        XCTAssert(
            componentsEqualAsideFromElementOrdering(unioned.components[0], expectedResult.components[0])
        )
    }

    func testUnionSelf() {
        let square = createSquare1()
        let copy = square.independentCopy()
        XCTAssertEqual(square.union(square), square)
        XCTAssertEqual(square.union(copy), square)
    }

    func testUnionCoincidentEdges1() {
        // a simple test of union'ing two squares where the max/min x edge are coincident
        let square1 = Path(cgPath: CGPath(rect: CGRect(x: 0, y: 0, width: 1, height: 1), transform: nil))
        let square2 = Path(cgPath: CGPath(rect: CGRect(x: 1, y: 0, width: 1, height: 1), transform: nil))
        let expectedUnion = { () -> Path in
            let temp = CGMutablePath()
            temp.move(to: CGPoint.zero)
            temp.addLine(to: CGPoint(x: 1.0, y: 0.0))
            temp.addLine(to: CGPoint(x: 2.0, y: 0.0))
            temp.addLine(to: CGPoint(x: 2.0, y: 1.0))
            temp.addLine(to: CGPoint(x: 1.0, y: 1.0))
            temp.addLine(to: CGPoint(x: 0.0, y: 1.0))
            temp.closeSubpath()
            return Path(cgPath: temp)
        }()
        let resultUnion1 = square1.union(square2)
        XCTAssertEqual(resultUnion1.components.count, 1)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(resultUnion1.components[0], expectedUnion.components[0]))
        // check that it also works if the path is reversed
        let resultUnion2 = square1.union(square2.reversed())
        XCTAssertEqual(resultUnion2.components.count, 1)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(resultUnion2.components[0], expectedUnion.components[0]))
    }

    func testUnionCoincidentEdges2() {
        // square 2 falls inside square 1 except its maximum x edge which is coincident
        let square1 = Path(cgPath: CGPath(rect: CGRect(x: 0, y: 0, width: 3, height: 3), transform: nil))
        let square2 = Path(cgPath: CGPath(rect: CGRect(x: 2, y: 1, width: 1, height: 1), transform: nil))
        let expectedUnion = { () -> Path in
            let temp = CGMutablePath()
            temp.move(to: CGPoint.zero)
            temp.addLine(to: CGPoint(x: 3.0, y: 0.0))
            temp.addLine(to: CGPoint(x: 3.0, y: 1.0))
            temp.addLine(to: CGPoint(x: 3.0, y: 2.0))
            temp.addLine(to: CGPoint(x: 3.0, y: 3.0))
            temp.addLine(to: CGPoint(x: 0.0, y: 3.0))
            temp.closeSubpath()
            return Path(cgPath: temp)
        }()
        let result1 = square1.union(square2)
        let result2 = square2.union(square1)
        XCTAssertEqual(result1.components.count, 1)
        XCTAssertEqual(result2.components.count, 1)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(result1.components[0], expectedUnion.components[0]))
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(result2.components[0], expectedUnion.components[0]))
    }

    func testUnionCoincidentEdges3() {
        // square 2 and 3 have a partially overlapping edge
        let square1 = Path(cgPath: CGPath(rect: CGRect(x: 0, y: 0, width: 3, height: 3), transform: nil))
        let square2 = Path(cgPath: CGPath(rect: CGRect(x: 3, y: 2, width: -2, height: 2), transform: nil))
        let expectedUnion = { () -> Path in
            let temp = CGMutablePath()
            temp.move(to: CGPoint.zero)
            temp.addLine(to: CGPoint(x: 3.0, y: 0.0))
            temp.addLine(to: CGPoint(x: 3.0, y: 2.0))
            temp.addLine(to: CGPoint(x: 3.0, y: 3.0))
            temp.addLine(to: CGPoint(x: 3.0, y: 4.0))
            temp.addLine(to: CGPoint(x: 1.0, y: 4.0))
            temp.addLine(to: CGPoint(x: 1.0, y: 3.0))
            temp.addLine(to: CGPoint(x: 0.0, y: 3.0))
            temp.closeSubpath()
            return Path(cgPath: temp)
        }()
        let result1 = square1.union(square2)
        let result2 = square1.union(square2.reversed())
        XCTAssertEqual(result1.components.count, 1)
        XCTAssertEqual(result2.components.count, 1)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(result1.components[0], expectedUnion.components[0]))
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(result2.components[0], expectedUnion.components[0]))
    }

    func testUnionCoincidentEdgesRealWorldTestCase1() {
        let polygon1 = {() -> Path in
            let temp = CGMutablePath()
            temp.addLines(between: [CGPoint(x: 111.2, y: 90.0),
                                    CGPoint(x: 144.72135954999578, y: 137.02282018339787),
                                    CGPoint(x: 179.15338649848962, y: 123.08999319271176),
                                    CGPoint(x: 171.33627533401454, y: 102.89462632327792)])
            temp.closeSubpath()
            return Path(cgPath: temp)
        }()
        let polygon2 = {() -> Path in
            let temp = CGMutablePath()
            temp.addLines(between: [CGPoint(x: 144.72135954999578, y: 137.02282018339787),
                                    CGPoint(x: 89.64133022449836, y: 119.6729633084088),
                                    CGPoint(x: 160.7501485041311, y: 111.6759272531885),
                                    CGPoint(x: 179.15338649848962, y: 123.08999319271176)])
            temp.closeSubpath()
            return Path(cgPath: temp)
        }()
        // polygon 1 & 2 share two points in common
        // polygon 1's [1] point is polygon 2's [0] point
        // polygon 1's [2] point is polygon 2's [3] point
        let unionResult1 = polygon1.union(polygon2)
        XCTAssertEqual(unionResult1.components.count, 1)
        XCTAssertEqual(unionResult1.components.first?.points.count, 7)

        let unionResult2 = polygon1.union(polygon2.reversed())
        XCTAssertEqual(unionResult2.components.count, 1)
        XCTAssertEqual(unionResult2.components.first?.points.count, 7)
    }

    func testUnionCoincidentEdgesRealWorldTestCase2() {
        let star = {() -> Path in
            let temp = CGMutablePath()
            temp.move(to: CGPoint(x: 111.2, y: 90.0))
            temp.addLine(to: CGPoint(x: 144.72135954999578, y: 137.02282018339787))
            temp.addLine(to: CGPoint(x: 89.64133022449836, y: 119.6729633084088))
            temp.addLine(to: CGPoint(x: 55.27864045000421, y: 166.0845213036123))
            temp.addLine(to: CGPoint(x: 54.758669775501644, y: 108.33889987152517))
            temp.addLine(to: CGPoint(x: 0.0, y: 90.00000000000001))
            temp.addLine(to: CGPoint(x: 54.75866977550164, y: 71.66110012847484))
            temp.addLine(to: CGPoint(x: 55.2786404500042, y: 13.915478696387723))
            temp.addLine(to: CGPoint(x: 89.64133022449835, y: 60.3270366915912))
            temp.addLine(to: CGPoint(x: 144.72135954999578, y: 42.97717981660214))
            temp.closeSubpath()
            return Path(cgPath: temp)
        }()
        let polygon = {() -> Path in
            let temp = CGMutablePath()
            temp.move(to: CGPoint(x: 89.64133022449836, y: 119.6729633084088))
            temp.addLine(to: CGPoint(x: 55.27864045000421, y: 166.0845213036123)) // this is marked as an exit if the polygon isn't reversed and it's correct BUT it's unlinked to the other path(!!!)
            temp.addLine(to: CGPoint(x: 143.9588334407257, y: 125.35115333505796))
            temp.addLine(to: CGPoint(x: 160.7501485041311, y: 111.6759272531885))
            temp.closeSubpath()
            return Path(cgPath: temp)
        }()
        let unionResult1 = star.union(polygon) // ugh, yeah see reversing the polygon causes the correct vertext to be recognized as an exit
        XCTAssertEqual(unionResult1.components.count, 1)

        let unionResult2 = star.union(polygon.reversed())
        XCTAssertEqual(unionResult2.components.count, 1)
    }

    func testUnionRealWorldEdgeCase() {
        guard MemoryLayout<CGFloat>.size > 4 else { return } // not enough precision in points for test to be valid
        let a = {() -> Path in
            let cgPath = CGMutablePath()
            cgPath.move(to: CGPoint(x: 310.198127403852, y: 190.08736919846973))
            cgPath.addCurve(to: CGPoint(x: 309.1982933716744, y: 195.17240727745877),
                control1: CGPoint(x: 310.390629965343, y: 191.78584973769978),
                control2: CGPoint(x: 310.0800866088565, y: 193.5583513843498))
            cgPath.addCurve(to: CGPoint(x: 297.52638944557776, y: 198.59685279578636),
                control1: CGPoint(x: 306.9208206199371, y: 199.34114906559483),
                control2: CGPoint(x: 301.6951312337138, y: 200.87432554752368))
            cgPath.addCurve(to: CGPoint(x: 293.06807628308206, y: 191.637728075906),
                control1: CGPoint(x: 294.8541298755864, y: 197.13694026929096),
                control2: CGPoint(x: 293.26485189217163, y: 194.46557442730858))
            cgPath.addCurve(to: CGPoint(x: 293.0490061981148, y: 191.24674708897507),
                control1: CGPoint(x: 293.05884562618036, y: 191.50820426365925),
                control2: CGPoint(x: 293.0524676850055, y: 191.37785711483136))
            cgPath.addCurve(to: CGPoint(x: 301.42017404234923, y: 182.42157189005232),
                control1: CGPoint(x: 292.9236355289621, y: 186.49810808117778),
                control2: CGPoint(x: 296.67153503455194, y: 182.546942559205))
            cgPath.addCurve(to: CGPoint(x: 310.198127403852, y: 190.08736919846973),
                control1: CGPoint(x: 305.9310607601042, y: 182.30247821176928),
                control2: CGPoint(x: 309.72232986751203, y: 185.6785144367646))
            return Path(cgPath: cgPath)
        }()
        let b = {() -> Path in
            let cgPath = CGMutablePath()
            cgPath.move(to: CGPoint(x: 309.5688043100249, y: 187.66446326122298))
            cgPath.addCurve(to: CGPoint(x: 304.8877314421214, y: 198.89156106846605),
                            control1: CGPoint(x: 311.37643918302956, y: 192.05738329201742),
                            control2: CGPoint(x: 309.28065147291585, y: 197.0839261954614))
            cgPath.addCurve(to: CGPoint(x: 293.6606336348783, y: 194.21048820056248),
                            control1: CGPoint(x: 300.4948114113269, y: 200.6991959414707),
                            control2: CGPoint(x: 295.46826850788295, y: 198.60340823135695))
            cgPath.addCurve(to: CGPoint(x: 298.3417065027818, y: 182.98339039331944),
                            control1: CGPoint(x: 291.85299876187366, y: 189.81756816976807),
                            control2: CGPoint(x: 293.9487864719874, y: 184.79102526632408))
            cgPath.addCurve(to: CGPoint(x: 309.5688043100249, y: 187.66446326122298),
                            control1: CGPoint(x: 302.7346265335763, y: 181.1757555203148),
                            control2: CGPoint(x: 307.76116943702027, y: 183.2715432304285))
            return Path(cgPath: cgPath)
        }()
        let result = a.union(b, accuracy: 1.0e-4)
        let point = CGPoint(x: 302, y: 191)
        let rule = PathFillRule.evenOdd
        XCTAssertTrue(a.contains(point, using: rule))
        XCTAssertTrue(b.contains(point, using: rule))
        XCTAssertTrue(result.contains(point, using: rule), "a union b should contain point that is in both a and b")
        XCTAssertTrue(result.boundingBox.cgRect.insetBy(dx: -1, dy: -1).contains(a.boundingBox.cgRect), "resulting bounding box should contain a.boundingBox")
        XCTAssertTrue(result.boundingBox.cgRect.insetBy(dx: -1, dy: -1).contains(b.boundingBox.cgRect), "resulting bounding box should contain b.boundingBox")
    }

    func testIntersecting() {
        let expectedResult = Path(components: [PathComponent(curves:
            [
                LineSegment(p0: p1, p1: p2),
                LineSegment(p0: p2, p1: p3),
                LineSegment(p0: p3, p1: p9),
                LineSegment(p0: p9, p1: p1)
            ]
        )])
        let square1 = createSquare1()
        let square2 = createSquare2()
        let intersected = square1.intersect(square2)
        XCTAssertEqual(intersected.components.count, 1)
        XCTAssert(
            componentsEqualAsideFromElementOrdering(intersected.components[0], expectedResult.components[0])
        )
    }

    func testIntersectingSelf() {
        let square = createSquare1()
        XCTAssertEqual(square.intersect(square), square)
        XCTAssertEqual(square.intersect(square.independentCopy()), square)
    }

    func testSubtractingSelf() {
        let square = createSquare1()
        let expectedResult = Path()
        XCTAssertEqual(square.subtract(square), expectedResult)
        XCTAssertEqual(square.subtract(square.independentCopy()), expectedResult)
    }

    func testSubtractingWindingDirection() {
        // this is a specific test of `subtracting` to ensure that when a component creates a "hole"
        // the order of the hole is reversed so that it is not contained in the shape when using .winding fill rule
        let circle   = Path(cgPath: CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 3, height: 3), transform: nil))
        let hole     = Path(cgPath: CGPath(ellipseIn: CGRect(x: 1, y: 1, width: 1, height: 1), transform: nil))
        let donut    = circle.subtract(hole)
        XCTAssertTrue(donut.contains(CGPoint(x: 0.5, y: 0.5), using: .winding))  // inside the donut (but not the hole)
        XCTAssertFalse(donut.contains(CGPoint(x: 1.5, y: 1.5), using: .winding)) // center of donut hole
    }

    func testSubtractingEntirelyErased() {
        // this is a specific test of `subtracting` to ensure that if a path component is entirely contained in the subtracting path that it gets removed
        let circle       = Path(cgPath: CGPath(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2), transform: nil))
        let biggerCircle = Path(cgPath: CGPath(ellipseIn: CGRect(x: -2, y: -2, width: 4, height: 4), transform: nil))
        XCTAssert(circle.subtract(biggerCircle).isEmpty)
    }

    func testSubtractingEdgeCase1() {
        // this is a specific edge case test of `subtracting`. There was an issue where if a path element intersected at the exact border between
        // two elements on the other path it would count as two intersections. The winding count would then be incremented twice on the way in
        // but only once on the way out. So the entrance would be recognized but the exit not recognized.

        let rectangle = Path(cgPath: CGPath(rect: CGRect(x: -1, y: -1, width: 4, height: 3), transform: nil))
        let circle    = Path(cgPath: CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 4, height: 4), transform: nil))

        // the circle intersects the rect at (0,2) and (3, 0.26792) ... the last number being exactly 2 - sqrt(3)
        let difference = rectangle.subtract(circle)
        XCTAssertEqual(difference.components.count, 1)
        XCTAssertFalse(difference.contains(CGPoint(x: 2.0, y: 2.0)))
    }

    func testSubtractingEdgeCase2() {

        // this unit test demosntrates an issue that came up in development where the logic for the winding direction
        // when corners intersect was not quite correct.

        let square1 = Path(cgPath: CGPath(rect: CGRect(x: 0.0, y: 0.0, width: 2.0, height: 2.0), transform: nil))
        let square2CGPath = CGMutablePath()
        square2CGPath.move(to: CGPoint.zero)
        square2CGPath.addLine(to: CGPoint(x: 1.0, y: -1.0))
        square2CGPath.addLine(to: CGPoint(x: 2.0, y: 0.0))
        square2CGPath.addLine(to: CGPoint(x: 1.0, y: 1.0))
        square2CGPath.closeSubpath()

        let square2 = Path(cgPath: square2CGPath)
        let result = square1.subtract(square2)

        let expectedResultCGPath = CGMutablePath()
        expectedResultCGPath.move(to: CGPoint.zero)
        expectedResultCGPath.addLine(to: CGPoint(x: 1.0, y: 1.0))
        expectedResultCGPath.addLine(to: CGPoint(x: 2.0, y: 0.0))
        expectedResultCGPath.addLine(to: CGPoint(x: 2.0, y: 2.0))
        expectedResultCGPath.addLine(to: CGPoint(x: 0.0, y: 2.0))
        expectedResultCGPath.closeSubpath()

        let expectedResult = Path(cgPath: expectedResultCGPath)

        XCTAssertEqual(result.components.count, expectedResult.components.count)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(result.components[0], expectedResult.components[0]))
    }

    func testCrossingsRemoved() {
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 3, y: 0),
            CGPoint(x: 3, y: 3),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 2, y: 1),
            CGPoint(x: 0, y: 3),
            CGPoint(x: 0, y: 0)
        ]
        let cgPath = CGMutablePath()
        cgPath.addLines(between: points)
        cgPath.closeSubpath()
        let path = Path(cgPath: cgPath)
        let intersection = CGPoint(x: 1.5, y: 1.5)

        let expectedResultCGPath = CGMutablePath()
        expectedResultCGPath.addLines(between: [points[0], points[1], points[2], intersection, points[5]])
        expectedResultCGPath.closeSubpath()
        let expectedResult = Path(cgPath: expectedResultCGPath)

        XCTAssertTrue(path.contains(CGPoint(x: 1.5, y: 1.25), using: .winding))
        XCTAssertFalse(path.contains(CGPoint(x: 1.5, y: 1.25), using: .evenOdd))

        let result = path.crossingsRemoved()
        XCTAssertEqual(result.components.count, 1)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(result.components[0], expectedResult.components[0]))

        // check also that the algorithm works when the first point falls *inside* the path
        let cgPathAlt = CGMutablePath()
        cgPathAlt.addLines(between: Array(points[3..<points.count]) + Array(points[1...3]))
        let pathAlt = Path(cgPath: cgPathAlt)

        let resultAlt = pathAlt.crossingsRemoved()
        XCTAssertEqual(resultAlt.components.count, 1)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(resultAlt.components[0], expectedResult.components[0]))
    }

    func testCrossingsRemovedNoCrossings() {
        // a test which ensures that if a path has no crossings then crossingsRemoved does not modify it
        let square = Path(cgPath: CGPath(ellipseIn: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0), transform: nil))
        let result = square.crossingsRemoved()
        XCTAssertEqual(result.components.count, 1)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(result.components[0], square.components[0]))
    }

    func testCrossingsRemovedEdgeCase() {
        // this is an edge cases which caused difficulty in practice
        // the contour, which intersects at (1,1) creates two squares, one with -1 winding count
        // the other with +1 winding count
        // incorrect implementation of this algorithm previously interpretted
        // the crossing as an entry / exit, which would completely cull off the square with +1 count

        let points = [CGPoint(x: 0, y: 1),
                      CGPoint(x: 1, y: 1),
                      CGPoint(x: 2, y: 1),
                      CGPoint(x: 2, y: 2),
                      CGPoint(x: 1, y: 2),
                      CGPoint(x: 1, y: 1),
                      CGPoint(x: 1, y: 0),
                      CGPoint(x: 0, y: 0)]

        let cgPath = CGMutablePath()
        cgPath.addLines(between: points)
        cgPath.closeSubpath()

        let contour = Path(cgPath: cgPath)
        XCTAssertEqual(contour.windingCount(CGPoint(x: 0.5, y: 0.5)), -1) // winding count at center of one square region
        XCTAssertEqual(contour.windingCount(CGPoint(x: 1.5, y: 1.5)), 1) // winding count at center of other square region

        let crossingsRemoved = contour.crossingsRemoved()

        XCTAssertEqual(crossingsRemoved.components.count, 1)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(crossingsRemoved.components[0], contour.components[0]))
    }

    func testCrossingsRemovedEdgeCaseInnerLoop() {

        // the path is a box with a loop that begins at (2,0), touches the top of the box at (2,2) exactly tangent
        // this tests an edge case of crossingsRemoved() when vertices of the path are exactly equal
        // the path does a complete loop in the middle

        let cgPath = CGMutablePath()

        cgPath.move(to: CGPoint.zero)
        cgPath.addLine(to: CGPoint(x: 2.0, y: 0.0))

        // loop in a complete circle back to 2, 0
        cgPath.addArc(tangent1End: CGPoint(x: 3.0, y: 0.0), tangent2End: CGPoint(x: 3.0, y: 1.0), radius: 1)
        cgPath.addArc(tangent1End: CGPoint(x: 3.0, y: 2.0), tangent2End: CGPoint(x: 2.0, y: 2.0), radius: 1)
        cgPath.addArc(tangent1End: CGPoint(x: 1.0, y: 2.0), tangent2End: CGPoint(x: 1.0, y: 1.0), radius: 1)
        cgPath.addArc(tangent1End: CGPoint(x: 1.0, y: 0.0), tangent2End: CGPoint(x: 2.0, y: 0.0), radius: 1)

        // proceed around to close the shape (grazing the loop at (2,2)
        cgPath.addLine(to: CGPoint(x: 4.0, y: 0.0))
        cgPath.addLine(to: CGPoint(x: 4.0, y: 2.0))
        cgPath.addLine(to: CGPoint(x: 2.0, y: 2.0))
        cgPath.addLine(to: CGPoint(x: 0.0, y: 2.0))
        cgPath.closeSubpath()

        let path = Path(cgPath: cgPath)

        // Quartz 'addArc' function creates some terrible near-zero length line segments
        // let's eliminate those
        let curves2 = path.components[0].curves.map {
            return type(of: $0).init(points: $0.points.map { point in
                let rounded = CGPoint(x: round(point.x), y: round(point.y))
                return distance(point, rounded) < 1.0e-3 ? rounded : point
            })
        }.filter { $0.length() > 0.0 }
        let cleanPath = Path(components: [PathComponent(curves: curves2)])

        let result = cleanPath.crossingsRemoved(accuracy: 1.0e-4)

        // check that the inner loop was eliminated by checking the winding count in the middle
        XCTAssertEqual(result.windingCount(CGPoint(x: 0.5, y: 1)), 1)
        XCTAssertEqual(result.windingCount(CGPoint(x: 2.0, y: 1)), 1) // if the inner loop wasn't eliminated we'd have a winding count of 2 here
        XCTAssertEqual(result.windingCount(CGPoint(x: 3.5, y: 1)), 1)
    }

    func testCrossingsRemovedRealWorldEdgeCaseMagicNumbers() {
        // in practice this data was failing because 'smallNumber', a magic number in augmented graph was too large
        // it was fixed by decreasing the value by 10x
        let cgPath = CGMutablePath()
        let start = CGPoint(x: 79.59559290956605, y: 697.9008011912572)
        cgPath.move(to: start)
        cgPath.addCurve(to: CGPoint(x: 71.31576744881897, y: 729.0705310397749), control1: CGPoint(x: 85.91646553575535, y: 708.7944954952286), control2: CGPoint(x: 82.2094612873204, y: 722.7496586836662))
        cgPath.addCurve(to: CGPoint(x: 40.14603795970622, y: 720.7907053704894), control1: CGPoint(x: 60.4220735042526, y: 735.3914034574259), control2: CGPoint(x: 46.46691031581487, y: 731.6843992089908))
        cgPath.addCurve(to: CGPoint(x: 37.21144227099133, y: 706.7177736592248), control1: CGPoint(x: 39.07549105339858, y: 718.7074812854011), control2: CGPoint(x: 37.21110624960683, y: 711.947464952338))
        cgPath.addCurve(to: CGPoint(x: 62.477966856736, y: 686.6750666235641), control1: CGPoint(x: 38.65395965539626, y: 694.2059748336982), control2: CGPoint(x: 49.96616803120935, y: 685.2325492391592))
        cgPath.addCurve(to: CGPoint(x: 82.52067606376023, y: 711.9415914596509), control1: CGPoint(x: 74.98976785362623, y: 688.1175842583111), control2: CGPoint(x: 83.96319344816517, y: 699.4297926341243))
        cgPath.addCurve(to: start, control1: CGPoint(x: 82.51999960076027, y: 706.7206820370851), control2: CGPoint(x: 80.65889482357387, y: 699.9715389099819))
        let path = Path(cgPath: cgPath)
        let result = path.crossingsRemoved(accuracy: 0.01)
         // in practice .crossingsRemoved was cutting off most of the shape
        XCTAssertEqual(path.boundingBox.size.x, result.boundingBox.size.x, accuracy: 1.0e-3)
        XCTAssertEqual(path.boundingBox.size.y, result.boundingBox.size.y, accuracy: 1.0e-3)
        XCTAssertEqual(result.components[0].numberOfElements, 5) // with crossings removed we should have 1 fewer curve (the last one)
    }

    func testCrossingsRemovedAnotherRealWorldCase() {

        guard MemoryLayout<CGFloat>.size > 4 else { return } // not enough precision in points for test to be valid

        let cgPath = CGMutablePath()
        let start = CGPoint(x: 503.3060153966664, y: 766.9140612367046)
        cgPath.move(to: start)
        cgPath.addCurve(to: CGPoint(x: 517.9306651149989, y: 762.0523534483476),
                        control1: CGPoint(x: 506.0019772976378, y: 761.5330522602719),
                        control2: CGPoint(x: 512.5496560294043, y: 759.3563914926846))
        cgPath.addCurve(to: CGPoint(x: 522.7923732205169, y: 776.6770033255823),
                        control1: CGPoint(x: 523.3116744085926, y: 764.7483155082213),
                        control2: CGPoint(x: 525.4883351761798, y: 771.2959942399877))
        cgPath.addCurve(to: CGPoint(x: 520.758836935199, y: 764.316674774872),
                        control1: CGPoint(x: 522.6619398993569, y: 776.9550303733141), control2: CGPoint(x: 522.7228057838222, y: 776.8532852161298))
        cgPath.addCurve(to: CGPoint(x: 520.6170414159213, y: 779.7723863761416),
                        control1: CGPoint(x: 524.9876580913353, y: 768.6238074338997), control2: CGPoint(x: 524.9241740749491, y: 775.5435652200052))
        cgPath.addCurve(to: CGPoint(x: 505.16132944417086, y: 779.6305912206088),
                        control1: CGPoint(x: 516.3099083864128, y: 784.001207896023),
                        control2: CGPoint(x: 509.3901506003072, y: 783.9377238796366))
        cgPath.addCurve(to: start, control1: CGPoint(x: 503.19076843492786, y: 767.0872665416827), control2: CGPoint(x: 503.3761460381431, y: 766.7563954079359))
        let path = Path(cgPath: cgPath)
        let result = path.crossingsRemoved(accuracy: 1.0e-5)
        // in practice .crossingsRemoved was cutting off most of the shape
        XCTAssertEqual(path.boundingBox.size.x, result.boundingBox.size.x, accuracy: 1.0e-3)
        XCTAssertEqual(path.boundingBox.size.y, result.boundingBox.size.y, accuracy: 1.0e-3)
    }

    func testCrossingsRemovedThirdRealWorldCase() {
        let cgPath = CGMutablePath()
        let points = [CGPoint(x: 115.23034681147224, y: 59.327037989273855),
                      CGPoint(x: 130.4334714935808, y: 59.32703798927386),
                      CGPoint(x: 130.4334714935808, y: 215.00646454457666),
                      CGPoint(x: 115.23034681147224, y: 215.00646454457666),
                      CGPoint(x: 115.23034681147222, y: 82.92265451611944)
                      ]
        cgPath.addLines(between: points)
        cgPath.closeSubpath()

        cgPath.move(to: CGPoint(x: 130.4334714935808, y: 59.32703798927387))
        cgPath.addLine(to: CGPoint(x: 130.43347149358078, y: 82.92265451611945))
        cgPath.addLine(to: CGPoint(x: 130.4334714935808, y: 215.00646454457666))
        cgPath.addCurve(to: CGPoint(x: 115.23034681147224, y: 215.00646454457666),
                        control1: CGPoint(x: 130.4334714935808, y: 225.1418809993157),
                        control2: CGPoint(x: 115.23034681147224, y: 225.1418809993157))
        cgPath.addLine(to: CGPoint(x: 115.23034681147224, y: 59.32703798927386))
        cgPath.addCurve(to: CGPoint(x: 130.4334714935808, y: 59.32703798927387),
                        control1: CGPoint(x: 115.23034681147224, y: 49.19162153453482),
                        control2: CGPoint(x: 130.4334714935808, y: 49.19162153453483))

        let p = Path(cgPath: cgPath)
        _ = p.crossingsRemoved(accuracy: 0.0001)
    }

    func testCrosingsRemovedFourthRealWorldCase() {
        // this case was cauesd by a curve that self-intersected which caused us to make the wrong determination
        // classifying which parts of the path should be included in the final result
        let cgPath = CGMutablePath()
        let firstPoint = CGPoint(x: 128.65039465906003, y: 123.73954643229627)
        cgPath.move(to: firstPoint)
        cgPath.addCurve(to: CGPoint(x: 116.95134864827014, y: 123.73672125818112), control1: CGPoint(x: 125.4190121591063, y: 126.96936863167058), control2: CGPoint(x: 120.18117084764445, y: 126.96810375813484))
        cgPath.addCurve(to: CGPoint(x: 116.95417382238529, y: 112.03767524739123), control1: CGPoint(x: 113.72152644889583, y: 120.5053387582274), control2: CGPoint(x: 113.72279132243156, y: 115.26749744676555))
        cgPath.addCurve(to: CGPoint(x: 117.06818455296886, y: 111.94933998303057), control1: CGPoint(x: 119.3560792543184, y: 110.34087389676174), control2: CGPoint(x: 120.25529993069892, y: 109.98254275757822))
        cgPath.addCurve(to: CGPoint(x: 128.80664909167646, y: 111.95922916966808), control1: CGPoint(x: 120.31240285203181, y: 108.71058333093575), control2: CGPoint(x: 125.56789243958164, y: 108.71501087060513))
        cgPath.addCurve(to: CGPoint(x: 128.79675990503895, y: 123.69769370837568), control1: CGPoint(x: 132.04540574377128, y: 115.20344746873103), control2: CGPoint(x: 132.0409782041019, y: 120.45893705628086))
        cgPath.addCurve(to: firstPoint, control1: CGPoint(x: 125.59151708590264, y: 125.68258785765616), control2: CGPoint(x: 126.31169113142379, y: 125.37317639620701))
        let path = Path(cgPath: cgPath)
        let result = path.crossingsRemoved(accuracy: 1.0e-4)
        let point1 = CGPoint(x: 128.50258215906004, y: 123.86146049479626)
        let point2 = CGPoint(x: 128.64870715906002, y: 123.77228080729627)
        let point3 = CGPoint(x: 127.29466809656003, y: 124.65276518229626)
        XCTAssertEqual(result.components.count, 2, "result should be a path with a hole")
        XCTAssertTrue(result.contains(point1, using: .evenOdd))
        XCTAssertTrue(result.contains(point2, using: .evenOdd))
        XCTAssertFalse(result.contains(point3, using: .evenOdd))
    }

    func testCrossingsRemovedMulticomponent() {
        // this path is a square with a self-intersecting inner region that should form a square shaped hole when crossings
        // this is similar to what happens if you use CoreGraphics to stroke shape, albeit simplified here for the sake of testing
        let cgPath = CGMutablePath()
        cgPath.addRect(CGRect(x: 0, y: 0, width: 5, height: 5))
        let points: [CGPoint] = [
            CGPoint(x: 1, y: 2),
            CGPoint(x: 2, y: 1),
            CGPoint(x: 2, y: 4),
            CGPoint(x: 1, y: 3),
            CGPoint(x: 4, y: 3),
            CGPoint(x: 3, y: 4),
            CGPoint(x: 3, y: 1),
            CGPoint(x: 4, y: 2)
        ]
        cgPath.addLines(between: points)
        cgPath.closeSubpath()
        let path = Path(cgPath: cgPath)
        let result = path.crossingsRemoved()

        let expectedResult = Path(cgPath: { () -> CGPath in
            let cgPath = CGMutablePath()
            cgPath.addRect(CGRect(x: 0, y: 0, width: 5, height: 5))
            cgPath.addLines(between: [
                CGPoint(x: 2, y: 2),
                CGPoint(x: 2, y: 3),
                CGPoint(x: 3, y: 3),
                CGPoint(x: 3, y: 2)
            ])
            cgPath.closeSubpath()
            return cgPath
        }())

        XCTAssertEqual(result.components.count, 2)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(result.components[0], expectedResult.components[0]))
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(result.components[1], expectedResult.components[1]))
    }

    func testCrossingsRemovedMulticomponentCoincidentEdgeRealWorldIssue() {
        let points1: [CGPoint] = [
            CGPoint(x: 306.7644175272825, y: 37.62048178369263),
            CGPoint(x: 306.7644175272825, y: 39.90095048600892),
            CGPoint(x: 304.4839488249662, y: 39.90095048600892),
            CGPoint(x: 304.4010007151713, y: 37.61425955635238),
            CGPoint(x: 306.7644175272825, y: 37.62048178369263)
        ]
        let points2: [CGPoint] = [
            CGPoint(x: 304.5969784942766, y: 37.514703918908296),
            CGPoint(x: 306.87744719659287, y: 37.514703918908296),
            CGPoint(x: 306.87744719659287, y: 39.79517262122458),
            CGPoint(x: 306.7644175272825, y: 39.90095048600892),
            CGPoint(x: 304.4839488249662, y: 39.90095048600892),
            CGPoint(x: 304.4839488249662, y: 37.62048178369263),
            CGPoint(x: 304.5969784942766, y: 37.514703918908296)
        ]
        let path = { () -> Path in
            let temp = CGMutablePath()
            temp.addLines(between: points1)
            temp.addLines(between: points2)
            return Path(cgPath: temp)
        }()
        let result = path.crossingsRemoved(accuracy: 0.0001)
        XCTAssertEqual(result.components.count, 1)
        // in practice we had an issue where this came out to be 9 instead of 7
        // where the coincident line shared between the component was followed a 2nd time (+1)
        // and then to recover from the error we jumped back (+1 again)
        // this was because although a `union` between two paths would exclude coincident edges
        // doing crossings removed would not.
        XCTAssertEqual(result.components.first?.numberOfElements, 7)
    }

    func testCrossingsRemovedRealWorldInfiniteLoop() {

        // in testing this data previously caused an infinite loop in AgumentedGraph.booleanOperation(_:)

        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 431.2394694928875, y: 109.81690300533613))
        cgPath.addCurve(to: CGPoint(x: 430.66935231730844, y: 110.3870201809152),
                        control1: CGPoint(x: 431.2394694928875, y: 110.13177002702506),
                        control2: CGPoint(x: 430.9842193389974, y: 110.3870201809152))
        cgPath.addLine(to: CGPoint(x: 382.89122776801867, y: 110.3870201809152))
        cgPath.addLine(to: CGPoint(x: 383.46134494359774, y: 109.81690300533613))
        cgPath.addLine(to: CGPoint(x: 383.46134494359774, y: 125.44498541142156))
        cgPath.addLine(to: CGPoint(x: 382.89122776801867, y: 124.87486823584248))
        cgPath.addLine(to: CGPoint(x: 430.66935231730844, y: 124.87486823584248))
        cgPath.addLine(to: CGPoint(x: 430.09923514172937, y: 125.44498541142156))
        cgPath.addLine(to: CGPoint(x: 430.09923514172937, y: 99.92396144754883))
        cgPath.addLine(to: CGPoint(x: 431.2394694928875, y: 99.92396144754883))
        cgPath.closeSubpath()

        cgPath.move(to: CGPoint(x: 430.09923514172937, y: 109.81690300533613))
        cgPath.addLine(to: CGPoint(x: 430.09923514172937, y: 99.92396144754883))
        cgPath.addCurve(to: CGPoint(x: 431.2394694928875, y: 99.92396144754883),
                        control1: CGPoint(x: 430.09923514172937, y: 99.16380521344341),
                        control2: CGPoint(x: 431.2394694928875, y: 99.16380521344341))
        cgPath.addLine(to: CGPoint(x: 431.2394694928875, y: 125.44498541142156))
        cgPath.addCurve(to: CGPoint(x: 430.66935231730844, y: 126.01510258700063),
                        control1: CGPoint(x: 431.2394694928875, y: 125.75985243311048),
                        control2: CGPoint(x: 430.9842193389974, y: 126.01510258700063))
        cgPath.addLine(to: CGPoint(x: 382.89122776801867, y: 126.01510258700063))
        cgPath.addCurve(to: CGPoint(x: 382.3211105924396, y: 125.44498541142156),
                        control1: CGPoint(x: 382.5763607463297, y: 126.01510258700063),
                        control2: CGPoint(x: 382.3211105924396, y: 125.75985243311048))
        cgPath.addLine(to: CGPoint(x: 382.3211105924396, y: 109.81690300533613))
        cgPath.addCurve(to: CGPoint(x: 382.89122776801867, y: 109.24678582975706),
                        control1: CGPoint(x: 382.3211105924396, y: 109.5020359836472),
                        control2: CGPoint(x: 382.5763607463297, y: 109.24678582975706))
        cgPath.addLine(to: CGPoint(x: 430.66935231730844, y: 109.24678582975706))
        cgPath.closeSubpath()

        let path = Path(cgPath: cgPath)
        _ = path.crossingsRemoved(accuracy: 0.01)

        // for now the test's only expectation is that we do not go into an infinite loop
        // TODO: make test stricter
    }

//    func testIntersectingOpenPath() {
//        // an open path intersecting a closed path should remove the region outside the closed path
//    }
//
//    func testUnionOpenPath() {
//        // union'ing with an open path simply appends the open components (for now)
//    }
//
//    func testSubtractingOpenPath() {
//        // an open path minus a closed path should remove the region inside the closed path
//
//        let openPath = Path(curve: CubicCurve(p0: CGPoint(x: 1, y: 1),
//                                              p1: CGPoint(x: 2, y: 2),
//                                              p2: CGPoint(x: 4, y: 0),
//                                              p3: CGPoint(x: 5, y: 1)))
//        let closedPath = Path(cgPath: CGPath(rect: CGRect(x: 0, y: 0, width: 2, height: 2), transform: nil))
//
//        //let subtractionResult = openPath.subtract(closedPath, accuracy: 1.0e-5)
//
//        // intersects at t = 0.27254795438823776
//
//        let intersections = openPath.intersections(with: closedPath, accuracy: 1.0e-10).map { openPath.point(at: $0.indexedPathLocation1)}
//        print(intersections)
//        #warning("this test just prints stuff?")
//    }

    func testOffset() {
        let circle = Path(cgPath: CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 2, height: 2), transform: nil)) // ellipse with radius 1 centered at 1,1
        let offsetCircle = circle.offset(distance: -1) // should be roughly an ellipse with radius 2
        XCTAssertEqual(offsetCircle.components.count, 1)
        // make sure that the offsetting process created a series of elements that is *contiguous*
        let component = offsetCircle.components.first!
        let elementCount = component.numberOfElements
        for i in 0..<elementCount {
            XCTAssertEqual(component.element(at: i).endingPoint, component.element(at: (i+1) % elementCount).startingPoint)
        }
        // make sure that the offset circle is a actually circle, or, well, close to one
        let expectedRadius: CGFloat = 2.0
        let expectedCenter = CGPoint(x: 1.0, y: 1.0)
        for i in 0..<offsetCircle.components[0].numberOfElements {
            let c = offsetCircle.components[0].element(at: i)
            for p in c.lookupTable(steps: 10) {
                let radius = distance(p, expectedCenter)
                let percentError = 100.0 * abs(radius - expectedRadius) / expectedRadius
                XCTAssert(percentError < 0.1, "expected offset circle to have radius \(expectedRadius), but there's a point distance \(distance(p, expectedCenter)) from the expected center.")
            }
        }
    }

    func testOffsetDegenerate() {
        // this can actually happen in practice if the path is created from a circle with zero radius
        let point = CGPoint(x: 245.2276926738644, y: 76.62374839782714)
        let curve = CubicCurve(p0: point, p1: point, p2: point, p3: point)
        let path = Path(components: [PathComponent(curves: [BezierCurve](repeating: curve, count: 4))])
        let result = path.offset(distance: 1)
        XCTAssert(result.isEmpty)
    }

    func testDisjointComponentsNesting() {
        XCTAssertEqual(Path().disjointComponents(), [])
        // test that a simple square just gives the same square back
        let squarePath = Path(cgPath: CGPath.init(rect: CGRect(x: 0, y: 0, width: 7, height: 7), transform: nil))
        let result1 = squarePath.disjointComponents()
        XCTAssertEqual(result1.count, 1)
        if let result = result1.first {
            XCTAssertEqual(squarePath, result)
        }
        // test that a square with a hole associates the hole correctly with the square
        let squareWithHolePath = { () -> Path in
            let cgPath = CGPath(rect: CGRect(x: 1, y: 1, width: 5, height: 5), transform: nil)
            let hole = Path(cgPath: cgPath).reversed()
            return Path(components: squarePath.components + hole.components)
        }()
        let result2 = squareWithHolePath.disjointComponents()
        XCTAssertEqual(result2.count, 1)
        if let result = result2.first {
            XCTAssertEqual(squareWithHolePath, result)
        }
        // test that nested paths correctly produce two paths
        let pegPath = Path(cgPath: CGPath(rect: CGRect(x: 2, y: 2, width: 3, height: 3), transform: nil))
        let squareWithPegPath = Path(components: squareWithHolePath.components + pegPath.components)
        let result3 = squareWithPegPath.disjointComponents()
        XCTAssertEqual(result3.count, 2)
        XCTAssert(result3.contains(squareWithHolePath))
        XCTAssert(result3.contains(pegPath))
        // test a trickier case: a square with a hole, nested inside a square with a hole
        let pegWithHolePath = { () -> Path in
            let cgPath = CGPath(rect: CGRect(x: 3, y: 3, width: 1, height: 1), transform: nil)
            let hole = Path(cgPath: cgPath).reversed()
            return Path(components: pegPath.components + hole.components)
        }()
        let squareWithPegWithHolePath = Path(components: squareWithHolePath.components + pegWithHolePath.components)
        let result4 = squareWithPegWithHolePath.disjointComponents()
        XCTAssertEqual(result4.count, 2)
        XCTAssert(result4.contains(squareWithHolePath))
        XCTAssert(result4.contains(pegWithHolePath))
    }

    func testDisjointComponentsWindingBackwards() {

        let innerSquare = Path(cgPath: CGPath(rect: CGRect(x: 2, y: 2, width: 1, height: 1), transform: nil))
        let hole        = Path(cgPath: CGPath(rect: CGRect(x: 1, y: 1, width: 3, height: 3), transform: nil)).reversed()
        let outerSquare = Path(cgPath: CGPath(rect: CGRect(x: 0, y: 0, width: 5, height: 5), transform: nil))
        let path = Path(components: innerSquare.components + outerSquare.components + hole.components)

        let disjointPaths = path.disjointComponents()

        // it's expected that disjointComponents should separate the path into
        // the outer square plus hole as one path, and the inner square as another
        let outerSquareWithHole = Path(components: outerSquare.components + hole.components)
        let expectedPaths = [outerSquareWithHole, innerSquare]

        XCTAssertEqual(disjointPaths.count, expectedPaths.count)
        expectedPaths.forEach {
            XCTAssert(disjointPaths.contains($0))
        }
    }

    func testSubtractionPerformance() {

        func circlePath(origin: CGPoint, radius: CGFloat, numPoints: Int) -> Path {
            let c: CGFloat = 0.551915024494 * radius * 4.0 / CGFloat(numPoints)
            let cgPath = CGMutablePath()
            var lastPoint = origin + CGPoint(x: radius, y: 0.0)
            var lastTangent = CGPoint(x: 0.0, y: c)
            cgPath.move(to: lastPoint)
            for i in 1...numPoints {
                let theta = CGFloat(2.0 * Double.pi) * CGFloat(i % numPoints) / CGFloat(numPoints)
                let cosTheta = cos(theta)
                let sinTheta = sin(theta)
                let point = origin + radius * CGPoint(x: cosTheta, y: sinTheta)
                let tangent = c * CGPoint(x: -sinTheta, y: cosTheta)
                cgPath.addCurve(to: point, control1: lastPoint + lastTangent, control2: point - tangent)
              //  cgPath.addLine(to: point)
                lastPoint = point
                lastTangent = tangent
            }
            return Path(cgPath: cgPath)
        }

        let numPoints = 300
        let path1 = circlePath(origin: CGPoint(x: 0, y: 0), radius: 100, numPoints: numPoints)
        let path2 = circlePath(origin: CGPoint(x: 1, y: 0), radius: 100, numPoints: numPoints)

        self.measure { // roughly 0.018s in debug mode
            _ = path1.subtract(path2, accuracy: 1.0e-3)
        }
    }

    func testNSCoder() {
        let l1 = LineSegment(p0: p1, p1: p2)
        let q1 = QuadraticCurve(p0: p2, p1: p3, p2: p4)
        let l2 = LineSegment(p0: p4, p1: p5)
        let c1 = CubicCurve(p0: p5, p1: p6, p2: p7, p3: p8)
        let path = Path(components: [PathComponent(curves: [l1, q1, l2, c1])])

        let data = NSKeyedArchiver.archivedData(withRootObject: path)
        let decodedPath = NSKeyedUnarchiver.unarchiveObject(with: data) as! Path
        XCTAssertEqual(path, decodedPath)
    }

    func testIndexedPathLocation() {
        let location1 = IndexedPathLocation(componentIndex: 0, elementIndex: 1, t: 0.5)
        let location2 = IndexedPathLocation(componentIndex: 0, elementIndex: 1, t: 1.0)
        let location3 = IndexedPathLocation(componentIndex: 0, elementIndex: 2, t: 0.0)
        let location4 = IndexedPathLocation(componentIndex: 1, elementIndex: 0, t: 0.0)
        let location5 = IndexedPathLocation(componentIndex: location4.componentIndex, locationInComponent: location4.locationInComponent)
        XCTAssert(location1 < location2)
        XCTAssert(location1 < location3)
        XCTAssert(location1 < location4)
        XCTAssertFalse(location2 < location1) // no! t is greater
        XCTAssertFalse(location3 < location1) // no! element index is greater
        XCTAssertFalse(location4 < location1) // no! component index is greater
        XCTAssertEqual(location1.locationInComponent, IndexedPathComponentLocation(elementIndex: location1.elementIndex, t: location1.t))
        XCTAssertEqual(location4, location5)
    }
}
