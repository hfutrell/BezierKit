//
//  BezierKitTests.swift
//  BezierKitTests
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class BezierKitTestHelpers {

    static internal func intersections(_ intersections: [Intersection], betweenCurve c1: BezierCurve, andOtherCurve c2: BezierCurve, areWithinTolerance epsilon: CGFloat) -> Bool {
        for i in intersections {
            let p1 = c1.point(at: i.t1)
            let p2 = c2.point(at: i.t2)
            if (p1 - p2).length > epsilon {
                return false
            }
        }
        return true
    }

    static internal func curveControlPointsEqual(curve1 c1: BezierCurve, curve2 c2: BezierCurve, tolerance epsilon: CGFloat) -> Bool {
        if c1.order != c2.order {
            return false
        }
        guard zip(c1.points, c2.points).allSatisfy({ distance($0, $1) <= epsilon }) else {
            return false
        }
        return true
    }

    static internal func shape(_ s: Shape, matchesShape other: Shape, tolerance: CGFloat = 1.0e-6) -> Bool {
        guard BezierKitTestHelpers.curve(s.forward, matchesCurve: other.forward, tolerance: tolerance) else {
            return false
        }
        guard BezierKitTestHelpers.curve(s.back, matchesCurve: other.back, tolerance: tolerance) else {
            return false
        }
        guard BezierKitTestHelpers.curve(s.startcap.curve, matchesCurve: other.startcap.curve, tolerance: tolerance) else {
            return false
        }
        guard BezierKitTestHelpers.curve(s.endcap.curve, matchesCurve: other.endcap.curve, tolerance: tolerance) else {
            return false
        }
        guard s.startcap.virtual == other.startcap.virtual else {
            return false
        }
        guard s.endcap.virtual == other.endcap.virtual else {
            return false
        }
        return true
    }

    static internal func curve(_ c1: BezierCurve, matchesCurve c2: BezierCurve, overInterval interval: Interval = Interval(start: 0.0, end: 1.0), tolerance: CGFloat = 1.0e-5) -> Bool {
        // checks if c1 over [0, 1] matches c2 over [interval.start, interval.end]
        // useful for checking if splitting a curve over a given interval worked correctly
        let numPointsToCheck = 10
        for i in 0..<numPointsToCheck {
            let t1 = CGFloat(i) / CGFloat(numPointsToCheck-1)
            let t2 = interval.start * (1.0 - t1) + interval.end * t1
            if distance(c1.point(at: t1), c2.point(at: t2)) > tolerance {
                return false
            }
        }
        return true
    }

    private static func evaluatePolynomial(_ p: [CGFloat], at t: CGFloat) -> CGFloat {
        var sum: CGFloat = 0.0
        for n in 0..<p.count {
            sum += p[p.count - n - 1] * pow(t, CGFloat(n))
        }
        return sum
    }

    static func cubicCurveFromPolynomials(_ f: [CGFloat], _ g: [CGFloat]) -> CubicCurve {
        precondition(f.count == 4 && g.count == 4)
        // create a cubic bezier curve from two polynomials
        // the first polynomial f[0] t^3 + f[1] t^2 + f[2] t + f[3] defines x(t) for the Bezier curve
        // the second polynomial g[0] t^3 + g[1] t^2 + g[2] t + g[3] defines y(t) for the Bezier curve
        let p = CGPoint(x: f[0], y: g[0])
        let q = CGPoint(x: f[1], y: g[1])
        let r = CGPoint(x: f[2], y: g[2])
        let s = CGPoint(x: f[3], y: g[3])
        let a = s
        let b = r / 3.0 + a
        let c = q / 3.0 + 2.0 * b - a
        let d = p + a - 3.0 * b + 3.0 * c
        // check that it worked
        let curve = CubicCurve(p0: a, p1: b, p2: c, p3: d)
        for t: CGFloat in stride(from: 0, through: 1, by: 0.1) {
            assert(distance(curve.point(at: t), CGPoint(x: evaluatePolynomial(f, at: t), y: evaluatePolynomial(g, at: t))) < 0.001, "internal error! failed to fit polynomial!")
        }
        return curve
    }

    static func isSatisfactoryReduceResult<A>(_ result: [Subcurve<A>], for curve: A) -> Bool {
        // ensure full curve represented
        guard result.count > 0 else { return false }
        guard result.first!.t1 == 0 else { return false }
        guard result.last!.t2 == 1 else { return false }
        // ensure contiguous ranges
        for i in 0..<result.count-1 {
            guard result[i].t2 == result[i+1].t1 else { return false }
        }
        // ensure that it conains the extrema
        let extrema = curve.extrema().all
        for e in extrema {
            let extremaExistsInSolution = result.contains { subcurve in
                abs(subcurve.t1 - e) <= reduceStepSize || abs(subcurve.t2 - e) <= reduceStepSize
            }
            guard extremaExistsInSolution else { return false }
        }
        // ensure that each subcurve is simple
        guard result.allSatisfy({ $0.curve.simple }) else { return false }
        // ensure that we haven't divided things into too many curves
        for subcurve in result {
            let t = subcurve.t2
            let isNearExtrema = extrema.contains { abs($0 - t) <= BezierKit.reduceStepSize  }
            if !isNearExtrema && t != 1.0 {
                if curve.split(from: subcurve.t1, to: Utils.clamp(t+BezierKit.reduceStepSize, 0, 1)).simple {
                    return false // we could have expanded subcurve and still had a simple result
                }
            }
        }
        return true
    }

//    static func quadraticCurveFromPolynomials(_ f: [CGFloat], _ g: [CGFloat]) -> QuadraticCurve {
//        precondition(f.count == 3 && g.count == 3)
//        // create a quadratic bezier curve from two polynomials
//        // the first polynomial f[0] t^2 + f[1] t + f[2] defines x(t) for the Bezier curve
//        // the second polynomial g[0] t^2 + g[1] t + g[2] defines y(t) for the Bezier curve
//        let q = CGPoint(x: f[0], y: g[0])
//        let r = CGPoint(x: f[1], y: g[1])
//        let s = CGPoint(x: f[2], y: g[2])
//        let a = s
//        let b = r / 3.0 + a
//        let c = q / 3.0 + 2.0 * b - a
//        // check that it worked
//        let curve = QuadraticCurve(p0: a, p1: b, p2: c)
//        for t: CGFloat in stride(from: 0, through: 1, by: 0.1) {
//            assert(distance(curve.compute(t), CGPoint(x: evaluatePolynomial(f, at: t), y: evaluatePolynomial(g, at: t))) < 0.001, "internal error! failed to fit polynomial!")
//        }
//        return curve
//    }

}
