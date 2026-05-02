//
//  RootFinding.swift
//  GraphicsPathNearest
//
//  Created by Holmes Futrell on 2/23/21.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

// Internal protocol for the bezier clipping algorithm.
// `forEachCoefficient` lets the sign-change and convex hull loops iterate without
// a branch-cascaded switch per step; `coefficient(at:)` is kept for skipped-root checks.
protocol BezierClippingPolynomial: ClippableBernsteinPolynomial {
    var degree: Int { get }
    func coefficient(at i: Int) -> CGFloat
    func forEachCoefficient(_ body: (CGFloat) -> Void)
}

extension BernsteinPolynomial0: BezierClippingPolynomial {
    var degree: Int { 0 }
    func coefficient(at i: Int) -> CGFloat { b0 }
    func forEachCoefficient(_ body: (CGFloat) -> Void) { body(b0) }
}

extension BernsteinPolynomial1: BezierClippingPolynomial {
    var degree: Int { 1 }
    func coefficient(at i: Int) -> CGFloat { i == 0 ? b0 : b1 }
    func forEachCoefficient(_ body: (CGFloat) -> Void) { body(b0); body(b1) }
}

extension BernsteinPolynomial2: BezierClippingPolynomial {
    var degree: Int { 2 }
    func coefficient(at i: Int) -> CGFloat {
        switch i { case 0: return b0; case 1: return b1; default: return b2 }
    }
    func forEachCoefficient(_ body: (CGFloat) -> Void) { body(b0); body(b1); body(b2) }
}

extension BernsteinPolynomial3: BezierClippingPolynomial {
    var degree: Int { 3 }
    func coefficient(at i: Int) -> CGFloat {
        switch i { case 0: return b0; case 1: return b1; case 2: return b2; default: return b3 }
    }
    func forEachCoefficient(_ body: (CGFloat) -> Void) { body(b0); body(b1); body(b2); body(b3) }
}

extension BernsteinPolynomial4: BezierClippingPolynomial {
    var degree: Int { 4 }
    func coefficient(at i: Int) -> CGFloat {
        switch i { case 0: return b0; case 1: return b1; case 2: return b2; case 3: return b3; default: return b4 }
    }
    func forEachCoefficient(_ body: (CGFloat) -> Void) { body(b0); body(b1); body(b2); body(b3); body(b4) }
}

extension BernsteinPolynomial5: BezierClippingPolynomial {
    var degree: Int { 5 }
    func coefficient(at i: Int) -> CGFloat {
        switch i { case 0: return b0; case 1: return b1; case 2: return b2; case 3: return b3; case 4: return b4; default: return b5 }
    }
    func forEachCoefficient(_ body: (CGFloat) -> Void) { body(b0); body(b1); body(b2); body(b3); body(b4); body(b5) }
}

// Bezier clipping convergence threshold (Sederberg & Nishita 1990).
// The convex hull property guarantees at least 50% reduction per step in the single-root case,
// giving quadratic convergence; we stop once the mapped interval is below this tolerance.
private let clippingErrorThreshold: CGFloat = 1e-5

private func rootsCore<P: BezierClippingPolynomial>(
    polynomial: P,
    start rangeStart: CGFloat,
    end rangeEnd: CGFloat,
    depth: Int,
    callback: (CGFloat) -> Void
) {
    guard depth < 48 else { return }
    let n = polynomial.degree
    let count = n + 1

    var coeffScale = 0.0
    polynomial.forEachCoefficient { coeffScale = Swift.max(coeffScale, Swift.abs(Double($0))) }
    let signThreshold = coeffScale * 1e-10
    var lastSign = 0
    var signChanges = 0
    polynomial.forEachCoefficient { coeff in
        let c = Double(coeff)
        guard Swift.abs(c) > signThreshold else { return }
        let s = c > 0 ? 1 : -1
        if lastSign != 0, s != lastSign { signChanges += 1 }
        lastSign = s
    }
    let c0 = polynomial.coefficient(at: 0)
    let cN = polynomial.coefficient(at: n)
    guard signChanges > 0 || c0 == 0 || cN == 0 else { return }

    if signChanges == 1 {
        if c0 * cN < 0 {
            let scale = Swift.max(Swift.abs(c0), Swift.abs(cN))
            let residualThreshold = scale * CGFloat.ulpOfOne.squareRoot()
            // Convert Bernstein coefficients to power basis once via iterated forward
            // differences (c_k = C(n,k) · Δ^k b[0]), then use Horner's method for all
            // Newton and bisection evaluations — O(n) per call vs O(n²) de Casteljau.
            var result = CGFloat(0)
            withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: count) { buf in
                var idx = 0
                polynomial.forEachCoefficient { buf[idx] = $0; idx += 1 }
                for k in 1..<count {
                    for i in stride(from: n, through: k, by: -1) { buf[i] -= buf[i - 1] }
                }
                for k in 0...n { buf[k] *= Utils.binomialCoefficient(n, choose: k) }

                func hValue(_ t: CGFloat) -> CGFloat {
                    var v = buf[n]
                    for k in stride(from: n - 1, through: 0, by: -1) { v = v * t + buf[k] }
                    return v
                }
                func hValueAndDerivative(_ t: CGFloat) -> (CGFloat, CGFloat) {
                    var v = buf[n], d = CGFloat(0)
                    for k in stride(from: n - 1, through: 0, by: -1) { d = d * t + v; v = v * t + buf[k] }
                    return (v, d)
                }

                var x = CGFloat(0.5)
                var newtonSucceeded = false
                for _ in 0..<20 {
                    let (f, fPrime) = hValueAndDerivative(x)
                    if f == 0 { newtonSucceeded = true; break }
                    guard fPrime != 0 else { break }
                    let delta = f / fPrime
                    x -= delta
                    if Swift.abs(delta) <= 1e-10 {
                        x = Swift.max(0, Swift.min(1, x))
                        newtonSucceeded = Swift.abs(hValue(x)) <= residualThreshold
                        break
                    }
                }
                x = Swift.max(0, Swift.min(1, x))
                if newtonSucceeded { result = x; return }

                var lo = CGFloat(0), hi = CGFloat(1), fL = c0, fH = cN
                for _ in 0..<52 {
                    let mid = CGFloat(0.5) * (lo + hi)
                    guard mid > lo else { break }
                    let fMid = hValue(mid)
                    if fMid == 0 { lo = mid; hi = mid; break }
                    if (fL > 0) == (fMid > 0) { lo = mid; fL = fMid } else { hi = mid; fH = fMid }
                }
                _ = fH
                result = 0.5 * (lo + hi)
            }
            callback(Utils.linearInterpolate(rangeStart, rangeEnd, result))
            return
        }
    }

    var lowerBound = CGFloat.infinity
    var upperBound = -CGFloat.infinity
    withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: count) { buf in
        var idx = 0
        polynomial.forEachCoefficient { buf[idx] = $0; idx += 1 }
        let nF = CGFloat(n)
        for i in 0..<n {
            let p1x = CGFloat(i) / nF
            let p1y = buf[i]
            for j in (i + 1)...n {
                let p2x = CGFloat(j) / nF
                let p2y = buf[j]
                guard p1y != 0 || p2y != 0 else {
                    if p1x < lowerBound { lowerBound = p1x }
                    if p2x > upperBound { upperBound = p2x }
                    continue
                }
                let tLine = -p1y / (p2y - p1y)
                if tLine >= 0, tLine <= 1 {
                    let tIntersect = Utils.linearInterpolate(p1x, p2x, tLine)
                    if tIntersect < lowerBound { lowerBound = tIntersect }
                    if tIntersect > upperBound { upperBound = tIntersect }
                }
            }
        }
    }
    guard lowerBound.isFinite, upperBound.isFinite else { return }
    let nextRangeStart = Utils.linearInterpolate(rangeStart, rangeEnd, lowerBound)
    let nextRangeEnd = Utils.linearInterpolate(rangeStart, rangeEnd, upperBound)
    guard nextRangeEnd - nextRangeStart > clippingErrorThreshold else {
        callback(Utils.linearInterpolate(nextRangeStart, nextRangeEnd, 0.5))
        return
    }
    guard upperBound - lowerBound < 0.8 else {
        let rangeMid = Utils.linearInterpolate(rangeStart, rangeEnd, 0.5)
        let (left, right) = polynomial.split(at: 0.5)
        rootsCore(polynomial: left, start: rangeStart, end: rangeMid, depth: depth + 1, callback: callback)
        rootsCore(polynomial: right, start: rangeMid, end: rangeEnd, depth: depth + 1, callback: callback)
        return
    }
    let subcurve = polynomial.split(from: lowerBound, to: upperBound)
    let skippedRoot = { (a: CGFloat, b: CGFloat) in a > 0 && b < 0 || a < 0 && b > 0 }
    if skippedRoot(c0, subcurve.coefficient(at: 0)) { callback(nextRangeStart) }
    rootsCore(polynomial: subcurve, start: nextRangeStart, end: nextRangeEnd, depth: depth + 1, callback: callback)
    if skippedRoot(subcurve.coefficient(at: n), cN) { callback(nextRangeEnd) }
}

/// Calls `callback` for each distinct root in `[0, 1]` using the Bezier clipping algorithm
/// (Sederberg & Nishita 1990). Roots are emitted in ascending order with duplicates suppressed.
func findDistinctRootsCallbackBezierClipping<P: BezierClippingPolynomial>(
    _ polynomial: P,
    _ callback: (CGFloat) -> Void
) {
    let n = polynomial.degree
    guard (0...n).contains(where: { polynomial.coefficient(at: $0) != .zero }) else { return }
    var lastRoot = CGFloat.infinity
    rootsCore(polynomial: polynomial, start: 0, end: 1, depth: 0) {
        guard $0 != lastRoot else { return }
        lastRoot = $0
        callback($0)
    }
}

func findDistinctRootsInUnitIntervalBezierClipping<P: BezierClippingPolynomial>(of polynomial: P) -> [CGFloat] {
    var result: [CGFloat] = []
    findDistinctRootsCallbackBezierClipping(polynomial) { result.append($0) }
    return result
}
