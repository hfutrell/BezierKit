//
//  PathComponentSplitPerformanceTests.swift
//  BezierKit
//

import BezierKit
import XCTest

#if !os(WASI)

private func makeMixedPath(elementCount: Int) -> PathComponent {
    // Repeating pattern: line, quadratic, cubic, …
    var curves: [BezierCurve] = []
    var cur = CGPoint(x: 0, y: 0)
    for i in 0..<elementCount {
        let next = CGPoint(x: CGFloat(i + 1), y: CGFloat((i * 7 + 3) % 10) * 0.1)
        switch i % 3 {
        case 0:
            curves.append(LineSegment(p0: cur, p1: next))
        case 1:
            curves.append(QuadraticCurve(p0: cur,
                                         p1: CGPoint(x: (cur.x + next.x) * 0.5, y: cur.y + 0.5),
                                         p2: next))
        default:
            curves.append(CubicCurve(p0: cur,
                                     p1: CGPoint(x: cur.x + 0.25, y: cur.y + 0.5),
                                     p2: CGPoint(x: next.x - 0.25, y: next.y + 0.5),
                                     p3: next))
        }
        cur = next
    }
    return PathComponent(curves: curves)
}

class PathComponentSplitPerformanceTests: XCTestCase {

    // MARK: - Short path (~5 elements, line/quad/cubic mix)
    //
    // Each test warms up for 10 000 iterations before the measure {} block
    // so the allocator is in steady state for all 10 XCTest runs.
    // Iteration counts target ~150 ms per run.

    func testSplitShortPathMidRange() {
        // partial start + full elements + partial end  — -Os ~270 ns/split
        let path = makeMixedPath(elementCount: 5)
        let n = path.numberOfElements
        let range = PathComponentRange(
            from: IndexedPathComponentLocation(elementIndex: n / 4, t: 0.3),
            to:   IndexedPathComponentLocation(elementIndex: 3 * n / 4, t: 0.7))
        var count = 0
        for _ in 0..<10_000 { count += path.split(standardizedRange: range).numberOfElements }
        self.measure {
            for _ in 0..<500_000 { count += path.split(standardizedRange: range).numberOfElements }
        }
        XCTAssert(count > 0)
    }

    func testSplitShortPathFullRange() {
        // t=0…1: fast path only, no boundary splits  — -Os ~200 ns/split
        let path = makeMixedPath(elementCount: 5)
        let n = path.numberOfElements
        let range = PathComponentRange(
            from: IndexedPathComponentLocation(elementIndex: n / 4, t: 0.0),
            to:   IndexedPathComponentLocation(elementIndex: 3 * n / 4, t: 1.0))
        var count = 0
        for _ in 0..<10_000 { count += path.split(standardizedRange: range).numberOfElements }
        self.measure {
            for _ in 0..<750_000 { count += path.split(standardizedRange: range).numberOfElements }
        }
        XCTAssert(count > 0)
    }

    func testSplitShortPathTwoElements() {
        // two adjacent partial elements, no full elements in between  — -Os ~250 ns/split
        let path = makeMixedPath(elementCount: 5)
        let mid = path.numberOfElements / 2
        let range = PathComponentRange(
            from: IndexedPathComponentLocation(elementIndex: mid,     t: 0.4),
            to:   IndexedPathComponentLocation(elementIndex: mid + 1, t: 0.6))
        var count = 0
        for _ in 0..<10_000 { count += path.split(standardizedRange: range).numberOfElements }
        self.measure {
            for _ in 0..<500_000 { count += path.split(standardizedRange: range).numberOfElements }
        }
        XCTAssert(count > 0)
    }

    // MARK: - Medium path (~51 elements)

    func testSplitMediumPathMidRange() {
        // -Os ~300 ns/split
        let path = makeMixedPath(elementCount: 51)
        let n = path.numberOfElements
        let range = PathComponentRange(
            from: IndexedPathComponentLocation(elementIndex: n / 4, t: 0.3),
            to:   IndexedPathComponentLocation(elementIndex: 3 * n / 4, t: 0.7))
        var count = 0
        for _ in 0..<10_000 { count += path.split(standardizedRange: range).numberOfElements }
        self.measure {
            for _ in 0..<500_000 { count += path.split(standardizedRange: range).numberOfElements }
        }
        XCTAssert(count > 0)
    }

    func testSplitMediumPathFullRange() {
        // -Os ~230 ns/split
        let path = makeMixedPath(elementCount: 51)
        let n = path.numberOfElements
        let range = PathComponentRange(
            from: IndexedPathComponentLocation(elementIndex: n / 4, t: 0.0),
            to:   IndexedPathComponentLocation(elementIndex: 3 * n / 4, t: 1.0))
        var count = 0
        for _ in 0..<10_000 { count += path.split(standardizedRange: range).numberOfElements }
        self.measure {
            for _ in 0..<500_000 { count += path.split(standardizedRange: range).numberOfElements }
        }
        XCTAssert(count > 0)
    }

    func testSplitMediumPathTwoElements() {
        // -Os ~255 ns/split
        let path = makeMixedPath(elementCount: 51)
        let mid = path.numberOfElements / 2
        let range = PathComponentRange(
            from: IndexedPathComponentLocation(elementIndex: mid,     t: 0.4),
            to:   IndexedPathComponentLocation(elementIndex: mid + 1, t: 0.6))
        var count = 0
        for _ in 0..<10_000 { count += path.split(standardizedRange: range).numberOfElements }
        self.measure {
            for _ in 0..<500_000 { count += path.split(standardizedRange: range).numberOfElements }
        }
        XCTAssert(count > 0)
    }

    // MARK: - Long path (~2001 elements)
    //
    // Warmup is larger (20 000) to settle the allocator for the bigger arrays.

    func testSplitLongPathMidRange() {
        // -Os ~1000 ns/split
        let path = makeMixedPath(elementCount: 2001)
        let n = path.numberOfElements
        let range = PathComponentRange(
            from: IndexedPathComponentLocation(elementIndex: n / 4, t: 0.3),
            to:   IndexedPathComponentLocation(elementIndex: 3 * n / 4, t: 0.7))
        var count = 0
        for _ in 0..<100_000 { count += path.split(standardizedRange: range).numberOfElements }
        self.measure {
            for _ in 0..<150_000 { count += path.split(standardizedRange: range).numberOfElements }
        }
        XCTAssert(count > 0)
    }

    func testSplitLongPathFullRange() {
        // -Os ~1000 ns/split
        let path = makeMixedPath(elementCount: 2001)
        let n = path.numberOfElements
        let range = PathComponentRange(
            from: IndexedPathComponentLocation(elementIndex: n / 4, t: 0.0),
            to:   IndexedPathComponentLocation(elementIndex: 3 * n / 4, t: 1.0))
        var count = 0
        for _ in 0..<100_000 { count += path.split(standardizedRange: range).numberOfElements }
        self.measure {
            for _ in 0..<150_000 { count += path.split(standardizedRange: range).numberOfElements }
        }
        XCTAssert(count > 0)
    }

    func testSplitLongPathTwoElements() {
        // -Os ~260 ns/split
        let path = makeMixedPath(elementCount: 2001)
        let mid = path.numberOfElements / 2
        let range = PathComponentRange(
            from: IndexedPathComponentLocation(elementIndex: mid,     t: 0.4),
            to:   IndexedPathComponentLocation(elementIndex: mid + 1, t: 0.6))
        var count = 0
        for _ in 0..<100_000 { count += path.split(standardizedRange: range).numberOfElements }
        self.measure {
            for _ in 0..<500_000 { count += path.split(standardizedRange: range).numberOfElements }
        }
        XCTAssert(count > 0)
    }
}

#endif
