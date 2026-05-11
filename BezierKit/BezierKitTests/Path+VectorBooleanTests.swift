//
//  Path+VectorBooleanOperationsTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 2/8/21.
//  Copyright © 2021 Holmes Futrell. All rights reserved.
//

@testable import BezierKit
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import XCTest

private extension Path {
    /// copies the path in such a way that it's impossible that optimizations would allow the copy to share the same underlying storage
    func independentCopy() -> Path {
        return self.copy(using: CGAffineTransform(translationX: 1, y: 0)).copy(using: CGAffineTransform(translationX: -1, y: 0))
    }
}

class PathVectorBooleanTests: XCTestCase {

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

    #if canImport(CoreGraphics)

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

    #endif

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

    #if canImport(CoreGraphics) // many of these tests rely on CGPath to build the test Paths

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

    #endif

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

    #if canImport(CoreGraphics)

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

    func testCrossingsRemovedSingleCurveLoop() {
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 0, y: 0))
        cgPath.addCurve(to: CGPoint(x: 0, y: 0),
                        control1: CGPoint(x: -1, y: 1),
                        control2: CGPoint(x: 1, y: 1))
        let path = Path(cgPath: cgPath)
        XCTAssertEqual(path.crossingsRemoved(), path)
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

    func testCrossingsRemovedCoincidentPoints() {
        // GitHub issue #84: crossingsRemoved gets confused by coincident points
        // Two overlapping triangles where one has a zero-length degenerate segment at (100, 585).
        // crossingsRemoved() should merge them into a single component, preserving the zero-length segment.
        let comp0 = PathComponent(curves: [
            LineSegment(p0: CGPoint(x: 100, y: 585), p1: CGPoint(x: 100, y: 585)),
            LineSegment(p0: CGPoint(x: 100, y: 585), p1: CGPoint(x: 225, y: 585)),
            LineSegment(p0: CGPoint(x: 225, y: 585), p1: CGPoint(x: 100, y: 680)),
            LineSegment(p0: CGPoint(x: 100, y: 680), p1: CGPoint(x: 100, y: 585))
        ] as [BezierCurve])
        let comp1 = PathComponent(curves: [
            LineSegment(p0: CGPoint(x: 260, y: 392), p1: CGPoint(x: 260, y: 585)),
            LineSegment(p0: CGPoint(x: 260, y: 585), p1: CGPoint(x: 160, y: 680)),
            LineSegment(p0: CGPoint(x: 160, y: 680), p1: CGPoint(x: 260, y: 392))
        ] as [BezierCurve])
        let path = Path(components: [comp0, comp1])
        let result = path.crossingsRemoved()
        XCTAssertEqual(result.components.count, 1)
        let hasZeroLengthSegment = result.components[0].curves.contains {
            $0.startingPoint == CGPoint(x: 100, y: 585) && $0.endingPoint == CGPoint(x: 100, y: 585)
        }
        XCTAssertTrue(hasZeroLengthSegment, "degenerate zero-length segment should be preserved in result")
    }

    func testCrossingsRemovedTwoOverlappingCircles() {
        // two overlapping near-circular components; crossingsRemoved should return
        // the outer boundary and preserve the bounding box of the union
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 39.8945, y: 48.9375))
        cgPath.addCurve(to: CGPoint(x: 36.9062, y: 51.9258),
                        control1: CGPoint(x: 39.8945, y: 50.5879),
                        control2: CGPoint(x: 38.5566, y: 51.9258))
        cgPath.addCurve(to: CGPoint(x: 33.918, y: 48.9375),
                        control1: CGPoint(x: 35.2559, y: 51.9258),
                        control2: CGPoint(x: 33.918, y: 50.5879))
        cgPath.addCurve(to: CGPoint(x: 36.9062, y: 45.9492),
                        control1: CGPoint(x: 33.918, y: 47.2871),
                        control2: CGPoint(x: 35.2559, y: 45.9492))
        cgPath.addCurve(to: CGPoint(x: 39.8945, y: 48.9375),
                        control1: CGPoint(x: 38.5566, y: 45.9492),
                        control2: CGPoint(x: 39.8945, y: 47.2871))
        cgPath.move(to: CGPoint(x: 36.4688, y: 51.832))
        cgPath.addCurve(to: CGPoint(x: 33.4805, y: 48.8438),
                        control1: CGPoint(x: 34.8184, y: 51.832),
                        control2: CGPoint(x: 33.4805, y: 50.4941))
        cgPath.addCurve(to: CGPoint(x: 36.4688, y: 45.8555),
                        control1: CGPoint(x: 33.4805, y: 47.1934),
                        control2: CGPoint(x: 34.8184, y: 45.8555))
        cgPath.addCurve(to: CGPoint(x: 38.2295, y: 46.2582),
                        control1: CGPoint(x: 37.406, y: 45.8555),
                        control2: CGPoint(x: 37.9564, y: 46.1233))
        cgPath.addCurve(to: CGPoint(x: 39.5853, y: 50.2609),
                        control1: CGPoint(x: 39.7092, y: 46.9891),
                        control2: CGPoint(x: 40.3162, y: 48.7812))
        cgPath.addCurve(to: CGPoint(x: 35.5826, y: 51.6166),
                        control1: CGPoint(x: 38.8544, y: 51.7406),
                        control2: CGPoint(x: 37.0623, y: 52.3476))
        cgPath.addCurve(to: CGPoint(x: 36.4688, y: 51.832),
                        control1: CGPoint(x: 35.3572, y: 51.5053),
                        control2: CGPoint(x: 36.9275, y: 51.832))
        let path = Path(cgPath: cgPath)
        let result = path.crossingsRemoved(accuracy: 0.0001)
        XCTAssertEqual(path.boundingBox.size.x, result.boundingBox.size.x, accuracy: 0.01)
        XCTAssertEqual(path.boundingBox.size.y, result.boundingBox.size.y, accuracy: 0.01)
    }

    func testCrossingsRemovedTwoOverlappingCircles2() {
        let cgPath = CGMutablePath()
        // component 0: clean circle centered near (84.5, 0)
        cgPath.move(to: CGPoint(x: 87.4883, y: 0))
        cgPath.addCurve(to: CGPoint(x: 84.5, y: 2.98828),
                        control1: CGPoint(x: 87.4883, y: 1.65038),
                        control2: CGPoint(x: 86.1504, y: 2.98828))
        cgPath.addCurve(to: CGPoint(x: 81.5117, y: 0),
                        control1: CGPoint(x: 82.8496, y: 2.98828),
                        control2: CGPoint(x: 81.5117, y: 1.65038))
        cgPath.addCurve(to: CGPoint(x: 84.5, y: -2.98828),
                        control1: CGPoint(x: 81.5117, y: -1.65038),
                        control2: CGPoint(x: 82.8496, y: -2.98828))
        cgPath.addCurve(to: CGPoint(x: 87.4883, y: 0),
                        control1: CGPoint(x: 86.1504, y: -2.98828),
                        control2: CGPoint(x: 87.4883, y: -1.65038))
        // component 1: irregular near-circle centered near (84.1875, 0)
        cgPath.move(to: CGPoint(x: 84.1875, y: 2.98828))
        cgPath.addCurve(to: CGPoint(x: 81.1992, y: 1.82979e-16),
                        control1: CGPoint(x: 82.5371, y: 2.98828),
                        control2: CGPoint(x: 81.1992, y: 1.65038))
        cgPath.addCurve(to: CGPoint(x: 84.1875, y: -2.98828),
                        control1: CGPoint(x: 81.1992, y: -1.65038),
                        control2: CGPoint(x: 82.5371, y: -2.98828))
        cgPath.addLine(to: CGPoint(x: 84.4035, y: -2.98728))
        cgPath.addCurve(to: CGPoint(x: 84.2974, y: -2.98111),
                        control1: CGPoint(x: 84.4271, y: -2.98689),
                        control2: CGPoint(x: 84.2343, y: -2.97689))
        cgPath.addCurve(to: CGPoint(x: 84.1259, y: -2.96459),
                        control1: CGPoint(x: 84.3331, y: -2.9835),
                        control2: CGPoint(x: 84.0369, y: -2.95339))
        cgPath.addCurve(to: CGPoint(x: 83.9162, y: -2.93059),
                        control1: CGPoint(x: 84.1749, y: -2.97075),
                        control2: CGPoint(x: 83.8183, y: -2.91109))
        cgPath.addCurve(to: CGPoint(x: 83.3546, y: -2.76001),
                        control1: CGPoint(x: 84.0239, y: -2.95202),
                        control2: CGPoint(x: 83.0458, y: -2.63186))
        cgPath.addCurve(to: CGPoint(x: 87.26, y: -1.1451),
                        control1: CGPoint(x: 84.879, y: -3.39249),
                        control2: CGPoint(x: 86.6275, y: -2.66947))
        cgPath.addCurve(to: CGPoint(x: 85.6451, y: 2.76025),
                        control1: CGPoint(x: 87.8925, y: 0.379281),
                        control2: CGPoint(x: 87.1695, y: 2.12776))
        cgPath.addCurve(to: CGPoint(x: 84.5723, y: 2.98795),
                        control1: CGPoint(x: 84.0486, y: 3.42263),
                        control2: CGPoint(x: 84.6252, y: 2.98648))
        cgPath.closeSubpath()
        let path = Path(cgPath: cgPath)
        let result = path.crossingsRemoved(accuracy: 0.0001)
        XCTAssertEqual(path.boundingBox.size.x, result.boundingBox.size.x, accuracy: 0.01)
        XCTAssertEqual(path.boundingBox.size.y, result.boundingBox.size.y, accuracy: 0.01)
    }

    func testTempE10E12Direct() {
        let e10 = CubicCurve(p0: CGPoint(x: -126.87232949400304, y: 148.4386462568562),
                             p1: CGPoint(x: -126.82100381061004, y: 148.31221332475099),
                             p2: CGPoint(x: -126.82100381061004, y: 148.31221332475099),
                             p3: CGPoint(x: -126.81891437160884, y: 148.3065860870587))
        let e12 = CubicCurve(p0: CGPoint(x: -126.8630702627638, y: 148.41570993771296),
                             p1: CGPoint(x: -125.21959509823608, y: 144.43288248399367),
                             p2: CGPoint(x: -124.66218794011559, y: 135.65291348287798),
                             p3: CGPoint(x: -125.61806652900981, y: 128.80510029733443))
        let e13 = CubicCurve(p0: CGPoint(x: -125.61806652900981, y: 128.80510029733443),
                             p1: CGPoint(x: -126.57394511790403, y: 121.95728711179089),
                             p2: CGPoint(x: -128.6811376781718, y: 119.63475728628889),
                             p3: CGPoint(x: -130.32461284270224, y: 123.6175847400148))
        let e16 = CubicCurve(p0: CGPoint(x: -130.33281854714375, y: 123.63796844315559),
                             p1: CGPoint(x: -130.2863291848816, y: 123.52141357138696),
                             p2: CGPoint(x: -130.2863291848816, y: 123.52141357138696),
                             p3: CGPoint(x: -130.08266939492287, y: 123.0881154324443))
        let e10e12 = e10.intersections(with: e12, accuracy: 0.0001)
        let e13e16 = e13.intersections(with: e16, accuracy: 0.0001)
        XCTAssertEqual(e10e12.count, 0, "E10∩E12 count")
        XCTAssertEqual(e13e16.count, 1, "E13∩E16 count")
    }

    func testCrossingsRemovedFourthRealWorldCase() {
        // single self-intersecting component with 27 elements; previously crossingsRemoved
        // returned an empty or degenerate result due to bezier-clipping budget exhaustion
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: -131.0439804414381, y: 125.95711173465887))
        cgPath.addCurve(to: CGPoint(x: -130.77374654941084, y: 124.90716552347212),
                        control1: CGPoint(x: -130.96209115248027, y: 125.59190742023301),
                        control2: CGPoint(x: -130.8715773273373, y: 125.2407572813251))
        cgPath.addCurve(to: CGPoint(x: -130.7200836936527, y: 124.728344965607),
                        control1: CGPoint(x: -130.7409023459286, y: 124.79638749713644),
                        control2: CGPoint(x: -130.7409023459286, y: 124.79638749713644))
        cgPath.addCurve(to: CGPoint(x: -131.34768445847735, y: 127.38131307462626),
                        control1: CGPoint(x: -130.7230200005632, y: 124.64712120497364),
                        control2: CGPoint(x: -130.7230200005632, y: 124.64712120497364))
        cgPath.addLine(to: CGPoint(x: -132.04479562345017, y: 136.33336379332712))
        cgPath.addLine(to: CGPoint(x: -127.94056980136787, y: 150.1149441766425))
        cgPath.addLine(to: CGPoint(x: -127.51270697920403, y: 149.6445983515889))
        cgPath.addLine(to: CGPoint(x: -127.29673858082157, y: 149.31026379759442))
        cgPath.addLine(to: CGPoint(x: -127.19565335710216, y: 149.12961568397853))
        cgPath.addLine(to: CGPoint(x: -127.14494841559127, y: 149.03291637666047))
        cgPath.addCurve(to: CGPoint(x: -126.87232949400304, y: 148.4386462568562),
                        control1: CGPoint(x: -126.91928978521454, y: 148.5563279928645),
                        control2: CGPoint(x: -126.91928978521454, y: 148.5563279928645))
        cgPath.addCurve(to: CGPoint(x: -126.81891437160884, y: 148.3065860870587),
                        control1: CGPoint(x: -126.82100381061004, y: 148.31221332475099),
                        control2: CGPoint(x: -126.82100381061004, y: 148.31221332475099))
        cgPath.addCurve(to: CGPoint(x: -126.8630702627638, y: 148.41570993771296),
                        control1: CGPoint(x: -126.83184177645951, y: 148.33917557887608),
                        control2: CGPoint(x: -126.83184177645951, y: 148.33917557887608))
        cgPath.addCurve(to: CGPoint(x: -125.61806652900981, y: 128.80510029733443),
                        control1: CGPoint(x: -125.21959509823608, y: 144.43288248399367),
                        control2: CGPoint(x: -124.66218794011559, y: 135.65291348287798))
        cgPath.addCurve(to: CGPoint(x: -130.32461284270224, y: 123.6175847400148),
                        control1: CGPoint(x: -126.57394511790403, y: 121.95728711179089),
                        control2: CGPoint(x: -128.6811376781718, y: 119.63475728628889))
        cgPath.addCurve(to: CGPoint(x: -130.38292936690004, y: 123.76176381068413),
                        control1: CGPoint(x: -130.36463468304368, y: 123.71565068073693),
                        control2: CGPoint(x: -130.36463468304368, y: 123.71565068073693))
        cgPath.addCurve(to: CGPoint(x: -130.33281854714375, y: 123.63796844315559),
                        control1: CGPoint(x: -130.382900758539, y: 123.76133343503324),
                        control2: CGPoint(x: -130.382900758539, y: 123.76133343503324))
        cgPath.addCurve(to: CGPoint(x: -130.08266939492287, y: 123.0881154324443),
                        control1: CGPoint(x: -130.2863291848816, y: 123.52141357138696),
                        control2: CGPoint(x: -130.2863291848816, y: 123.52141357138696))
        cgPath.addLine(to: CGPoint(x: -130.01027583220983, y: 122.94877911367857))
        cgPath.addLine(to: CGPoint(x: -129.90922355890595, y: 122.76818921942686))
        cgPath.addLine(to: CGPoint(x: -129.69329216474878, y: 122.43391275620685))
        cgPath.addLine(to: CGPoint(x: -129.26545712213291, y: 121.96359892699498))
        cgPath.addLine(to: CGPoint(x: -125.53703487315062, y: 142.56177079566012))
        cgPath.addCurve(to: CGPoint(x: -126.47171528542721, y: 147.30319269081826),
                        control1: CGPoint(x: -126.48268039692829, y: 147.42988544797757),
                        control2: CGPoint(x: -126.48268039692829, y: 147.42988544797757))
        cgPath.addCurve(to: CGPoint(x: -126.41329568690841, y: 147.10799026873386),
                        control1: CGPoint(x: -126.45446689769328, y: 147.24686556701914),
                        control2: CGPoint(x: -126.45446689769328, y: 147.24686556701914))
        cgPath.addCurve(to: CGPoint(x: -126.01305691207703, y: 145.54178963252627),
                        control1: CGPoint(x: -126.27879555748534, y: 146.649360218389),
                        control2: CGPoint(x: -126.14513316579554, y: 146.1308143792919))
        cgPath.addCurve(to: CGPoint(x: -126.17835732901345, y: 125.26835999742597),
                        control1: CGPoint(x: -124.71509864007656, y: 139.7532430849646),
                        control2: CGPoint(x: -124.78910615759808, y: 130.6765194640968))
        cgPath.addCurve(to: CGPoint(x: -131.0439804414381, y: 125.95711173465887),
                        control1: CGPoint(x: -127.5676085004288, y: 119.86020053075514),
                        control2: CGPoint(x: -129.7460221694371, y: 120.16856518709484))
        cgPath.closeSubpath()
        let path = Path(cgPath: cgPath)
        let result = path.crossingsRemoved(accuracy: 0.0001)
        XCTAssertFalse(result.isEmpty)
        XCTAssertGreaterThan(result.boundingBox.size.x, 0)
        XCTAssertGreaterThan(result.boundingBox.size.y, 0)
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

    func testUnionRealWorldIssue() {
        // this test data has an intersection that is very close to the end of a path element
        // in practice there was an issue where if the intersection were not computed precisely
        // the classification of the edge beginning at that intersection could be incorrect
        let p1 = CGMutablePath()
        p1.move(to: CGPoint(x: 160.30770651563628, y: 827.7553004653367))
        p1.addCurve(to: CGPoint(x: 110.26942663248718, y: 568.5268524837642),
                    control1: CGPoint(x: 181.33161356383755, y: 737.7466984152248),
                    control2: CGPoint(x: 164.05060972624904, y: 653.3356412085424))
        p1.addCurve(to: CGPoint(x: 68.86790851824688, y: 559.2578558910238),
                    control1: CGPoint(x: 101.39627582752009, y: 554.534576214393),
                    control2: CGPoint(x: 82.86018478761805, y: 550.3847050860568))
        p1.addCurve(to: CGPoint(x: 59.59891192550654, y: 600.6593740052641),
                    control1: CGPoint(x: 54.875632248875704, y: 568.1310066959909),
                    control2: CGPoint(x: 50.725761120539445, y: 586.667097735893))
        p1.addCurve(to: CGPoint(x: 101.88038125865839, y: 814.1080420111522),
                    control1: CGPoint(x: 105.11513351206828, y: 672.4349541994575),
                    control2: CGPoint(x: 119.06082214735332, y: 740.5542794564268))
        p1.addCurve(to: CGPoint(x: 124.27041466005505, y: 850.1453338667334),
                    control1: CGPoint(x: 98.11179489803564, y: 830.2423023675684),
                    control2: CGPoint(x: 108.13615430363883, y: 846.3767475061106))
        p1.addCurve(to: CGPoint(x: 160.30770651563628, y: 827.7553004653367),
                    control1: CGPoint(x: 140.40467501647126, y: 853.9139202273561),
                    control2: CGPoint(x: 156.53912015501353, y: 843.889560821753))

        let p2 = CGMutablePath()
        p2.move(to: CGPoint(x: 110.01560660410875, y: 568.1334199999095))
        p2.addCurve(to: CGPoint(x: -34.46691786355873, y: 426.72807843882487),
                    control1: CGPoint(x: 64.94829801467844, y: 499.45942595887277),
                    control2: CGPoint(x: 20.78869552632778, y: 454.67344613026177))
        p2.addCurve(to: CGPoint(x: -69.07061390857123, y: 474.860094579322),
                    control1: CGPoint(x: -65.01464367993249, y: 411.2786538880151),
                    control2: CGPoint(x: -93.44515961076199, y: 450.82408423410607))
        p2.addLine(to: CGPoint(x: 63.869824962902115, y: 605.9541384664693))
        p2.addCurve(to: CGPoint(x: 110.01560660410875, y: 568.1334199999095),
                    control1: CGPoint(x: 89.4862743247028, y: 631.2148038093562),
                    control2: CGPoint(x: 129.75430800678396, y: 598.2114411849384))

        let point1 = CGPoint(x: 90, y: 650)
        let point2 = CGPoint(x: -30, y: 450)
        let path1 = Path(cgPath: p1)
        let path2 = Path(cgPath: p2)

        let rule: PathFillRule = .evenOdd

        XCTAssertTrue(path1.contains(point1, using: rule))
        XCTAssertFalse(path2.contains(point1, using: rule))
        XCTAssertFalse(path1.contains(point2, using: rule))
        XCTAssertTrue(path2.contains(point2, using: rule))

        let result = path1.union(path2, accuracy: 0.5)
        XCTAssertTrue(result.contains(point1, using: rule), "point1 is in path1 so it should be in the union")
        XCTAssertTrue(result.contains(point2, using: rule), "point2 is in path2 so it should be in the union")
    }

    func testCrossingsRemovedAugmentedGraphDuplicateNeighborAssert() {
        // this path was triggering assert(self.neighborsContain(node) == false) in AugmentedGraph
        // when sortAndMergeDuplicates merged two nodes that were already mutual neighbors
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 5.42578, y: 50.875))
        cgPath.addCurve(to: CGPoint(x: 5.28516, y: 50.7812), control1: CGPoint(x: 5.32031, y: 50.8125), control2: CGPoint(x: 5.19531, y: 50.75))
        cgPath.addCurve(to: CGPoint(x: 5.42578, y: 50.875), control1: CGPoint(x: 5.33203, y: 50.8125), control2: CGPoint(x: 5.37891, y: 50.8438))
        cgPath.addCurve(to: CGPoint(x: 8.27344, y: 52.2812), control1: CGPoint(x: 6.47656, y: 51.5), control2: CGPoint(x: 7.26562, y: 51.9062))
        cgPath.addCurve(to: CGPoint(x: 14.0547, y: 53.4375), control1: CGPoint(x: 9.6875, y: 52.8438), control2: CGPoint(x: 11.5547, y: 53.2812))
        cgPath.addLine(to: CGPoint(x: 15.5703, y: 53.4688))
        cgPath.addCurve(to: CGPoint(x: 19.2656, y: 53.5), control1: CGPoint(x: 17.5, y: 53.5625), control2: CGPoint(x: 18.5156, y: 53.5625))
        cgPath.addLine(to: CGPoint(x: 21.3594, y: 53.4062))
        cgPath.addLine(to: CGPoint(x: 23.0469, y: 53.125))
        cgPath.addCurve(to: CGPoint(x: 30, y: 51.4375), control1: CGPoint(x: 25.25, y: 52.75), control2: CGPoint(x: 27.5156, y: 52.1875))
        cgPath.addLine(to: CGPoint(x: 30.4844, y: 51.2812))
        cgPath.addCurve(to: CGPoint(x: 28.7031, y: 63.8438), control1: CGPoint(x: 29.8125, y: 55.5625), control2: CGPoint(x: 29.1875, y: 59.8438))
        cgPath.addLine(to: CGPoint(x: 28.3906, y: 66.6875))
        cgPath.addCurve(to: CGPoint(x: 27.875, y: 75.75), control1: CGPoint(x: 28.0938, y: 69.75), control2: CGPoint(x: 27.9219, y: 72.8125))
        cgPath.addCurve(to: CGPoint(x: 28.0625, y: 87.3125), control1: CGPoint(x: 27.8281, y: 79.5), control2: CGPoint(x: 27.8125, y: 83.3125))
        cgPath.addCurve(to: CGPoint(x: 29.0625, y: 96.375), control1: CGPoint(x: 28.2656, y: 90.5), control2: CGPoint(x: 28.7031, y: 93.5625))
        cgPath.addLine(to: CGPoint(x: 30.1406, y: 104.875))
        cgPath.addLine(to: CGPoint(x: 31.1094, y: 113))
        cgPath.addLine(to: CGPoint(x: 32.3125, y: 124.312))
        cgPath.addLine(to: CGPoint(x: 32.625, y: 127.562))
        cgPath.addLine(to: CGPoint(x: 32.8438, y: 130.125))
        cgPath.addLine(to: CGPoint(x: 33.1875, y: 133.75))
        cgPath.addLine(to: CGPoint(x: 30.0469, y: 135.625))
        cgPath.addLine(to: CGPoint(x: 24.6094, y: 138.625))
        cgPath.addLine(to: CGPoint(x: 21.7188, y: 140.25))
        cgPath.addCurve(to: CGPoint(x: 19.6719, y: 145.625), control1: CGPoint(x: 21.1094, y: 142), control2: CGPoint(x: 20.4219, y: 143.875))
        cgPath.addCurve(to: CGPoint(x: 17.6875, y: 150), control1: CGPoint(x: 19.0156, y: 147.125), control2: CGPoint(x: 18.3438, y: 148.625))
        cgPath.addCurve(to: CGPoint(x: 16.1719, y: 153.125), control1: CGPoint(x: 17.25, y: 151.125), control2: CGPoint(x: 16.5781, y: 152.25))
        cgPath.addCurve(to: CGPoint(x: 11.9375, y: 160.375), control1: CGPoint(x: 14.6719, y: 155.875), control2: CGPoint(x: 13.2578, y: 158.25))
        cgPath.addCurve(to: CGPoint(x: 7.1875, y: 167), control1: CGPoint(x: 10.4531, y: 162.625), control2: CGPoint(x: 8.90625, y: 164.875))
        cgPath.addLine(to: CGPoint(x: 4.69922, y: 170))
        cgPath.addCurve(to: CGPoint(x: -6.66797, y: 179.375), control1: CGPoint(x: 0.932129, y: 174), control2: CGPoint(x: -2.57422, y: 177.125))
        cgPath.addCurve(to: CGPoint(x: -13.9688, y: 182.375), control1: CGPoint(x: -8.10156, y: 180.25), control2: CGPoint(x: -10.6094, y: 181.625))
        cgPath.addLine(to: CGPoint(x: -17.7344, y: 182.625))
        cgPath.addCurve(to: CGPoint(x: -24.0469, y: 182), control1: CGPoint(x: -18.3594, y: 182.75), control2: CGPoint(x: -20.8594, y: 182.875))
        cgPath.addCurve(to: CGPoint(x: -34.5, y: 174.375), control1: CGPoint(x: -28.5469, y: 180.25), control2: CGPoint(x: -32.0625, y: 177.75))
        cgPath.addCurve(to: CGPoint(x: -38.3125, y: 164), control1: CGPoint(x: -36.2812, y: 171.75), control2: CGPoint(x: -37.9688, y: 168.125))
        cgPath.addCurve(to: CGPoint(x: -38.3438, y: 159.875), control1: CGPoint(x: -38.4375, y: 162.375), control2: CGPoint(x: -38.4062, y: 161))
        cgPath.addLine(to: CGPoint(x: -41.25, y: 159.875))
        cgPath.addCurve(to: CGPoint(x: -52.7812, y: 158.625), control1: CGPoint(x: -45.2812, y: 159.875), control2: CGPoint(x: -49.1562, y: 159.375))
        cgPath.addCurve(to: CGPoint(x: -54.4062, y: 158.25), control1: CGPoint(x: -53.2812, y: 158.5), control2: CGPoint(x: -53.8125, y: 158.375))
        cgPath.addCurve(to: CGPoint(x: -60.0625, y: 168.25), control1: CGPoint(x: -55.9688, y: 161.75), control2: CGPoint(x: -57.8125, y: 165))
        cgPath.addCurve(to: CGPoint(x: -62.0938, y: 171.375), control1: CGPoint(x: -60.5625, y: 169.125), control2: CGPoint(x: -61.375, y: 170.25))
        cgPath.addCurve(to: CGPoint(x: -72.25, y: 181.75), control1: CGPoint(x: -65.3125, y: 175.75), control2: CGPoint(x: -68.9375, y: 179.125))
        cgPath.addCurve(to: CGPoint(x: -83.25, y: 186.875), control1: CGPoint(x: -74.9375, y: 183.625), control2: CGPoint(x: -77.875, y: 186))
        cgPath.addCurve(to: CGPoint(x: -86.6875, y: 187.125), control1: CGPoint(x: -84.5625, y: 187.125), control2: CGPoint(x: -86.0625, y: 187.125))
        cgPath.addCurve(to: CGPoint(x: -91.125, y: 186.875), control1: CGPoint(x: -88, y: 187.375), control2: CGPoint(x: -90.125, y: 187))
        cgPath.addCurve(to: CGPoint(x: -94, y: 186), control1: CGPoint(x: -92.125, y: 186.625), control2: CGPoint(x: -93.125, y: 186.375))
        cgPath.addCurve(to: CGPoint(x: -97.4375, y: 184.375), control1: CGPoint(x: -95.125, y: 185.5), control2: CGPoint(x: -96.1875, y: 185))
        cgPath.addCurve(to: CGPoint(x: -104.312, y: 177.5), control1: CGPoint(x: -101.438, y: 181.75), control2: CGPoint(x: -103.062, y: 179.375))
        cgPath.addCurve(to: CGPoint(x: -105, y: 176.375), control1: CGPoint(x: -104.5, y: 177.125), control2: CGPoint(x: -104.75, y: 176.75))
        cgPath.addLine(to: CGPoint(x: -108.188, y: 177.625))
        cgPath.addCurve(to: CGPoint(x: -125.062, y: 182.375), control1: CGPoint(x: -114.312, y: 180), control2: CGPoint(x: -119.938, y: 181.375))
        cgPath.addCurve(to: CGPoint(x: -129.875, y: 183.125), control1: CGPoint(x: -126.5, y: 182.625), control2: CGPoint(x: -128, y: 183))
        cgPath.addCurve(to: CGPoint(x: -134, y: 183.5), control1: CGPoint(x: -130.75, y: 183.25), control2: CGPoint(x: -132.125, y: 183.5))
        cgPath.addLine(to: CGPoint(x: -137.125, y: 183.5))
        cgPath.addLine(to: CGPoint(x: -140.5, y: 183.5))
        cgPath.addCurve(to: CGPoint(x: -149.375, y: 182), control1: CGPoint(x: -143.75, y: 183.25), control2: CGPoint(x: -146.375, y: 183))
        cgPath.addCurve(to: CGPoint(x: -153.875, y: 180.375), control1: CGPoint(x: -150.875, y: 181.75), control2: CGPoint(x: -152.625, y: 181))
        cgPath.addCurve(to: CGPoint(x: -156.625, y: 178.875), control1: CGPoint(x: -154.5, y: 180.25), control2: CGPoint(x: -156, y: 179.25))
        cgPath.addCurve(to: CGPoint(x: -163.625, y: 172.375), control1: CGPoint(x: -159.375, y: 177.25), control2: CGPoint(x: -161.75, y: 175))
        cgPath.addCurve(to: CGPoint(x: -168.875, y: 160), control1: CGPoint(x: -166.25, y: 169), control2: CGPoint(x: -168.125, y: 164.75))
        cgPath.addCurve(to: CGPoint(x: -169.375, y: 157.125), control1: CGPoint(x: -169.375, y: 158.5), control2: CGPoint(x: -169.375, y: 157.125))
        cgPath.addCurve(to: CGPoint(x: -169.5, y: 155.625), control1: CGPoint(x: -169.375, y: 156.625), control2: CGPoint(x: -169.5, y: 156.125))
        cgPath.addCurve(to: CGPoint(x: -167.125, y: 138.75), control1: CGPoint(x: -169.75, y: 150.375), control2: CGPoint(x: -169.25, y: 144.625))
        cgPath.addCurve(to: CGPoint(x: -165.25, y: 134.125), control1: CGPoint(x: -166.625, y: 137.125), control2: CGPoint(x: -165.875, y: 135.5))
        cgPath.addCurve(to: CGPoint(x: -162.75, y: 129.75), control1: CGPoint(x: -164.875, y: 133.5), control2: CGPoint(x: -164.25, y: 131.875))
        cgPath.addCurve(to: CGPoint(x: -151, y: 116.438), control1: CGPoint(x: -159.875, y: 125.312), control2: CGPoint(x: -155.75, y: 120.688))
        cgPath.addCurve(to: CGPoint(x: -148, y: 113.812), control1: CGPoint(x: -149.875, y: 115.375), control2: CGPoint(x: -148.875, y: 114.562))
        cgPath.addLine(to: CGPoint(x: -143.75, y: 110.5))
        cgPath.addCurve(to: CGPoint(x: -131.875, y: 102.312), control1: CGPoint(x: -140.125, y: 107.625), control2: CGPoint(x: -136, y: 104.875))
        cgPath.addLine(to: CGPoint(x: -127.125, y: 99.5625))
        cgPath.addCurve(to: CGPoint(x: -118.438, y: 95.5), control1: CGPoint(x: -124, y: 97.875), control2: CGPoint(x: -121.062, y: 96.625))
        cgPath.addCurve(to: CGPoint(x: -104.688, y: 91.4375), control1: CGPoint(x: -113.875, y: 93.5), control2: CGPoint(x: -109.188, y: 92.1875))
        cgPath.addCurve(to: CGPoint(x: -98.75, y: 90.6875), control1: CGPoint(x: -103.875, y: 91.25), control2: CGPoint(x: -101.875, y: 90.6875))
        cgPath.addLine(to: CGPoint(x: -95.625, y: 90.6875))
        cgPath.addCurve(to: CGPoint(x: -91.5625, y: 90.75), control1: CGPoint(x: -94.5, y: 90.6875), control2: CGPoint(x: -93.125, y: 90.6875))
        cgPath.addCurve(to: CGPoint(x: -81.5625, y: 92.1875), control1: CGPoint(x: -88.3125, y: 90.8125), control2: CGPoint(x: -84.875, y: 91.3125))
        cgPath.addCurve(to: CGPoint(x: -76.875, y: 81.875), control1: CGPoint(x: -80.1875, y: 88.6875), control2: CGPoint(x: -78.625, y: 85.25))
        cgPath.addCurve(to: CGPoint(x: -62.625, y: 61.2812), control1: CGPoint(x: -72.8125, y: 74.25), control2: CGPoint(x: -68, y: 67.25))
        cgPath.addLine(to: CGPoint(x: -58.375, y: 56.8125))
        cgPath.addLine(to: CGPoint(x: -54.875, y: 53.5938))
        cgPath.addCurve(to: CGPoint(x: -50.1875, y: 49.7812), control1: CGPoint(x: -53.4688, y: 52.3438), control2: CGPoint(x: -52.0312, y: 51.0625))
        cgPath.addCurve(to: CGPoint(x: -45.8125, y: 47.0312), control1: CGPoint(x: -48.875, y: 48.8438), control2: CGPoint(x: -47.4688, y: 47.9062))
        cgPath.addCurve(to: CGPoint(x: -41.375, y: 45.0312), control1: CGPoint(x: -44.0938, y: 46.0938), control2: CGPoint(x: -42.5625, y: 45.4688))
        cgPath.addCurve(to: CGPoint(x: -35.5, y: 43.5312), control1: CGPoint(x: -40.3438, y: 44.625), control2: CGPoint(x: -38.625, y: 43.7812))
        cgPath.addCurve(to: CGPoint(x: -31.4844, y: 43.4688), control1: CGPoint(x: -33.8438, y: 43.375), control2: CGPoint(x: -32.3438, y: 43.4375))
        cgPath.addCurve(to: CGPoint(x: -27.1875, y: 44.1562), control1: CGPoint(x: -30.125, y: 43.4688), control2: CGPoint(x: -28.4531, y: 43.7812))
        cgPath.addCurve(to: CGPoint(x: -23.0156, y: 46.0938), control1: CGPoint(x: -25.7344, y: 44.5938), control2: CGPoint(x: -24.3125, y: 45.25))
        cgPath.addLine(to: CGPoint(x: -23.0625, y: 45.4375))
        cgPath.addLine(to: CGPoint(x: -23.0625, y: 43.7188))
        cgPath.addCurve(to: CGPoint(x: -22.7812, y: 36.1562), control1: CGPoint(x: -23.125, y: 41.25), control2: CGPoint(x: -23.0781, y: 38.75))
        cgPath.addCurve(to: CGPoint(x: -22, y: 31.1406), control1: CGPoint(x: -22.6094, y: 34.625), control2: CGPoint(x: -22.375, y: 32.9062))
        cgPath.addLine(to: CGPoint(x: -21.6875, y: 29.7344))
        cgPath.addLine(to: CGPoint(x: -21.3594, y: 28.2188))
        cgPath.addCurve(to: CGPoint(x: -20.3281, y: 24.1094), control1: CGPoint(x: -21.125, y: 27.1875), control2: CGPoint(x: -20.7969, y: 25.7031))
        cgPath.addLine(to: CGPoint(x: -19.6562, y: 21.75))
        cgPath.addLine(to: CGPoint(x: -18.5156, y: 17.6875))
        cgPath.addLine(to: CGPoint(x: -17.5938, y: 14.4453))
        cgPath.addLine(to: CGPoint(x: -16.0938, y: 8.89844))
        cgPath.addLine(to: CGPoint(x: -15.6953, y: 7.20312))
        cgPath.addLine(to: CGPoint(x: -15.1016, y: 4.01953))
        cgPath.addCurve(to: CGPoint(x: -14.3047, y: 0.496582), control1: CGPoint(x: -14.8438, y: 2.65625), control2: CGPoint(x: -14.5547, y: 1.46973))
        cgPath.addCurve(to: CGPoint(x: -11.0156, y: -6.08984), control1: CGPoint(x: -14.1328, y: -0.137451), control2: CGPoint(x: -14.0234, y: -2.6582))
        cgPath.addCurve(to: CGPoint(x: -8.53125, y: -8.375), control1: CGPoint(x: -10.3125, y: -6.88672), control2: CGPoint(x: -9.50781, y: -7.65625))
        cgPath.addCurve(to: CGPoint(x: 3.23242, y: -11.5156), control1: CGPoint(x: -5.57422, y: -11.3828), control2: CGPoint(x: -1.11426, y: -12.7344))
        cgPath.addCurve(to: CGPoint(x: 11.5156, y: 3.21875), control1: CGPoint(x: 9.58594, y: -9.73438), control2: CGPoint(x: 13.2969, y: -3.13672))
        cgPath.addCurve(to: CGPoint(x: 8.36719, y: 8.59375), control1: CGPoint(x: 10.9375, y: 5.28906), control2: CGPoint(x: 9.66406, y: 7.17578))
        cgPath.addLine(to: CGPoint(x: 7.69141, y: 12.1641))
        cgPath.addLine(to: CGPoint(x: 7.08984, y: 14.7266))
        cgPath.addLine(to: CGPoint(x: 5.41406, y: 20.9219))
        cgPath.addLine(to: CGPoint(x: 4.49219, y: 24.2031))
        cgPath.addLine(to: CGPoint(x: 3.33984, y: 28.2969))
        cgPath.addLine(to: CGPoint(x: 2.66016, y: 30.6719))
        cgPath.addLine(to: CGPoint(x: 1.90234, y: 33.75))
        cgPath.addLine(to: CGPoint(x: 1.75488, y: 34.4375))
        cgPath.addLine(to: CGPoint(x: 1.37598, y: 36.1562))
        cgPath.addLine(to: CGPoint(x: 0.973633, y: 38.8438))
        cgPath.addCurve(to: CGPoint(x: 0.831543, y: 43.0938), control1: CGPoint(x: 0.839844, y: 40), control2: CGPoint(x: 0.793457, y: 41.4375))
        cgPath.addLine(to: CGPoint(x: 0.833496, y: 44.8438))
        cgPath.addLine(to: CGPoint(x: 0.964355, y: 45.625))
        cgPath.addLine(to: CGPoint(x: 1.03027, y: 45.9062))
        cgPath.addCurve(to: CGPoint(x: 1.98926, y: 48.0625), control1: CGPoint(x: 1.34473, y: 46.875), control2: CGPoint(x: 1.71387, y: 47.625))
        cgPath.addCurve(to: CGPoint(x: 4.00391, y: 49.875), control1: CGPoint(x: 2.15234, y: 48.3125), control2: CGPoint(x: 2.74805, y: 48.9688))
        cgPath.addLine(to: CGPoint(x: 5.30859, y: 50.8125))
        cgPath.addLine(to: CGPoint(x: 5.53906, y: 50.9375))
        cgPath.addCurve(to: CGPoint(x: 5.42578, y: 50.875), control1: CGPoint(x: 5.57812, y: 50.9688), control2: CGPoint(x: 5.50781, y: 50.9375))

        cgPath.move(to: CGPoint(x: 27.0938, y: 102))
        cgPath.addCurve(to: CGPoint(x: 24.1875, y: 104.312), control1: CGPoint(x: 26.125, y: 102.75), control2: CGPoint(x: 25.1562, y: 103.5))
        cgPath.addCurve(to: CGPoint(x: 25.1094, y: 108.188), control1: CGPoint(x: 24.5625, y: 105.625), control2: CGPoint(x: 24.8594, y: 106.938))
        cgPath.addCurve(to: CGPoint(x: 25.5, y: 110.562), control1: CGPoint(x: 25.2344, y: 108.812), control2: CGPoint(x: 25.375, y: 109.625))
        cgPath.addCurve(to: CGPoint(x: 26.5781, y: 109.875), control1: CGPoint(x: 25.8594, y: 110.312), control2: CGPoint(x: 26.2188, y: 110.125))
        cgPath.addCurve(to: CGPoint(x: 26.8281, y: 104.188), control1: CGPoint(x: 26.5469, y: 108), control2: CGPoint(x: 26.6406, y: 106.125))
        cgPath.addCurve(to: CGPoint(x: 27.0938, y: 102), control1: CGPoint(x: 26.9062, y: 103.438), control2: CGPoint(x: 27, y: 102.688))

        cgPath.move(to: CGPoint(x: -31.6406, y: 134.875))
        cgPath.addCurve(to: CGPoint(x: -30.375, y: 132.375), control1: CGPoint(x: -31.25, y: 134.125), control2: CGPoint(x: -30.8281, y: 133.25))
        cgPath.addCurve(to: CGPoint(x: -27.8438, y: 127.75), control1: CGPoint(x: -29.5781, y: 130.75), control2: CGPoint(x: -28.6719, y: 129.25))
        cgPath.addCurve(to: CGPoint(x: -21.2188, y: 117.5), control1: CGPoint(x: -25.7656, y: 124.062), control2: CGPoint(x: -23.4375, y: 120.75))
        cgPath.addCurve(to: CGPoint(x: -17.2656, y: 112.188), control1: CGPoint(x: -20.125, y: 115.875), control2: CGPoint(x: -18.8281, y: 114.062))
        cgPath.addCurve(to: CGPoint(x: -12.7891, y: 106.938), control1: CGPoint(x: -15.8281, y: 110.375), control2: CGPoint(x: -14.3047, y: 108.688))
        cgPath.addCurve(to: CGPoint(x: -7.33594, y: 101), control1: CGPoint(x: -11.1172, y: 105.062), control2: CGPoint(x: -9.32031, y: 103.062))
        cgPath.addCurve(to: CGPoint(x: -7.13672, y: 100.812), control1: CGPoint(x: -7.26953, y: 100.938), control2: CGPoint(x: -7.20312, y: 100.875))
        cgPath.addCurve(to: CGPoint(x: -11.0781, y: 99.3125), control1: CGPoint(x: -8.32031, y: 100.188), control2: CGPoint(x: -9.65625, y: 99.625))
        cgPath.addLine(to: CGPoint(x: -13.6328, y: 98.875))
        cgPath.addLine(to: CGPoint(x: -15.6328, y: 98.6875))
        cgPath.addLine(to: CGPoint(x: -18.6719, y: 98.6875))
        cgPath.addLine(to: CGPoint(x: -21.3125, y: 98.875))
        cgPath.addCurve(to: CGPoint(x: -21.7656, y: 98.9375), control1: CGPoint(x: -21.4531, y: 98.875), control2: CGPoint(x: -21.6094, y: 98.9375))
        cgPath.addLine(to: CGPoint(x: -24.6875, y: 99.625))
        cgPath.addCurve(to: CGPoint(x: -26.0938, y: 100.062), control1: CGPoint(x: -25.2188, y: 99.8125), control2: CGPoint(x: -25.6875, y: 99.9375))
        cgPath.addCurve(to: CGPoint(x: -32.4688, y: 111.812), control1: CGPoint(x: -28.125, y: 104.062), control2: CGPoint(x: -30.3125, y: 108))
        cgPath.addCurve(to: CGPoint(x: -35.375, y: 116.938), control1: CGPoint(x: -33.3125, y: 113.375), control2: CGPoint(x: -34.2812, y: 115.125))
        cgPath.addLine(to: CGPoint(x: -37.875, y: 120.875))
        cgPath.addCurve(to: CGPoint(x: -40.8125, y: 125.5), control1: CGPoint(x: -38.6875, y: 122.188), control2: CGPoint(x: -39.6562, y: 123.812))
        cgPath.addCurve(to: CGPoint(x: -47.9375, y: 135.125), control1: CGPoint(x: -43.0625, y: 128.75), control2: CGPoint(x: -45.4062, y: 132))
        cgPath.addCurve(to: CGPoint(x: -41.25, y: 135.875), control1: CGPoint(x: -45.2812, y: 135.75), control2: CGPoint(x: -43.25, y: 135.875))
        cgPath.addLine(to: CGPoint(x: -37.0312, y: 135.875))
        cgPath.addCurve(to: CGPoint(x: -34.125, y: 135.375), control1: CGPoint(x: -36.7812, y: 135.875), control2: CGPoint(x: -35.5312, y: 135.75))
        cgPath.addCurve(to: CGPoint(x: -31.6406, y: 134.875), control1: CGPoint(x: -33.3125, y: 135.25), control2: CGPoint(x: -32.4688, y: 135.125))

        cgPath.move(to: CGPoint(x: -7.83203, y: 70.75))
        cgPath.addCurve(to: CGPoint(x: -7.83203, y: 70.75), control1: CGPoint(x: -7.77344, y: 70.8125), control2: CGPoint(x: -7.69531, y: 70.8125))
        cgPath.addLine(to: CGPoint(x: -10.0938, y: 69.1875))
        cgPath.addCurve(to: CGPoint(x: -15.0234, y: 64.9375), control1: CGPoint(x: -11.7188, y: 68), control2: CGPoint(x: -13.4141, y: 66.625))
        cgPath.addCurve(to: CGPoint(x: -15.2031, y: 67.1875), control1: CGPoint(x: -15.0547, y: 65.625), control2: CGPoint(x: -15.1094, y: 66.375))
        cgPath.addCurve(to: CGPoint(x: -16.5312, y: 74.75), control1: CGPoint(x: -15.4766, y: 69.5625), control2: CGPoint(x: -15.9062, y: 72.0625))
        cgPath.addCurve(to: CGPoint(x: -14.4219, y: 74.8125), control1: CGPoint(x: -15.8203, y: 74.75), control2: CGPoint(x: -15.1172, y: 74.75))
        cgPath.addCurve(to: CGPoint(x: -10.2969, y: 75.1875), control1: CGPoint(x: -12.75, y: 74.875), control2: CGPoint(x: -11.3984, y: 75.0625))
        cgPath.addCurve(to: CGPoint(x: -5.69141, y: 76), control1: CGPoint(x: -8.58594, y: 75.4375), control2: CGPoint(x: -7.21875, y: 75.6875))
        cgPath.addCurve(to: CGPoint(x: 7.11719, y: 81.5), control1: CGPoint(x: -1.05273, y: 77.125), control2: CGPoint(x: 3.27539, y: 79))
        cgPath.addCurve(to: CGPoint(x: 10.6641, y: 84.125), control1: CGPoint(x: 8.54688, y: 82.5), control2: CGPoint(x: 9.6875, y: 83.375))
        cgPath.addCurve(to: CGPoint(x: 10.8828, y: 84.3125), control1: CGPoint(x: 10.7344, y: 84.1875), control2: CGPoint(x: 10.8047, y: 84.25))
        cgPath.addCurve(to: CGPoint(x: 20.1406, y: 77.375), control1: CGPoint(x: 13.8359, y: 81.9375), control2: CGPoint(x: 16.9062, y: 79.625))
        cgPath.addCurve(to: CGPoint(x: 15.0625, y: 77.375), control1: CGPoint(x: 18.6094, y: 77.5625), control2: CGPoint(x: 16.5938, y: 77.4375))
        cgPath.addCurve(to: CGPoint(x: 12.2422, y: 77.3125), control1: CGPoint(x: 14.7422, y: 77.375), control2: CGPoint(x: 13.6328, y: 77.375))
        cgPath.addCurve(to: CGPoint(x: -0.309814, y: 74.625), control1: CGPoint(x: 7.94922, y: 77), control2: CGPoint(x: 3.69336, y: 76.1875))
        cgPath.addCurve(to: CGPoint(x: -6.92969, y: 71.3125), control1: CGPoint(x: -2.60742, y: 73.75), control2: CGPoint(x: -4.84766, y: 72.625))
        cgPath.addLine(to: CGPoint(x: -7.82031, y: 70.75))
        cgPath.addCurve(to: CGPoint(x: -7.83203, y: 70.75), control1: CGPoint(x: -7.91406, y: 70.6875), control2: CGPoint(x: -7.87891, y: 70.75))

        cgPath.move(to: CGPoint(x: -143.25, y: 143.5))
        cgPath.addCurve(to: CGPoint(x: -143.25, y: 143.5), control1: CGPoint(x: -143.25, y: 143.625), control2: CGPoint(x: -143.25, y: 143.625))
        cgPath.addLine(to: CGPoint(x: -143.875, y: 144.875))
        cgPath.addLine(to: CGPoint(x: -144.5, y: 146.5))
        cgPath.addCurve(to: CGPoint(x: -145.625, y: 154.625), control1: CGPoint(x: -145.5, y: 149.125), control2: CGPoint(x: -145.75, y: 151.875))
        cgPath.addCurve(to: CGPoint(x: -145.5, y: 155.125), control1: CGPoint(x: -145.625, y: 154.75), control2: CGPoint(x: -145.625, y: 155))
        cgPath.addCurve(to: CGPoint(x: -144.5, y: 158.25), control1: CGPoint(x: -145.125, y: 157.125), control2: CGPoint(x: -144.75, y: 157.75))
        cgPath.addCurve(to: CGPoint(x: -144.125, y: 158.5), control1: CGPoint(x: -144.25, y: 158.5), control2: CGPoint(x: -144.375, y: 158.375))
        cgPath.addCurve(to: CGPoint(x: -144.25, y: 158.5), control1: CGPoint(x: -144, y: 158.625), control2: CGPoint(x: -144.125, y: 158.5))
        cgPath.addCurve(to: CGPoint(x: -143, y: 159), control1: CGPoint(x: -143, y: 159), control2: CGPoint(x: -143.125, y: 159))
        cgPath.addCurve(to: CGPoint(x: -139.75, y: 159.625), control1: CGPoint(x: -142.125, y: 159.25), control2: CGPoint(x: -141, y: 159.5))
        cgPath.addLine(to: CGPoint(x: -137.125, y: 159.5))
        cgPath.addLine(to: CGPoint(x: -134, y: 159.5))
        cgPath.addLine(to: CGPoint(x: -132.625, y: 159.375))
        cgPath.addLine(to: CGPoint(x: -129.625, y: 158.875))
        cgPath.addCurve(to: CGPoint(x: -116.875, y: 155.375), control1: CGPoint(x: -125.5, y: 158.125), control2: CGPoint(x: -121.312, y: 157))
        cgPath.addLine(to: CGPoint(x: -113, y: 153.875))
        cgPath.addLine(to: CGPoint(x: -108.688, y: 152))
        cgPath.addCurve(to: CGPoint(x: -107.625, y: 151.5), control1: CGPoint(x: -108.375, y: 151.875), control2: CGPoint(x: -108, y: 151.75))
        cgPath.addCurve(to: CGPoint(x: -107.312, y: 150.125), control1: CGPoint(x: -107.562, y: 151.125), control2: CGPoint(x: -107.438, y: 150.625))
        cgPath.addCurve(to: CGPoint(x: -106.25, y: 146.75), control1: CGPoint(x: -107.062, y: 149.25), control2: CGPoint(x: -106.75, y: 148.125))
        cgPath.addCurve(to: CGPoint(x: -96.5, y: 128.5), control1: CGPoint(x: -104.125, y: 140.875), control2: CGPoint(x: -100.875, y: 134.75))
        cgPath.addCurve(to: CGPoint(x: -93.8125, y: 124.938), control1: CGPoint(x: -95.6875, y: 127.312), control2: CGPoint(x: -94.75, y: 126.125))
        cgPath.addCurve(to: CGPoint(x: -86.6875, y: 116.125), control1: CGPoint(x: -91.75, y: 122.125), control2: CGPoint(x: -89.3125, y: 119.188))
        cgPath.addCurve(to: CGPoint(x: -86.6875, y: 115.625), control1: CGPoint(x: -86.6875, y: 115.938), control2: CGPoint(x: -86.6875, y: 115.75))
        cgPath.addCurve(to: CGPoint(x: -92.4375, y: 114.625), control1: CGPoint(x: -88.75, y: 115), control2: CGPoint(x: -90.5625, y: 114.688))
        cgPath.addLine(to: CGPoint(x: -95.625, y: 114.562))
        cgPath.addLine(to: CGPoint(x: -98.75, y: 114.562))
        cgPath.addCurve(to: CGPoint(x: -98.6875, y: 114.625), control1: CGPoint(x: -99, y: 114.562), control2: CGPoint(x: -98.4375, y: 114.562))
        cgPath.addLine(to: CGPoint(x: -100.375, y: 114.938))
        cgPath.addCurve(to: CGPoint(x: -109, y: 117.5), control1: CGPoint(x: -103.375, y: 115.438), control2: CGPoint(x: -106.188, y: 116.25))
        cgPath.addCurve(to: CGPoint(x: -115.75, y: 120.625), control1: CGPoint(x: -111.5, y: 118.5), control2: CGPoint(x: -113.688, y: 119.5))
        cgPath.addLine(to: CGPoint(x: -119.5, y: 122.75))
        cgPath.addCurve(to: CGPoint(x: -129.25, y: 129.5), control1: CGPoint(x: -122.812, y: 124.812), control2: CGPoint(x: -126.312, y: 127.188))
        cgPath.addLine(to: CGPoint(x: -132.75, y: 132.25))
        cgPath.addLine(to: CGPoint(x: -134.875, y: 134.125))
        cgPath.addCurve(to: CGPoint(x: -143, y: 143.25), control1: CGPoint(x: -138.5, y: 137.25), control2: CGPoint(x: -141.125, y: 140.375))
        cgPath.addCurve(to: CGPoint(x: -143.25, y: 143.5), control1: CGPoint(x: -143.125, y: 143.375), control2: CGPoint(x: -143.125, y: 143.5))

        cgPath.move(to: CGPoint(x: -50.9062, y: 85.0625))
        cgPath.addCurve(to: CGPoint(x: -46.0312, y: 82.375), control1: CGPoint(x: -49.4062, y: 84.125), control2: CGPoint(x: -47.7188, y: 83.25))
        cgPath.addCurve(to: CGPoint(x: -43.8125, y: 81.25), control1: CGPoint(x: -45.3438, y: 82), control2: CGPoint(x: -44.5938, y: 81.625))
        cgPath.addLine(to: CGPoint(x: -43.4375, y: 80.375))
        cgPath.addLine(to: CGPoint(x: -41.9375, y: 76.25))
        cgPath.addLine(to: CGPoint(x: -40.875, y: 73.1875))
        cgPath.addLine(to: CGPoint(x: -41.5938, y: 73.8125))
        cgPath.addLine(to: CGPoint(x: -44.9062, y: 77.3125))
        cgPath.addCurve(to: CGPoint(x: -50.9062, y: 85.0625), control1: CGPoint(x: -46.9375, y: 79.5625), control2: CGPoint(x: -48.9688, y: 82.1875))

        let path = Path(cgPath: cgPath)
        let result = path.crossingsRemoved(accuracy: 0.0001)

        // For each element in the original path, sample points offset by ±normal and verify
        // that containment agrees between the original (winding) and result (evenOdd).
        let testTs: [CGFloat] = [0.05, 0.5, 0.95]
        let normalDistance: CGFloat = 0.1
        for (componentIndex, component) in path.components.enumerated() {
            for elementIndex in 0..<component.numberOfElements {
                for t in testTs {
                    let location = IndexedPathComponentLocation(elementIndex: elementIndex, t: t)
                    let point = component.point(at: location)
                    let normal = component.normal(at: location)
                    guard normal.x != 0 || normal.y != 0 else { continue }
                    for sign: CGFloat in [1, -1] {
                        let testPoint = point + sign * normalDistance * normal
                        XCTAssertEqual(
                            path.contains(testPoint, using: .winding),
                            result.contains(testPoint, using: .evenOdd),
                            "Containment mismatch at component \(componentIndex), element \(elementIndex), t=\(t), sign=\(sign)"
                        )
                    }
                }
            }
        }
    }

    func testCrossingsRemovedCircleWithTube() {
        // A circle (component 0) intersected by a tube-like shape (component 1).
        // crossingsRemoved was returning an incorrect result for this input.
        let cgPath = CGMutablePath()
        // Component 0: circle
        cgPath.move(to: CGPoint(x: 67.05598962306976, y: 35.15625))
        cgPath.addCurve(to: CGPoint(x: 65.1875, y: 37.02473962306976),
                        control1: CGPoint(x: 67.05598962306976, y: 36.18818832398098),
                        control2: CGPoint(x: 66.21943832398098, y: 37.02473962306976))
        cgPath.addCurve(to: CGPoint(x: 63.31901037693024, y: 35.15625),
                        control1: CGPoint(x: 64.15556167601902, y: 37.02473962306976),
                        control2: CGPoint(x: 63.31901037693024, y: 36.18818832398098))
        cgPath.addCurve(to: CGPoint(x: 65.1875, y: 33.28776037693024),
                        control1: CGPoint(x: 63.31901037693024, y: 34.12431167601902),
                        control2: CGPoint(x: 64.15556167601902, y: 33.28776037693024))
        cgPath.addCurve(to: CGPoint(x: 67.05598962306976, y: 35.15625),
                        control1: CGPoint(x: 66.21943832398098, y: 33.28776037693024),
                        control2: CGPoint(x: 67.05598962306976, y: 34.12431167601902))
        // Component 1: tube-like shape passing through the circle
        cgPath.move(to: CGPoint(x: 63.02026378606149, y: 35.83404526742314))
        cgPath.addCurve(to: CGPoint(x: 62.72845473257686, y: 33.20776378606149),
                        control1: CGPoint(x: 62.21445533559582, y: 35.18939850705061),
                        control2: CGPoint(x: 62.083807972204326, y: 34.01357223652715))
        cgPath.addCurve(to: CGPoint(x: 65.35473621393851, y: 32.91595473257686),
                        control1: CGPoint(x: 63.37310149294939, y: 32.40195533559582),
                        control2: CGPoint(x: 64.54892776347285, y: 32.271307972204326))
        cgPath.addLine(to: CGPoint(x: 66.30892872311176, y: 33.66170958887128))
        cgPath.addCurve(to: CGPoint(x: 66.68167901539591, y: 36.27773026207722),
                        control1: CGPoint(x: 67.13425503555436, y: 34.28117159940185),
                        control2: CGPoint(x: 67.30114102592648, y: 35.45240394963462))
        cgPath.addCurve(to: CGPoint(x: 64.06565834218998, y: 36.65048055436137),
                        control1: CGPoint(x: 66.06221700486535, y: 37.10305657451982),
                        control2: CGPoint(x: 64.89098465463258, y: 37.26994256489194))
        cgPath.addLine(to: CGPoint(x: 63.02026378606149, y: 35.83404526742314))

        let path = Path(cgPath: cgPath)
        let result = path.crossingsRemoved(accuracy: 0.0001)

        XCTAssertFalse(result.components.isEmpty, "crossingsRemoved returned empty path")
        XCTAssertTrue(result.contains(CGPoint(x: 65.1875, y: 35.15625), using: .evenOdd), "center of circle should be inside result")

        let testTs: [CGFloat] = [0.05, 0.5, 0.95]
        let normalDistance: CGFloat = 0.1
        for (componentIndex, component) in path.components.enumerated() {
            for elementIndex in 0..<component.numberOfElements {
                for t in testTs {
                    let location = IndexedPathComponentLocation(elementIndex: elementIndex, t: t)
                    let point = component.point(at: location)
                    let normal = component.normal(at: location)
                    guard normal.x != 0 || normal.y != 0 else { continue }
                    for sign: CGFloat in [1, -1] {
                        let testPoint = point + sign * normalDistance * normal
                        XCTAssertEqual(
                            path.contains(testPoint, using: .winding),
                            result.contains(testPoint, using: .evenOdd),
                            "Containment mismatch at component \(componentIndex), element \(elementIndex), t=\(t), sign=\(sign)"
                        )
                    }
                }
            }
        }
    }

    func testCrossingsRemovedTwoOverlappingIrregularComponents() {
        let cgPath = CGMutablePath()
        // Component 0: 10-element closed shape
        cgPath.move(to: CGPoint(x: 18.532630597477276, y: 50.513658174132814))
        cgPath.addCurve(to: CGPoint(x: 16.158216825867186, y: 51.67325559747728),
                        control1: CGPoint(x: 18.19716832599986, y: 51.48954841843075),
                        control2: CGPoint(x: 17.134107070165125, y: 52.00871786895469))
        cgPath.addCurve(to: CGPoint(x: 14.998619402522722, y: 49.298841825867186),
                        control1: CGPoint(x: 15.18232658156925, y: 51.33779332599986),
                        control2: CGPoint(x: 14.663157131045308, y: 50.27473207016512))
        cgPath.addLine(to: CGPoint(x: 15.444686525360819, y: 47.931843457608245))
        cgPath.addCurve(to: CGPoint(x: 16.32877207502522, y: 45.69563603751261),
                        control1: CGPoint(x: 15.802480282958161, y: 46.83946081554559),
                        control2: CGPoint(x: 16.113580843425787, y: 46.126018500711474))
        cgPath.addLine(to: CGPoint(x: 16.59543672645252, y: 45.106900572788874))
        cgPath.addCurve(to: CGPoint(x: 19.049457786744338, y: 44.1269579322823),
                        control1: CGPoint(x: 17.00249224208086, y: 44.15863768113002),
                        control2: CGPoint(x: 18.101194895085477, y: 43.719902416653966))
        cgPath.addCurve(to: CGPoint(x: 20.029400427250906, y: 46.58097899257412),
                        control1: CGPoint(x: 19.997720678403198, y: 44.53401344791064),
                        control2: CGPoint(x: 20.436455942879245, y: 45.63271610091526))
        cgPath.addLine(to: CGPoint(x: 19.693193793681928, y: 47.321407103718236))
        cgPath.addCurve(to: CGPoint(x: 19.00973436189334, y: 49.051289790621254),
                        control1: CGPoint(x: 19.54384528074403, y: 47.62162925094889),
                        control2: CGPoint(x: 19.29947866319219, y: 48.16825953904381))
        cgPath.addLine(to: CGPoint(x: 18.532630597477276, y: 50.513658174132814))
        // Component 1: 8-element closed shape
        cgPath.move(to: CGPoint(x: 16.81532416596536, y: 44.72584181894499))
        cgPath.addCurve(to: CGPoint(x: 19.430460300470145, y: 44.3469355758635),
                        control1: CGPoint(x: 17.432841999005355, y: 43.89905984624708),
                        control2: CGPoint(x: 18.60367832777223, y: 43.7294177428235))
        cgPath.addCurve(to: CGPoint(x: 19.809366543551644, y: 46.962071710368285),
                        control1: CGPoint(x: 20.257242273168067, y: 44.964453408903495),
                        control2: CGPoint(x: 20.42688437659164, y: 46.13528973767036))
        cgPath.addLine(to: CGPoint(x: 19.297814762820426, y: 47.83186966813563))
        cgPath.addLine(to: CGPoint(x: 18.313290869473846, y: 49.98551214126323))
        cgPath.addCurve(to: CGPoint(x: 15.84261285873677, y: 50.922665869473846),
                        control1: CGPoint(x: 17.889819832130172, y: 50.92655889091584),
                        control2: CGPoint(x: 16.78365960838938, y: 51.34613690681752))
        cgPath.addCurve(to: CGPoint(x: 14.905459130526154, y: 48.45198785873677),
                        control1: CGPoint(x: 14.901566109084158, y: 50.49919483213017),
                        control2: CGPoint(x: 14.481988093182478, y: 49.393034608389385))
        cgPath.addLine(to: CGPoint(x: 15.989276449311067, y: 46.09450664963527))
        cgPath.addCurve(to: CGPoint(x: 16.81532416596536, y: 44.72584181894499),
                        control1: CGPoint(x: 16.402125538201027, y: 45.301744953903174),
                        control2: CGPoint(x: 16.726143320395295, y: 44.84524422561608))

        let path = Path(cgPath: cgPath)
        let result = path.crossingsRemoved(accuracy: 0.0001)

        XCTAssertFalse(result.components.isEmpty, "crossingsRemoved returned empty path")
        XCTAssertEqual(result.components.count, 1, "expected 1 outer boundary component, got \(result.components.count): \(result.components.map { "\($0.numberOfElements) elements" })")

        let testTs: [CGFloat] = [0.05, 0.5, 0.95]
        let normalDistance: CGFloat = 0.1
        for (componentIndex, component) in path.components.enumerated() {
            for elementIndex in 0..<component.numberOfElements {
                for t in testTs {
                    let location = IndexedPathComponentLocation(elementIndex: elementIndex, t: t)
                    let point = component.point(at: location)
                    let normal = component.normal(at: location)
                    guard normal.x != 0 || normal.y != 0 else { continue }
                    for sign: CGFloat in [1, -1] {
                        let testPoint = point + sign * normalDistance * normal
                        XCTAssertEqual(
                            path.contains(testPoint, using: .winding),
                            result.contains(testPoint, using: .evenOdd),
                            "Containment mismatch at component \(componentIndex), element \(elementIndex), t=\(t), sign=\(sign)"
                        )
                    }
                }
            }
        }
    }

    func testCrossingsRemovedIrregularComponentWithLargeNeighbor() {
        let cgPath = CGMutablePath()
        // Component 0: 12-element closed shape
        cgPath.move(to: CGPoint(x: 7.373464509647199, y: 65.4158429529536))
        cgPath.addCurve(to: CGPoint(x: 8.701344547046398, y: 63.1312770096472),
                        control1: CGPoint(x: 7.109282991556626, y: 64.4182935406436),
                        control2: CGPoint(x: 7.703795134736394, y: 63.39545852773777))
        cgPath.addCurve(to: CGPoint(x: 10.9859104903528, y: 64.4591570470464),
                        control1: CGPoint(x: 9.698893959356402, y: 62.867095491556626),
                        control2: CGPoint(x: 10.721728972262227, y: 63.461607634736396))
        cgPath.addLine(to: CGPoint(x: 14.03661523547465, y: 76.28635944275752))
        cgPath.addLine(to: CGPoint(x: 15.236873390046032, y: 81.11861452417352))
        cgPath.addLine(to: CGPoint(x: 16.24238869442051, y: 85.17182470139487))
        cgPath.addLine(to: CGPoint(x: 16.50996510667901, y: 86.17532522327646))
        cgPath.addCurve(to: CGPoint(x: 15.259065183086692, y: 88.50293264812187),
                        control1: CGPoint(x: 16.807289673147686, y: 87.16350274107116),
                        control2: CGPoint(x: 16.24724270088139, y: 88.2056080816532))
        cgPath.addCurve(to: CGPoint(x: 12.93145775824128, y: 87.25203272452956),
                        control1: CGPoint(x: 14.270887665236899, y: 88.80025721460713),
                        control2: CGPoint(x: 13.228782324726533, y: 88.24021024237935))
        cgPath.addLine(to: CGPoint(x: 12.609596989483988, y: 86.0475210113698))
        cgPath.addLine(to: CGPoint(x: 11.609173805579491, y: 82.01567529860513))
        cgPath.addLine(to: CGPoint(x: 10.411971256618742, y: 77.19554695708023))
        cgPath.addLine(to: CGPoint(x: 7.373464509647199, y: 65.4158429529536))
        // Component 1: 39-element closed shape
        cgPath.move(to: CGPoint(x: 16.456500267679782, y: 86.02221206693565))
        cgPath.addCurve(to: CGPoint(x: 15.412151753816177, y: 88.44952398027304),
                        control1: CGPoint(x: 16.838395065210253, y: 86.98088462214929),
                        control2: CGPoint(x: 16.37082430902981, y: 88.06762918274258))
        cgPath.addCurve(to: CGPoint(x: 12.98483984047878, y: 87.40517546640945),
                        control1: CGPoint(x: 14.453479198549093, y: 88.83141877782481),
                        control2: CGPoint(x: 13.366734638030545, y: 88.36384802167653))
        cgPath.addCurve(to: CGPoint(x: 12.961416147934731, y: 87.34357050702428),
                        control1: CGPoint(x: 12.941310469389864, y: 87.29590345307356),
                        control2: CGPoint(x: 12.96413874937197, y: 87.35083077752358))
        cgPath.addLine(to: CGPoint(x: 11.378901851231218, y: 83.12278568845693))
        cgPath.addCurve(to: CGPoint(x: 7.2226489193128485, y: 73.53615990582145),
                        control1: CGPoint(x: 10.397195255730114, y: 80.62956303041938),
                        control2: CGPoint(x: 8.82438829016071, y: 77.34908094471781))
        cgPath.addLine(to: CGPoint(x: 6.137611283651439, y: 70.96646119138579))
        cgPath.addCurve(to: CGPoint(x: 3.2860602865280617, y: 63.667273680769874),
                        control1: CGPoint(x: 5.155156918200706, y: 68.56759373569584),
                        control2: CGPoint(x: 4.173255609366089, y: 66.11800156807132))
        cgPath.addCurve(to: CGPoint(x: 1.6524614079150084, y: 58.38775386413275),
                        control1: CGPoint(x: 2.6422405092609926, y: 61.84195182796664),
                        control2: CGPoint(x: 2.1296404491684906, y: 60.05985232273999))
        cgPath.addLine(to: CGPoint(x: 0.9198234656134832, y: 55.65642018947058))
        cgPath.addCurve(to: CGPoint(x: -0.1958825624058005, y: 50.12985125333686),
                        control1: CGPoint(x: 0.32621837591532044, y: 53.345336879111386),
                        control2: CGPoint(x: -0.03959042680545122, y: 51.426497119058276))
        cgPath.addCurve(to: CGPoint(x: -0.8094317564020836, y: 46.883660618955574),
                        control1: CGPoint(x: -0.3519850015543976, y: 48.81244759478967),
                        control2: CGPoint(x: -0.644052664607605, y: 47.83150496595676))
        cgPath.addLine(to: CGPoint(x: -0.9266129304666213, y: 46.271594087235634))
        cgPath.addLine(to: CGPoint(x: -0.9548506262898406, y: 46.15212294620823))
        cgPath.addCurve(to: CGPoint(x: -0.9145903645728168, y: 46.25923683595981),
                        control1: CGPoint(x: -0.9596567237767037, y: 46.137028693422124),
                        control2: CGPoint(x: -0.8880038520678494, y: 46.321993992680184))
        cgPath.addCurve(to: CGPoint(x: -0.7123013410803307, y: 46.6121630191447),
                        control1: CGPoint(x: -0.9411525646835774, y: 46.19653706836609),
                        control2: CGPoint(x: -0.567075607539318, y: 46.80931908082273))
        cgPath.addCurve(to: CGPoint(x: -0.32522948011236497, y: 46.9999938814477),
                        control1: CGPoint(x: -0.7842958495212704, y: 46.51442446137971),
                        control2: CGPoint(x: -0.1116878150550639, y: 47.158213938929165))
        cgPath.addCurve(to: CGPoint(x: 0.10297826616787975, y: 47.237046196567896),
                        control1: CGPoint(x: -0.43247417336544053, y: 46.920532753678884),
                        control2: CGPoint(x: 0.28583144157071655, y: 47.30873935706215))
        cgPath.addCurve(to: CGPoint(x: 0.7725887645909678, y: 47.36555572306841),
                        control1: CGPoint(x: -0.08111638198660556, y: 47.16486627884322),
                        control2: CGPoint(x: 1.0278139412722749, y: 47.366994419873855))
        cgPath.addCurve(to: CGPoint(x: 1.513433505181576, y: 47.21656727097353),
                        control1: CGPoint(x: 0.5216748961973383, y: 47.364141328980836),
                        control2: CGPoint(x: 1.7400074694449943, y: 47.120089035683414))
        cgPath.addCurve(to: CGPoint(x: 2.0387014184526144, y: 46.87925126236991),
                        control1: CGPoint(x: 1.29783807208769, y: 47.30837070032661),
                        control2: CGPoint(x: 2.172584076578715, y: 46.757194266536686))
        cgPath.addCurve(to: CGPoint(x: 2.4673382893544247, y: 46.29906142228866),
                        control1: CGPoint(x: 1.7928324890726424, y: 47.10340294346803),
                        control2: CGPoint(x: 2.5387041616346133, y: 46.147678193019495))
        cgPath.addCurve(to: CGPoint(x: 2.619505306587215, y: 45.80556856350308),
                        control1: CGPoint(x: 2.34689327479055, y: 46.55455266301035),
                        control2: CGPoint(x: 2.6349156513027734, y: 45.70727491677901))
        cgPath.addCurve(to: CGPoint(x: 2.639652946082534, y: 45.5528031583224),
                        control1: CGPoint(x: 2.595866749288817, y: 45.956345203678396),
                        control2: CGPoint(x: 2.639479011762479, y: 45.51246646130421))
        cgPath.addCurve(to: CGPoint(x: 1.0421251925373916, y: 47.69607443556191),
                        control1: CGPoint(x: 2.784647376785828, y: 46.621510344905346),
                        control2: CGPoint(x: 2.0651357299801285, y: 47.560626494337995))
        cgPath.addCurve(to: CGPoint(x: -1.0554494355619124, y: 46.08900019253739),
                        control1: CGPoint(x: 0.019114655037615776, y: 47.83152237679338),
                        control2: CGPoint(x: -0.9200014943304442, y: 47.11201073003717))
        cgPath.addLine(to: CGPoint(x: -1.0951805101712822, y: 45.45776059545682))
        cgPath.addCurve(to: CGPoint(x: -0.7775004809259427, y: 44.465600195923635),
                        control1: CGPoint(x: -1.0892843184090109, y: 45.321562470511104),
                        control2: CGPoint(x: -1.244152890256034, y: 45.16738841968484))
        cgPath.addCurve(to: CGPoint(x: 1.1460509103475607, y: 43.66410753834934),
                        control1: CGPoint(x: -0.5214598643436779, y: 44.0805463830012),
                        control2: CGPoint(x: 0.34687362305420166, y: 43.50626973085697))
        cgPath.addCurve(to: CGPoint(x: 2.4551692107892906, y: 44.65042629244017),
                        control1: CGPoint(x: 2.4425519158247915, y: 43.92016696267213),
                        control2: CGPoint(x: 2.367205879402592, y: 44.481849900088264))
        cgPath.addCurve(to: CGPoint(x: 2.8726113293130875, y: 46.245258882819826),
                        control1: CGPoint(x: 2.852623046674599, y: 45.412122475653455),
                        control2: CGPoint(x: 2.7591633007117577, y: 45.586772950699455))
        cgPath.addCurve(to: CGPoint(x: 3.514689236929417, y: 49.68639144661709),
                        control1: CGPoint(x: 2.9810603359873955, y: 46.866792732697554),
                        control2: CGPoint(x: 3.3239341712002437, y: 48.0765025402434))
        cgPath.addCurve(to: CGPoint(x: 4.538262682383132, y: 54.72266770786392),
                        control1: CGPoint(x: 3.6412277644949658, y: 50.7361607936251),
                        control2: CGPoint(x: 3.9805890571131535, y: 52.55145839347947))
        cgPath.addLine(to: CGPoint(x: 5.247922042315912, y: 57.369114699036146))
        cgPath.addCurve(to: CGPoint(x: 6.805081583986528, y: 62.40979056301368),
                        control1: CGPoint(x: 5.7194044419005365, y: 59.02120167571676),
                        control2: CGPoint(x: 6.211944694278586, y: 60.72798469852533))
        cgPath.addCurve(to: CGPoint(x: 9.59238419748177, y: 69.5418640889425),
                        control1: CGPoint(x: 7.659039233634469, y: 64.76851692201093),
                        control2: CGPoint(x: 8.621920113316662, y: 67.17221684728634))
        cgPath.addLine(to: CGPoint(x: 10.679091910949639, y: 72.11589220095773))
        cgPath.addCurve(to: CGPoint(x: 14.855758192276918, y: 81.75293778991596),
                        control1: CGPoint(x: 12.231882000083209, y: 75.81169906327746),
                        control2: CGPoint(x: 13.798038289339564, y: 79.06666502055126))
        cgPath.addLine(to: CGPoint(x: 16.442030685474, y: 85.98424339340119))
        cgPath.addCurve(to: CGPoint(x: 16.456500267679782, y: 86.02221206693565),
                        control1: CGPoint(x: 16.469095756234793, y: 86.05446123742779),
                        control2: CGPoint(x: 16.414755995532065, y: 85.91742119703072))

        let path = Path(cgPath: cgPath)
        let result = path.crossingsRemoved(accuracy: 0.0001)

        XCTAssertFalse(result.components.isEmpty, "crossingsRemoved returned empty path")

        let testTs: [CGFloat] = [0.05, 0.5, 0.95]
        let normalDistance: CGFloat = 0.1
        for (componentIndex, component) in path.components.enumerated() {
            for elementIndex in 0..<component.numberOfElements {
                for t in testTs {
                    let location = IndexedPathComponentLocation(elementIndex: elementIndex, t: t)
                    let point = component.point(at: location)
                    let normal = component.normal(at: location)
                    guard normal.x != 0 || normal.y != 0 else { continue }
                    for sign: CGFloat in [1, -1] {
                        let testPoint = point + sign * normalDistance * normal
                        XCTAssertEqual(
                            path.contains(testPoint, using: .winding),
                            result.contains(testPoint, using: .evenOdd),
                            "Containment mismatch at component \(componentIndex), element \(elementIndex), t=\(t), sign=\(sign)"
                        )
                    }
                }
            }
        }
    }

    func testUnionRealWorldCase1() {
        // union of two overlapping paths each containing tiny degenerate self-loop sub-components
        let pathAData = CGMutablePath()
        pathAData.move(to: CGPoint(x: 144.93972764715573, y: -76.83260226033795))
        pathAData.addLine(to: CGPoint(x: 144.91318486993958, y: -76.97042781825232))
        pathAData.addCurve(to: CGPoint(x: 145.84002821821812, y: -71.36929015756373),
                           control1: CGPoint(x: 146.40863039409797, y: -73.23181400785634),
                           control2: CGPoint(x: 145.84002821821812, y: -72.05951674919625))
        pathAData.addCurve(to: CGPoint(x: 145.78062144778988, y: -70.21669221051258),
                           control1: CGPoint(x: 145.84002821821812, y: -70.98403866724536),
                           control2: CGPoint(x: 145.8201702820003, y: -70.5993321248332))
        pathAData.addCurve(to: CGPoint(x: 145.60235261981012, y: -67.59632417162202),
                           control1: CGPoint(x: 145.78456618001172, y: -69.73757279849448),
                           control2: CGPoint(x: 145.77578078536746, y: -68.81032133052344))
        pathAData.addCurve(to: CGPoint(x: 144.76702699022007, y: -63.70908801051573),
                           control1: CGPoint(x: 145.30342119878327, y: -65.19096627701924),
                           control2: CGPoint(x: 144.85138166412403, y: -64.1519500485116))
        pathAData.addLine(to: CGPoint(x: 143.50529765344118, y: -59.05648842375796))
        pathAData.addLine(to: CGPoint(x: 139.47568840930148, y: -46.28074641862159))
        pathAData.addCurve(to: CGPoint(x: 135.3408448362938, y: -32.70831184909752),
                           control1: CGPoint(x: 138.07388215024665, y: -41.91232675740464),
                           control2: CGPoint(x: 136.67840260187813, y: -37.35936498851581))
        pathAData.addLine(to: CGPoint(x: 133.43047678563633, y: -25.710796095801125))
        pathAData.addCurve(to: CGPoint(x: 129.65421030603824, y: -10.825867408594336),
                           control1: CGPoint(x: 132.05291750667004, y: -20.678889920823167),
                           control2: CGPoint(x: 130.83371156872062, y: -15.730109500800017))
        pathAData.addCurve(to: CGPoint(x: 126.6673736265491, y: 3.3045012654116084),
                           control1: CGPoint(x: 128.54982772280096, y: -6.146333939059139),
                           control2: CGPoint(x: 127.63641791539415, y: -1.3519584267157443))
        pathAData.addLine(to: CGPoint(x: 125.6533417429766, y: 9.298668779079199))
        pathAData.addCurve(to: CGPoint(x: 124.10034447055406, y: 18.714544842772977),
                           control1: CGPoint(x: 124.94335957062401, y: 13.163283947555941),
                           control2: CGPoint(x: 124.46588644078156, y: 16.17859742431974))
        pathAData.addLine(to: CGPoint(x: 123.4819376471536, y: 22.688381359307243))
        pathAData.addCurve(to: CGPoint(x: 122.7786519650067, y: 26.543950000331982),
                           control1: CGPoint(x: 123.24127408108963, y: 24.084658903641987),
                           control2: CGPoint(x: 123.12290200897381, y: 25.125349886079395))
        pathAData.addCurve(to: CGPoint(x: 121.36291031937907, y: 30.630392471671083),
                           control1: CGPoint(x: 122.74314034894684, y: 27.084422182566602),
                           control2: CGPoint(x: 122.71459434452808, y: 28.26494542766031))
        pathAData.addCurve(to: CGPoint(x: 106.06690808898333, y: 34.802029443597206),
                           control1: CGPoint(x: 118.29100167765021, y: 36.006232594696584),
                           control2: CGPoint(x: 111.44274821200882, y: 37.87393808532606))
        pathAData.addCurve(to: CGPoint(x: 101.0902829386656, y: 28.892315418941216),
                           control1: CGPoint(x: 103.66542362851722, y: 33.429752609045146),
                           control2: CGPoint(x: 101.96401183991007, y: 31.30387989298855))
        pathAData.addCurve(to: CGPoint(x: 97.30127442023806, y: 18.232699493392815),
                           control1: CGPoint(x: 98.09269894693192, y: 26.3614917642216),
                           control2: CGPoint(x: 96.52284406445469, y: 22.334060571066946))
        pathAData.addLine(to: CGPoint(x: 97.48864910296679, y: 16.047323815365697))
        pathAData.addLine(to: CGPoint(x: 97.61864952747034, y: 13.200425026014695))
        pathAData.addLine(to: CGPoint(x: 97.8877468586405, y: 8.220525000003844))
        pathAData.addCurve(to: CGPoint(x: 99.38371578229558, y: -8.127332053665386),
                           control1: CGPoint(x: 98.07381938379378, y: 3.524886946114221),
                           control2: CGPoint(x: 98.61085225649319, y: -2.0838009283967542))
        pathAData.addLine(to: CGPoint(x: 100.51351337820337, y: -15.134642056223475))
        pathAData.addCurve(to: CGPoint(x: 104.63636984409648, y: -34.200188782671056),
                           control1: CGPoint(x: 101.58515191633475, y: -21.649040657726278),
                           control2: CGPoint(x: 103.0892205417471, y: -28.0921722661042))
        pathAData.addCurve(to: CGPoint(x: 106.41174790431869, y: -40.20007962393081),
                           control1: CGPoint(x: 105.21890161526615, y: -36.30502816759959),
                           control2: CGPoint(x: 105.76365874639475, y: -38.219807196941005))
        pathAData.addCurve(to: CGPoint(x: 111.99426099935228, y: -56.46728595416922),
                           control1: CGPoint(x: 108.09592512491584, y: -45.891671692049385),
                           control2: CGPoint(x: 110.05420500772794, y: -51.48334901016877))
        pathAData.addCurve(to: CGPoint(x: 115.73995609305427, y: -65.39313631586624),
                           control1: CGPoint(x: 113.24231927763687, y: -59.685989136263295),
                           control2: CGPoint(x: 114.5045364236236, y: -62.682076485726725))
        pathAData.addLine(to: CGPoint(x: 117.61208704174754, y: -69.11377545168138))
        pathAData.addCurve(to: CGPoint(x: 119.2702711170572, y: -72.36897278679854),
                           control1: CGPoint(x: 117.90833360730069, y: -69.81226270401645),
                           control2: CGPoint(x: 118.54428715922877, y: -71.09850086059879))
        pathAData.addLine(to: CGPoint(x: 120.41205831874828, y: -74.42517146636546))
        pathAData.addCurve(to: CGPoint(x: 122.17602687153996, y: -77.1504993886825),
                           control1: CGPoint(x: 121.37519963545378, y: -76.19093054699222),
                           control2: CGPoint(x: 122.14409541414422, y: -77.10260220258888))
        pathAData.addCurve(to: CGPoint(x: 124.93613578850957, y: -80.42162008727229),
                           control1: CGPoint(x: 123.45146490710556, y: -78.79384301090614),
                           control2: CGPoint(x: 124.036939344671, y: -79.52242364343371))
        pathAData.addCurve(to: CGPoint(x: 130.9138050411661, y: -83.96471191492252),
                           control1: CGPoint(x: 125.8992978225212, y: -81.38478212128392),
                           control2: CGPoint(x: 127.30704348365613, y: -83.03454108090924))
        pathAData.addCurve(to: CGPoint(x: 131.03503898441235, y: -83.99549709278678),
                           control1: CGPoint(x: 130.9539432113291, y: -83.97506340465117),
                           control2: CGPoint(x: 130.99435371974317, y: -83.98532577661949))
        pathAData.addCurve(to: CGPoint(x: 130.89730210008406, y: -83.95994147232818),
                           control1: CGPoint(x: 131.17796861323083, y: -84.0312294999914),
                           control2: CGPoint(x: 130.8228630265439, y: -83.93909853173693))
        pathAData.addCurve(to: CGPoint(x: 133.0367610877022, y: -84.36570820169413),
                           control1: CGPoint(x: 131.10925103339497, y: -84.02267280828706),
                           control2: CGPoint(x: 131.68508048021022, y: -84.23609499275655))
        pathAData.addCurve(to: CGPoint(x: 139.26777438651843, y: -83.20915749416434),
                           control1: CGPoint(x: 134.60736686021326, y: -84.51631423467465),
                           control2: CGPoint(x: 137.17985816945702, y: -84.25311560269505))
        pathAData.addCurve(to: CGPoint(x: 142.9379440337978, y: -80.36058407091775),
                           control1: CGPoint(x: 139.46402832625574, y: -83.11103052429569),
                           control2: CGPoint(x: 141.11974699456854, y: -82.48181395001855))
        pathAData.addCurve(to: CGPoint(x: 144.93972764715573, y: -76.83260226033795),
                           control1: CGPoint(x: 143.82644796082502, y: -79.32399615605267),
                           control2: CGPoint(x: 144.48654915212404, y: -78.07836852169797))
        pathAData.closeSubpath()
        // Component 1: tiny closed loop near path A's left boundary
        pathAData.move(to: CGPoint(x: 97.30127442023806, y: 18.232699493392815))
        pathAData.addCurve(to: CGPoint(x: 97.35450896664717, y: 17.9691923242425),
                           control1: CGPoint(x: 97.3179399214171, y: 18.14489300259006),
                           control2: CGPoint(x: 97.33568175912232, y: 18.057052626025136))
        pathAData.addCurve(to: CGPoint(x: 97.30127442023806, y: 18.232699493392815),
                           control1: CGPoint(x: 97.39966898648285, y: 17.758445565009342),
                           control2: CGPoint(x: 97.29329728707219, y: 18.319610123395215))
        pathAData.closeSubpath()
        // Component 2: degenerate self-loop cubic near path A's right boundary
        pathAData.move(to: CGPoint(x: 145.72800038851935, y: -69.87876538161127))
        pathAData.addCurve(to: CGPoint(x: 145.72800038851935, y: -69.87876538161127),
                           control1: CGPoint(x: 145.72340747608004, y: -69.80756727961926),
                           control2: CGPoint(x: 145.72395489689956, y: -69.82559889168347))
        pathAData.closeSubpath()
        // Component 3: degenerate self-loop cubic near path A's right boundary
        pathAData.move(to: CGPoint(x: 145.76871232808568, y: -70.33190994863763))
        pathAData.addCurve(to: CGPoint(x: 145.76871232808568, y: -70.33190994863763),
                           control1: CGPoint(x: 145.7665041019907, y: -70.26423527831467),
                           control2: CGPoint(x: 145.7668830317481, y: -70.2847365345153))
        pathAData.closeSubpath()

        let pathBData = CGMutablePath()
        // Component 0: degenerate self-loop cubic near path B's upper boundary
        pathBData.move(to: CGPoint(x: 122.65538881555764, y: 27.026411362720857))
        pathBData.addCurve(to: CGPoint(x: 122.65538881555764, y: 27.026411362720857),
                           control1: CGPoint(x: 122.64567114098331, y: 27.10193805549278),
                           control2: CGPoint(x: 122.64847132553246, y: 27.07805999305857))
        pathBData.closeSubpath()
        // Component 1: main 53-element closed component
        pathBData.move(to: CGPoint(x: 122.70979440930768, y: 26.663090459247186))
        pathBData.addCurve(to: CGPoint(x: 122.62439589048587, y: 27.26407182270474),
                           control1: CGPoint(x: 122.68672349043645, y: 26.864825940656573),
                           control2: CGPoint(x: 122.65821319806716, y: 27.06521158421933))
        pathBData.addCurve(to: CGPoint(x: 122.50653007733864, y: 27.858660159015347),
                           control1: CGPoint(x: 122.59041957940387, y: 27.46386706980952),
                           control2: CGPoint(x: 122.5510862303349, y: 27.662122533699364))
        pathBData.addCurve(to: CGPoint(x: 122.4393915402758, y: 28.126573097092162),
                           control1: CGPoint(x: 122.4855984681464, y: 27.942907592353),
                           control2: CGPoint(x: 122.46324658242268, y: 28.032122892784766))
        pathBData.addCurve(to: CGPoint(x: 119.01700887437187, y: 33.762702036038135),
                           control1: CGPoint(x: 121.86716511787473, y: 30.392211622193148),
                           control2: CGPoint(x: 120.64265395683171, y: 32.320876879664475))
        pathBData.addCurve(to: CGPoint(x: 113.12752518635966, y: 36.483423239043894),
                           control1: CGPoint(x: 117.42108481029707, y: 35.183397649319836),
                           control2: CGPoint(x: 115.40218719732398, y: 36.164236488267136))
        pathBData.addCurve(to: CGPoint(x: 110.96452449489284, y: 36.5779614724114),
                           control1: CGPoint(x: 112.39751162982805, y: 36.585860723825874),
                           control2: CGPoint(x: 111.67406755655828, y: 36.61553108095051))
        pathBData.addCurve(to: CGPoint(x: 108.82447374427262, y: 36.250873231004526),
                           control1: CGPoint(x: 110.25511857113693, y: 36.538836313052805),
                           control2: CGPoint(x: 109.53914076061022, y: 36.43137481827723))
        pathBData.addCurve(to: CGPoint(x: 103.26241445912143, y: 32.91117679732363),
                           control1: CGPoint(x: 106.59741073970459, y: 35.68838972737106),
                           control2: CGPoint(x: 104.69594385051077, y: 34.49564442726446))
        pathBData.addCurve(to: CGPoint(x: 100.81389683887147, y: 28.54867644170363),
                           control1: CGPoint(x: 102.15037059693927, y: 31.68656020327437),
                           control2: CGPoint(x: 101.29985380424964, y: 30.206501647779522))
        pathBData.addCurve(to: CGPoint(x: 100.42716185212602, y: 22.9774024245772),
                           control1: CGPoint(x: 99.63123348207472, y: 24.828726053968065),
                           control2: CGPoint(x: 100.30163942011484, y: 24.107104312677823))
        pathBData.addCurve(to: CGPoint(x: 100.73895695468858, y: 20.51073977233501),
                           control1: CGPoint(x: 100.35859278381854, y: 22.077874534841545),
                           control2: CGPoint(x: 100.64120850713009, y: 21.14610468146514))
        pathBData.addLine(to: CGPoint(x: 101.02275257648652, y: 18.334100621454706))
        pathBData.addLine(to: CGPoint(x: 101.46867147620203, y: 14.648263294474306))
        pathBData.addLine(to: CGPoint(x: 101.93391205592032, y: 10.371214781482626))
        pathBData.addLine(to: CGPoint(x: 102.38447558154246, y: 6.060489083249685))
        pathBData.addLine(to: CGPoint(x: 102.97124622047964, y: 0.6493535731355559))
        pathBData.addCurve(to: CGPoint(x: 106.24771955826719, y: -17.469366329297646),
                           control1: CGPoint(x: 103.7697599174271, y: -5.620045431369374),
                           control2: CGPoint(x: 104.9546523779395, y: -11.61823733831479))
        pathBData.addCurve(to: CGPoint(x: 110.68914360604687, y: -34.932280661442086),
                           control1: CGPoint(x: 107.54459811378874, y: -23.38645332345245),
                           control2: CGPoint(x: 109.03172273328322, y: -29.297049694045693))
        pathBData.addCurve(to: CGPoint(x: 114.07909997277282, y: -45.889797121564726),
                           control1: CGPoint(x: 111.75794474963162, y: -38.594583954530755),
                           control2: CGPoint(x: 112.85640600975621, y: -42.289642674904705))
        pathBData.addCurve(to: CGPoint(x: 117.98825728158837, y: -56.017544660746225),
                           control1: CGPoint(x: 115.41348857274359, y: -49.718488404380274),
                           control2: CGPoint(x: 116.80019178849538, y: -53.078645809410936))
        pathBData.addLine(to: CGPoint(x: 119.67463369535663, y: -59.88503941265729))
        pathBData.addCurve(to: CGPoint(x: 124.01873068696305, y: -67.95878639668136),
                           control1: CGPoint(x: 121.337856467501, y: -63.3337658379583),
                           control2: CGPoint(x: 122.74757474401147, y: -65.84019315842873))
        pathBData.addCurve(to: CGPoint(x: 126.92219493768862, y: -72.04718520042017),
                           control1: CGPoint(x: 124.76725545859519, y: -69.10444940186909),
                           control2: CGPoint(x: 125.4456647981751, y: -70.34917553997964))
        pathBData.addCurve(to: CGPoint(x: 130.07970035410997, y: -75.99313656827664),
                           control1: CGPoint(x: 127.2825633558757, y: -72.75241124778987),
                           control2: CGPoint(x: 128.47913828444482, y: -74.39257449861148))
        pathBData.addCurve(to: CGPoint(x: 133.05866984103798, y: -78.70343442235432),
                           control1: CGPoint(x: 130.60424913225944, y: -76.58900413154218),
                           control2: CGPoint(x: 131.56382983569995, y: -77.6056612934342))
        pathBData.addCurve(to: CGPoint(x: 141.8672758235768, y: -81.36875423728806),
                           control1: CGPoint(x: 134.65671733162205, y: -79.87700054825201),
                           control2: CGPoint(x: 137.27383760802962, y: -81.73045197123142))
        pathBData.addCurve(to: CGPoint(x: 143.53289392599694, y: -81.20024763709534),
                           control1: CGPoint(x: 141.48352532257368, y: -81.40408427401015),
                           control2: CGPoint(x: 142.26775126012913, y: -81.41998294221976))
        pathBData.addCurve(to: CGPoint(x: 151.3097149039089, y: -76.44020418374146),
                           control1: CGPoint(x: 145.7651207881653, y: -80.81254507682401),
                           control2: CGPoint(x: 149.34306964994514, y: -79.07610704314158))
        pathBData.addCurve(to: CGPoint(x: 153.84692847505139, y: -70.08375451875072),
                           control1: CGPoint(x: 153.17195764815156, y: -73.94423244478504),
                           control2: CGPoint(x: 153.60090021932245, y: -71.74444524492094))
        pathBData.addCurve(to: CGPoint(x: 154.09296778381852, y: -66.12830663856808),
                           control1: CGPoint(x: 154.19248864774877, y: -68.42830389708604),
                           control2: CGPoint(x: 154.09296778381852, y: -67.0991314975187))
        pathBData.addLine(to: CGPoint(x: 154.09296778381852, y: -63.06580663856807))
        pathBData.addCurve(to: CGPoint(x: 153.26996655582047, y: -57.34310449152007),
                           control1: CGPoint(x: 153.8157014422048, y: -60.00117943571678),
                           control2: CGPoint(x: 153.50579315524035, y: -58.581194138474515))
        pathBData.addLine(to: CGPoint(x: 152.07600240384954, y: -52.19631283411673))
        pathBData.addLine(to: CGPoint(x: 151.05586907930117, y: -47.35742076268746))
        pathBData.addCurve(to: CGPoint(x: 148.98152399166165, y: -36.99422751693125),
                           control1: CGPoint(x: 150.3951264405294, y: -44.353902690228644),
                           control2: CGPoint(x: 149.7760007178929, y: -40.801095163456104))
        pathBData.addCurve(to: CGPoint(x: 145.57476699826867, y: -17.57653392672598),
                           control1: CGPoint(x: 147.5585513116932, y: -30.116443939262275),
                           control2: CGPoint(x: 146.4830418163862, y: -23.20459396041843))
        pathBData.addLine(to: CGPoint(x: 145.13271733389286, y: -14.52181396181466))
        pathBData.addLine(to: CGPoint(x: 144.61962432662776, y: -11.271627432860178))
        pathBData.addLine(to: CGPoint(x: 144.09624684841916, y: -8.258023771453274))
        pathBData.addCurve(to: CGPoint(x: 143.96622663505548, y: -6.784939037619051),
                           control1: CGPoint(x: 143.98887750626457, y: -7.400263742805692),
                           control2: CGPoint(x: 143.9684691623446, y: -6.98749241681363))
        pathBData.addCurve(to: CGPoint(x: 143.9678995881537, y: -6.624862237528569),
                           control1: CGPoint(x: 143.96715664685613, y: -6.731669867691962),
                           control2: CGPoint(x: 143.9677151247449, y: -6.678310107472431))
        pathBData.addLine(to: CGPoint(x: 143.96796778381855, y: -6.397906227953971))
        pathBData.addCurve(to: CGPoint(x: 132.75703028381852, y: 4.8130996114319275),
                           control1: CGPoint(x: 143.96796778381852, y: -0.20620807635713492),
                           control2: CGPoint(x: 138.94866009602947, y: 4.8130996114319275))
        pathBData.addCurve(to: CGPoint(x: 125.39573436104469, y: 2.057936777055406),
                           control1: CGPoint(x: 129.93974655458098, y: 4.8130996114319275),
                           control2: CGPoint(x: 127.36517869331657, y: 3.7739094462999407))
        pathBData.addCurve(to: CGPoint(x: 125.25175026683972, y: 3.135823990576767),
                           control1: CGPoint(x: 125.34555745951123, y: 2.4198049665840586),
                           control2: CGPoint(x: 125.29752881530979, y: 2.779154475863189))
        pathBData.addLine(to: CGPoint(x: 124.6606837584213, y: 8.597315172808104))
        pathBData.addLine(to: CGPoint(x: 124.23055970029553, y: 12.725233868317325))
        pathBData.addLine(to: CGPoint(x: 123.68212432662776, y: 17.697122567139818))
        pathBData.addLine(to: CGPoint(x: 123.26836724637822, y: 21.1316128643374))
        pathBData.addLine(to: CGPoint(x: 122.9799678086023, y: 23.278342173316098))
        pathBData.addLine(to: CGPoint(x: 122.82426865457732, y: 24.36122266039211))
        pathBData.addLine(to: CGPoint(x: 122.76480477629224, y: 24.77479121112714))
        pathBData.addCurve(to: CGPoint(x: 122.70979440930768, y: 26.663090459247186),
                           control1: CGPoint(x: 122.8001277024233, y: 25.41353769063375),
                           control2: CGPoint(x: 122.78051986397581, y: 26.044656762478724))
        pathBData.closeSubpath()

        let pathA = Path(cgPath: pathAData)
        let pathB = Path(cgPath: pathBData)
        let rule: PathFillRule = .evenOdd
        let pointInA = CGPoint(x: 115.0, y: -25.0)
        let pointInBNotA = CGPoint(x: 150.0, y: -60.0)
        XCTAssertTrue(pathA.contains(pointInA, using: rule), "sanity: point should be inside path A")
        XCTAssertFalse(pathA.contains(pointInBNotA, using: rule), "sanity: point should be outside path A")
        XCTAssertTrue(pathB.contains(pointInBNotA, using: rule), "sanity: point should be inside path B")
        let result = pathA.union(pathB, accuracy: 1.0e-4)
        XCTAssertTrue(result.contains(pointInA, using: rule), "point inside path A should be in the union")
        XCTAssertTrue(result.contains(pointInBNotA, using: rule), "point inside path B should be in the union")
    }

    func testUnionRealWorldCase2() {
        let pathAData = CGMutablePath()
        pathAData.move(to: CGPoint(x: 169.4526401097924, y: -59.941311462821474))
        pathAData.addCurve(to: CGPoint(x: 165.92191811498446, y: -53.93973168860035),
                           control1: CGPoint(x: 168.61485274771488, y: -58.45969901067963),
                           control2: CGPoint(x: 167.4854383898041, y: -56.480452135182254))
        pathAData.addCurve(to: CGPoint(x: 150.49840647202086, y: -50.26746701170425),
                           control1: CGPoint(x: 162.67690086973818, y: -48.66657866507511),
                           control2: CGPoint(x: 155.77155949554611, y: -47.022449766457946))
        pathAData.addCurve(to: CGPoint(x: 146.82614179512478, y: -65.69097865466784),
                           control1: CGPoint(x: 145.22525344849564, y: -53.51248425695054),
                           control2: CGPoint(x: 143.58112454987847, y: -60.417825631142605))
        pathAData.addCurve(to: CGPoint(x: 150.30955962234808, y: -71.61582116775507),
                           control1: CGPoint(x: 148.5198149419813, y: -68.4431975183097),
                           control2: CGPoint(x: 149.4923079753478, y: -70.21242399620873))
        pathAData.addCurve(to: CGPoint(x: 151.17096610837646, y: -73.15906440275288),
                           control1: CGPoint(x: 150.55459424181458, y: -72.14984324595407),
                           control2: CGPoint(x: 150.8422579161966, y: -72.66600211448306))
        pathAData.addCurve(to: CGPoint(x: 153.12221254131865, y: -75.40946098751837),
                           control1: CGPoint(x: 151.68275956242442, y: -73.9267545838248),
                           control2: CGPoint(x: 152.28974100738088, y: -74.66618283221679))
        pathAData.addCurve(to: CGPoint(x: 155.96662671099963, y: -77.27344906104203),
                           control1: CGPoint(x: 153.77132958772813, y: -75.98902977895543),
                           control2: CGPoint(x: 154.53319445179335, y: -76.61570324589991))
        pathAData.addCurve(to: CGPoint(x: 162.89649770717003, y: -78.0767423654457),
                           control1: CGPoint(x: 157.15410199017145, y: -77.81833486952277),
                           control2: CGPoint(x: 158.8866631095937, y: -78.89022501024118))
        pathAData.addCurve(to: CGPoint(x: 168.3892288432265, y: -75.21983606010723),
                           control1: CGPoint(x: 164.56118593302034, y: -77.73902395143851),
                           control2: CGPoint(x: 166.64315515706753, y: -76.87651022509158))
        pathAData.addCurve(to: CGPoint(x: 171.48194657329262, y: -70.0664091096708),
                           control1: CGPoint(x: 169.93273365799553, y: -73.7553591766706),
                           control2: CGPoint(x: 170.99910973349068, y: -71.81521210437153))
        pathAData.addCurve(to: CGPoint(x: 171.39708697021973, y: -63.79828084686825),
                           control1: CGPoint(x: 172.2814425238716, y: -67.17068782792857),
                           control2: CGPoint(x: 171.80392433979563, y: -65.13131499685137))
        pathAData.addCurve(to: CGPoint(x: 169.4526401097924, y: -59.941311462821474),
                           control1: CGPoint(x: 170.73346225622873, y: -61.623863075351885),
                           control2: CGPoint(x: 170.04529348713692, y: -60.587365295861474))
        pathAData.closeSubpath()
        // Component 1: tiny closed 4-element loop near path A's lower boundary
        pathAData.move(to: CGPoint(x: 150.37810863980434, y: -71.73329156202611))
        pathAData.addCurve(to: CGPoint(x: 150.4609393398093, y: -71.87452612177839),
                           control1: CGPoint(x: 150.40587539704168, y: -71.78077197986615),
                           control2: CGPoint(x: 150.43347800218032, y: -71.82784184780914))
        pathAData.addLine(to: CGPoint(x: 150.51325865010278, y: -72.00510896713574))
        pathAData.addCurve(to: CGPoint(x: 150.47282965322088, y: -71.92748867071217),
                           control1: CGPoint(x: 150.46466004690927, y: -71.91136425807576),
                           control2: CGPoint(x: 150.46000072886014, y: -71.90249899513445))
        pathAData.addCurve(to: CGPoint(x: 150.37810863980434, y: -71.73329156202611),
                           control1: CGPoint(x: 150.46806473177253, y: -71.91626313427945),
                           control2: CGPoint(x: 150.4161568123335, y: -71.81029417979279))
        pathAData.closeSubpath()

        let pathBData = CGMutablePath()
        // Component 0: degenerate self-loop cubic
        pathBData.move(to: CGPoint(x: 150.56254052524326, y: -71.84375493658648))
        pathBData.addCurve(to: CGPoint(x: 150.56254052524326, y: -71.84375493658648),
                           control1: CGPoint(x: 150.52379768837753, y: -71.77454471325406),
                           control2: CGPoint(x: 150.50321047774688, y: -71.74001407452634))
        pathBData.closeSubpath()
        // Component 1: main 13-element closed component
        pathBData.move(to: CGPoint(x: 150.4611924165118, y: -71.72239763983333))
        pathBData.addCurve(to: CGPoint(x: 163.3497199493032, y: -77.87492465635971),
                           control1: CGPoint(x: 152.67745201882607, y: -76.50760831422711),
                           control2: CGPoint(x: 158.04480083349435, y: -79.20115443531192))
        pathBData.addCurve(to: CGPoint(x: 171.50687515072048, y: -64.27966598733089),
                           control1: CGPoint(x: 169.35648317529586, y: -76.37323384986153),
                           control2: CGPoint(x: 173.00856595721865, y: -70.28642921332359))
        pathBData.addCurve(to: CGPoint(x: 169.52981752928926, y: -59.92069316227049),
                           control1: CGPoint(x: 170.7908597608953, y: -61.41560442803017),
                           control2: CGPoint(x: 169.98318019546818, y: -60.62592397632657))
        pathBData.addLine(to: CGPoint(x: 168.4639044256191, y: -58.29234013287742))
        pathBData.addCurve(to: CGPoint(x: 163.42045040561774, y: -49.14091600968427),
                           control1: CGPoint(x: 167.4208949789778, y: -56.441497625960885),
                           control2: CGPoint(x: 165.63809794807432, y: -53.34277451118093))
        pathBData.addCurve(to: CGPoint(x: 157.76088819359563, y: -38.16499306485307),
                           control1: CGPoint(x: 161.59088262347183, y: -45.67780354931521),
                           control2: CGPoint(x: 159.5811663334907, y: -42.004642266194224))
        pathBData.addLine(to: CGPoint(x: 154.74699239360197, y: -31.97954050174344))
        pathBData.addCurve(to: CGPoint(x: 139.7989909961042, y: -26.69489354303211),
                           control1: CGPoint(x: 152.07853074937503, y: -26.392448934143275),
                           control2: CGPoint(x: 145.38608256370438, y: -24.026431898805164))
        pathBData.addCurve(to: CGPoint(x: 134.51434403739287, y: -41.642894940529885),
                           control1: CGPoint(x: 134.21189942850404, y: -29.363355187259053),
                           control2: CGPoint(x: 131.84588239316594, y: -36.05580337292972))
        pathBData.addLine(to: CGPoint(x: 137.60330087889682, y: -47.981151389436974))
        pathBData.addCurve(to: CGPoint(x: 143.5930314487334, y: -59.610582428106326),
                           control1: CGPoint(x: 139.6570267053385, y: -52.31897508322968),
                           control2: CGPoint(x: 141.8589489231659, y: -56.32821193328217))
        pathBData.addCurve(to: CGPoint(x: 149.2718486143365, y: -69.87340035037147),
                           control1: CGPoint(x: 145.99860509089376, y: -64.16851345146269),
                           control2: CGPoint(x: 147.96780028147822, y: -67.59131576786947))
        pathBData.addLine(to: CGPoint(x: 150.4611924165118, y: -71.72239763983333))
        pathBData.closeSubpath()

        let pathA = Path(cgPath: pathAData)
        let pathB = Path(cgPath: pathBData)
        let rule: PathFillRule = .evenOdd
        let pointInA = CGPoint(x: 157.0, y: -66.0)
        let pointInB = CGPoint(x: 152.0, y: -60.0)
        XCTAssertTrue(pathA.contains(pointInA, using: rule), "sanity: point should be inside path A")
        XCTAssertTrue(pathB.contains(pointInB, using: rule), "sanity: point should be inside path B")
        let result = pathA.union(pathB, accuracy: 1.0e-4)
        XCTAssertTrue(result.contains(pointInA, using: rule), "point inside path A should be in the union")
        XCTAssertTrue(result.contains(pointInB, using: rule), "point inside path B should be in the union")
    }

    func testUnionRealWorldCase3() {
        let pathAData = CGMutablePath()
        pathAData.move(to: CGPoint(x: 95.42684472987237, y: 14.112542326547688))
        pathAData.addCurve(to: CGPoint(x: 99.06812243180225, y: 6.003413710553378),
                           control1: CGPoint(x: 96.58744632142007, y: 11.491858473265038),
                           control2: CGPoint(x: 97.79517715765391, y: 8.773701662946715))
        pathAData.addLine(to: CGPoint(x: 102.01189630821541, y: -0.06141728012209651))
        pathAData.addLine(to: CGPoint(x: 104.5755425278924, y: -5.117460593578404))
        pathAData.addCurve(to: CGPoint(x: 115.24116297687908, y: -25.43132974835794),
                           control1: CGPoint(x: 108.16739302581404, y: -12.258796382497954),
                           control2: CGPoint(x: 111.81590219471934, y: -19.194770022350102))
        pathAData.addLine(to: CGPoint(x: 119.80688611355227, y: -33.64031914100532))
        pathAData.addLine(to: CGPoint(x: 121.91751846254424, y: -37.298206302496766))
        pathAData.addCurve(to: CGPoint(x: 126.58432501849636, y: -45.474637306566024),
                           control1: CGPoint(x: 123.80332691343831, y: -40.49681182618086),
                           control2: CGPoint(x: 125.47699675931518, y: -43.370713614121804))
        pathAData.addCurve(to: CGPoint(x: 127.29769131376996, y: -46.63491593132077),
                           control1: CGPoint(x: 127.34655853057846, y: -46.726194100887504),
                           control2: CGPoint(x: 127.20961482692614, y: -46.425734275066695))
        pathAData.addLine(to: CGPoint(x: 129.99134985801416, y: -51.62590601202733))
        pathAData.addCurve(to: CGPoint(x: 131.98123063415375, y: -54.64470962769172),
                           control1: CGPoint(x: 130.537111311146, y: -52.56819727095026),
                           control2: CGPoint(x: 130.36564554353805, y: -52.78691560100911))
        pathAData.addCurve(to: CGPoint(x: 132.74457208286663, y: -55.509574591971344),
                           control1: CGPoint(x: 131.9984971710431, y: -54.68709743555362),
                           control2: CGPoint(x: 132.10833268294073, y: -54.847998224791745))
        pathAData.addCurve(to: CGPoint(x: 137.02443371325853, y: -58.289534646315886),
                           control1: CGPoint(x: 133.1646402242235, y: -55.94637111063887),
                           control2: CGPoint(x: 133.27075736481638, y: -56.93333835721404))
        pathAData.addCurve(to: CGPoint(x: 141.0771623031116, y: -58.95422284457678),
                           control1: CGPoint(x: 137.99578444463327, y: -58.640481860465954),
                           control2: CGPoint(x: 139.3190271681256, y: -58.99219483963622))
        pathAData.addCurve(to: CGPoint(x: 146.89649794058604, y: -57.17724788889969),
                           control1: CGPoint(x: 142.865252822395, y: -58.91560387666417),
                           control2: CGPoint(x: 145.0594467393391, y: -58.3576928782591))
        pathAData.addCurve(to: CGPoint(x: 151.80732862109193, y: -50.05401663178891),
                           control1: CGPoint(x: 150.38924886678123, y: -54.93289001411157),
                           control2: CGPoint(x: 151.44422169277425, y: -51.778264300214644))
        pathAData.addCurve(to: CGPoint(x: 151.8876073421258, y: -45.8488363031942),
                           control1: CGPoint(x: 152.38632075375455, y: -47.30461760653286),
                           control2: CGPoint(x: 151.99318398272027, y: -46.46729036028322))
        pathAData.addCurve(to: CGPoint(x: 151.47026663282563, y: -44.174955086279624),
                           control1: CGPoint(x: 151.41552021088842, y: -43.08341205812191),
                           control2: CGPoint(x: 151.47585220635386, y: -44.19310820024639))
        pathAData.addCurve(to: CGPoint(x: 150.4889075033928, y: -41.90975052799673),
                           control1: CGPoint(x: 151.22753074114385, y: -43.386063438313826),
                           control2: CGPoint(x: 150.8984162508424, y: -42.626390836033494))
        pathAData.addCurve(to: CGPoint(x: 147.40825856392894, y: -36.52968954082086),
                           control1: CGPoint(x: 149.65604271030136, y: -40.45223714008671),
                           control2: CGPoint(x: 148.79532070219517, y: -39.14376818601493))
        pathAData.addLine(to: CGPoint(x: 145.73077586423403, y: -33.418695740820176))
        pathAData.addCurve(to: CGPoint(x: 144.4599782438638, y: -31.46611243211342),
                           control1: CGPoint(x: 145.3682539595436, y: -32.711778026673834),
                           control2: CGPoint(x: 144.9410082503627, y: -32.05974262639149))
        pathAData.addCurve(to: CGPoint(x: 141.1613079187749, y: -25.791723308763764),
                           control1: CGPoint(x: 143.54922998002738, y: -29.84573738105402),
                           control2: CGPoint(x: 142.39231193168877, y: -27.8786597994068))
        pathAData.addLine(to: CGPoint(x: 139.49242264427673, y: -22.90656640477486))
        pathAData.addLine(to: CGPoint(x: 134.8896922582644, y: -14.62967732110783))
        pathAData.addCurve(to: CGPoint(x: 124.58296884065044, y: 5.003838652545757),
                           control1: CGPoint(x: 131.61001881792313, y: -8.658188982476128),
                           control2: CGPoint(x: 128.07731273981162, y: -1.9433759629341807))
        pathAData.addLine(to: CGPoint(x: 122.13299911050254, y: 9.828648655591563))
        pathAData.addLine(to: CGPoint(x: 119.39170673371696, y: 15.473270621422836))
        pathAData.addCurve(to: CGPoint(x: 112.58614958316029, y: 30.68281078864501),
                           control1: CGPoint(x: 117.08092703567787, y: 20.503696842970278),
                           control2: CGPoint(x: 114.85253930626573, y: 25.69675339781306))
        pathAData.addCurve(to: CGPoint(x: 106.85924641530256, y: 43.442813320415),
                           control1: CGPoint(x: 110.47123060809967, y: 35.31700250980358),
                           control2: CGPoint(x: 108.50748870456074, y: 39.627437650835894))
        pathAData.addLine(to: CGPoint(x: 104.97858290165591, y: 47.56613959250927))
        pathAData.addLine(to: CGPoint(x: 103.21735854968287, y: 51.23238395113027))
        pathAData.addCurve(to: CGPoint(x: 101.4264075033928, y: 54.590249472003265),
                           control1: CGPoint(x: 102.68542851591805, y: 52.380392078978566),
                           control2: CGPoint(x: 101.97481835269247, y: 53.63053048572885))
        pathAData.addCurve(to: CGPoint(x: 99.07185932059708, y: 58.18773397746063),
                           control1: CGPoint(x: 100.94538826326472, y: 55.49108167611251),
                           control2: CGPoint(x: 100.18057763053031, y: 56.801836090044105))
        pathAData.addCurve(to: CGPoint(x: 95.68241783194043, y: 62.080396772477016),
                           control1: CGPoint(x: 98.00123063267486, y: 59.76441627913121),
                           control2: CGPoint(x: 96.46758713657853, y: 61.29522746783891))
        pathAData.addCurve(to: CGPoint(x: 91.83127157053218, y: 64.86793417936907),
                           control1: CGPoint(x: 94.60880045549234, y: 63.035009877715524),
                           control2: CGPoint(x: 93.70844011543295, y: 63.92934990691869))
        pathAData.addCurve(to: CGPoint(x: 84.45634167775803, y: 66.30426398540209),
                           control1: CGPoint(x: 89.10156766993364, y: 66.37909830028765),
                           control2: CGPoint(x: 85.2862239954273, y: 66.36354129380703))
        pathAData.addCurve(to: CGPoint(x: 77.95281521188738, y: 63.87887536091124),
                           control1: CGPoint(x: 83.15262927353666, y: 66.33275434276845),
                           control2: CGPoint(x: 80.4369766928486, y: 65.77852825811688))
        pathAData.addCurve(to: CGPoint(x: 73.40682600063988, y: 56.08228282871017),
                           control1: CGPoint(x: 75.40860279640142, y: 61.93330116083374),
                           control2: CGPoint(x: 73.78588110481184, y: 58.735668557913804))
        pathAData.addCurve(to: CGPoint(x: 73.49593854908086, y: 50.03066691886834),
                           control1: CGPoint(x: 73.1859714616622, y: 53.89358703890074),
                           control2: CGPoint(x: 73.25569289699793, y: 52.07275496157324))
        pathAData.addCurve(to: CGPoint(x: 74.21279625873608, y: 45.30957269478674),
                           control1: CGPoint(x: 73.57575102535989, y: 48.48495653990902),
                           control2: CGPoint(x: 73.91737021902806, y: 46.99350112112241))
        pathAData.addLine(to: CGPoint(x: 74.97212742210698, y: 41.71849621537374))
        pathAData.addCurve(to: CGPoint(x: 75.8229344017573, y: 37.94973650175151),
                           control1: CGPoint(x: 75.21247187029553, y: 40.372659164664434),
                           control2: CGPoint(x: 75.55682714994614, y: 39.12060840972054))
        pathAData.addCurve(to: CGPoint(x: 77.0904351767012, y: 32.87079576577903),
                           control1: CGPoint(x: 76.19831983715183, y: 36.22062402128146),
                           control2: CGPoint(x: 76.66673028248998, y: 34.505086072022344))
        pathAData.addCurve(to: CGPoint(x: 78.90624155256523, y: 26.639087338811834),
                           control1: CGPoint(x: 77.63105229187016, y: 30.936563302516973),
                           control2: CGPoint(x: 78.17113682365361, y: 28.899534380215087))
        pathAData.addCurve(to: CGPoint(x: 80.6321713135411, y: 21.15149610032694),
                           control1: CGPoint(x: 79.38935718131297, y: 24.921570885056646),
                           control2: CGPoint(x: 80.04555558554716, y: 22.999335643507823))
        pathAData.addCurve(to: CGPoint(x: 94.70978364467338, y: 13.858275254077684),
                           control1: CGPoint(x: 82.50562929042803, y: 15.250103473133088),
                           control2: CGPoint(x: 88.80839101747952, y: 11.984817277190746))
        pathAData.addCurve(to: CGPoint(x: 95.42684472987237, y: 14.112542326547688),
                           control1: CGPoint(x: 94.95335321285246, y: 13.935598926515487),
                           control2: CGPoint(x: 95.19243222651228, y: 14.020467829197619))
        pathAData.closeSubpath()
        // Component 1: tiny closed loop
        pathAData.move(to: CGPoint(x: 131.98123063415375, y: -54.64470962769172))
        pathAData.addCurve(to: CGPoint(x: 132.25092874355178, y: -54.95132463161385),
                           control1: CGPoint(x: 132.06607991184583, y: -54.74227953111574),
                           control2: CGPoint(x: 132.15585835660616, y: -54.84437044630004))
        pathAData.addCurve(to: CGPoint(x: 131.98123063415375, y: -54.64470962769172),
                           control1: CGPoint(x: 132.39099331865648, y: -55.108897278606655),
                           control2: CGPoint(x: 131.9605919006197, y: -54.60468872477935))
        pathAData.closeSubpath()

        let pathBData = CGMutablePath()
        pathBData.move(to: CGPoint(x: 138.65391637549612, y: -19.071191957822034))
        pathBData.addCurve(to: CGPoint(x: 140.4243404094738, y: -6.920802201130714),
                           control1: CGPoint(x: 141.51399065907958, y: -15.835138174752894),
                           control2: CGPoint(x: 142.35891229793907, y: -11.088864203883118))
        pathBData.addCurve(to: CGPoint(x: 134.09345099878925, y: 7.674800174485943),
                           control1: CGPoint(x: 138.28253593621196, y: -2.306254716203657),
                           control2: CGPoint(x: 136.21300227747065, y: 2.622358776268864))
        pathBData.addCurve(to: CGPoint(x: 128.40119836375132, y: 22.323363491247786),
                           control1: CGPoint(x: 132.02609106635623, y: 12.689847295768416),
                           control2: CGPoint(x: 130.04463259908576, y: 17.620500344598785))
        pathBData.addLine(to: CGPoint(x: 125.91786927253007, y: 29.49405812061804))
        pathBData.addLine(to: CGPoint(x: 123.43961490527866, y: 36.96154039796975))
        pathBData.addLine(to: CGPoint(x: 121.71252508800843, y: 42.416637130014095))
        pathBData.addCurve(to: CGPoint(x: 119.8212676438836, y: 48.48101684852743),
                           control1: CGPoint(x: 120.96402031912767, y: 44.832269874709574),
                           control2: CGPoint(x: 120.25604938242778, y: 46.886817140532116))
        pathBData.addLine(to: CGPoint(x: 117.060586972701, y: 58.426153652831495))
        pathBData.addCurve(to: CGPoint(x: 115.4788260753661, y: 63.73748417835357),
                           control1: CGPoint(x: 116.66320219861184, y: 59.87384920700127),
                           control2: CGPoint(x: 116.24202302275171, y: 61.638692573043144))
        pathBData.addCurve(to: CGPoint(x: 114.39098990346439, y: 67.10768377760935),
                           control1: CGPoint(x: 115.22805657574479, y: 64.71646711889287),
                           control2: CGPoint(x: 114.72295322170913, y: 66.11179382287511))
        pathBData.addCurve(to: CGPoint(x: 112.80943665389924, y: 70.94800909341751),
                           control1: CGPoint(x: 113.7740821779436, y: 68.77464755662386),
                           control2: CGPoint(x: 113.28188183439224, y: 69.92437786901603))
        pathBData.addCurve(to: CGPoint(x: 109.19572649336821, y: 76.80133286189154),
                           control1: CGPoint(x: 111.59658403154711, y: 73.47774368141617),
                           control2: CGPoint(x: 110.31145500668953, y: 75.38131475402804))
        pathBData.addCurve(to: CGPoint(x: 104.13004337096102, y: 81.42129365819089),
                           control1: CGPoint(x: 108.0055402173393, y: 78.2897561201623),
                           control2: CGPoint(x: 107.21313111184757, y: 79.65952923482715))
        pathBData.addCurve(to: CGPoint(x: 97.71559948549029, y: 82.54983512425346),
                           control1: CGPoint(x: 101.91035615641857, y: 82.26902412620952),
                           control2: CGPoint(x: 99.70178418067147, y: 82.60780731924939))
        pathBData.addLine(to: CGPoint(x: 98.25536074172622, y: 82.77341155702996))
        pathBData.addCurve(to: CGPoint(x: 94.13611961194688, y: 81.94942737641746),
                           control1: CGPoint(x: 97.14971001293273, y: 82.77341155702996),
                           control2: CGPoint(x: 95.65849488879442, y: 82.54200946893113))
        pathBData.addCurve(to: CGPoint(x: 92.14602651060743, y: 80.99991290370814),
                           control1: CGPoint(x: 93.38611381628715, y: 81.69991744813588),
                           control2: CGPoint(x: 92.71550773408447, y: 81.37956705269283))
        pathBData.addCurve(to: CGPoint(x: 90.37447414016839, y: 79.54782830449679),
                           control1: CGPoint(x: 91.32806392870876, y: 80.45460451577569),
                           control2: CGPoint(x: 90.75742497475423, y: 79.93644295361716))
        pathBData.addCurve(to: CGPoint(x: 87.33430907430022, y: 74.18341547370594),
                           control1: CGPoint(x: 88.51033197461439, y: 77.71365094627136),
                           control2: CGPoint(x: 87.6800508373692, y: 75.60946098410852))
        pathBData.addCurve(to: CGPoint(x: 87.01973408896086, y: 70.00852495732939),
                           control1: CGPoint(x: 86.54418196497683, y: 70.92445940517553),
                           control2: CGPoint(x: 86.83603560294918, y: 70.1827362536434))
        pathBData.addCurve(to: CGPoint(x: 87.44349548325657, y: 64.73442839972125),
                           control1: CGPoint(x: 86.90396006928036, y: 68.29556314633143),
                           control2: CGPoint(x: 87.19162474943403, y: 66.74939427030168))
        pathBData.addCurve(to: CGPoint(x: 87.88859050694317, y: 61.08121054814522),
                           control1: CGPoint(x: 87.49603179964036, y: 63.66506207140266),
                           control2: CGPoint(x: 87.71940406489446, y: 62.37830660385205))
        pathBData.addLine(to: CGPoint(x: 88.82196011126429, y: 55.56315728528631))
        pathBData.addLine(to: CGPoint(x: 90.03843910483556, y: 49.361157346174366))
        pathBData.addCurve(to: CGPoint(x: 93.83660027759653, y: 33.751396558326896),
                           control1: CGPoint(x: 91.07958294898047, y: 44.73701639875948),
                           control2: CGPoint(x: 92.240920453522, y: 39.43600593159245))
        pathBData.addCurve(to: CGPoint(x: 99.36518777772426, y: 16.29951094428974),
                           control1: CGPoint(x: 95.43864359631803, y: 28.285749369845647),
                           control2: CGPoint(x: 97.12014198404951, y: 22.37133934081917))
        pathBData.addCurve(to: CGPoint(x: 102.61419233247102, y: 7.871424830082082),
                           control1: CGPoint(x: 100.4345911724011, y: 13.32389065818779),
                           control2: CGPoint(x: 101.59568508929753, y: 10.500072200331322))
        pathBData.addCurve(to: CGPoint(x: 105.75498238516428, y: -0.3036235476312019),
                           control1: CGPoint(x: 103.5637653369264, y: 5.292908340627944),
                           control2: CGPoint(x: 104.60710504717544, y: 2.500657669624642))
        pathBData.addCurve(to: CGPoint(x: 112.2208229539968, y: -15.21246945764585),
                           control1: CGPoint(x: 108.03174166537644, y: -5.699418101811216),
                           control2: CGPoint(x: 110.23498950698531, y: -10.63574393523656))
        pathBData.addCurve(to: CGPoint(x: 118.12277034820022, y: -28.10999731296602),
                           control1: CGPoint(x: 114.28114160755307, y: -19.880926123879163),
                           control2: CGPoint(x: 116.25700607746822, y: -24.16937449978206))
        pathBData.addLine(to: CGPoint(x: 120.9562123985469, y: -34.021222696838144))
        pathBData.addLine(to: CGPoint(x: 123.47799340512559, y: -39.07620961127035))
        pathBData.addLine(to: CGPoint(x: 125.59016702641364, y: -43.259273019859606))
        pathBData.addCurve(to: CGPoint(x: 140.48335781861576, y: -48.6964696582826),
                           control1: CGPoint(x: 128.20136770907874, y: -48.87335448758953),
                           control2: CGPoint(x: 134.86927635088583, y: -51.30767034094768))
        pathBData.addCurve(to: CGPoint(x: 145.92055445703878, y: -33.80327886608048),
                           control1: CGPoint(x: 146.09743928665873, y: -46.08526897547193),
                           control2: CGPoint(x: 148.53175513984945, y: -39.41736033412344))
        pathBData.addCurve(to: CGPoint(x: 143.37626721350998, y: -28.74742245816341),
                           control1: CGPoint(x: 145.18768098814328, y: -32.22760090795515),
                           control2: CGPoint(x: 144.34111214468456, y: -30.539277330344785))
        pathBData.addLine(to: CGPoint(x: 141.08292130914194, y: -24.151938982087806))
        pathBData.addLine(to: CGPoint(x: 138.65391637549612, y: -19.071191957822034))
        pathBData.closeSubpath()

        let pathA = Path(cgPath: pathAData)
        let pathB = Path(cgPath: pathBData)
        let rule: PathFillRule = .evenOdd
        let pointInA = CGPoint(x: 100.0, y: 20.0)
        let pointInB = CGPoint(x: 130.0, y: 5.0)
        XCTAssertTrue(pathA.contains(pointInA, using: rule), "sanity: point should be inside path A")
        XCTAssertTrue(pathB.contains(pointInB, using: rule), "sanity: point should be inside path B")
        let result = pathA.union(pathB, accuracy: 1.0e-4)
        XCTAssertTrue(result.contains(pointInA, using: rule), "point inside path A should be in the union")
        XCTAssertTrue(result.contains(pointInB, using: rule), "point inside path B should be in the union")
    }

    #endif

}
