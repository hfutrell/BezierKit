//
//  PerformanceTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/3/21.
//  Copyright © 2021 Holmes Futrell. All rights reserved.
//

import BezierKit
import XCTest

#if !os(WASI)
private extension PerformanceTests {

    func generateRandomCurves(count: Int, selfIntersect: Bool? = nil, reseed: Int? = nil) -> [CubicCurve] {
        if let reseed = reseed {
            srand48(reseed) // seed with zero so that "random" values are actually the same across test runs
        }
        func randomPoint() -> CGPoint {
            let x = CGFloat(drand48())
            let y = CGFloat(drand48())
            return CGPoint(x: x, y: y)
        }
       func randomCurve() -> CubicCurve {
            return CubicCurve(p0: randomPoint(),
                              p1: randomPoint(),
                              p2: randomPoint(),
                              p3: randomPoint())
       }
        var curves: [CubicCurve] = []
        while curves.count < count {
            let curve = randomCurve()
            if selfIntersect == nil || curve.selfIntersects == selfIntersect {
                curves.append(curve)
            }
        }
        return curves
    }

    #if canImport(CoreGraphics)

    func parametricPath(numCurves: Int,
                        theta: (_: CGFloat) -> CGFloat,
                        dthetadt: (_: CGFloat) -> CGFloat,
                        r: (_: CGFloat) -> CGFloat,
                        drdt: (_: CGFloat) -> CGFloat) -> Path {
        func p(_ t: CGFloat) -> CGPoint {
            return CGPoint(x: r(t) * cos(theta(t)), y: r(t) * sin(theta(t)))
        }
        func d(_ t: CGFloat) -> CGPoint {
            return CGPoint(x: drdt(t) * cos(theta(t)) - r(t) * sin(theta(t)) * dthetadt(t),
                           y: drdt(t) * sin(theta(t)) + r(t) * cos(theta(t)) * dthetadt(t))
        }
        let cgPath = CGMutablePath()
        var previousT: CGFloat = 0.0
        var previousPoint = p(previousT)
        cgPath.move(to: previousPoint)
        let delta = 1.0 / CGFloat(numCurves)
        for i in 1...numCurves {
            let nextT = CGFloat(i) / CGFloat(numCurves)
            let nextPoint = p(nextT)
            cgPath.addCurve(to: nextPoint, control1: previousPoint + delta / 3.0 * d(previousT), control2: nextPoint - delta / 3.0 * d(nextT))
            previousPoint = nextPoint
            previousT = nextT
        }
        return Path(cgPath: cgPath)
    }

    #endif
}

class PerformanceTests: XCTestCase {

    func testCubicSelfIntersectionsPerformanceNoIntersect() {
        // test the performance of `selfIntersections` when the curves DO NOT self-intersect
        // -Onone 0.036 seconds
        // -Os 0.004 seconds
        let dataCount = 100000
        let curves = generateRandomCurves(count: dataCount, selfIntersect: false, reseed: 0)
        self.measure {
            var count = 0
            for curve in curves {
                count += curve.selfIntersections.count
            }
            XCTAssertEqual(count, 0)
        }
    }

    func testCubicSelfIntersectionsPerformanceYesIntersect() {
        // test the performance of `selfIntersections` when the curves self-intersect
        // -Onone 0.048 seconds
        // -Os 0.014 seconds
        let dataCount = 100000
        let curves = generateRandomCurves(count: dataCount, selfIntersect: true, reseed: 1)
        self.measure {
            var count = 0
            for curve in curves {
                count += curve.selfIntersections.count
            }
            XCTAssertEqual(count, dataCount)
        }
    }

    func testCubicIntersectionsPerformance() {
        // test the performance of `intersections(with:,accuracy:)`
        // -Onone 0.57 seconds
        // -Os 0.075 seconds
        let dataCount = 50
        let curves = generateRandomCurves(count: dataCount, reseed: 2)
        self.measure {
            var count = 0
            for curve1 in curves {
                for curve2 in curves {
                    count += curve1.intersections(with: curve2, accuracy: 1.0e-5).count
                }
            }
        }
    }

    func testCubicIntersectionsPerformanceTangentEndpoint() {
        // test the performance of `intersections(with:,accuracy:)`
        // -Onone 0.89 seconds
        // -Os 0.059 seconds
        let dataCount = 250
        let curves = generateRandomCurves(count: dataCount, reseed: 3)
        self.measure {
            var count = 0
            for curve1 in curves {
                // create a curve that starts at the other curve's endpoint
                // and whose first tangent double's back on the curve
                // this is a difficult edge case for divide-and-conquer
                // algorithms
                let curve2 = CubicCurve(p0: curve1.endingPoint,
                                        p1: CGFloat(drand48()) * (curve1.p2 - curve1.p3) + curve1.endingPoint,
                                        p2: CGPoint(x: drand48(), y: drand48()),
                                        p3: CGPoint(x: drand48(), y: drand48()))
                count += curve1.intersections(with: curve2, accuracy: 1.0e-5).count
            }
        }
    }

    func testQuadraticCurveProjectPerformance() {
        let q = QuadraticCurve(p0: CGPoint(x: -1, y: -1),
                               p1: CGPoint(x: 0, y: 2),
                               p2: CGPoint(x: 1, y: -1))
        self.measure {
            // roughly 0.043 -Onone, 0.022 with -Ospeed
            // if comparing with cubic performance, be sure to note `by` parameter in stride
            for theta in stride(from: 0, to: 2*Double.pi, by: 0.0001) {
                _ = q.project(CGPoint(x: cos(theta), y: sin(theta)))
            }
        }
    }

    func testCubicCurveProjectPerformance() {
        let c = CubicCurve(p0: CGPoint(x: -1, y: -1),
                           p1: CGPoint(x: 3, y: 1),
                           p2: CGPoint(x: -3, y: 1),
                           p3: CGPoint(x: 1, y: -1))
        self.measure {
            // roughly 0.029 -Onone, 0.004 with -Ospeed
            for theta in stride(from: 0, to: 2*Double.pi, by: 0.01) {
                _ = c.project(CGPoint(x: cos(theta), y: sin(theta)))
            }
        }
    }

    #if canImport(CoreGraphics)

    func testPathProjectPerformance() {
        let k: CGFloat = 2.0 * CGFloat.pi * 10
        let maxRadius: CGFloat = 100.0
        func theta(_ t: CGFloat) -> CGFloat {
            return k * t
        }
        func r(_ t: CGFloat) -> CGFloat {
            return t * maxRadius
        }
        func drdt(_ t: CGFloat) -> CGFloat {
            return maxRadius
        }
        func dthetadt(_ t: CGFloat) -> CGFloat {
            return k
        }
        let spiral = parametricPath(numCurves: 100, theta: theta, dthetadt: dthetadt, r: r, drdt: drdt)
        // about 0.31s in -Onone, 0.033s in -Ospeed
        self.measure {
            var pointsTested = 0
            var totalDistance: CGFloat = 0.0
            for x in stride(from: -maxRadius, through: maxRadius, by: 10) {
                for y in stride(from: -maxRadius, through: maxRadius, by: 10) {
                   // print("(\(x), \(y))")
                    let point = CGPoint(x: x, y: y)
                    let projection = spiral.project(point)!.point
                    pointsTested += 1
                    totalDistance += distance(projection, point)
                }
            }
            // print("tested \(pointsTested) points, average distance from spiral = \(totalDistance / CGFloat(pointsTested))")
        }
    }

    func testPathSubtractionPerformance() {
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

    // Replication of the original production implementation (before this PR's optimizations).
    private func pathFromCGPathOriginal(_ cgPath: CGPath) -> Path {
        final class Ctx {
            var currentPoint: CGPoint?
            var componentStartPoint: CGPoint?
            var currentComponentPoints: [CGPoint] = []
            var currentComponentOrders: [Int] = []
            var components: [PathComponent] = []
            func completeComponentIfNeededAndClearPointsAndOrders() {
                if currentComponentPoints.isEmpty == false {
                    if currentComponentOrders.isEmpty { currentComponentOrders.append(0) }
                    let pts = currentComponentPoints; let ords = currentComponentOrders
                    components.append(PathComponent(
                        points: pts.capacity  > pts.count  ? Array(pts)  : pts,
                        orders: ords.capacity > ords.count ? Array(ords) : ords))
                }
                currentComponentPoints = []; currentComponentOrders = []
            }
            func appendCurrentPointIfEmpty() {
                if currentComponentPoints.isEmpty { currentComponentPoints = [currentPoint!] }
            }
        }
        let ctx = Ctx()
        func applier(_ raw: UnsafeMutableRawPointer?, _ el: UnsafePointer<CGPathElement>) {
            guard let ctx = raw?.assumingMemoryBound(to: Ctx.self).pointee else { fatalError() }
            let p = el.pointee.points
            switch el.pointee.type {
            case .moveToPoint:
                ctx.completeComponentIfNeededAndClearPointsAndOrders()
                ctx.componentStartPoint = p[0]; ctx.currentComponentPoints = [p[0]]
                ctx.currentComponentOrders = []; ctx.currentPoint = p[0]
            case .addLineToPoint:
                ctx.appendCurrentPointIfEmpty()
                ctx.currentComponentOrders.append(1); ctx.currentComponentPoints.append(p[0])
                ctx.currentPoint = p[0]
            case .addQuadCurveToPoint:
                ctx.appendCurrentPointIfEmpty()
                ctx.currentComponentOrders.append(2)
                ctx.currentComponentPoints.append(p[0]); ctx.currentComponentPoints.append(p[1])
                ctx.currentPoint = p[1]
            case .addCurveToPoint:
                ctx.appendCurrentPointIfEmpty()
                ctx.currentComponentOrders.append(3)
                ctx.currentComponentPoints.append(p[0]); ctx.currentComponentPoints.append(p[1])
                ctx.currentComponentPoints.append(p[2]); ctx.currentPoint = p[2]
            case .closeSubpath:
                if ctx.currentPoint != ctx.componentStartPoint {
                    ctx.currentComponentOrders.append(1)
                    ctx.currentComponentPoints.append(ctx.componentStartPoint!)
                }
                ctx.completeComponentIfNeededAndClearPointsAndOrders()
                ctx.currentPoint = ctx.componentStartPoint
            @unknown default: fatalError()
            }
        }
        withUnsafePointer(to: ctx) {
            cgPath.apply(info: UnsafeMutableRawPointer(mutating: $0), function: applier)
        }
        ctx.completeComponentIfNeededAndClearPointsAndOrders()
        return Path(components: ctx.components)
    }

    private static let emptyCGPath  = CGMutablePath() as CGPath
    private static let smallCGPath: CGPath = {
        let p = CGMutablePath(); p.move(to: .zero)
        for i in 1...4 { let x = CGFloat(i)
            p.addCurve(to: CGPoint(x: x, y: 0), control1: CGPoint(x: x-0.7, y: 1), control2: CGPoint(x: x-0.3, y: -1)) }
        return p
    }()
    private static let largeCGPath: CGPath = {
        let p = CGMutablePath(); p.move(to: .zero)
        for i in 1...1999 { let x = CGFloat(i)
            p.addCurve(to: CGPoint(x: x, y: 0), control1: CGPoint(x: x-0.7, y: 1), control2: CGPoint(x: x-0.3, y: -1)) }
        return p
    }()
    private static let mediumCGPath: CGPath = {
        let p = CGMutablePath(); p.move(to: .zero)
        for i in 1...49 { let x = CGFloat(i)
            p.addCurve(to: CGPoint(x: x, y: 0), control1: CGPoint(x: x-0.7, y: 1), control2: CGPoint(x: x-0.3, y: -1)) }
        return p
    }()

    // MARK: Before
    func testPathFromCGPathLargePerformance_before() {
        let p = Self.largeCGPath
        measure { for _ in 0..<50 { _ = pathFromCGPathOriginal(p) } }
    }
    func testPathFromCGPathEmptyPerformance_before() {
        let p = Self.emptyCGPath
        measure { for _ in 0..<1_000_000 { _ = pathFromCGPathOriginal(p) } }
    }
    func testPathFromCGPathSmallPerformance_before() {
        let p = Self.smallCGPath
        measure { for _ in 0..<100_000 { _ = pathFromCGPathOriginal(p) } }
    }
    func testPathFromCGPathMediumPerformance_before() {
        let p = Self.mediumCGPath
        measure { for _ in 0..<10_000 { _ = pathFromCGPathOriginal(p) } }
    }

    // Struct approach without @inline(__always) — isolates the inlining contribution.
    private func pathFromCGPathStructNoInline(_ cgPath: CGPath) -> Path {
        guard !cgPath.isEmpty else { return Path(components: []) }
        struct Ctx {
            var currentPoint: CGPoint?
            var componentStartPoint: CGPoint?
            var currentComponentPoints: [CGPoint] = []
            var currentComponentOrders: [Int] = []
            var components: [PathComponent] = []
            mutating func completeComponentIfNeededAndClearPointsAndOrders() {
                if currentComponentPoints.isEmpty == false {
                    if currentComponentOrders.isEmpty { currentComponentOrders.append(0) }
                    let pts = currentComponentPoints; let ords = currentComponentOrders
                    components.append(PathComponent(
                        points: pts.capacity  > pts.count  ? Array(pts)  : pts,
                        orders: ords.capacity > ords.count ? Array(ords) : ords))
                }
                currentComponentPoints = []; currentComponentOrders = []
            }
            mutating func appendCurrentPointIfEmpty() {
                if currentComponentPoints.isEmpty { currentComponentPoints = [currentPoint!] }
            }
        }
        var ctx = Ctx()
        func apply(_ raw: UnsafeMutableRawPointer?, _ el: UnsafePointer<CGPathElement>) {
            let c = raw!.assumingMemoryBound(to: Ctx.self)
            let p = el.pointee.points
            switch el.pointee.type {
            case .moveToPoint:
                c.pointee.completeComponentIfNeededAndClearPointsAndOrders()
                c.pointee.componentStartPoint = p[0]; c.pointee.currentComponentPoints = [p[0]]
                c.pointee.currentComponentOrders = []; c.pointee.currentPoint = p[0]
            case .addLineToPoint:
                c.pointee.appendCurrentPointIfEmpty()
                c.pointee.currentComponentOrders.append(1); c.pointee.currentComponentPoints.append(p[0])
                c.pointee.currentPoint = p[0]
            case .addQuadCurveToPoint:
                c.pointee.appendCurrentPointIfEmpty(); c.pointee.currentComponentOrders.append(2)
                c.pointee.currentComponentPoints.append(contentsOf: UnsafeBufferPointer(start: p, count: 2))
                c.pointee.currentPoint = p[1]
            case .addCurveToPoint:
                c.pointee.appendCurrentPointIfEmpty(); c.pointee.currentComponentOrders.append(3)
                c.pointee.currentComponentPoints.append(contentsOf: UnsafeBufferPointer(start: p, count: 3))
                c.pointee.currentPoint = p[2]
            case .closeSubpath:
                if c.pointee.currentPoint != c.pointee.componentStartPoint {
                    c.pointee.currentComponentOrders.append(1)
                    c.pointee.currentComponentPoints.append(c.pointee.componentStartPoint!)
                }
                c.pointee.completeComponentIfNeededAndClearPointsAndOrders()
                c.pointee.currentPoint = c.pointee.componentStartPoint
            @unknown default: fatalError()
            }
        }
        withUnsafeMutablePointer(to: &ctx) { cgPath.apply(info: $0, function: apply) }
        ctx.completeComponentIfNeededAndClearPointsAndOrders()
        return Path(components: ctx.components)
    }

    // MARK: After (struct + @inline(__always))
    func testPathFromCGPathLargePerformance_after() {
        let p = Self.largeCGPath
        measure { for _ in 0..<50 { _ = Path(cgPath: p) } }
    }
    func testPathFromCGPathEmptyPerformance_after() {
        let p = Self.emptyCGPath
        measure { for _ in 0..<1_000_000 { _ = Path(cgPath: p) } }
    }
    func testPathFromCGPathSmallPerformance_after() {
        let p = Self.smallCGPath
        measure { for _ in 0..<100_000 { _ = Path(cgPath: p) } }
    }
    func testPathFromCGPathMediumPerformance_after() {
        let p = Self.mediumCGPath
        measure { for _ in 0..<10_000 { _ = Path(cgPath: p) } }
    }

    // MARK: Struct without @inline(__always)
    func testPathFromCGPathSmallPerformance_structNoInline() {
        let p = Self.smallCGPath
        measure { for _ in 0..<100_000 { _ = pathFromCGPathStructNoInline(p) } }
    }
    func testPathFromCGPathMediumPerformance_structNoInline() {
        let p = Self.mediumCGPath
        measure { for _ in 0..<10_000 { _ = pathFromCGPathStructNoInline(p) } }
    }

    // MARK: Unsafe prepass — two passes: count exact sizes, then fill into raw buffers
    //
    // Pass 1 (counting): no arrays, no function calls, just integer arithmetic on the context.
    //   The callback needs no callee-saved registers → potentially no prologue/epilogue.
    // Pass 2 (fill): direct pointer stores into pre-allocated UnsafeMutablePointer buffers.
    //   Hot path (addCurveToPoint) has zero function calls — no COW, no uniqueness check,
    //   no capacity check. Just stores and arithmetic.
    private func pathFromCGPath_unsafePrepass(_ cgPath: CGPath) -> Path {
        guard !cgPath.isEmpty else { return Path(components: []) }

        // Pass 1: count exact allocation sizes
        struct CountCtx { var ptCount = 0; var ordCount = 0 }
        var counts = CountCtx()
        func countApplier(_ raw: UnsafeMutableRawPointer?, _ el: UnsafePointer<CGPathElement>) {
            let c = raw!.assumingMemoryBound(to: CountCtx.self)
            switch el.pointee.type {
            case .moveToPoint:         c.pointee.ptCount  += 2
            case .addCurveToPoint:     c.pointee.ptCount  += 3; c.pointee.ordCount += 1
            case .addQuadCurveToPoint: c.pointee.ptCount  += 2; c.pointee.ordCount += 1
            case .addLineToPoint:      c.pointee.ptCount  += 1; c.pointee.ordCount += 1
            case .closeSubpath:                                  c.pointee.ordCount += 1
            @unknown default: break
            }
        }
        withUnsafeMutablePointer(to: &counts) {
            cgPath.apply(info: $0, function: countApplier)
        }
        if counts.ordCount == 0 { counts.ordCount = 1 }

        // Allocate exact-size raw buffers — no COW, no capacity tracking needed
        let ptsBuf  = UnsafeMutablePointer<CGPoint>.allocate(capacity: counts.ptCount)
        let ordsBuf = UnsafeMutablePointer<Int>.allocate(capacity: counts.ordCount)
        defer { ptsBuf.deallocate(); ordsBuf.deallocate() }

        // Pass 2: fill — hot path has zero function calls
        struct FillCtx {
            var ptsBuf:  UnsafeMutablePointer<CGPoint>
            var ordsBuf: UnsafeMutablePointer<Int>
            var ptsCount = 0;  var ordsCount = 0
            var startPts = 0;  var startOrds = 0
            var curPt  = CGPoint.zero
            var startPt = CGPoint.zero
            var components: [PathComponent] = []
        }
        var fill = FillCtx(ptsBuf: ptsBuf, ordsBuf: ordsBuf)

        func flush(_ c: UnsafeMutablePointer<FillCtx>) {
            let n = c.pointee.ptsCount - c.pointee.startPts; guard n > 0 else { return }
            var m = c.pointee.ordsCount - c.pointee.startOrds
            if m == 0 { c.pointee.ordsBuf[c.pointee.ordsCount] = 0; c.pointee.ordsCount += 1; m = 1 }
            let pts  = Array(UnsafeBufferPointer(start: c.pointee.ptsBuf  + c.pointee.startPts,  count: n))
            let ords = Array(UnsafeBufferPointer(start: c.pointee.ordsBuf + c.pointee.startOrds, count: m))
            c.pointee.components.append(PathComponent(points: pts, orders: ords))
            c.pointee.startPts = c.pointee.ptsCount; c.pointee.startOrds = c.pointee.ordsCount
        }

        func fillApplier(_ raw: UnsafeMutableRawPointer?, _ el: UnsafePointer<CGPathElement>) {
            let c = raw!.assumingMemoryBound(to: FillCtx.self)
            let p = el.pointee.points
            switch el.pointee.type {
            case .moveToPoint:
                flush(c)
                c.pointee.startPt = p[0]; c.pointee.curPt = p[0]
                c.pointee.ptsBuf[c.pointee.ptsCount] = p[0]; c.pointee.ptsCount += 1
            case .addLineToPoint:
                if c.pointee.ptsCount == c.pointee.startPts {
                    c.pointee.ptsBuf[c.pointee.ptsCount] = c.pointee.curPt; c.pointee.ptsCount += 1
                }
                c.pointee.ordsBuf[c.pointee.ordsCount] = 1; c.pointee.ordsCount += 1
                c.pointee.ptsBuf[c.pointee.ptsCount] = p[0]; c.pointee.ptsCount += 1
                c.pointee.curPt = p[0]
            case .addQuadCurveToPoint:
                if c.pointee.ptsCount == c.pointee.startPts {
                    c.pointee.ptsBuf[c.pointee.ptsCount] = c.pointee.curPt; c.pointee.ptsCount += 1
                }
                c.pointee.ordsBuf[c.pointee.ordsCount] = 2; c.pointee.ordsCount += 1
                c.pointee.ptsBuf[c.pointee.ptsCount]     = p[0]
                c.pointee.ptsBuf[c.pointee.ptsCount + 1] = p[1]; c.pointee.ptsCount += 2
                c.pointee.curPt = p[1]
            case .addCurveToPoint:
                if c.pointee.ptsCount == c.pointee.startPts {
                    c.pointee.ptsBuf[c.pointee.ptsCount] = c.pointee.curPt; c.pointee.ptsCount += 1
                }
                c.pointee.ordsBuf[c.pointee.ordsCount] = 3; c.pointee.ordsCount += 1
                c.pointee.ptsBuf[c.pointee.ptsCount]     = p[0]
                c.pointee.ptsBuf[c.pointee.ptsCount + 1] = p[1]
                c.pointee.ptsBuf[c.pointee.ptsCount + 2] = p[2]; c.pointee.ptsCount += 3
                c.pointee.curPt = p[2]
            case .closeSubpath:
                if c.pointee.curPt != c.pointee.startPt {
                    c.pointee.ordsBuf[c.pointee.ordsCount] = 1; c.pointee.ordsCount += 1
                    c.pointee.ptsBuf[c.pointee.ptsCount] = c.pointee.startPt; c.pointee.ptsCount += 1
                }
                flush(c); c.pointee.curPt = c.pointee.startPt
            @unknown default: break
            }
        }
        withUnsafeMutablePointer(to: &fill) {
            cgPath.apply(info: $0, function: fillApplier)
        }
        flush(&fill)
        return Path(components: fill.components)
    }

    // MARK: Unsafe prepass benchmarks
    func testPathFromCGPathSmallPerformance_unsafePrepass() {
        let p = Self.smallCGPath
        measure { for _ in 0..<100_000 { _ = pathFromCGPath_unsafePrepass(p) } }
    }
    func testPathFromCGPathMediumPerformance_unsafePrepass() {
        let p = Self.mediumCGPath
        measure { for _ in 0..<10_000 { _ = pathFromCGPath_unsafePrepass(p) } }
    }

    #endif
}
#endif
