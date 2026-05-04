//
//  PerformanceTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/3/21.
//  Copyright © 2021 Holmes Futrell. All rights reserved.
//

@testable import BezierKit
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

    func generateRandomQuadraticCurves(count: Int, reseed: Int? = nil) -> [QuadraticCurve] {
        if let reseed = reseed {
            srand48(reseed)
        }
        func randomPoint() -> CGPoint {
            return CGPoint(x: CGFloat(drand48()), y: CGFloat(drand48()))
        }
        return (0..<count).map { _ in
            QuadraticCurve(p0: randomPoint(), p1: randomPoint(), p2: randomPoint())
        }
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
    private static let measureOptions: XCTMeasureOptions = {
        let options = XCTMeasureOptions()
        options.iterationCount = 10
        return options
    }()


    func testCubicSelfIntersectionsPerformanceNoIntersect() {
        // test the performance of `selfIntersections` when the curves DO NOT self-intersect
        // -Onone 0.036 seconds
        // -Os 0.004 seconds
        let dataCount = 100000
        let curves = generateRandomCurves(count: dataCount, selfIntersect: false, reseed: 0)
        self.measure(options: Self.measureOptions) {
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
        self.measure(options: Self.measureOptions) {
            var count = 0
            for curve in curves {
                count += curve.selfIntersections.count
            }
            XCTAssertEqual(count, dataCount)
        }
    }

    func testCubicIntersectionsPerformance() {
        // test the performance of `intersections(with:,accuracy:)`
        let dataCount = 50
        let curves = generateRandomCurves(count: dataCount, reseed: 2)
        self.measure(options: Self.measureOptions) {
            var count = 0
            for _ in 0..<100 {
                for curve1 in curves {
                    for curve2 in curves {
                        count += curve1.intersections(with: curve2, accuracy: 1.0e-5).count
                    }
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
        self.measure(options: Self.measureOptions) {
            var count = 0
            for _ in 0..<10 {
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
    }

    func testQuadraticIntersectionsPerformance() {
        // test the performance of `intersections(with:,accuracy:)` for quadratic-quadratic pairs
        let dataCount = 50
        let curves = generateRandomQuadraticCurves(count: dataCount, reseed: 10)
        self.measure(options: Self.measureOptions) {
            var count = 0
            for _ in 0..<10 {
                for curve1 in curves {
                    for curve2 in curves {
                        count += curve1.intersections(with: curve2, accuracy: 1.0e-5).count
                    }
                }
            }
        }
    }

    func testQuadraticIntersectionsPerformanceTangentEndpoint() {
        let dataCount = 250
        let curves = generateRandomQuadraticCurves(count: dataCount, reseed: 13)
        self.measure(options: Self.measureOptions) {
            var count = 0
            for _ in 0..<10 {
                for curve1 in curves {
                    let curve2 = QuadraticCurve(p0: curve1.endingPoint,
                                                p1: CGFloat(drand48()) * (curve1.p1 - curve1.p2) + curve1.endingPoint,
                                                p2: CGPoint(x: CGFloat(drand48()), y: CGFloat(drand48())))
                    count += curve1.intersections(with: curve2, accuracy: 1.0e-5).count
                }
            }
        }
    }

    func testQuadraticIntersectionsAccuracyTangentEndpoint() {
        let accuracy: CGFloat = 1.0e-5
        let curves = generateRandomQuadraticCurves(count: 250, reseed: 13)
        var maxError: CGFloat = 0; var totalError: CGFloat = 0; var intersectionCount = 0
        for curve1 in curves {
            let curve2 = QuadraticCurve(p0: curve1.endingPoint,
                                        p1: CGFloat(drand48()) * (curve1.p1 - curve1.p2) + curve1.endingPoint,
                                        p2: CGPoint(x: CGFloat(drand48()), y: CGFloat(drand48())))
            for i in curve1.intersections(with: curve2, accuracy: accuracy) {
                let err = distance(curve1.point(at: i.t1), curve2.point(at: i.t2))
                maxError = max(maxError, err); totalError += err; intersectionCount += 1
            }
        }
        let avgError = intersectionCount > 0 ? totalError / CGFloat(intersectionCount) : 0
        print("Quad×Quad tangent EP: \(intersectionCount) intersections, max error = \(maxError), avg error = \(avgError)")
    }

    func testQuadraticCubicIntersectionsPerformance() {
        let dataCount = 50
        let quadratics = generateRandomQuadraticCurves(count: dataCount, reseed: 11)
        let cubics = generateRandomCurves(count: dataCount, reseed: 12)
        self.measure(options: Self.measureOptions) {
            var count = 0
            for _ in 0..<10 {
                for curve1 in quadratics {
                    for curve2 in cubics {
                        count += curve1.intersections(with: curve2, accuracy: 1.0e-5).count
                    }
                }
            }
        }
    }

    func testCubicQuadraticIntersectionsPerformanceTangentEndpoint() {
        let dataCount = 250
        let curves = generateRandomCurves(count: dataCount, reseed: 14)
        self.measure(options: Self.measureOptions) {
            var count = 0
            for _ in 0..<10 {
                for curve1 in curves {
                    let curve2 = QuadraticCurve(p0: curve1.endingPoint,
                                                p1: CGFloat(drand48()) * (curve1.p2 - curve1.p3) + curve1.endingPoint,
                                                p2: CGPoint(x: CGFloat(drand48()), y: CGFloat(drand48())))
                    count += curve1.intersections(with: curve2, accuracy: 1.0e-5).count
                }
            }
        }
    }

    func testCubicQuadraticIntersectionsAccuracyTangentEndpoint() {
        let accuracy: CGFloat = 1.0e-5
        let curves = generateRandomCurves(count: 250, reseed: 14)
        var maxError: CGFloat = 0; var totalError: CGFloat = 0; var intersectionCount = 0
        for curve1 in curves {
            let curve2 = QuadraticCurve(p0: curve1.endingPoint,
                                        p1: CGFloat(drand48()) * (curve1.p2 - curve1.p3) + curve1.endingPoint,
                                        p2: CGPoint(x: CGFloat(drand48()), y: CGFloat(drand48())))
            for i in curve1.intersections(with: curve2, accuracy: accuracy) {
                let err = distance(curve1.point(at: i.t1), curve2.point(at: i.t2))
                maxError = max(maxError, err); totalError += err; intersectionCount += 1
            }
        }
        let avgError = intersectionCount > 0 ? totalError / CGFloat(intersectionCount) : 0
        print("Cubic×Quad tangent EP: \(intersectionCount) intersections, max error = \(maxError), avg error = \(avgError)")
    }

    func testQuadraticIntersectionsAccuracy() {
        let accuracy: CGFloat = 1.0e-5
        let curves = generateRandomQuadraticCurves(count: 50, reseed: 10)
        var maxError: CGFloat = 0; var totalError: CGFloat = 0; var intersectionCount = 0
        for curve1 in curves {
            for curve2 in curves {
                for i in curve1.intersections(with: curve2, accuracy: accuracy) {
                    let err = distance(curve1.point(at: i.t1), curve2.point(at: i.t2))
                    maxError = max(maxError, err); totalError += err; intersectionCount += 1
                }
            }
        }
        let avgError = intersectionCount > 0 ? totalError / CGFloat(intersectionCount) : 0
        print("Quad×Quad: \(intersectionCount) intersections, max error = \(maxError), avg error = \(avgError)")
    }

    func testQuadraticCubicIntersectionsAccuracy() {
        let accuracy: CGFloat = 1.0e-5
        let quadratics = generateRandomQuadraticCurves(count: 50, reseed: 11)
        let cubics = generateRandomCurves(count: 50, reseed: 12)
        var maxError: CGFloat = 0; var totalError: CGFloat = 0; var intersectionCount = 0
        for curve1 in quadratics {
            for curve2 in cubics {
                for i in curve1.intersections(with: curve2, accuracy: accuracy) {
                    let err = distance(curve1.point(at: i.t1), curve2.point(at: i.t2))
                    maxError = max(maxError, err); totalError += err; intersectionCount += 1
                }
            }
        }
        let avgError = intersectionCount > 0 ? totalError / CGFloat(intersectionCount) : 0
        print("Quad×Cubic: \(intersectionCount) intersections, max error = \(maxError), avg error = \(avgError)")
    }

    func testCubicIntersectionsAccuracy() {
        let accuracy: CGFloat = 1.0e-5
        let curves = generateRandomCurves(count: 50, reseed: 2)
        var maxError: CGFloat = 0; var totalError: CGFloat = 0; var intersectionCount = 0
        for curve1 in curves {
            for curve2 in curves {
                for i in curve1.intersections(with: curve2, accuracy: accuracy) {
                    let err = distance(curve1.point(at: i.t1), curve2.point(at: i.t2))
                    maxError = max(maxError, err); totalError += err; intersectionCount += 1
                }
            }
        }
        let avgError = intersectionCount > 0 ? totalError / CGFloat(intersectionCount) : 0
        print("Cubic×Cubic: \(intersectionCount) intersections, max error = \(maxError), avg error = \(avgError)")
    }

    func testQuadraticCurveProjectPerformance() {
        let q = QuadraticCurve(p0: CGPoint(x: -1, y: -1),
                               p1: CGPoint(x: 0, y: 2),
                               p2: CGPoint(x: 1, y: -1))
        self.measure(options: Self.measureOptions) {
            // roughly 0.043 -Onone, 0.022 with -Ospeed
            // if comparing with cubic performance, be sure to note `by` parameter in stride
            for theta in stride(from: 0, to: 2*Double.pi, by: 0.0001) {
                _ = q.project(CGPoint(x: cos(theta), y: sin(theta)))
            }
        }
    }

    func testQuadraticCurveSplitFromToPerformance() {
        let dataCount = 10000000
        let curves = generateRandomQuadraticCurves(count: dataCount, reseed: 5)
        srand48(5)
        let params: [(CGFloat, CGFloat)] = (0..<dataCount).map { _ in
            let a = CGFloat(drand48()), b = CGFloat(drand48())
            return a < b ? (a, b) : (b, a)
        }
        self.measure(options: Self.measureOptions) {
            var sink = CGPoint.zero
            for i in 0..<dataCount {
                let s = curves[i].split(from: params[i].0, to: params[i].1)
                sink.x += s.p0.x
            }
            XCTAssertNotEqual(sink, CGPoint.zero)
        }
    }

    func testCubicCurveSplitFromToPerformance() {
        let dataCount = 10000000
        let curves = generateRandomCurves(count: dataCount, reseed: 4)
        srand48(4)
        let params: [(CGFloat, CGFloat)] = (0..<dataCount).map { _ in
            let a = CGFloat(drand48())
            let b = CGFloat(drand48())
            return a < b ? (a, b) : (b, a)
        }
        self.measure(options: Self.measureOptions) {
            var sink = CGPoint.zero
            for i in 0..<dataCount {
                let s = curves[i].split(from: params[i].0, to: params[i].1)
                sink.x += s.p0.x
            }
            XCTAssertNotEqual(sink, CGPoint.zero)
        }
    }

    func testCubicCurveProjectPerformance() {
        let c = CubicCurve(p0: CGPoint(x: -1, y: -1),
                           p1: CGPoint(x: 3, y: 1),
                           p2: CGPoint(x: -3, y: 1),
                           p3: CGPoint(x: 1, y: -1))
        self.measure(options: Self.measureOptions) {
            // roughly 0.029 -Onone, 0.004 with -Ospeed
            for theta in stride(from: 0, to: 2*Double.pi, by: 0.0001) {
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
        self.measure(options: Self.measureOptions) {
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
        self.measure(options: Self.measureOptions) { // roughly 0.018s in debug mode
            _ = path1.subtract(path2, accuracy: 1.0e-3)
        }
    }

    #endif

}
#endif
