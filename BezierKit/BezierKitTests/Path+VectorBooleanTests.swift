//
//  Path+VectorBooleanOperationsTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 2/8/21.
//  Copyright © 2021 Holmes Futrell. All rights reserved.
//

@testable import BezierKit
import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if !os(WASI)
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

    #endif
}

#endif