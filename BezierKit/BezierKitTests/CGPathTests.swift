//
//  PathCGPathTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/13/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

private struct CGPathElementRecord: Equatable {
    var type: CGPathElementType
    var pointsArray: [CGPoint]
    init(_ pathElement: CGPathElement) {
        self.type = pathElement.type
        let count = { () -> Int in
            switch pathElement.type {
            case .moveToPoint:
                return 1
            case .addLineToPoint:
                return 1
            case .addQuadCurveToPoint:
                return 2
            case .addCurveToPoint:
                return 3
            case .closeSubpath:
                return 0
            }
        }()
        self.pointsArray = [CGPoint](UnsafeBufferPointer(start: pathElement.points, count: count))
    }
}

fileprivate extension CGPath {
    private class ElementGetterContext {
        var elements: [CGPathElementRecord] = []
    }
    fileprivate var elements: [CGPathElementRecord] {
        func elementGetterApplierFunction(_ info: UnsafeMutableRawPointer?, _ element: UnsafePointer<CGPathElement>) -> Void {
            let context = info!.assumingMemoryBound(to: ElementGetterContext.self).pointee
            context.elements.append(CGPathElementRecord(element.pointee))
        }
        var elementGetterContext = ElementGetterContext()
        self.apply(info: &elementGetterContext, function: elementGetterApplierFunction)
        return elementGetterContext.elements
    }
}

class PathCGPathTests: XCTestCase {

    
    private func cgPathsHaveEqualCGPathElements(_ path1: Path, _ path2: CGPath) -> Bool {
        return cgPathsHaveEqualCGPathElements(Path(data: path1.data)!.cgPath, path2)
    }
        
    private func cgPathsHaveEqualCGPathElements(_ path1: CGPath, _ path2: CGPath) -> Bool {
        // checks that the CGPathElements that make up the paths are exactly equal
        // unfortunately we cannot just check path1 == path2 because CGPath.isRect can differ even if the underlying data is the same
        let pathElements1 = path1.elements
        let pathElements2 = path2.elements
        return pathElements1 == pathElements2
    }

    func testTooling() {
        let rect = CGRect(x: 1, y: 1, width: 2, height: 3)
        let rectCGPath = CGPath(rect: rect, transform: nil)
        let ellipseCGPath = CGPath(ellipseIn: rect, transform: nil)
        let emptyPath = CGMutablePath()
        let quadPath1 = { () -> CGPath in
            let cgPath = CGMutablePath()
            cgPath.move(to: CGPoint(x: 1, y: 1))
            cgPath.addQuadCurve(to: CGPoint(x: 3, y: 1), control: CGPoint(x: 3, y: 4))
            return cgPath
        }()
        let quadPath2 = { () -> CGPath in
            let cgPath = CGMutablePath()
            cgPath.move(to: CGPoint(x: 1, y: 1))
            cgPath.addQuadCurve(to: CGPoint(x: 3, y: 1), control: CGPoint(x: 3, y: 5))
            return cgPath
        }()
        XCTAssertTrue(cgPathsHaveEqualCGPathElements(emptyPath, emptyPath))
        XCTAssertFalse(cgPathsHaveEqualCGPathElements(rectCGPath, emptyPath))
        XCTAssertFalse(cgPathsHaveEqualCGPathElements(rectCGPath, ellipseCGPath))
        XCTAssertFalse(cgPathsHaveEqualCGPathElements(quadPath1, quadPath2))
        XCTAssertTrue(cgPathsHaveEqualCGPathElements(quadPath1, quadPath1))
        XCTAssertTrue(cgPathsHaveEqualCGPathElements(rectCGPath, rectCGPath))
        XCTAssertTrue(cgPathsHaveEqualCGPathElements(ellipseCGPath, ellipseCGPath))
    }

    func testEmpty() {
        let emptyCGPath = CGMutablePath()
        XCTAssertTrue(cgPathsHaveEqualCGPathElements(Path(), emptyCGPath))
        XCTAssertTrue(cgPathsHaveEqualCGPathElements(Path(cgPath: emptyCGPath), emptyCGPath))
    }

    func testRectangle() {
        let rectCGPath = CGPath(rect: CGRect(x: 1, y: 1, width: 2, height: 3), transform: nil)
        XCTAssertTrue(cgPathsHaveEqualCGPathElements(Path(cgPath: rectCGPath), rectCGPath))
    }

    func testSingleOpenPath() {
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 3, y: 4))
        cgPath.addCurve(to: CGPoint(x: 4, y: 5), control1: CGPoint(x: 5, y: 5), control2: CGPoint(x: 6, y: 4))
        XCTAssertTrue(cgPathsHaveEqualCGPathElements(Path(cgPath: cgPath), cgPath))
    }

    func testSingleClosedPathClosePath() {
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 3, y: 4))
        cgPath.addLine(to: CGPoint(x: 4, y: 4))
        cgPath.addLine(to: CGPoint(x: 4, y: 5))
        cgPath.addLine(to: CGPoint(x: 3, y: 5))
        cgPath.closeSubpath()
        XCTAssertTrue(cgPathsHaveEqualCGPathElements(Path(cgPath: cgPath), cgPath))
    }

    func testMultipleOpenPaths() {
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 3, y: 4))
        cgPath.addLine(to: CGPoint(x: 4, y: 5))
        cgPath.move(to: CGPoint(x: 6, y: 4))
        cgPath.addLine(to: CGPoint(x: 7, y: 5))
        cgPath.move(to: CGPoint(x: 9, y: 4))
        cgPath.addLine(to: CGPoint(x: 10, y: 5))
        XCTAssertTrue(cgPathsHaveEqualCGPathElements(Path(cgPath: cgPath), cgPath))
    }

    func testUnsupportedPathDoesNotCrash() {
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 3, y: 4))
        cgPath.closeSubpath()
        let resultingCGPath = Path(cgPath: cgPath).cgPath
        XCTAssertTrue(cgPathsHaveEqualCGPathElements(resultingCGPath, CGMutablePath()))
    }

    func testMultipleClosedPaths() {
        let cgPath = CGMutablePath()
        cgPath.addRect(CGRect(x: 1, y: 1, width: 2, height: 3))
        cgPath.addRect(CGRect(x: 4, y: 2, width: 2, height: 3))
        XCTAssertTrue(cgPathsHaveEqualCGPathElements(Path(cgPath: cgPath), cgPath))
    }

}
