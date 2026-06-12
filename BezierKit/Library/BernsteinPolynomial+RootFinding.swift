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
// a branch-cascaded switch per step; `firstCoefficient`/`lastCoefficient` are used
// for endpoint sign checks.
protocol BezierClippingPolynomial: ClippableBernsteinPolynomial {
    var degree: Int { get }
    var firstCoefficient: CGFloat { get }
    var lastCoefficient: CGFloat { get }
    func forEachCoefficient(_ body: (CGFloat) -> Void)
}

extension BernsteinPolynomial0: BezierClippingPolynomial {
    var degree: Int { 0 }
    var firstCoefficient: CGFloat { b0 }
    var lastCoefficient: CGFloat { b0 }
    func forEachCoefficient(_ body: (CGFloat) -> Void) { body(b0) }
}

extension BernsteinPolynomial1: BezierClippingPolynomial {
    var degree: Int { 1 }
    var firstCoefficient: CGFloat { b0 }
    var lastCoefficient: CGFloat { b1 }
    func forEachCoefficient(_ body: (CGFloat) -> Void) { body(b0); body(b1) }
}

extension BernsteinPolynomial2: BezierClippingPolynomial {
    var degree: Int { 2 }
    var firstCoefficient: CGFloat { b0 }
    var lastCoefficient: CGFloat { b2 }
    func forEachCoefficient(_ body: (CGFloat) -> Void) { body(b0); body(b1); body(b2) }
}

extension BernsteinPolynomial3: BezierClippingPolynomial {
    var degree: Int { 3 }
    var firstCoefficient: CGFloat { b0 }
    var lastCoefficient: CGFloat { b3 }
    func forEachCoefficient(_ body: (CGFloat) -> Void) { body(b0); body(b1); body(b2); body(b3) }
}

extension BernsteinPolynomial4: BezierClippingPolynomial {
    var degree: Int { 4 }
    var firstCoefficient: CGFloat { b0 }
    var lastCoefficient: CGFloat { b4 }
    func forEachCoefficient(_ body: (CGFloat) -> Void) { body(b0); body(b1); body(b2); body(b3); body(b4) }
}

extension BernsteinPolynomial5: BezierClippingPolynomial {
    var degree: Int { 5 }
    var firstCoefficient: CGFloat { b0 }
    var lastCoefficient: CGFloat { b5 }
    func forEachCoefficient(_ body: (CGFloat) -> Void) { body(b0); body(b1); body(b2); body(b3); body(b4); body(b5) }
}

extension BernsteinPolynomial6: BezierClippingPolynomial {
    var degree: Int { 6 }
    var firstCoefficient: CGFloat { b0 }
    var lastCoefficient: CGFloat { b6 }
    func forEachCoefficient(_ body: (CGFloat) -> Void) { body(b0); body(b1); body(b2); body(b3); body(b4); body(b5); body(b6) }
}

extension BernsteinPolynomial7: BezierClippingPolynomial {
    var degree: Int { 7 }
    var firstCoefficient: CGFloat { b0 }
    var lastCoefficient: CGFloat { b7 }
    func forEachCoefficient(_ body: (CGFloat) -> Void) { body(b0); body(b1); body(b2); body(b3); body(b4); body(b5); body(b6); body(b7) }
}

extension BernsteinPolynomial8: BezierClippingPolynomial {
    var degree: Int { 8 }
    var firstCoefficient: CGFloat { b0 }
    var lastCoefficient: CGFloat { b8 }
    func forEachCoefficient(_ body: (CGFloat) -> Void) {
        body(b0); body(b1); body(b2); body(b3); body(b4); body(b5); body(b6); body(b7); body(b8)
    }
}

extension BernsteinPolynomial9: BezierClippingPolynomial {
    var degree: Int { 9 }
    var firstCoefficient: CGFloat { b0 }
    var lastCoefficient: CGFloat { b9 }
    func forEachCoefficient(_ body: (CGFloat) -> Void) {
        body(b0); body(b1); body(b2); body(b3); body(b4); body(b5); body(b6); body(b7); body(b8); body(b9)
    }
}

// Bezier clipping convergence threshold (Sederberg & Nishita 1990).
// The convex hull property guarantees at least 50% reduction per step in the single-root case,
// giving quadratic convergence; we stop once the mapped interval is below this tolerance.
private let clippingErrorThreshold: CGFloat = 1e-5

// Finds the unique root in [0,1] of a polynomial bracketed by c0 * lastCoefficient < 0.
// Fast path: Horner Newton-bisection (O(n) per eval). Validates via one de Casteljau evaluation
// (reusing the power-basis scratch area); falls back to de Casteljau Newton-bisection when the
// power-basis conversion has catastrophic cancellation from deep bezier-clipping subdivision.
private func refineBracketedRoot<P: BezierClippingPolynomial>(
    polynomial: P,
    n: Int,
    c0: CGFloat
) -> CGFloat {
    let count = n + 1
    let nF = CGFloat(n)
    var result = CGFloat(0)
    // buf[0..<count]: Bernstein coefficients (preserved for de Casteljau fallback)
    // buf[count..<2*count]: power-basis during Horner Newton, then reused as de Casteljau scratch
    withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 2 * count) { buf in
        var idx = 0
        polynomial.forEachCoefficient { buf[idx] = $0; idx += 1 }
        // Convert Bernstein → power basis in buf[count..] via forward differences + binomial scaling.
        for k in 0..<count { buf[count + k] = buf[k] }
        for k in 1..<count {
            for i in stride(from: n, through: k, by: -1) { buf[count + i] -= buf[count + i - 1] }
        }
        var binom: CGFloat = 1.0
        for k in 0...n {
            buf[count + k] *= binom
            if k < n { binom = binom * CGFloat(n - k) / CGFloat(k + 1) }
        }
        // Horner simultaneous value + derivative (synthetic-division identity).
        func hValueAndDerivative(_ t: CGFloat) -> (CGFloat, CGFloat) {
            var v = buf[count + n], d = CGFloat(0)
            for k in stride(from: n - 1, through: 0, by: -1) { d = d * t + v; v = v * t + buf[count + k] }
            return (v, d)
        }
        // Bracket-enforcing Newton-bisection; prevents stuck-at-boundary failure when Newton
        // overshoots and plain clamping keeps it at the edge indefinitely.
        var lo = CGFloat(0), hi = CGFloat(1), fLo = c0
        var x = CGFloat(0.5)
        for _ in 0..<52 {
            let (f, fPrime) = hValueAndDerivative(x)
            if f == 0 { lo = x; hi = x; break }
            if (fLo > 0) == (f > 0) { lo = x; fLo = f } else { hi = x }
            guard fPrime != 0 else { break }
            let newton = x - f / fPrime
            x = (newton > lo && newton < hi) ? newton : 0.5 * (lo + hi)
            if hi - lo <= 1e-10 { break }
        }
        let candidate = 0.5 * (lo + hi)
        // Validate via one de Casteljau evaluation using buf[count..] as scratch.
        // If Horner had catastrophic cancellation the polynomial value at candidate will be
        // large relative to the coefficient scale and we fall back to full de Casteljau.
        var coeffScale = CGFloat(0)
        for k in 0..<count { coeffScale = Swift.max(coeffScale, Swift.abs(buf[k])) }
        for k in 0..<count { buf[count + k] = buf[k] }
        let mt = 1.0 - candidate
        for round in 1..<n {
            for i in 0...(n - round) { buf[count + i] = mt * buf[count + i] + candidate * buf[count + i + 1] }
        }
        let dcValue = mt * buf[count] + candidate * buf[count + 1]
        guard Swift.abs(dcValue) > coeffScale * 1e-6 else { result = candidate; return }
        // Horner had catastrophic cancellation in the power-basis conversion — exceedingly rare
        // in practice (0% hit rate on typical workloads), but occurs for specific polynomials
        // produced by deep bezier-clipping subdivision. See testAdversarialIntersectionMatrix
        // and testProjectRealWorldIssue for cases that exercise this path.
        // Fall back to de Casteljau Newton-bisection, which is numerically stable.
        // B'(t) = n × (d^{n−1}_1 − d^{n−1}_0) from the penultimate reduction row.
        func dcEval(_ t: CGFloat) -> (CGFloat, CGFloat) {
            for k in 0..<count { buf[count + k] = buf[k] }
            let mt2 = 1.0 - t
            for round in 1..<n {
                for i in 0...(n - round) { buf[count + i] = mt2 * buf[count + i] + t * buf[count + i + 1] }
            }
            let deriv = nF * (buf[count + 1] - buf[count])
            return (mt2 * buf[count] + t * buf[count + 1], deriv)
        }
        lo = 0.0; hi = 1.0; fLo = c0
        x = 0.5
        for _ in 0..<52 {
            guard hi - lo > 1e-10 else { break }
            let (f, fPrime) = dcEval(x)
            if f == 0 { lo = x; hi = x; break }
            if (fLo > 0) == (f > 0) { lo = x; fLo = f } else { hi = x }
            let newton = (fPrime != 0) ? x - f / fPrime : CGFloat.infinity
            x = (newton > lo && newton < hi) ? newton : 0.5 * (lo + hi)
        }
        result = 0.5 * (lo + hi)
    }
    return result
}

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
    let c0 = polynomial.firstCoefficient
    let cN = polynomial.lastCoefficient
    guard signChanges > 0 || c0 == 0 || cN == 0 else { return }

    if signChanges == 1, c0 * cN < 0 {
        let result = refineBracketedRoot(polynomial: polynomial, n: n, c0: c0)
        callback(Utils.linearInterpolate(rangeStart, rangeEnd, result))
        return
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
    if skippedRoot(c0, subcurve.firstCoefficient) { callback(nextRangeStart) }
    rootsCore(polynomial: subcurve, start: nextRangeStart, end: nextRangeEnd, depth: depth + 1, callback: callback)
    if skippedRoot(subcurve.lastCoefficient, cN) { callback(nextRangeEnd) }
}

/// Calls `callback` for each distinct root in `[0, 1]` using the Bezier clipping algorithm
/// (Sederberg & Nishita 1990). Roots are emitted in ascending order with duplicates suppressed.
func findDistinctRootsCallbackBezierClipping<P: BezierClippingPolynomial>(
    _ polynomial: P,
    _ callback: (CGFloat) -> Void
) {
    var hasNonZero = false
    polynomial.forEachCoefficient { if $0 != .zero { hasNonZero = true } }
    guard hasNonZero else { return }
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
