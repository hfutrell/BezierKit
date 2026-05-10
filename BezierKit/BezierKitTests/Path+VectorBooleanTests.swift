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

    #endif

}
