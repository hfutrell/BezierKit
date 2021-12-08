//
//  PathTest.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/1/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import BezierKit

#if canImport(CoreGraphics)
private func applierFunction(_ info: UnsafeMutableRawPointer?, _ element: UnsafePointer<CGPathElement>) {
    var records = info!.assumingMemoryBound(to: [CGPathElementRecord].self).pointee
    records.append(CGPathElementRecord(element.pointee))
    info!.assumingMemoryBound(to: [CGPathElementRecord].self).pointee = records
}
#endif

class PathTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

#if canImport(CoreGraphics) // many of these tests rely on CGPath to build the test Paths

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

    func testGeometricProperties() {
        // create a path with two components
        let path: Path = {
            let mutablePath = CGMutablePath()
            mutablePath.move(to: CGPoint(x: 2, y: 1))
            mutablePath.addLine(to: CGPoint(x: 3, y: 1))
            mutablePath.addQuadCurve(to: CGPoint(x: 4, y: 2),
                                     control: CGPoint(x: 4, y: 1))
            mutablePath.addCurve(to: CGPoint(x: 2, y: 1),
                                 control1: CGPoint(x: 4, y: 3),
                                 control2: CGPoint(x: 2, y: 3))
            mutablePath.move(to: CGPoint(x: 1, y: 1))
            return Path(cgPath: mutablePath)
        }()

        XCTAssertEqual(path.components.count, 2)

        // test the first element of the first component, which is a line
        let lineLocation = IndexedPathLocation(componentIndex: 0, elementIndex: 0, t: 0)
        let expectedLinePosition = CGPoint(x: 2, y: 1)
        let expectedLineDerivative = CGPoint(x: 1, y: 0)
        let expectedLineNormal = CGPoint(x: 0, y: 1)
        XCTAssertEqual(path.point(at: lineLocation), expectedLinePosition)
        XCTAssertEqual(path.components[0].point(at: lineLocation.locationInComponent), expectedLinePosition)
        XCTAssertEqual(path.derivative(at: lineLocation), expectedLineDerivative)
        XCTAssertEqual(path.components[0].derivative(at: lineLocation.locationInComponent), expectedLineDerivative)
        XCTAssertEqual(path.normal(at: lineLocation), expectedLineNormal)
        XCTAssertEqual(path.components[0].normal(at: lineLocation.locationInComponent), expectedLineNormal)

        // test the second element of the first component, which is a quad
        let quadraticLocation = IndexedPathLocation(componentIndex: 0, elementIndex: 1, t: 0.25)
        let expectedQuadraticPosition = CGPoint(x: 3.4375, y: 1.0625)
        let expectedQuadraticDerivative = CGPoint(x: 1.5, y: 0.5)
        let expectedQuadraticNormal = CGPoint(x: -0.316, y: 0.949)
        XCTAssertEqual(path.point(at: quadraticLocation), expectedQuadraticPosition)
        XCTAssertEqual(path.components[0].point(at: quadraticLocation.locationInComponent), expectedQuadraticPosition)
        XCTAssertEqual(path.derivative(at: quadraticLocation), expectedQuadraticDerivative)
        XCTAssertEqual(path.components[0].derivative(at: quadraticLocation.locationInComponent), expectedQuadraticDerivative)
        XCTAssertTrue(distance(path.normal(at: quadraticLocation), expectedQuadraticNormal) < 1.0e-2)
        XCTAssertTrue(distance(path.components[0].normal(at: quadraticLocation.locationInComponent), expectedQuadraticNormal) < 1.0e-2)

        // test the third element of the first component, which is a cubic
        let cubicLocation = IndexedPathLocation(componentIndex: 0, elementIndex: 2, t: 1)
        let expectedCubicPosition = CGPoint(x: 2, y: 1)
        let expectedCubicDerivative = CGPoint(x: 0, y: -6)
        let expectedCubicNormal = CGPoint(x: 1, y: 0)
        XCTAssertEqual(path.point(at: cubicLocation), expectedCubicPosition)
        XCTAssertEqual(path.components[0].point(at: cubicLocation.locationInComponent), expectedCubicPosition)
        XCTAssertEqual(path.derivative(at: cubicLocation), expectedCubicDerivative)
        XCTAssertEqual(path.components[0].derivative(at: cubicLocation.locationInComponent), expectedCubicDerivative)
        XCTAssertEqual(path.normal(at: cubicLocation), expectedCubicNormal)
        XCTAssertEqual(path.components[0].normal(at: cubicLocation.locationInComponent), expectedCubicNormal)

        // test the second component, which is just a point
        let firstComponentLocation = IndexedPathLocation(componentIndex: 1, elementIndex: 0, t: 0)
        let expectedPointPosition = CGPoint(x: 1, y: 1)
        let expectedPointDerivative = CGPoint.zero
        XCTAssertEqual(path.point(at: firstComponentLocation), expectedPointPosition)
        XCTAssertEqual(path.components[1].point(at: firstComponentLocation.locationInComponent), expectedPointPosition)
        XCTAssertEqual(path.derivative(at: firstComponentLocation), expectedPointDerivative)
        XCTAssertEqual(path.components[1].derivative(at: firstComponentLocation.locationInComponent), expectedPointDerivative)
        XCTAssertTrue(path.normal(at: firstComponentLocation).x.isNaN)
        XCTAssertTrue(path.normal(at: firstComponentLocation).y.isNaN)
        XCTAssertTrue(path.components[1].normal(at: firstComponentLocation.locationInComponent).x.isNaN)
        XCTAssertTrue(path.components[1].normal(at: firstComponentLocation.locationInComponent).y.isNaN)
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
    
    func testHashing() {
        // two paths that are equal
        let rect = CGRect(origin: CGPoint(x: -1, y: -1), size: CGSize(width: 2, height: 2))
        let path1 = Path(cgPath: CGPath(rect: rect, transform: nil))
        let path2 = Path(cgPath: CGPath(rect: rect, transform: nil))
        
        XCTAssert(path1.hash == path2.hash)
        
        // path that is equal should be located in a set
        let path3 = path1.copy(using: CGAffineTransform.identity)
        let set = Set([path1])
        XCTAssert(set.contains(path3))
    }

    func testEncodeDecode() {
        let rect = CGRect(origin: CGPoint(x: -1, y: -1), size: CGSize(width: 2, height: 2))
        let path = Path(cgPath: CGPath(rect: rect, transform: nil))
        let decodedPath: Path?
        if #available(OSX 10.13, iOS 11.0, *) {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: path, requiringSecureCoding: true) {
                decodedPath = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [Path.self, NSData.self], from: data) as? Path
            } else {
                decodedPath = nil
            }
        } else {
            // Fallback on earlier versions
            let data = NSKeyedArchiver.archivedData(withRootObject: path)
            decodedPath = NSKeyedUnarchiver.unarchiveObject(with: data) as? Path
        }
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

    func testApply() {

        let emptyPath = Path()
        var records: [CGPathElementRecord] = []

        func clearRecordsAndGetPointer(block: (_: UnsafeMutablePointer<[CGPathElementRecord]>) -> Void) {
            records.removeAll()
            withUnsafeMutablePointer(to: &records) { recordsPointer in
                block(recordsPointer)
            }
        }

        // the empty case
        clearRecordsAndGetPointer { recordsPointer in
            emptyPath.apply(info: recordsPointer, function: applierFunction)
        }
        XCTAssertEqual(records, [])

        // a path component from just a moveTo
        let pointPathComponent = PathComponent(points: [CGPoint(x: 3, y: 5)], orders: [0])
        clearRecordsAndGetPointer { recordsPointer in
            pointPathComponent.apply(info: recordsPointer, function: applierFunction)
        }
        XCTAssertEqual(records, [CGPathElementRecord(type: .moveToPoint, points: [CGPoint(x: 3, y: 5)])])

        // a more complex path component
        let points = [
            CGPoint(x: -1, y: 2),
            CGPoint(x: 5, y: -3),
            CGPoint(x: 3, y: 7),
            CGPoint(x: -5, y: 2),
            CGPoint(x: 2, y: 6),
            CGPoint(x: 1, y: -8),
            CGPoint(x: -2, y: 1)
        ]
        let multiCurveCGPath = CGMutablePath()
        multiCurveCGPath.move(to: points[0])
        multiCurveCGPath.addLine(to: points[1])
        multiCurveCGPath.addQuadCurve(to: points[3], control: points[2])
        multiCurveCGPath.addCurve(to: points[6], control1: points[4], control2: points[5])
        multiCurveCGPath.closeSubpath()

        let multiCurvePath = Path(cgPath: multiCurveCGPath)
        let multiCurvePathComponent = multiCurvePath.components[0]

        let expectedRecords = [
            CGPathElementRecord(type: .moveToPoint, points: [points[0]]),
            CGPathElementRecord(type: .addLineToPoint, points: [points[1]]),
            CGPathElementRecord(type: .addQuadCurveToPoint, points: [points[2], points[3]]),
            CGPathElementRecord(type: .addCurveToPoint, points: [points[4], points[5], points[6]]),
            CGPathElementRecord(type: .closeSubpath, points: [])
        ]

        clearRecordsAndGetPointer { recordsPointer in
            multiCurvePathComponent.apply(info: recordsPointer, function: applierFunction)
        }
        XCTAssertEqual(records, expectedRecords)

        clearRecordsAndGetPointer { recordsPointer in
            multiCurvePath.apply(info: recordsPointer, function: applierFunction)
        }
        XCTAssertEqual(records, expectedRecords)
    }

    #endif

    func testBoundingBoxOfPath() {
        XCTAssertEqual(Path().boundingBoxOfPath, BoundingBox.empty)
        let quad1 = QuadraticCurve(p0: CGPoint(x: 1, y: 2),
                                   p1: CGPoint(x: 2, y: 4),
                                   p2: CGPoint(x: 3, y: 2))
        let quad2 = QuadraticCurve(p0: CGPoint(x: 3, y: 2),
                                   p1: CGPoint(x: 2, y: 0),
                                   p2: CGPoint(x: 1, y: 2))
        let path1 = Path(curve: quad1)
        XCTAssertEqual(path1.boundingBoxOfPath, BoundingBox(p1: CGPoint(x: 1, y: 2), p2: CGPoint(x: 3, y: 4)))
        let path2 = Path(components: [PathComponent(curve: quad1),
                                      PathComponent(curve: quad2)])
        XCTAssertEqual(path2.boundingBoxOfPath, BoundingBox(p1: CGPoint(x: 1, y: 0), p2: CGPoint(x: 3, y: 4)))
    }

    func testNSCoder() {
        // just some random curves, but we ensure they're continuous
        let l1 = LineSegment(p0: CGPoint(x: 4.9652, y: 8.2774),
                             p1: CGPoint(x: 3.8449, y: 4.9902))
        let q1 = QuadraticCurve(p0: CGPoint(x: 3.8449, y: 4.9902),
                                p1: CGPoint(x: 4.0766, y: 7.0715),
                                p2: CGPoint(x: 7.7088, y: 8.6246))
        let l2 = LineSegment(p0: CGPoint(x: 7.7088, y: 8.6246),
                             p1: CGPoint(x: 3.6054, y: 3.0114))
        let c1 = CubicCurve(p0: CGPoint(x: 3.6054, y: 3.0114),
                            p1: CGPoint(x: 6.9423, y: 2.5472),
                            p2: CGPoint(x: 3.2955, y: 9.4288),
                            p3: CGPoint(x: 1.8175, y: 6.9295))
        let path = Path(components: [PathComponent(curves: [l1, q1, l2, c1])])

        let decodedPath: Path?
        if #available(OSX 10.13, iOS 11.0, *) {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: path, requiringSecureCoding: true) {
                decodedPath = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [Path.self, NSData.self], from: data) as? Path
            } else {
                decodedPath = nil
            }
        } else {
            // Fallback on earlier versions
            let data = NSKeyedArchiver.archivedData(withRootObject: path)
            decodedPath = NSKeyedUnarchiver.unarchiveObject(with: data) as? Path
        }
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
