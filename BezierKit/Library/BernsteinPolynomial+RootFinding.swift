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

// Internal protocol providing per-index coefficient access for the bezier clipping algorithm.
// BP0–BP5 all conform so `findDistinctRootsCallbackBezierClipping` can be generic.
protocol BezierClippingPolynomial: BernsteinPolynomial {
    var degree: Int { get }
    func coefficient(at i: Int) -> CGFloat
}

extension BernsteinPolynomial0: BezierClippingPolynomial {
    var degree: Int { 0 }
    func coefficient(at i: Int) -> CGFloat { b0 }
}

extension BernsteinPolynomial1: BezierClippingPolynomial {
    var degree: Int { 1 }
    func coefficient(at i: Int) -> CGFloat {
        switch i {
        case 0: return b0
        default: return b1
        }
    }
}

extension BernsteinPolynomial2: BezierClippingPolynomial {
    var degree: Int { 2 }
    func coefficient(at i: Int) -> CGFloat {
        switch i {
        case 0: return b0
        case 1: return b1
        default: return b2
        }
    }
}

extension BernsteinPolynomial3: BezierClippingPolynomial {
    var degree: Int { 3 }
    func coefficient(at i: Int) -> CGFloat {
        switch i {
        case 0: return b0
        case 1: return b1
        case 2: return b2
        default: return b3
        }
    }
}

extension BernsteinPolynomial4: BezierClippingPolynomial {
    var degree: Int { 4 }
    func coefficient(at i: Int) -> CGFloat {
        switch i {
        case 0: return b0
        case 1: return b1
        case 2: return b2
        case 3: return b3
        default: return b4
        }
    }
}

extension BernsteinPolynomial5: BezierClippingPolynomial {
    var degree: Int { 5 }
    func coefficient(at i: Int) -> CGFloat {
        switch i {
        case 0: return b0
        case 1: return b1
        case 2: return b2
        case 3: return b3
        case 4: return b4
        default: return b5
        }
    }
}

// Converts Bernstein control points to power basis using iterative forward differences.
// a[m] = C(n,m) * Δ^m b_0, so p(t) = Σ a[m] * t^m.
private func bernsteinToPowerBasis<P: BezierClippingPolynomial>(_ polynomial: P) -> [Double] {
    let n = polynomial.degree
    let count = n + 1
    var diffs = (0..<count).map { Double(polynomial.coefficient(at: $0)) }
    var result = [Double](repeating: 0, count: count)
    for m in 0...n {
        result[m] = Double(Utils.binomialCoefficient(n, choose: m)) * diffs[0]
        for k in 0..<(n - m) { diffs[k] = diffs[k + 1] - diffs[k] }
    }
    return result
}

private func horner(_ c: [Double], at t: Double) -> Double {
    var v = c[c.count - 1]
    for i in stride(from: c.count - 2, through: 0, by: -1) { v = v * t + c[i] }
    return v
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
    for i in 0..<count { coeffScale = Swift.max(coeffScale, Swift.abs(Double(polynomial.coefficient(at: i)))) }
    let signThreshold = coeffScale * 1e-10
    var lastSign = 0
    var signChanges = 0
    for i in 0..<count {
        let c = Double(polynomial.coefficient(at: i))
        guard Swift.abs(c) > signThreshold else { continue }
        let s = c > 0 ? 1 : -1
        if lastSign != 0, s != lastSign { signChanges += 1 }
        lastSign = s
    }
    let c0 = polynomial.coefficient(at: 0)
    let cN = polynomial.coefficient(at: n)
    guard signChanges > 0 || c0 == 0 || cN == 0 else { return }

    if signChanges == 1 {
        let fLo = Double(c0)
        let fHi = Double(cN)
        if fLo * fHi < 0 {
            let pow = bernsteinToPowerBasis(polynomial)
            var lo = 0.0, hi = 1.0, fL = fLo, fH = fHi
            let threshold = Double(clippingErrorThreshold) / Double(rangeEnd - rangeStart)
            while hi - lo > threshold {
                let mid = 0.5 * (lo + hi)
                let fMid = horner(pow, at: mid)
                if fMid == 0 { lo = mid; hi = mid; break }
                if (fL > 0) == (fMid > 0) { lo = mid; fL = fMid } else { hi = mid; fH = fMid }
            }
            _ = fH
            callback(Utils.linearInterpolate(rangeStart, rangeEnd, CGFloat(0.5 * (lo + hi))))
            return
        }
    }

    var lowerBound = CGFloat.infinity
    var upperBound = -CGFloat.infinity
    for i in 0..<n {
        for j in (i + 1)...n {
            let p1x = CGFloat(i) / CGFloat(n)
            let p1y = polynomial.coefficient(at: i)
            let p2x = CGFloat(j) / CGFloat(n)
            let p2y = polynomial.coefficient(at: j)
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
