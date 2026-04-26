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
    var order: Int { get }
    var coefficients: [CGFloat] { get }
    associatedtype NextLowerOrderPolynomial: BernsteinPolynomial
    /// a polynomial of the next lower order where each coefficient `b[i]` is defined by `a1 * b[i] + a2 * b[i+1]`
    func difference(a1: CGFloat, a2: CGFloat) -> NextLowerOrderPolynomial
    /// reduces the polynomial by repeatedly applying `difference` until left with a constant value
    func reduce(a1: CGFloat, a2: CGFloat) -> CGFloat
    var derivative: NextLowerOrderPolynomial { get }
}

// Callback-based root protocol: implementations pass each root to the callback directly,
// avoiding any heap allocation for the result.
internal protocol AnalyticalRootsCallback {
    func forEachDistinctRoot(between start: CGFloat, and end: CGFloat, _ callback: (CGFloat) -> Void)
}

extension AnalyticalRootsCallback {
    internal func distinctAnalyticalRoots(between start: CGFloat, and end: CGFloat) -> [CGFloat] {
        var result: [CGFloat] = []
        forEachDistinctRoot(between: start, and: end) { result.append($0) }
        return result
    }
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
    func value(at x: CGFloat) -> CGFloat {
        let oneMinusX = 1.0 - x
        return self.reduce(a1: oneMinusX, a2: x)
    }
    var derivative: NextLowerOrderPolynomial {
        let order = CGFloat(self.order)
        return self.difference(a1: -order, a2: order)
    }
    func reduce(a1: CGFloat, a2: CGFloat) -> CGFloat {
        return self.difference(a1: a1, a2: a2).reduce(a1: a1, a2: a2)
    }
}

public struct BernsteinPolynomial0: BernsteinPolynomial, Sendable {
    public init(b0: CGFloat) { self.b0 = b0 }
    public var b0: CGFloat
    public var coefficients: [CGFloat] { return [b0] }
    public func value(at x: CGFloat) -> CGFloat {
        return b0
    }
    public var order: Int { return 0 }
    public func reduce(a1: CGFloat, a2: CGFloat) -> CGFloat { return 0.0 }
    public func difference(a1: CGFloat, a2: CGFloat) -> BernsteinPolynomial0 {
        return BernsteinPolynomial0(b0: 0.0)
    }
}

public struct BernsteinPolynomial1: BernsteinPolynomial, Sendable {
    public init(b0: CGFloat, b1: CGFloat) {
        self.b0 = b0
        self.b1 = b1
    }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial0
    public var b0, b1: CGFloat
    public var coefficients: [CGFloat] { return [b0, b1] }
    public func reduce(a1: CGFloat, a2: CGFloat) -> CGFloat {
        return a1 * b0 + a2 * b1
    }
    public func difference(a1: CGFloat, a2: CGFloat) -> BernsteinPolynomial0 {
        return BernsteinPolynomial0(b0: self.reduce(a1: a1, a2: a2))
    }
    public var order: Int { return 1 }
}

public struct BernsteinPolynomial2: BernsteinPolynomial, Sendable {
    public init(b0: CGFloat, b1: CGFloat, b2: CGFloat) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
    }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial1
    public var b0, b1, b2: CGFloat
    public var coefficients: [CGFloat] { return [b0, b1, b2] }
    public func difference(a1: CGFloat, a2: CGFloat) -> BernsteinPolynomial1 {
        return BernsteinPolynomial1(b0: a1 * b0 + a2 * b1,
                           b1: a1 * b1 + a2 * b2)
    }
    public var order: Int { return 2 }
}

public struct BernsteinPolynomial3: BernsteinPolynomial, Sendable {
    public init(b0: CGFloat, b1: CGFloat, b2: CGFloat, b3: CGFloat) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.b3 = b3
    }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial2
    public var b0, b1, b2, b3: CGFloat
    public var coefficients: [CGFloat] { return [b0, b1, b2, b3] }
    public func difference(a1: CGFloat, a2: CGFloat) -> BernsteinPolynomial2 {
        return BernsteinPolynomial2(b0: a1 * b0 + a2 * b1,
                           b1: a1 * b1 + a2 * b2,
                           b2: a1 * b2 + a2 * b3)
    }
    public var order: Int { return 3 }
}

public struct BernsteinPolynomial4: BernsteinPolynomial, Sendable {
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
    public func difference(a1: CGFloat, a2: CGFloat) -> BernsteinPolynomial3 {
        return BernsteinPolynomial3(b0: a1 * b0 + a2 * b1,
                           b1: a1 * b1 + a2 * b2,
                           b2: a1 * b2 + a2 * b3,
                           b3: a1 * b3 + a2 * b4)
    }
    public func value(at x: CGFloat) -> CGFloat {
        let s = 1 - x, t = x
        let c10 = s * b0 + t * b1; let c11 = s * b1 + t * b2
        let c12 = s * b2 + t * b3; let c13 = s * b3 + t * b4
        let c20 = s * c10 + t * c11; let c21 = s * c11 + t * c12; let c22 = s * c12 + t * c13
        let c30 = s * c20 + t * c21; let c31 = s * c21 + t * c22
        return s * c30 + t * c31
    }
    public var order: Int { return 4 }
}

public struct BernsteinPolynomial5: BernsteinPolynomial, Sendable {
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
    public func difference(a1: CGFloat, a2: CGFloat) -> BernsteinPolynomial4 {
        return BernsteinPolynomial4(b0: a1 * b0 + a2 * b1,
                           b1: a1 * b1 + a2 * b2,
                           b2: a1 * b2 + a2 * b3,
                           b3: a1 * b3 + a2 * b4,
                           b4: a1 * b4 + a2 * b5)
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
    public var order: Int { return 5 }
}

private func newton<P: BernsteinPolynomial>(polynomial: P, derivative: P.NextLowerOrderPolynomial, guess: CGFloat, relaxation: CGFloat = 1) -> CGFloat {
    let maxIterations = 20
    var x = guess
    for _ in 0..<maxIterations {
        let f = polynomial.value(at: x)
        guard f != 0.0 else { break }
        let fPrime = derivative.value(at: x)
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
    let highSign = polynomial.value(at: high).sign
    assert(lowSign != highSign)
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
            assert(nextGuessF.sign == highSign)
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
    assert(start < end)
    var result: [CGFloat] = []
    findDistinctRootsCallback(of: polynomial, between: start, and: end) { result.append($0) }
    return result
}
