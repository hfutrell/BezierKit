//
//  Path+DataTests.swift
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
    var elements: [CGPathElementRecord] {
        func elementGetterApplierFunction(_ info: UnsafeMutableRawPointer?, _ element: UnsafePointer<CGPathElement>) -> Void {
            let context = info!.assumingMemoryBound(to: ElementGetterContext.self).pointee
            context.elements.append(CGPathElementRecord(element.pointee))
        }
        var elementGetterContext = ElementGetterContext()
        self.apply(info: &elementGetterContext, function: elementGetterApplierFunction)
        return elementGetterContext.elements
    }
}

class PathDataTests: XCTestCase {

    private func pathHasEqualElementsToCGPath(_ path1: Path, _ path2: CGPath) -> Bool {
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
        XCTAssertTrue(pathHasEqualElementsToCGPath(Path(), emptyCGPath))
        XCTAssertTrue(pathHasEqualElementsToCGPath(Path(cgPath: emptyCGPath), emptyCGPath))
    }

    func testRectangle() {
        let rectCGPath = CGPath(rect: CGRect(x: 1, y: 1, width: 2, height: 3), transform: nil)
        XCTAssertTrue(pathHasEqualElementsToCGPath(Path(cgPath: rectCGPath), rectCGPath))
    }

    func testSingleOpenPath() {
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 3, y: 4))
        cgPath.addCurve(to: CGPoint(x: 4, y: 5), control1: CGPoint(x: 5, y: 5), control2: CGPoint(x: 6, y: 4))
        XCTAssertTrue(pathHasEqualElementsToCGPath(Path(cgPath: cgPath), cgPath))
    }

    func testSingleClosedPathClosePath() {
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 3, y: 4))
        cgPath.addLine(to: CGPoint(x: 4, y: 4))
        cgPath.addLine(to: CGPoint(x: 4, y: 5))
        cgPath.addLine(to: CGPoint(x: 3, y: 5))
        cgPath.closeSubpath()
        XCTAssertTrue(pathHasEqualElementsToCGPath(Path(cgPath: cgPath), cgPath))
    }

    func testMultipleOpenPaths() {
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 3, y: 4))
        cgPath.addLine(to: CGPoint(x: 4, y: 5))
        cgPath.move(to: CGPoint(x: 6, y: 4))
        cgPath.addLine(to: CGPoint(x: 7, y: 5))
        cgPath.move(to: CGPoint(x: 9, y: 4))
        cgPath.addLine(to: CGPoint(x: 10, y: 5))
        XCTAssertTrue(pathHasEqualElementsToCGPath(Path(cgPath: cgPath), cgPath))
    }

    func testSinglePointMoveTo() {
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 3, y: 4))
        XCTAssertTrue(pathHasEqualElementsToCGPath(Path(cgPath: cgPath), cgPath))
    }

    func testSinglePointMoveToCloseSubpath() {
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 3, y: 4))
        let beforeClosing = Path(cgPath: cgPath)
        cgPath.closeSubpath()
        XCTAssertTrue(pathHasEqualElementsToCGPath(Path(cgPath: cgPath), beforeClosing.cgPath))
    }

    func testMultipleSinglePoints() {
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 1, y: 2))
        cgPath.move(to: CGPoint(x: 2, y: 3))
        cgPath.move(to: CGPoint(x: 3, y: 4))
        XCTAssertTrue(pathHasEqualElementsToCGPath(Path(cgPath: cgPath), cgPath))
        cgPath.addLine(to: CGPoint(x: 4, y: 5))
        XCTAssertTrue(pathHasEqualElementsToCGPath(Path(cgPath: cgPath), cgPath))
    }

    func testMultipleClosedPaths() {
        let cgPath = CGMutablePath()
        cgPath.addRect(CGRect(x: 1, y: 1, width: 2, height: 3))
        cgPath.addRect(CGRect(x: 4, y: 2, width: 2, height: 3))
        XCTAssertTrue(pathHasEqualElementsToCGPath(Path(cgPath: cgPath), cgPath))
    }

    func testEmptyData() {
        let path = Path(data: Data())
        XCTAssertEqual(path, nil)
    }

    let simpleRectangle = Path(cgPath: CGPath(rect: CGRect(x: 1, y: 2, width: 3, height: 4), transform: nil))
    let expectedSimpleRectangleData = Data(base64Encoded: "JbPlSAUAAAAAAQEBAQAAAAAAAPA/AAAAAAAAAEAAAAAAAAAQQAAAAAAAAABAAAAAAAAAEEAAAAAAAAAYQAAAAAAAAPA/AAAAAAAAGEAAAAAAAADwPwAAAAAAAABA")!

    func testSimpleRectangle() {
        XCTAssertEqual(simpleRectangle.data, expectedSimpleRectangleData)
    }

    func testWrongMagicNumber() {
        var data = simpleRectangle.data
        XCTAssertNotEqual(Path(data: data), nil)
        data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) in
            bytes[0] = ~bytes[0]
        }
        XCTAssertEqual(Path(data: data), nil)
    }

    func testCorruptedData() {
        let data = simpleRectangle.data
        XCTAssertNotEqual(Path(data: data), nil)
        let corruptData1 = data[0..<data.count-1] // missing last y coordinate
        XCTAssertEqual(Path(data: corruptData1), nil)
        let corruptData2 = data[0..<data.count-9] // missing last x coordinate
        XCTAssertEqual(Path(data: corruptData2), nil)
        let corruptData3 = data[0..<3] // magic number cut off
        XCTAssertEqual(Path(data: corruptData3), nil)
        let corruptData4 = data[0..<4] // only magic number
        XCTAssertEqual(Path(data: corruptData4), nil)
        let corruptData5 = data[0..<5] // command count cut off
        XCTAssertEqual(Path(data: corruptData5), nil)
        let corruptData6 = data[0..<10] // commands cut off
        XCTAssertEqual(Path(data: corruptData6), nil)
    }
}
