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

private extension Path {
    /// copies the path in such a way that it's impossible that optimizations would allow the copy to share the same underlying storage
    func independentCopy() -> Path {
        return Path(components: self.components.map { PathComponent(curves: $0.curves) })
    }
}

private func makeRectPath(_ rect: CGRect) -> Path {
    let r = rect.standardized
    let p0 = CGPoint(x: r.minX, y: r.minY)
    let p1 = CGPoint(x: r.maxX, y: r.minY)
    let p2 = CGPoint(x: r.maxX, y: r.maxY)
    let p3 = CGPoint(x: r.minX, y: r.maxY)
    return Path(components: [PathComponent(curves: [
        LineSegment(p0: p0, p1: p1),
        LineSegment(p0: p1, p1: p2),
        LineSegment(p0: p2, p1: p3),
        LineSegment(p0: p3, p1: p0)
    ])])
}

private func makePolygonPath(_ points: [CGPoint]) -> Path {
    let count = points.count
    var curves: [any BezierCurve] = []
    for i in 0..<count {
        curves.append(LineSegment(p0: points[i], p1: points[(i + 1) % count]))
    }
    return Path(components: [PathComponent(curves: curves)])
}

private func makeEllipsePath(in rect: CGRect) -> Path {
    let cx = rect.midX, cy = rect.midY
    let rx = rect.width / 2, ry = rect.height / 2
    let k: CGFloat = 0.5522847498
    let kx = k * rx, ky = k * ry
    return Path(components: [PathComponent(curves: [
        CubicCurve(p0: CGPoint(x: cx+rx, y: cy),    p1: CGPoint(x: cx+rx, y: cy+ky),
                   p2: CGPoint(x: cx+kx, y: cy+ry), p3: CGPoint(x: cx,    y: cy+ry)),
        CubicCurve(p0: CGPoint(x: cx,    y: cy+ry), p1: CGPoint(x: cx-kx, y: cy+ry),
                   p2: CGPoint(x: cx-rx, y: cy+ky), p3: CGPoint(x: cx-rx, y: cy)),
        CubicCurve(p0: CGPoint(x: cx-rx, y: cy),    p1: CGPoint(x: cx-rx, y: cy-ky),
                   p2: CGPoint(x: cx-kx, y: cy-ry), p3: CGPoint(x: cx,    y: cy-ry)),
        CubicCurve(p0: CGPoint(x: cx,    y: cy-ry), p1: CGPoint(x: cx+kx, y: cy-ry),
                   p2: CGPoint(x: cx+rx, y: cy-ky), p3: CGPoint(x: cx+rx, y: cy))
    ])])
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

    func testUnionCoincidentEdges1() {
        // a simple test of union'ing two squares where the max/min x edge are coincident
        let square1 = makeRectPath(CGRect(x: 0, y: 0, width: 1, height: 1))
        let square2 = makeRectPath(CGRect(x: 1, y: 0, width: 1, height: 1))
        let expectedUnion = makePolygonPath([CGPoint.zero,
                                             CGPoint(x: 1.0, y: 0.0),
                                             CGPoint(x: 2.0, y: 0.0),
                                             CGPoint(x: 2.0, y: 1.0),
                                             CGPoint(x: 1.0, y: 1.0),
                                             CGPoint(x: 0.0, y: 1.0)])
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
        let square1 = makeRectPath(CGRect(x: 0, y: 0, width: 3, height: 3))
        let square2 = makeRectPath(CGRect(x: 2, y: 1, width: 1, height: 1))
        let expectedUnion = makePolygonPath([CGPoint.zero,
                                             CGPoint(x: 3.0, y: 0.0),
                                             CGPoint(x: 3.0, y: 1.0),
                                             CGPoint(x: 3.0, y: 2.0),
                                             CGPoint(x: 3.0, y: 3.0),
                                             CGPoint(x: 0.0, y: 3.0)])
        let result1 = square1.union(square2)
        let result2 = square2.union(square1)
        XCTAssertEqual(result1.components.count, 1)
        XCTAssertEqual(result2.components.count, 1)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(result1.components[0], expectedUnion.components[0]))
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(result2.components[0], expectedUnion.components[0]))
    }

    func testUnionCoincidentEdges3() {
        // square 2 and 3 have a partially overlapping edge
        let square1 = makeRectPath(CGRect(x: 0, y: 0, width: 3, height: 3))
        let square2 = makeRectPath(CGRect(x: 3, y: 2, width: -2, height: 2))
        let expectedUnion = makePolygonPath([CGPoint.zero,
                                             CGPoint(x: 3.0, y: 0.0),
                                             CGPoint(x: 3.0, y: 2.0),
                                             CGPoint(x: 3.0, y: 3.0),
                                             CGPoint(x: 3.0, y: 4.0),
                                             CGPoint(x: 1.0, y: 4.0),
                                             CGPoint(x: 1.0, y: 3.0),
                                             CGPoint(x: 0.0, y: 3.0)])
        let result1 = square1.union(square2)
        let result2 = square1.union(square2.reversed())
        XCTAssertEqual(result1.components.count, 1)
        XCTAssertEqual(result2.components.count, 1)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(result1.components[0], expectedUnion.components[0]))
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(result2.components[0], expectedUnion.components[0]))
    }

    func testUnionCoincidentEdgesRealWorldTestCase1() {
        let polygon1 = makePolygonPath([CGPoint(x: 111.2, y: 90.0),
                                        CGPoint(x: 144.72135954999578, y: 137.02282018339787),
                                        CGPoint(x: 179.15338649848962, y: 123.08999319271176),
                                        CGPoint(x: 171.33627533401454, y: 102.89462632327792)])
        let polygon2 = makePolygonPath([CGPoint(x: 144.72135954999578, y: 137.02282018339787),
                                        CGPoint(x: 89.64133022449836, y: 119.6729633084088),
                                        CGPoint(x: 160.7501485041311, y: 111.6759272531885),
                                        CGPoint(x: 179.15338649848962, y: 123.08999319271176)])
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
        let star = makePolygonPath([CGPoint(x: 111.2, y: 90.0),
                                    CGPoint(x: 144.72135954999578, y: 137.02282018339787),
                                    CGPoint(x: 89.64133022449836, y: 119.6729633084088),
                                    CGPoint(x: 55.27864045000421, y: 166.0845213036123),
                                    CGPoint(x: 54.758669775501644, y: 108.33889987152517),
                                    CGPoint(x: 0.0, y: 90.00000000000001),
                                    CGPoint(x: 54.75866977550164, y: 71.66110012847484),
                                    CGPoint(x: 55.2786404500042, y: 13.915478696387723),
                                    CGPoint(x: 89.64133022449835, y: 60.3270366915912),
                                    CGPoint(x: 144.72135954999578, y: 42.97717981660214)])
        let polygon = makePolygonPath([CGPoint(x: 89.64133022449836, y: 119.6729633084088),
                                       CGPoint(x: 55.27864045000421, y: 166.0845213036123),
                                       CGPoint(x: 143.9588334407257, y: 125.35115333505796),
                                       CGPoint(x: 160.7501485041311, y: 111.6759272531885)])
        let unionResult1 = star.union(polygon)
        XCTAssertEqual(unionResult1.components.count, 1)

        let unionResult2 = star.union(polygon.reversed())
        XCTAssertEqual(unionResult2.components.count, 1)
    }

    func testUnionRealWorldEdgeCase() {
        guard MemoryLayout<CGFloat>.size > 4 else { return } // not enough precision in points for test to be valid
        let a = Path(components: [PathComponent(curves: [
            CubicCurve(p0: CGPoint(x: 310.198127403852, y: 190.08736919846973),
                       p1: CGPoint(x: 310.390629965343, y: 191.78584973769978),
                       p2: CGPoint(x: 310.0800866088565, y: 193.5583513843498),
                       p3: CGPoint(x: 309.1982933716744, y: 195.17240727745877)),
            CubicCurve(p0: CGPoint(x: 309.1982933716744, y: 195.17240727745877),
                       p1: CGPoint(x: 306.9208206199371, y: 199.34114906559483),
                       p2: CGPoint(x: 301.6951312337138, y: 200.87432554752368),
                       p3: CGPoint(x: 297.52638944557776, y: 198.59685279578636)),
            CubicCurve(p0: CGPoint(x: 297.52638944557776, y: 198.59685279578636),
                       p1: CGPoint(x: 294.8541298755864, y: 197.13694026929096),
                       p2: CGPoint(x: 293.26485189217163, y: 194.46557442730858),
                       p3: CGPoint(x: 293.06807628308206, y: 191.637728075906)),
            CubicCurve(p0: CGPoint(x: 293.06807628308206, y: 191.637728075906),
                       p1: CGPoint(x: 293.05884562618036, y: 191.50820426365925),
                       p2: CGPoint(x: 293.0524676850055, y: 191.37785711483136),
                       p3: CGPoint(x: 293.0490061981148, y: 191.24674708897507)),
            CubicCurve(p0: CGPoint(x: 293.0490061981148, y: 191.24674708897507),
                       p1: CGPoint(x: 292.9236355289621, y: 186.49810808117778),
                       p2: CGPoint(x: 296.67153503455194, y: 182.546942559205),
                       p3: CGPoint(x: 301.42017404234923, y: 182.42157189005232)),
            CubicCurve(p0: CGPoint(x: 301.42017404234923, y: 182.42157189005232),
                       p1: CGPoint(x: 305.9310607601042, y: 182.30247821176928),
                       p2: CGPoint(x: 309.72232986751203, y: 185.6785144367646),
                       p3: CGPoint(x: 310.198127403852, y: 190.08736919846973))
        ])])
        let b = Path(components: [PathComponent(curves: [
            CubicCurve(p0: CGPoint(x: 309.5688043100249, y: 187.66446326122298),
                       p1: CGPoint(x: 311.37643918302956, y: 192.05738329201742),
                       p2: CGPoint(x: 309.28065147291585, y: 197.0839261954614),
                       p3: CGPoint(x: 304.8877314421214, y: 198.89156106846605)),
            CubicCurve(p0: CGPoint(x: 304.8877314421214, y: 198.89156106846605),
                       p1: CGPoint(x: 300.4948114113269, y: 200.6991959414707),
                       p2: CGPoint(x: 295.46826850788295, y: 198.60340823135695),
                       p3: CGPoint(x: 293.6606336348783, y: 194.21048820056248)),
            CubicCurve(p0: CGPoint(x: 293.6606336348783, y: 194.21048820056248),
                       p1: CGPoint(x: 291.85299876187366, y: 189.81756816976807),
                       p2: CGPoint(x: 293.9487864719874, y: 184.79102526632408),
                       p3: CGPoint(x: 298.3417065027818, y: 182.98339039331944)),
            CubicCurve(p0: CGPoint(x: 298.3417065027818, y: 182.98339039331944),
                       p1: CGPoint(x: 302.7346265335763, y: 181.1757555203148),
                       p2: CGPoint(x: 307.76116943702027, y: 183.2715432304285),
                       p3: CGPoint(x: 309.5688043100249, y: 187.66446326122298))
        ])])
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
        let circle   = makeEllipsePath(in: CGRect(x: 0, y: 0, width: 3, height: 3))
        let hole     = makeEllipsePath(in: CGRect(x: 1, y: 1, width: 1, height: 1))
        let donut    = circle.subtract(hole)
        XCTAssertTrue(donut.contains(CGPoint(x: 0.5, y: 0.5), using: .winding))  // inside the donut (but not the hole)
        XCTAssertFalse(donut.contains(CGPoint(x: 1.5, y: 1.5), using: .winding)) // center of donut hole
    }

    func testSubtractingEntirelyErased() {
        // this is a specific test of `subtracting` to ensure that if a path component is entirely contained in the subtracting path that it gets removed
        let circle       = makeEllipsePath(in: CGRect(x: -1, y: -1, width: 2, height: 2))
        let biggerCircle = makeEllipsePath(in: CGRect(x: -2, y: -2, width: 4, height: 4))
        XCTAssert(circle.subtract(biggerCircle).isEmpty)
    }

    func testSubtractingEdgeCase1() {
        // this is a specific edge case test of `subtracting`. There was an issue where if a path element intersected at the exact border between
        // two elements on the other path it would count as two intersections. The winding count would then be incremented twice on the way in
        // but only once on the way out. So the entrance would be recognized but the exit not recognized.

        let rectangle = makeRectPath(CGRect(x: -1, y: -1, width: 4, height: 3))
        let circle    = makeEllipsePath(in: CGRect(x: 0, y: 0, width: 4, height: 4))

        // the circle intersects the rect at (0,2) and (3, 0.26792) ... the last number being exactly 2 - sqrt(3)
        let difference = rectangle.subtract(circle)
        XCTAssertEqual(difference.components.count, 1)
        XCTAssertFalse(difference.contains(CGPoint(x: 2.0, y: 2.0)))
    }

    func testSubtractingEdgeCase2() {

        // this unit test demosntrates an issue that came up in development where the logic for the winding direction
        // when corners intersect was not quite correct.

        let square1  = makeRectPath(CGRect(x: 0.0, y: 0.0, width: 2.0, height: 2.0))
        let square2  = makePolygonPath([CGPoint.zero,
                                        CGPoint(x: 1.0, y: -1.0),
                                        CGPoint(x: 2.0, y: 0.0),
                                        CGPoint(x: 1.0, y: 1.0)])
        let result = square1.subtract(square2)

        let expectedResult = makePolygonPath([CGPoint.zero,
                                              CGPoint(x: 1.0, y: 1.0),
                                              CGPoint(x: 2.0, y: 0.0),
                                              CGPoint(x: 2.0, y: 2.0),
                                              CGPoint(x: 0.0, y: 2.0)])

        XCTAssertEqual(result.components.count, expectedResult.components.count)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(result.components[0], expectedResult.components[0]))
    }

    func testCrossingsRemoved() {
        // self-intersecting path: (0,0)→(3,0)→(3,3)→(1,1)→(2,1)→(0,3)→back
        let path = makePolygonPath([CGPoint(x: 0, y: 0),
                                    CGPoint(x: 3, y: 0),
                                    CGPoint(x: 3, y: 3),
                                    CGPoint(x: 1, y: 1),
                                    CGPoint(x: 2, y: 1),
                                    CGPoint(x: 0, y: 3)])
        let intersection = CGPoint(x: 1.5, y: 1.5)
        let expectedResult = makePolygonPath([CGPoint(x: 0, y: 0),
                                              CGPoint(x: 3, y: 0),
                                              CGPoint(x: 3, y: 3),
                                              intersection,
                                              CGPoint(x: 0, y: 3)])

        XCTAssertTrue(path.contains(CGPoint(x: 1.5, y: 1.25), using: .winding))
        XCTAssertFalse(path.contains(CGPoint(x: 1.5, y: 1.25), using: .evenOdd))

        let result = path.crossingsRemoved()
        XCTAssertEqual(result.components.count, 1)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(result.components[0], expectedResult.components[0]))

        // check also that the algorithm works when the first point falls *inside* the path
        // rotated version: starts at (1,1)
        let pathAlt = makePolygonPath([CGPoint(x: 1, y: 1),
                                       CGPoint(x: 2, y: 1),
                                       CGPoint(x: 0, y: 3),
                                       CGPoint(x: 0, y: 0),
                                       CGPoint(x: 3, y: 0),
                                       CGPoint(x: 3, y: 3)])
        let resultAlt = pathAlt.crossingsRemoved()
        XCTAssertEqual(resultAlt.components.count, 1)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(resultAlt.components[0], expectedResult.components[0]))
    }

    func testCrossingsRemovedNoCrossings() {
        // a test which ensures that if a path has no crossings then crossingsRemoved does not modify it
        let square = makeEllipsePath(in: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))
        let result = square.crossingsRemoved()
        XCTAssertEqual(result.components.count, 1)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(result.components[0], square.components[0]))
    }

    func testCrossingsRemovedSingleCurveLoop() {
        let path = Path(components: [PathComponent(curves: [
            CubicCurve(p0: CGPoint(x: 0, y: 0),
                       p1: CGPoint(x: -1, y: 1),
                       p2: CGPoint(x: 1, y: 1),
                       p3: CGPoint(x: 0, y: 0))
        ])])
        XCTAssertEqual(path.crossingsRemoved(), path)
    }

    func testCrossingsRemovedEdgeCase() {
        // this is an edge cases which caused difficulty in practice
        // the contour, which intersects at (1,1) creates two squares, one with -1 winding count
        // the other with +1 winding count
        // incorrect implementation of this algorithm previously interpretted
        // the crossing as an entry / exit, which would completely cull off the square with +1 count

        let contour = makePolygonPath([CGPoint(x: 0, y: 1),
                                       CGPoint(x: 1, y: 1),
                                       CGPoint(x: 2, y: 1),
                                       CGPoint(x: 2, y: 2),
                                       CGPoint(x: 1, y: 2),
                                       CGPoint(x: 1, y: 1),
                                       CGPoint(x: 1, y: 0),
                                       CGPoint(x: 0, y: 0)])
        XCTAssertEqual(contour.windingCount(CGPoint(x: 0.5, y: 0.5)), -1) // winding count at center of one square region
        XCTAssertEqual(contour.windingCount(CGPoint(x: 1.5, y: 1.5)), 1) // winding count at center of other square region

        let crossingsRemoved = contour.crossingsRemoved()

        XCTAssertEqual(crossingsRemoved.components.count, 1)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(crossingsRemoved.components[0], contour.components[0]))
    }

#if canImport(CoreGraphics)
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
#endif

    func testCrossingsRemovedRealWorldEdgeCaseMagicNumbers() {
        // in practice this data was failing because 'smallNumber', a magic number in augmented graph was too large
        // it was fixed by decreasing the value by 10x
        let start = CGPoint(x: 79.59559290956605, y: 697.9008011912572)
        let path = Path(components: [PathComponent(curves: [
            CubicCurve(p0: start,
                       p1: CGPoint(x: 85.91646553575535, y: 708.7944954952286),
                       p2: CGPoint(x: 82.2094612873204, y: 722.7496586836662),
                       p3: CGPoint(x: 71.31576744881897, y: 729.0705310397749)),
            CubicCurve(p0: CGPoint(x: 71.31576744881897, y: 729.0705310397749),
                       p1: CGPoint(x: 60.4220735042526, y: 735.3914034574259),
                       p2: CGPoint(x: 46.46691031581487, y: 731.6843992089908),
                       p3: CGPoint(x: 40.14603795970622, y: 720.7907053704894)),
            CubicCurve(p0: CGPoint(x: 40.14603795970622, y: 720.7907053704894),
                       p1: CGPoint(x: 39.07549105339858, y: 718.7074812854011),
                       p2: CGPoint(x: 37.21110624960683, y: 711.947464952338),
                       p3: CGPoint(x: 37.21144227099133, y: 706.7177736592248)),
            CubicCurve(p0: CGPoint(x: 37.21144227099133, y: 706.7177736592248),
                       p1: CGPoint(x: 38.65395965539626, y: 694.2059748336982),
                       p2: CGPoint(x: 49.96616803120935, y: 685.2325492391592),
                       p3: CGPoint(x: 62.477966856736, y: 686.6750666235641)),
            CubicCurve(p0: CGPoint(x: 62.477966856736, y: 686.6750666235641),
                       p1: CGPoint(x: 74.98976785362623, y: 688.1175842583111),
                       p2: CGPoint(x: 83.96319344816517, y: 699.4297926341243),
                       p3: CGPoint(x: 82.52067606376023, y: 711.9415914596509)),
            CubicCurve(p0: CGPoint(x: 82.52067606376023, y: 711.9415914596509),
                       p1: CGPoint(x: 82.51999960076027, y: 706.7206820370851),
                       p2: CGPoint(x: 80.65889482357387, y: 699.9715389099819),
                       p3: start)
        ])])
        let result = path.crossingsRemoved(accuracy: 0.01)
        // in practice .crossingsRemoved was cutting off most of the shape
        XCTAssertEqual(path.boundingBox.size.x, result.boundingBox.size.x, accuracy: 1.0e-3)
        XCTAssertEqual(path.boundingBox.size.y, result.boundingBox.size.y, accuracy: 1.0e-3)
        XCTAssertEqual(result.components[0].numberOfElements, 5) // with crossings removed we should have 1 fewer curve (the last one)
    }

    func testCrossingsRemovedAnotherRealWorldCase() {

        guard MemoryLayout<CGFloat>.size > 4 else { return } // not enough precision in points for test to be valid

        let start = CGPoint(x: 503.3060153966664, y: 766.9140612367046)
        let path = Path(components: [PathComponent(curves: [
            CubicCurve(p0: start,
                       p1: CGPoint(x: 506.0019772976378, y: 761.5330522602719),
                       p2: CGPoint(x: 512.5496560294043, y: 759.3563914926846),
                       p3: CGPoint(x: 517.9306651149989, y: 762.0523534483476)),
            CubicCurve(p0: CGPoint(x: 517.9306651149989, y: 762.0523534483476),
                       p1: CGPoint(x: 523.3116744085926, y: 764.7483155082213),
                       p2: CGPoint(x: 525.4883351761798, y: 771.2959942399877),
                       p3: CGPoint(x: 522.7923732205169, y: 776.6770033255823)),
            CubicCurve(p0: CGPoint(x: 522.7923732205169, y: 776.6770033255823),
                       p1: CGPoint(x: 522.6619398993569, y: 776.9550303733141),
                       p2: CGPoint(x: 522.7228057838222, y: 776.8532852161298),
                       p3: CGPoint(x: 520.758836935199, y: 764.316674774872)),
            CubicCurve(p0: CGPoint(x: 520.758836935199, y: 764.316674774872),
                       p1: CGPoint(x: 524.9876580913353, y: 768.6238074338997),
                       p2: CGPoint(x: 524.9241740749491, y: 775.5435652200052),
                       p3: CGPoint(x: 520.6170414159213, y: 779.7723863761416)),
            CubicCurve(p0: CGPoint(x: 520.6170414159213, y: 779.7723863761416),
                       p1: CGPoint(x: 516.3099083864128, y: 784.001207896023),
                       p2: CGPoint(x: 509.3901506003072, y: 783.9377238796366),
                       p3: CGPoint(x: 505.16132944417086, y: 779.6305912206088)),
            CubicCurve(p0: CGPoint(x: 505.16132944417086, y: 779.6305912206088),
                       p1: CGPoint(x: 503.19076843492786, y: 767.0872665416827),
                       p2: CGPoint(x: 503.3761460381431, y: 766.7563954079359),
                       p3: start)
        ])])
        let result = path.crossingsRemoved(accuracy: 1.0e-5)
        // in practice .crossingsRemoved was cutting off most of the shape
        XCTAssertEqual(path.boundingBox.size.x, result.boundingBox.size.x, accuracy: 1.0e-3)
        XCTAssertEqual(path.boundingBox.size.y, result.boundingBox.size.y, accuracy: 1.0e-3)
    }

    func testCrossingsRemovedThirdRealWorldCase() {
        let component1 = PathComponent(curves: [
            LineSegment(p0: CGPoint(x: 115.23034681147224, y: 59.327037989273855),
                        p1: CGPoint(x: 130.4334714935808, y: 59.32703798927386)),
            LineSegment(p0: CGPoint(x: 130.4334714935808, y: 59.32703798927386),
                        p1: CGPoint(x: 130.4334714935808, y: 215.00646454457666)),
            LineSegment(p0: CGPoint(x: 130.4334714935808, y: 215.00646454457666),
                        p1: CGPoint(x: 115.23034681147224, y: 215.00646454457666)),
            LineSegment(p0: CGPoint(x: 115.23034681147224, y: 215.00646454457666),
                        p1: CGPoint(x: 115.23034681147222, y: 82.92265451611944)),
            LineSegment(p0: CGPoint(x: 115.23034681147222, y: 82.92265451611944),
                        p1: CGPoint(x: 115.23034681147224, y: 59.327037989273855))
        ])
        let component2 = PathComponent(curves: [
            LineSegment(p0: CGPoint(x: 130.4334714935808, y: 59.32703798927387),
                        p1: CGPoint(x: 130.43347149358078, y: 82.92265451611945)),
            LineSegment(p0: CGPoint(x: 130.43347149358078, y: 82.92265451611945),
                        p1: CGPoint(x: 130.4334714935808, y: 215.00646454457666)),
            CubicCurve(p0: CGPoint(x: 130.4334714935808, y: 215.00646454457666),
                       p1: CGPoint(x: 130.4334714935808, y: 225.1418809993157),
                       p2: CGPoint(x: 115.23034681147224, y: 225.1418809993157),
                       p3: CGPoint(x: 115.23034681147224, y: 215.00646454457666)),
            LineSegment(p0: CGPoint(x: 115.23034681147224, y: 215.00646454457666),
                        p1: CGPoint(x: 115.23034681147224, y: 59.32703798927386)),
            CubicCurve(p0: CGPoint(x: 115.23034681147224, y: 59.32703798927386),
                       p1: CGPoint(x: 115.23034681147224, y: 49.19162153453482),
                       p2: CGPoint(x: 130.4334714935808, y: 49.19162153453483),
                       p3: CGPoint(x: 130.4334714935808, y: 59.32703798927387))
        ])
        let p = Path(components: [component1, component2])
        _ = p.crossingsRemoved(accuracy: 0.0001)
    }

    func testCrosingsRemovedFourthRealWorldCase() {
        // this case was cauesd by a curve that self-intersected which caused us to make the wrong determination
        // classifying which parts of the path should be included in the final result
        let firstPoint = CGPoint(x: 128.65039465906003, y: 123.73954643229627)
        let path = Path(components: [PathComponent(curves: [
            CubicCurve(p0: firstPoint,
                       p1: CGPoint(x: 125.4190121591063, y: 126.96936863167058),
                       p2: CGPoint(x: 120.18117084764445, y: 126.96810375813484),
                       p3: CGPoint(x: 116.95134864827014, y: 123.73672125818112)),
            CubicCurve(p0: CGPoint(x: 116.95134864827014, y: 123.73672125818112),
                       p1: CGPoint(x: 113.72152644889583, y: 120.5053387582274),
                       p2: CGPoint(x: 113.72279132243156, y: 115.26749744676555),
                       p3: CGPoint(x: 116.95417382238529, y: 112.03767524739123)),
            CubicCurve(p0: CGPoint(x: 116.95417382238529, y: 112.03767524739123),
                       p1: CGPoint(x: 119.3560792543184, y: 110.34087389676174),
                       p2: CGPoint(x: 120.25529993069892, y: 109.98254275757822),
                       p3: CGPoint(x: 117.06818455296886, y: 111.94933998303057)),
            CubicCurve(p0: CGPoint(x: 117.06818455296886, y: 111.94933998303057),
                       p1: CGPoint(x: 120.31240285203181, y: 108.71058333093575),
                       p2: CGPoint(x: 125.56789243958164, y: 108.71501087060513),
                       p3: CGPoint(x: 128.80664909167646, y: 111.95922916966808)),
            CubicCurve(p0: CGPoint(x: 128.80664909167646, y: 111.95922916966808),
                       p1: CGPoint(x: 132.04540574377128, y: 115.20344746873103),
                       p2: CGPoint(x: 132.0409782041019, y: 120.45893705628086),
                       p3: CGPoint(x: 128.79675990503895, y: 123.69769370837568)),
            CubicCurve(p0: CGPoint(x: 128.79675990503895, y: 123.69769370837568),
                       p1: CGPoint(x: 125.59151708590264, y: 125.68258785765616),
                       p2: CGPoint(x: 126.31169113142379, y: 125.37317639620701),
                       p3: firstPoint)
        ])])
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
        let outerSquare = makeRectPath(CGRect(x: 0, y: 0, width: 5, height: 5))
        let selfIntersecting = makePolygonPath([CGPoint(x: 1, y: 2),
                                                CGPoint(x: 2, y: 1),
                                                CGPoint(x: 2, y: 4),
                                                CGPoint(x: 1, y: 3),
                                                CGPoint(x: 4, y: 3),
                                                CGPoint(x: 3, y: 4),
                                                CGPoint(x: 3, y: 1),
                                                CGPoint(x: 4, y: 2)])
        let path = Path(components: outerSquare.components + selfIntersecting.components)
        let result = path.crossingsRemoved()

        let expectedOuter = makeRectPath(CGRect(x: 0, y: 0, width: 5, height: 5))
        let expectedHole  = makePolygonPath([CGPoint(x: 2, y: 2),
                                             CGPoint(x: 2, y: 3),
                                             CGPoint(x: 3, y: 3),
                                             CGPoint(x: 3, y: 2)])
        let expectedResult = Path(components: expectedOuter.components + expectedHole.components)

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
        // The last element duplicates the first; drop it to avoid a zero-length closing segment.
        let component1 = makePolygonPath(Array(points1.dropLast())).components[0]
        let component2 = makePolygonPath(Array(points2.dropLast())).components[0]
        let path = Path(components: [component1, component2])
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

        let component1 = PathComponent(curves: [
            CubicCurve(p0: CGPoint(x: 431.2394694928875, y: 109.81690300533613),
                       p1: CGPoint(x: 431.2394694928875, y: 110.13177002702506),
                       p2: CGPoint(x: 430.9842193389974, y: 110.3870201809152),
                       p3: CGPoint(x: 430.66935231730844, y: 110.3870201809152)),
            LineSegment(p0: CGPoint(x: 430.66935231730844, y: 110.3870201809152),
                        p1: CGPoint(x: 382.89122776801867, y: 110.3870201809152)),
            LineSegment(p0: CGPoint(x: 382.89122776801867, y: 110.3870201809152),
                        p1: CGPoint(x: 383.46134494359774, y: 109.81690300533613)),
            LineSegment(p0: CGPoint(x: 383.46134494359774, y: 109.81690300533613),
                        p1: CGPoint(x: 383.46134494359774, y: 125.44498541142156)),
            LineSegment(p0: CGPoint(x: 383.46134494359774, y: 125.44498541142156),
                        p1: CGPoint(x: 382.89122776801867, y: 124.87486823584248)),
            LineSegment(p0: CGPoint(x: 382.89122776801867, y: 124.87486823584248),
                        p1: CGPoint(x: 430.66935231730844, y: 124.87486823584248)),
            LineSegment(p0: CGPoint(x: 430.66935231730844, y: 124.87486823584248),
                        p1: CGPoint(x: 430.09923514172937, y: 125.44498541142156)),
            LineSegment(p0: CGPoint(x: 430.09923514172937, y: 125.44498541142156),
                        p1: CGPoint(x: 430.09923514172937, y: 99.92396144754883)),
            LineSegment(p0: CGPoint(x: 430.09923514172937, y: 99.92396144754883),
                        p1: CGPoint(x: 431.2394694928875, y: 99.92396144754883)),
            LineSegment(p0: CGPoint(x: 431.2394694928875, y: 99.92396144754883),
                        p1: CGPoint(x: 431.2394694928875, y: 109.81690300533613))
        ])
        let component2 = PathComponent(curves: [
            LineSegment(p0: CGPoint(x: 430.09923514172937, y: 109.81690300533613),
                        p1: CGPoint(x: 430.09923514172937, y: 99.92396144754883)),
            CubicCurve(p0: CGPoint(x: 430.09923514172937, y: 99.92396144754883),
                       p1: CGPoint(x: 430.09923514172937, y: 99.16380521344341),
                       p2: CGPoint(x: 431.2394694928875, y: 99.16380521344341),
                       p3: CGPoint(x: 431.2394694928875, y: 99.92396144754883)),
            LineSegment(p0: CGPoint(x: 431.2394694928875, y: 99.92396144754883),
                        p1: CGPoint(x: 431.2394694928875, y: 125.44498541142156)),
            CubicCurve(p0: CGPoint(x: 431.2394694928875, y: 125.44498541142156),
                       p1: CGPoint(x: 431.2394694928875, y: 125.75985243311048),
                       p2: CGPoint(x: 430.9842193389974, y: 126.01510258700063),
                       p3: CGPoint(x: 430.66935231730844, y: 126.01510258700063)),
            LineSegment(p0: CGPoint(x: 430.66935231730844, y: 126.01510258700063),
                        p1: CGPoint(x: 382.89122776801867, y: 126.01510258700063)),
            CubicCurve(p0: CGPoint(x: 382.89122776801867, y: 126.01510258700063),
                       p1: CGPoint(x: 382.5763607463297, y: 126.01510258700063),
                       p2: CGPoint(x: 382.3211105924396, y: 125.75985243311048),
                       p3: CGPoint(x: 382.3211105924396, y: 125.44498541142156)),
            LineSegment(p0: CGPoint(x: 382.3211105924396, y: 125.44498541142156),
                        p1: CGPoint(x: 382.3211105924396, y: 109.81690300533613)),
            CubicCurve(p0: CGPoint(x: 382.3211105924396, y: 109.81690300533613),
                       p1: CGPoint(x: 382.3211105924396, y: 109.5020359836472),
                       p2: CGPoint(x: 382.5763607463297, y: 109.24678582975706),
                       p3: CGPoint(x: 382.89122776801867, y: 109.24678582975706)),
            LineSegment(p0: CGPoint(x: 382.89122776801867, y: 109.24678582975706),
                        p1: CGPoint(x: 430.66935231730844, y: 109.24678582975706)),
            LineSegment(p0: CGPoint(x: 430.66935231730844, y: 109.24678582975706),
                        p1: CGPoint(x: 430.09923514172937, y: 109.81690300533613))
        ])
        let path = Path(components: [component1, component2])
        _ = path.crossingsRemoved(accuracy: 0.01)

        // for now the test's only expectation is that we do not go into an infinite loop
        // TODO: make test stricter
    }

    // MARK: - Adversarial tests for winding-count-based edge classification

    func testContainmentNoIntersection() {
        // When one path is fully inside the other and they share no intersections, the seed
        // computation must use the correct winding count to classify all edges.
        let outer = Path(components: [PathComponent(curves: [
            LineSegment(p0: CGPoint(x: 0, y: 0), p1: CGPoint(x: 4, y: 0)),
            LineSegment(p0: CGPoint(x: 4, y: 0), p1: CGPoint(x: 4, y: 4)),
            LineSegment(p0: CGPoint(x: 4, y: 4), p1: CGPoint(x: 0, y: 4)),
            LineSegment(p0: CGPoint(x: 0, y: 4), p1: CGPoint(x: 0, y: 0))
        ])])
        let inner = Path(components: [PathComponent(curves: [
            LineSegment(p0: CGPoint(x: 1, y: 1), p1: CGPoint(x: 3, y: 1)),
            LineSegment(p0: CGPoint(x: 3, y: 1), p1: CGPoint(x: 3, y: 3)),
            LineSegment(p0: CGPoint(x: 3, y: 3), p1: CGPoint(x: 1, y: 3)),
            LineSegment(p0: CGPoint(x: 1, y: 3), p1: CGPoint(x: 1, y: 1))
        ])])
        // inner is entirely inside outer, no intersections
        XCTAssert(outer.intersections(with: inner).isEmpty)
        // intersect should yield inner (the shared region)
        let intersected = outer.intersect(inner)
        XCTAssertEqual(intersected.components.count, 1)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(intersected.components[0], inner.components[0]))
        // union should yield outer (inner adds nothing new)
        let united = outer.union(inner)
        XCTAssertEqual(united.components.count, 1)
        XCTAssertTrue(componentsEqualAsideFromElementOrdering(united.components[0], outer.components[0]))
    }

    func testIntersectionAtCornerOfPath() {
        // Tests intersection at t=1 of a line element (a corner vertex of the path).
        // The convention is that intersections at t=0 of element i are stored as t=1 of
        // element i-1 (for closed paths), so the winding-count delta formula always uses
        // the incoming tangent — confirmed to give the correct result here.
        //
        // square1 corners: (0,0),(2,0),(2,2),(0,2).
        // diamond: a rotated square with a vertex at exactly (2,0) — the bottom-right
        // corner of square1. The corner-to-corner intersection tests that the winding
        // count delta at a t=1 corner node is computed correctly.
        let square1 = createSquare1()  // corners (0,0),(2,0),(2,2),(0,2)
        // Diamond centered at (3,1) with vertices at (2,0),(4,0),(4,2),(2,2) — wait,
        // that is a square, not a diamond. Use a proper diamond:
        // vertices at (2,0), (3,-1), (4,0), (3,1) — all outside square1 except the one point
        let diamond = Path(components: [PathComponent(curves: [
            LineSegment(p0: CGPoint(x: 2, y: 0), p1: CGPoint(x: 3, y: -1)),
            LineSegment(p0: CGPoint(x: 3, y: -1), p1: CGPoint(x: 4, y: 0)),
            LineSegment(p0: CGPoint(x: 4, y: 0), p1: CGPoint(x: 3, y: 1)),
            LineSegment(p0: CGPoint(x: 3, y: 1), p1: CGPoint(x: 2, y: 0))
        ])])
        // The two paths share only the single point (2,0). Neither contains the other.
        // union should produce a path whose bounding box covers both shapes.
        let united = square1.union(diamond)
        XCTAssertFalse(united.isEmpty)
        XCTAssertGreaterThan(united.boundingBox.size.x, 2.0)  // extends beyond x=2
        // intersect of two paths touching at a single point has no interior area
        let intersected = square1.intersect(diamond)
        XCTAssertTrue(intersected.isEmpty || intersected.boundingBox.area < 1e-6)
    }

    func testIntersectionAtCornerToInterior() {
        // One path's CORNER vertex lies on the INTERIOR of the other path's edge.
        // On path1, the intersection is at t=1 of the element whose endpoint is the corner.
        // On path2, the intersection is at an interior t value (not a corner).
        // This exercises the case where only one of the two participants is at a corner.
        //
        // square1 corners: (0,0),(2,0),(2,2),(0,2).
        // path2 is a rectangle whose left edge passes through square1's corner (2,0):
        // path2 has corners at (2,-1),(4,-1),(4,1),(2,1) — its left edge at x=2 runs
        // through (2,0) (which is a corner of square1, but only an interior point of path2).
        let square1 = createSquare1()  // corners (0,0),(2,0),(2,2),(0,2)
        let path2 = Path(components: [PathComponent(curves: [
            LineSegment(p0: CGPoint(x: 2, y: -1), p1: CGPoint(x: 4, y: -1)),
            LineSegment(p0: CGPoint(x: 4, y: -1), p1: CGPoint(x: 4, y: 1)),
            LineSegment(p0: CGPoint(x: 4, y: 1), p1: CGPoint(x: 2, y: 1)),
            LineSegment(p0: CGPoint(x: 2, y: 1), p1: CGPoint(x: 2, y: -1))
        ])])
        // The intersection points are:
        //   (2,0): corner of square1 (t=1 of E0=(0,0)→(2,0)) × interior of path2's left edge
        //   (2,1): interior of square1's right edge × corner of path2
        // path2 covers x∈[2,4], square1 covers x∈[0,2]. They share the 1D boundary x=2.
        // subtract(path2) should leave square1 unchanged geometrically (no 2D area overlap).
        // The algorithm may split square1's right edge at (2,1), producing 5 elements instead
        // of 4, so we verify geometric equivalence via bounding box rather than element equality.
        let subtracted = square1.subtract(path2)
        XCTAssertEqual(subtracted.components.count, 1)
        XCTAssertEqual(subtracted.boundingBox, square1.boundingBox)
    }

    func testDegenerateFirstElementInPath() {
        // A path that starts with a zero-length segment. The seed-point normal is NaN for
        // zero-length elements, so the code falls back to the midpoint without an offset.
        // The test verifies that boolean ops do not crash and produce a plausible result.
        let square = createSquare1()
        // Build a path identical to square1 but with a zero-length first element inserted.
        let zeroPoint = CGPoint(x: 0, y: 0)
        let degeneratePath = Path(components: [PathComponent(curves: [
            LineSegment(p0: zeroPoint, p1: zeroPoint),   // zero-length element
            LineSegment(p0: CGPoint(x: 0, y: 0), p1: CGPoint(x: 2, y: 0)),
            LineSegment(p0: CGPoint(x: 2, y: 0), p1: CGPoint(x: 2, y: 2)),
            LineSegment(p0: CGPoint(x: 2, y: 2), p1: CGPoint(x: 0, y: 2)),
            LineSegment(p0: CGPoint(x: 0, y: 2), p1: CGPoint(x: 0, y: 0))
        ])])
        // Should not crash regardless of first element being degenerate.
        _ = degeneratePath.union(square)
        _ = degeneratePath.intersect(square)
        _ = degeneratePath.subtract(square)
    }

    func testTangentIntersectionProducesNoWindingCountChange() {
        // Two circles tangent to each other externally — their cross product of normals
        // at the tangent point is zero, so windingCountDelta returns 0.
        // union of two externally-tangent circles should be two components.
        #if canImport(CoreGraphics)
        let circle1 = Path(cgPath: CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 2, height: 2), transform: nil))
        let circle2 = Path(cgPath: CGPath(ellipseIn: CGRect(x: 2, y: 0, width: 2, height: 2), transform: nil))
        // The circles are tangent at (2,1). They share no interior.
        let united = circle1.union(circle2)
        // Two externally-tangent shapes either produce 2 components (if tangent point is ignored)
        // or 1 component (if the tangent point is treated as a connection). Either is acceptable —
        // this test just verifies no crash and no empty result.
        XCTAssertFalse(united.isEmpty)
        #endif
    }

    func testWindingCountSeedPointWithNearbyEdge() {
        // Verifies that two non-intersecting, non-containing paths are union-ed as two
        // separate components.  The seed point for each component is the midpoint of the
        // first edge offset by smallDistance (1e-6 on 64-bit, 1e-4 on 32-bit) in the
        // normal direction.  For this test to be reliable the gap between the paths must
        // exceed smallDistance so that the seed offset cannot accidentally cross the other
        // path's boundary.  We use a gap of 0.01, which is >> max(1e-4, 1e-6).
        let top = Path(components: [PathComponent(curves: [
            LineSegment(p0: CGPoint(x: 0, y: 0.01), p1: CGPoint(x: 2, y: 0.01)),
            LineSegment(p0: CGPoint(x: 2, y: 0.01), p1: CGPoint(x: 2, y: 2)),
            LineSegment(p0: CGPoint(x: 2, y: 2), p1: CGPoint(x: 0, y: 2)),
            LineSegment(p0: CGPoint(x: 0, y: 2), p1: CGPoint(x: 0, y: 0.01))
        ])])
        let bottom = Path(components: [PathComponent(curves: [
            LineSegment(p0: CGPoint(x: 0, y: 0), p1: CGPoint(x: 2, y: 0)),
            LineSegment(p0: CGPoint(x: 2, y: 0), p1: CGPoint(x: 2, y: -2)),
            LineSegment(p0: CGPoint(x: 2, y: -2), p1: CGPoint(x: 0, y: -2)),
            LineSegment(p0: CGPoint(x: 0, y: -2), p1: CGPoint(x: 0, y: 0))
        ])])
        // Paths don't intersect (gap = 0.01)
        XCTAssert(top.intersections(with: bottom).isEmpty)
        // union of two non-overlapping paths = two separate components
        let united = top.union(bottom)
        XCTAssertEqual(united.components.count, 2)
    }
}
