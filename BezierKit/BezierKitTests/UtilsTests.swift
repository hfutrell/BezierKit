//
//  UtilsTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/12/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class UtilsTests: XCTestCase {

    func testClamp() {
        XCTAssertEqual(1.0, Utils.clamp(1.0, -1.0, 1.0))
        XCTAssertEqual(0.0, Utils.clamp(0.0, -1.0, 1.0))
        XCTAssertEqual(-1.0, Utils.clamp(-1.0, -1.0, 1.0))
        XCTAssertEqual(1.0, Utils.clamp(2.0, -1.0, 1.0))
        XCTAssertEqual(-1.0, Utils.clamp(-2.0, -1.0, 1.0))
        XCTAssertEqual(-1.0, Utils.clamp(-CGFloat.infinity, -1.0, 1.0))
        XCTAssertEqual(1.0, Utils.clamp(+CGFloat.infinity, -1.0, 1.0))
        XCTAssertEqual(-20.0, Utils.clamp(-20.0, -CGFloat.infinity, 0.0))
        XCTAssertEqual(20.0, Utils.clamp(20.0, 0.0, CGFloat.infinity))
        XCTAssertTrue(Utils.clamp(CGFloat.nan, -1.0, 1.0).isNaN)
    }

    private func drootsQuadraticTestHelper(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat) -> [CGFloat] {
        var roots: [CGFloat] = []
        Utils.droots(a, b, c) {
            roots.append($0)
        }
        return roots
    }

    private func drootsCubicTestHelper(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> [CGFloat] {
        var roots: [CGFloat] = []
        Utils.droots(a, b, c, d) {
            roots.append($0)
        }
        return roots
    }

    func testDrootsCubicWorldIssue() {
        var points: [CGPoint] = [
            CGPoint(x: 523.4257521858988, y: 691.8949684622992),
            CGPoint(x: 523.1393916834338, y: 691.8714265856051),
            CGPoint(x: 522.8595588275791, y: 691.7501129962762),
            CGPoint(x: 522.6404735257349, y: 691.531027694432)
        ]
        let y: CGFloat = 691.87778055040201
        points = points.map { $0 - CGPoint(x: 0, y: y)}
        let r = drootsCubicTestHelper(points[0].y, points[1].y, points[2].y, points[3].y)
        let filtered = r.filter { $0 >= 0 && $0 <= 1 }
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first!, CGFloat(0.1499651773565319), accuracy: 1.0e-3)
    }

    func testDrootsQuadratic() {
        let a: CGFloat = 0.36159566118413977
        let b: CGFloat = -3.2979288390483816
        let c: CGFloat = 3.5401259561374445
        let roots = drootsQuadraticTestHelper(a, b, c)
        let accuracy: CGFloat = 1.0e-5
        XCTAssertEqual(roots[0], CGFloat(0.053511820486391165), accuracy: accuracy)
        XCTAssertEqual(roots[1], CGFloat(0.64370120305889711), accuracy: accuracy)
    }

    func testDrootsQuadraticEdgeCases() {
        let oneThird = CGFloat(1.0 / 3.0)
        let twoThirds = CGFloat(2.0 / 3.0)
        XCTAssertEqual(drootsQuadraticTestHelper(3, 6, 12), [-1])
        XCTAssertEqual(drootsQuadraticTestHelper(12, 6, 3), [2])
        XCTAssertEqual(drootsQuadraticTestHelper(12, 6, 4), [])
        XCTAssertEqual(drootsQuadraticTestHelper(2, 1, 0), [1])
        XCTAssertEqual(drootsQuadraticTestHelper(1, 1, 1), [])
        XCTAssertEqual(drootsQuadraticTestHelper(4, -5, 4), [oneThird, twoThirds])
        XCTAssertEqual(drootsQuadraticTestHelper(-4, 5, -4), [oneThird, twoThirds])
        XCTAssertEqual(drootsQuadraticTestHelper(CGFloat.nan, CGFloat.nan, CGFloat.nan), [])
    }

    func testLinesIntersection() {
        let p0 = CGPoint(x: 1, y: 2)
        let p1 = CGPoint(x: 3, y: 4)
        let p2 = CGPoint(x: 1, y: 4)
        let p3 = CGPoint(x: 3, y: 2)
        let p4 = CGPoint(x: 1, y: 3)
        let p5 = CGPoint(x: 3, y: 5)
        let nanPoint = CGPoint(x: CGFloat.nan, y: CGFloat.nan)
        // basic cases
        XCTAssertEqual(CGPoint(x: 2, y: 3), Utils.linesIntersection(p0, p1, p2, p3), "these lines should intersect.")
        XCTAssertNil(Utils.linesIntersection(p0, p1, p4, p5), "these lines should NOT intersect.")
        // degenerate case
        XCTAssertNil(Utils.linesIntersection(nanPoint, nanPoint, p0, p1), "nothing should intersect a line that includes NaN values.")
    }

    func testSortedAndUniqued() {
        XCTAssertEqual([Int]().sortedAndUniqued(), [])
        XCTAssertEqual([1].sortedAndUniqued(), [1])
        XCTAssertEqual([1, 1].sortedAndUniqued(), [1])
        XCTAssertEqual([1, 3, 1].sortedAndUniqued(), [1, 3])
        XCTAssertEqual([1, 2, 4, 5, 5, 6].sortedAndUniqued(), [1, 2, 4, 5, 6])
    }
}
