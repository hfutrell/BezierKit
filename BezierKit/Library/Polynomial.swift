//
//  Polynomial.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/15/20.
//  Copyright © 2020 Holmes Futrell. All rights reserved.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

public protocol BernsteinPolynomial: Equatable {
    func value(at x: CGFloat) -> CGFloat
    /// Returns (value, derivative) at x. Conformers can override to share de Casteljau intermediates.
    func valueAndDerivative(at x: CGFloat) -> (CGFloat, CGFloat)
    associatedtype NextLowerOrderPolynomial: BernsteinPolynomial
    var derivative: NextLowerOrderPolynomial { get }
}


internal protocol AnalyticalRootsCallback {
    func forEachDistinctRoot(between start: CGFloat, and end: CGFloat, _ callback: (CGFloat) -> Void)
}

extension BernsteinPolynomial0: AnalyticalRootsCallback {
    func forEachDistinctRoot(between start: CGFloat, and end: CGFloat, _ callback: (CGFloat) -> Void) {}
}

extension BernsteinPolynomial1: AnalyticalRootsCallback {
    func forEachDistinctRoot(between start: CGFloat, and end: CGFloat, _ callback: (CGFloat) -> Void) {
        Utils.droots(self.b0, self.b1) {
            guard $0 >= start, $0 <= end else { return }
            callback($0)
        }
    }
}

extension BernsteinPolynomial2: AnalyticalRootsCallback {
    func forEachDistinctRoot(between start: CGFloat, and end: CGFloat, _ callback: (CGFloat) -> Void) {
        Utils.droots(self.b0, self.b1, self.b2) {
            guard $0 >= start, $0 <= end else { return }
            callback($0)
        }
    }
}

extension BernsteinPolynomial3: AnalyticalRootsCallback {
    func forEachDistinctRoot(between start: CGFloat, and end: CGFloat, _ callback: (CGFloat) -> Void) {
        Utils.droots(self.b0, self.b1, self.b2, self.b3) {
            guard $0 >= start, $0 <= end else { return }
            callback($0)
        }
    }
}

public extension BernsteinPolynomial {
    func valueAndDerivative(at x: CGFloat) -> (CGFloat, CGFloat) {
        return (value(at: x), derivative.value(at: x))
    }
//    func split(to x: CGFloat) -> Self {
//        let oneMinusX = 1.0 - x
//        let difference = self.difference(a1: oneMinusX, a2: x)
//        let differenceSplit: Difference = difference.split(to: x)
//        return Self(first: self.first, differenceSplit)
//    }
//    func split(from x: CGFloat) -> Self {
//        let oneMinusX = 1.0 - x
//        let difference = self.difference(a1: oneMinusX, a2: x)
//        let differenceSplit: Difference = difference.split(from: x)
//        return Self(differenceSplit, last: self.last)
//    }
//    func split(from tMin: CGFloat, to tMax: CGFloat) -> Self {
//        guard tMax > tMin else {
//    #warning("I think this goes into infinite recursion if tMax = tMin = 0.5")
//            return self.reversed().split(from: 1.0 - tMin, to: 1.0 - tMax)
//        }
//        var clippedPolynomial = self.split(to: tMax)
//        guard tMax > 0 else {
//            return clippedPolynomial
//        }
//        let tMinPrime = tMin / tMax
//        clippedPolynomial = clippedPolynomial.split(from: tMinPrime)
//        return clippedPolynomial
//    }
//    func reversed() -> Self {
//        let differenceReversed = self.difference(a1: 1, a2: 0).reversed()
//        return Self(first: self.last, differenceReversed)
//    }
}

public struct BernsteinPolynomial0: BernsteinPolynomial, Sendable {
//    func enumerated(block: (Int, CGFloat) -> Void) {
//        block(0, b0)
//    }
//    var last: CGFloat { return b0 }
//    var first: CGFloat { return b0 }
//    init(_ d: BernsteinPolynomial0, last: CGFloat) { self.b0 = last }
//    init(first: CGFloat, _ d: BernsteinPolynomial0) { self.b0 = first }
//    func reversed() -> BernsteinPolynomial0 { return self }
//    func split(to x: CGFloat) -> Self { return self }
//    func split(from x: CGFloat) -> Self { return self }
    public init(b0: CGFloat) { self.b0 = b0 }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial0
    public var b0: CGFloat
    public var coefficients: [CGFloat] { return [b0] }
    public func value(at x: CGFloat) -> CGFloat { return b0 }
    public var derivative: BernsteinPolynomial0 { return BernsteinPolynomial0(b0: 0.0) }
    public var order: Int { return 0 }
}

public struct BernsteinPolynomial1: BernsteinPolynomial, Sendable {
//    func enumerated(block: (Int, CGFloat) -> Void) {
//        block(0, b0)
//        block(1, b1)
//    }
//
//    var last: CGFloat { return b1 }
//    var first: CGFloat { return b0 }
//
//    init(_ d: BernsteinPolynomial0, last: CGFloat) {
//        self.b0 = d.b0
//        self.b1 = last
//    }
//
//    init(first: CGFloat, _ d: BernsteinPolynomial0) {
//        self.b0 = first
//        self.b1 = d.b0
//    }
//    func reversed() -> BernsteinPolynomial1 { BernsteinPolynomial1(b0: b1, b1: b0) }
    public init(b0: CGFloat, b1: CGFloat) {
        self.b0 = b0
        self.b1 = b1
    }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial0
    public var b0, b1: CGFloat
    public var coefficients: [CGFloat] { return [b0, b1] }
    public func value(at x: CGFloat) -> CGFloat { return (1.0 - x) * b0 + x * b1 }
    public var derivative: BernsteinPolynomial0 { return BernsteinPolynomial0(b0: b1 - b0) }
    public var order: Int { return 1 }
}

public struct BernsteinPolynomial2: BernsteinPolynomial, Sendable {
//    func enumerated(block: (Int, CGFloat) -> Void) {
//        block(0, b0)
//        block(1, b1)
//        block(2, b2)
//    }
//    var last: CGFloat { return b2 }
//    var first: CGFloat { return b0 }
//    init(_ d: BernsteinPolynomial1, last: CGFloat) {
//        self.b0 = d.b0
//        self.b1 = d.b1
//        self.b2 = last
//    }
//    init(first: CGFloat, _ d: BernsteinPolynomial1) {
//        self.b0 = first
//        self.b1 = d.b0
//        self.b2 = d.b1
//    }
    public init(b0: CGFloat, b1: CGFloat, b2: CGFloat) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
    }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial1
    public var b0, b1, b2: CGFloat
    public var coefficients: [CGFloat] { return [b0, b1, b2] }
    public func value(at x: CGFloat) -> CGFloat {
        let s = 1 - x, t = x
        return s * (s * b0 + t * b1) + t * (s * b1 + t * b2)
    }
    public var derivative: BernsteinPolynomial1 {
        return BernsteinPolynomial1(b0: 2 * (b1 - b0), b1: 2 * (b2 - b1))
    }
    public var order: Int { return 2 }
}

public struct BernsteinPolynomial3: BernsteinPolynomial, Sendable {
//    func enumerated(block: (Int, CGFloat) -> Void) {
//        block(0, b0)
//        block(1, b1)
//        block(2, b2)
//        block(3, b3)
//    }
//    var last: CGFloat { return b3 }
//    var first: CGFloat { return b0 }
//    init(_ d: BernsteinPolynomial2, last: CGFloat) {
//        self.b0 = d.b0
//        self.b1 = d.b1
//        self.b2 = d.b2
//        self.b3 = last
//    }
//    init(first: CGFloat, _ d: BernsteinPolynomial2) {
//        self.b0 = first
//        self.b1 = d.b0
//        self.b2 = d.b1
//        self.b3 = d.b2
//    }
    public init(b0: CGFloat, b1: CGFloat, b2: CGFloat, b3: CGFloat) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.b3 = b3
    }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial2
    public var b0, b1, b2, b3: CGFloat
    public var coefficients: [CGFloat] { return [b0, b1, b2, b3] }
    public func value(at x: CGFloat) -> CGFloat {
        let s = 1 - x, t = x
        let c10 = s * b0 + t * b1; let c11 = s * b1 + t * b2; let c12 = s * b2 + t * b3
        let c20 = s * c10 + t * c11; let c21 = s * c11 + t * c12
        return s * c20 + t * c21
    }
    public var derivative: BernsteinPolynomial2 {
        return BernsteinPolynomial2(b0: 3 * (b1 - b0), b1: 3 * (b2 - b1), b2: 3 * (b3 - b2))
    }
    public var order: Int { return 3 }
}

public struct BernsteinPolynomial4: BernsteinPolynomial, Sendable {
//    func enumerated(block: (Int, CGFloat) -> Void) {
//        block(0, b0)
//        block(1, b1)
//        block(2, b2)
//        block(3, b3)
//        block(4, b4)
//    }
//    var last: CGFloat { return b4 }
//    var first: CGFloat { return b0 }
//    init(_ d: BernsteinPolynomial3, last: CGFloat) {
//        self.b0 = d.b0
//        self.b1 = d.b1
//        self.b2 = d.b2
//        self.b3 = d.b3
//        self.b4 = last
//    }
//    init(first: CGFloat, _ d: BernsteinPolynomial3) {
//        self.b0 = first
//        self.b1 = d.b0
//        self.b2 = d.b1
//        self.b3 = d.b2
//        self.b4 = d.b3
//    }
    public init(b0: CGFloat, b1: CGFloat, b2: CGFloat, b3: CGFloat, b4: CGFloat) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.b3 = b3
        self.b4 = b4
    }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial3
    public var b0, b1, b2, b3, b4: CGFloat
    public var coefficients: [CGFloat] { return [b0, b1, b2, b3, b4] }
    public var derivative: BernsteinPolynomial3 {
        return BernsteinPolynomial3(b0: 4 * (b1 - b0), b1: 4 * (b2 - b1), b2: 4 * (b3 - b2), b3: 4 * (b4 - b3))
    }
    public func value(at x: CGFloat) -> CGFloat {
        let s = 1 - x, t = x
        let c10 = s * b0 + t * b1; let c11 = s * b1 + t * b2
        let c12 = s * b2 + t * b3; let c13 = s * b3 + t * b4
        let c20 = s * c10 + t * c11; let c21 = s * c11 + t * c12; let c22 = s * c12 + t * c13
        let c30 = s * c20 + t * c21; let c31 = s * c21 + t * c22
        return s * c30 + t * c31
    }
    public func valueAndDerivative(at x: CGFloat) -> (CGFloat, CGFloat) {
        let s = 1 - x, t = x
        let c10 = s * b0 + t * b1; let c11 = s * b1 + t * b2
        let c12 = s * b2 + t * b3; let c13 = s * b3 + t * b4
        let c20 = s * c10 + t * c11; let c21 = s * c11 + t * c12; let c22 = s * c12 + t * c13
        let c30 = s * c20 + t * c21; let c31 = s * c21 + t * c22
        return (s * c30 + t * c31, 4 * (c31 - c30))
    }
    public var order: Int { return 4 }
}

public struct BernsteinPolynomial5: BernsteinPolynomial, Sendable {
//    func enumerated(block: (Int, CGFloat) -> Void) {
//        block(0, b0)
//        block(1, b1)
//        block(2, b2)
//        block(3, b3)
//        block(4, b4)
//        block(5, b5)
//    }
//    var last: CGFloat { return b5 }
//    var first: CGFloat { return b0 }
//    init(_ d: BernsteinPolynomial4, last: CGFloat) {
//        self.b0 = d.b0
//        self.b1 = d.b1
//        self.b2 = d.b2
//        self.b3 = d.b3
//        self.b4 = d.b4
//        self.b5 = last
//    }
//    init(first: CGFloat, _ d: BernsteinPolynomial4) {
//        self.b0 = first
//        self.b1 = d.b0
//        self.b2 = d.b1
//        self.b3 = d.b2
//        self.b4 = d.b3
//        self.b5 = d.b4
//    }
    public init(b0: CGFloat, b1: CGFloat, b2: CGFloat, b3: CGFloat, b4: CGFloat, b5: CGFloat) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.b3 = b3
        self.b4 = b4
        self.b5 = b5
    }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial4
    public var b0, b1, b2, b3, b4, b5: CGFloat
    public var coefficients: [CGFloat] { return [b0, b1, b2, b3, b4, b5] }
    public var derivative: BernsteinPolynomial4 {
        return BernsteinPolynomial4(b0: 5 * (b1 - b0), b1: 5 * (b2 - b1), b2: 5 * (b3 - b2), b3: 5 * (b4 - b3), b4: 5 * (b5 - b4))
    }
    public func value(at x: CGFloat) -> CGFloat {
        let s = 1 - x, t = x
        let c10 = s * b0 + t * b1; let c11 = s * b1 + t * b2
        let c12 = s * b2 + t * b3; let c13 = s * b3 + t * b4; let c14 = s * b4 + t * b5
        let c20 = s * c10 + t * c11; let c21 = s * c11 + t * c12
        let c22 = s * c12 + t * c13; let c23 = s * c13 + t * c14
        let c30 = s * c20 + t * c21; let c31 = s * c21 + t * c22; let c32 = s * c22 + t * c23
        let c40 = s * c30 + t * c31; let c41 = s * c31 + t * c32
        return s * c40 + t * c41
    }
    public func valueAndDerivative(at x: CGFloat) -> (CGFloat, CGFloat) {
        let s = 1 - x, t = x
        let c10 = s * b0 + t * b1; let c11 = s * b1 + t * b2
        let c12 = s * b2 + t * b3; let c13 = s * b3 + t * b4; let c14 = s * b4 + t * b5
        let c20 = s * c10 + t * c11; let c21 = s * c11 + t * c12
        let c22 = s * c12 + t * c13; let c23 = s * c13 + t * c14
        let c30 = s * c20 + t * c21; let c31 = s * c21 + t * c22; let c32 = s * c22 + t * c23
        let c40 = s * c30 + t * c31; let c41 = s * c31 + t * c32
        return (s * c40 + t * c41, 5 * (c41 - c40))
    }
    public var order: Int { return 5 }
}

private func newton<P: BernsteinPolynomial>(polynomial: P, derivative: P.NextLowerOrderPolynomial, guess: CGFloat, relaxation: CGFloat = 1) -> CGFloat {
    let maxIterations = 20
    var x = guess
    for _ in 0..<maxIterations {
        let (f, fPrime) = polynomial.valueAndDerivative(at: x)
        guard f != 0.0 else { break }
        let delta = relaxation * f / fPrime
        let previous = x
        x -= delta
        guard Swift.abs(x - previous) > 1.0e-10 else { break }
    }
    return x
}

private func findRootBisection<P: BernsteinPolynomial>(of polynomial: P, start: CGFloat, end: CGFloat) -> CGFloat {
    var guess = (start + end) / 2
    var low = start
    var high = end
    let lowSign = polynomial.value(at: low).sign
    #if DEBUG
    let highSign = polynomial.value(at: high).sign
    assert(lowSign != highSign)
    #endif
    let maxIterations = 20
    var iterations = 0
    while high - low > 1.0e-5 {
        let midGuess = (low + high) / 2
        guess = midGuess
        let nextGuessF = polynomial.value(at: guess)
        if nextGuessF == 0 {
            return guess
        } else if nextGuessF.sign == lowSign {
            low = guess
        } else {
            #if DEBUG
            assert(nextGuessF.sign == highSign)
            #endif
            high = guess
        }
        iterations += 1
        guard iterations < maxIterations else { break }
    }
    return guess
}

// Zero-allocation root finder. Calls `callback` for each root in sorted order.
// For degree ≤ 3, delegates to Utils.droots (analytical). For higher degrees,
// finds critical points of the derivative recursively and searches each interval.
// Intervals are stored in a withUnsafeTemporaryAllocation buffer (stack for small sizes).
// Capacity is 6: BernsteinPolynomial5 is the highest-order type defined in this library,
// and a degree-5 polynomial needs at most [start] + 4 critical points + [end] = 6 slots.
// A compile-time constant lets the compiler stack-allocate the buffer without a dynamic alloca.
internal func findDistinctRootsCallback<P: BernsteinPolynomial>(
    of polynomial: P,
    between start: CGFloat, and end: CGFloat,
    _ callback: (CGFloat) -> Void
) {
    if let analytical = polynomial as? AnalyticalRootsCallback {
        analytical.forEachDistinctRoot(between: start, and: end, callback)
        return
    }
    let derivative = polynomial.derivative
    withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 6) { buffer in
        var count = 0
        buffer[count] = start; count += 1
        findDistinctRootsCallback(of: derivative, between: start, and: end) { criticalPoint in
            buffer[count] = criticalPoint; count += 1
        }
        buffer[count] = end; count += 1
        var lastFoundRoot: CGFloat?
        for i in 0..<count - 1 {
            let iStart = buffer[i]
            let iEnd   = buffer[i + 1]
            let fStart = polynomial.value(at: iStart)
            let fEnd   = polynomial.value(at: iEnd)
            let absFStart = Swift.abs(fStart)
            let absFEnd = Swift.abs(fEnd)
            let scale = Swift.max(absFStart, absFEnd)
            let residualToConsiderRoot = scale * CGFloat.ulpOfOne.squareRoot()
            let root: CGFloat
            if fStart * fEnd < 0 {
                let guess = (iStart + iEnd) / 2
                let newtonRoot = newton(polynomial: polynomial, derivative: derivative, guess: guess)
                if iStart < newtonRoot, newtonRoot < iEnd,
                   Swift.abs(polynomial.value(at: newtonRoot)) <= residualToConsiderRoot {
                    root = newtonRoot
                } else {
                    root = findRootBisection(of: polynomial, start: iStart, end: iEnd)
                }
            } else if absFStart <= residualToConsiderRoot, absFEnd >= residualToConsiderRoot {
                root = iStart
            } else if absFStart > residualToConsiderRoot, absFEnd <= residualToConsiderRoot {
                root = iEnd
            } else {
                continue
            }
            if let lastFoundRoot, lastFoundRoot + 1.0e-5 >= root { continue }
            lastFoundRoot = root
            callback(root)
        }
    }
}


public func findDistinctRootsInUnitInterval<P: BernsteinPolynomial>(of polynomial: P) -> [CGFloat] {
    var result: [CGFloat] = []
    findDistinctRootsCallback(of: polynomial, between: 0, and: 1) { result.append($0) }
    return result
}

internal func findDistinctRoots<P: BernsteinPolynomial>(of polynomial: P, between start: CGFloat, and end: CGFloat) -> [CGFloat] {
    var result: [CGFloat] = []
    findDistinctRootsCallback(of: polynomial, between: start, and: end) { result.append($0) }
    return result
}

// internal func findRoots<P: BernsteinPolynomial>(of polynomial: P, between start: CGFloat, and end: CGFloat) -> [CGFloat] {
//    assert(start < end)
//
//    var tMin: CGFloat = CGFloat.infinity
//    var tMax: CGFloat = -CGFloat.infinity
//    var intersected = false
//
//    func x(_ i: Int) -> CGFloat {
//        return CGFloat(i) / CGFloat(polynomial.order)
//    }
//    // compute the intersections of each pair of lines with the x axis
//    polynomial.enumerated { i, c1 in
//        polynomial.enumerated { j, c2 in
//            guard j > i else { return }
//            let x1 = x(i)
//            let x2 = x(j)
//            let yDifference = c2 - c1
//            guard yDifference != 0 else { return }
//            guard c1 <= 0 || c2 <= 0 else { return }
//            guard c1 >= 0 || c2 >= 0 else { return }
//            intersected = true
//            let tLine = -c1 / (c2 - c1)
//            let t = x1 * (1 - tLine) + x2 * tLine
//            if t < tMin {
//                tMin = t
//            }
//            if t > tMax {
//                tMax = t
//            }
//        }
//    }
//
//    guard intersected == true else {
//        return [] // no intersections with convex hull
//    }
//
//    assert(tMin >= 0 && tMin <= 1)
//    assert(tMax >= 0 && tMax <= 1)
//    assert(tMax >= tMin)
//
//    // find [adjustedStart, adjustedEnd] range represented by [tMin, tMax] in original polynomial
//    func adjustedT(_ t: CGFloat) -> CGFloat {
//        return start * (1.0 - t) + end * t
//    }
//    let adjustedStart = adjustedT(tMin)
//    let adjustedEnd = adjustedT(tMax)
//    guard adjustedEnd > adjustedStart else {
//        return [(adjustedStart + adjustedEnd) / 2.0]
//    }
//
//    guard tMax - tMin <= 0.8 else {
//        // we didn't clip enough of the polynomial off
//        // split the polynomial in two and find solutions in each half
//        let mid = (start + end) / 2
//        let left = polynomial.split(to: 0.5)
//        let solutionsLeft = findRoots(of: left, between: start, and: mid)
//        let right = polynomial.split(from: 0.5)
//        var solutionsRight = findRoots(of: right, between: mid, and: end)
//        if let lastLeft = solutionsLeft.last {
//            // filter out double-roots
//            solutionsRight = solutionsRight.filter { $0 - lastLeft > 1.0e-7 }
//        }
//        return solutionsLeft + solutionsRight
//    }
//
//    // clip the polynomial to [tMin, tMax]
//    let clippedPolynomial = polynomial.split(from: tMin, to: tMax)
//    return findRoots(of: clippedPolynomial,
//                     between: adjustedStart,
//                     and: adjustedEnd)
// }
