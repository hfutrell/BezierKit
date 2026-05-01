//
//  ProjectionAccuracyTests.swift
//  BezierKit
//

import XCTest
@testable import BezierKit

// Seeded PRNG (xorshift64) for reproducible random curve generation.
private struct RNG {
    var state: UInt64
    mutating func next() -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Double(state >> 11) / Double(1 << 53)
    }
    mutating func point(in lo: Double = -1, _ hi: Double = 1) -> CGPoint {
        CGPoint(x: lo + next() * (hi - lo), y: lo + next() * (hi - lo))
    }
}

// Ground-truth closest-point via dense sampling (10 000 steps).
private func bruteForceProject(_ curve: CubicCurve, _ p: CGPoint) -> (point: CGPoint, t: CGFloat) {
    let steps = 10_000
    var bestT: CGFloat = 0
    var bestD = CGFloat.infinity
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps)
        let d = distance(curve.point(at: t), p)
        if d < bestD { bestD = d; bestT = t }
    }
    return (curve.point(at: bestT), bestT)
}

private func bruteForceProject(_ curve: QuadraticCurve, _ p: CGPoint) -> (point: CGPoint, t: CGFloat) {
    let steps = 10_000
    var bestT: CGFloat = 0
    var bestD = CGFloat.infinity
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps)
        let d = distance(curve.point(at: t), p)
        if d < bestD { bestD = d; bestT = t }
    }
    return (curve.point(at: bestT), bestT)
}

class ProjectionAccuracyTests: XCTestCase {

    func testCubicProjectionAccuracy() {
        var rng = RNG(state: 0xdeadbeef_cafebabe)
        let nCurves = 200
        let nPointsPerCurve = 20

        var perpResiduals: [Double] = []
        var distanceErrors: [Double] = []  // vs brute-force reference

        for _ in 0..<nCurves {
            let curve = CubicCurve(p0: rng.point(), p1: rng.point(), p2: rng.point(), p3: rng.point())
            for _ in 0..<nPointsPerCurve {
                let p = rng.point(in: -1.5, 1.5)
                let result = curve.project(p)
                let t = result.t

                // Perpendicularity residual only for interior projections where
                // p is not too close to the curve (avoids ill-conditioned normalization).
                if t > 1e-6 && t < 1 - 1e-6 {
                    let ct = curve.point(at: t)
                    let dist = Double(distance(ct, p))
                    if dist > 1e-3 {
                        let dt = curve.derivative(at: t)
                        let diff = ct - p
                        let perp = abs(Double(diff.x * dt.x + diff.y * dt.y))
                        let scale = Double(dt.length) * dist
                        perpResiduals.append(perp / scale)
                    }
                }

                // Distance error vs brute force
                let bf = bruteForceProject(curve, p)
                let dResult = Double(distance(result.point, p))
                let dBrute  = Double(distance(bf.point, p))
                distanceErrors.append(dResult - dBrute)
            }
        }

        let maxPerp = perpResiduals.max()!
        let meanPerp = perpResiduals.reduce(0, +) / Double(perpResiduals.count)
        let maxDistErr = distanceErrors.max()!
        let meanDistErr = distanceErrors.reduce(0, +) / Double(distanceErrors.count)

        // Track absolute perp too (not normalized — avoids blowup on near-degenerate curves)
        var rng2 = RNG(state: 0xdeadbeef_cafebabe)
        var absPerps: [Double] = []
        for _ in 0..<nCurves {
            let curve = CubicCurve(p0: rng2.point(), p1: rng2.point(), p2: rng2.point(), p3: rng2.point())
            for _ in 0..<nPointsPerCurve {
                let p = rng2.point(in: -1.5, 1.5)
                let result = curve.project(p)
                let t = result.t
                if t > 1e-6 && t < 1 - 1e-6 {
                    let ct = curve.point(at: t)
                    let dt = curve.derivative(at: t)
                    let diff = ct - p
                    let perp = abs(Double(diff.x * dt.x + diff.y * dt.y))
                    absPerps.append(perp)
                }
            }
        }
        let maxAbsPerp = absPerps.max()!
        let meanAbsPerp = absPerps.reduce(0, +) / Double(absPerps.count)

        print("=== Cubic projection accuracy (\(nCurves * nPointsPerCurve) samples) ===")
        print(String(format: "Perp residual   max=%.2e  mean=%.2e  (normalized)", maxPerp, meanPerp))
        print(String(format: "Perp absolute   max=%.2e  mean=%.2e  (dot product)", maxAbsPerp, meanAbsPerp))
        print(String(format: "Distance error  max=%.2e  mean=%.2e  (vs brute-force 10k sample)", maxDistErr, meanDistErr))

        // Fail if significantly worse than brute-force (distance error > 0.01 in curve-unit coords)
        XCTAssertLessThan(maxDistErr, 0.01, "Cubic projection distance worse than brute-force by > 0.01")
    }

    func testQuadraticProjectionAccuracy() {
        var rng = RNG(state: 0xfeedface_deadc0de)
        let nCurves = 200
        let nPointsPerCurve = 20

        var perpResiduals: [Double] = []
        var distanceErrors: [Double] = []

        for _ in 0..<nCurves {
            let curve = QuadraticCurve(p0: rng.point(), p1: rng.point(), p2: rng.point())
            for _ in 0..<nPointsPerCurve {
                let p = rng.point(in: -1.5, 1.5)
                let result = curve.project(p)
                let t = result.t

                if t > 1e-6 && t < 1 - 1e-6 {
                    let ct = curve.point(at: t)
                    let dist = Double(distance(ct, p))
                    if dist > 1e-3 {
                        let dt = curve.derivative(at: t)
                        let diff = ct - p
                        let perp = abs(Double(diff.x * dt.x + diff.y * dt.y))
                        let scale = Double(dt.length) * dist
                        perpResiduals.append(perp / scale)
                    }
                }

                let bf = bruteForceProject(curve, p)
                let dResult = Double(distance(result.point, p))
                let dBrute  = Double(distance(bf.point, p))
                distanceErrors.append(dResult - dBrute)
            }
        }

        let maxPerp = perpResiduals.max()!
        let meanPerp = perpResiduals.reduce(0, +) / Double(perpResiduals.count)
        let maxDistErr = distanceErrors.max()!
        let meanDistErr = distanceErrors.reduce(0, +) / Double(distanceErrors.count)

        print("=== Quadratic projection accuracy (\(nCurves * nPointsPerCurve) samples) ===")
        print(String(format: "Perp residual   max=%.2e  mean=%.2e", maxPerp, meanPerp))
        print(String(format: "Distance error  max=%.2e  mean=%.2e  (vs brute-force 10k sample)", maxDistErr, meanDistErr))

        XCTAssertLessThan(maxDistErr, 0.01, "Quadratic projection distance worse than brute-force by > 0.01")
    }
}
