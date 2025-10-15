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
//    var last: CGFloat { get }
//    var first: CGFloat { get }
//    func enumerated(block: (Int, CGFloat) -> Void)
    associatedtype NextLowerOrderPolynomial: BernsteinPolynomial
    /// a polynomial of the next lower order where each coefficient `b[i]` is defined by `a1 * b[i] + a2 * b[i+1]`
    func difference(a1: CGFloat, a2: CGFloat) -> NextLowerOrderPolynomial
    /// reduces the polynomial by repeatedly applying `difference` until left with a constant value
    func reduce(a1: CGFloat, a2: CGFloat) -> CGFloat
    var derivative: NextLowerOrderPolynomial { get }
//    init(_ d: Difference, last: CGFloat)
//    init(first: CGFloat, _ d: Difference)
//    func reversed() -> Self
//    func split(to x: CGFloat) -> Self
//    func split(from x: CGFloat) -> Self
//    func split(from tMin: CGFloat, to tMax: CGFloat) -> Self
}

internal protocol AnalyticalRoots {
    func distinctAnalyticalRoots(between start: CGFloat, and end: CGFloat) -> [CGFloat]
}

extension BernsteinPolynomial0: AnalyticalRoots {
    internal func distinctAnalyticalRoots(between start: CGFloat, and end: CGFloat) -> [CGFloat] {
        return []
    }
}

extension BernsteinPolynomial1: AnalyticalRoots {
    internal func distinctAnalyticalRoots(between start: CGFloat, and end: CGFloat) -> [CGFloat] {
        var result: [CGFloat] = []
        Utils.droots(self.b0, self.b1) {
            guard $0 >= start, $0 <= end else { return }
            result.append($0)
        }
        return result
    }
}

extension BernsteinPolynomial2: AnalyticalRoots {
    internal func distinctAnalyticalRoots(between start: CGFloat, and end: CGFloat) -> [CGFloat] {
        var result: [CGFloat] = []
        Utils.droots(self.b0, self.b1, self.b2) {
            guard $0 >= start, $0 <= end else { return }
            result.append($0)
        }
        return result
    }
}

extension BernsteinPolynomial3: AnalyticalRoots {
    internal func distinctAnalyticalRoots(between start: CGFloat, and end: CGFloat) -> [CGFloat] {
        var result: [CGFloat] = []
        Utils.droots(self.b0, self.b1, self.b2, self.b3) {
            guard $0 >= start, $0 <= end else { return }
            result.append($0)
        }
        return result
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
    public func reduce(a1: CGFloat, a2: CGFloat) -> CGFloat {
        return a1 * b0 + a2 * b1
    }
    public func difference(a1: CGFloat, a2: CGFloat) -> BernsteinPolynomial0 {
        return BernsteinPolynomial0(b0: self.reduce(a1: a1, a2: a2))
    }
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
    public func difference(a1: CGFloat, a2: CGFloat) -> BernsteinPolynomial1 {
        return BernsteinPolynomial1(b0: a1 * b0 + a2 * b1,
                           b1: a1 * b1 + a2 * b2)
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
    public func difference(a1: CGFloat, a2: CGFloat) -> BernsteinPolynomial2 {
        return BernsteinPolynomial2(b0: a1 * b0 + a2 * b1,
                           b1: a1 * b1 + a2 * b2,
                           b2: a1 * b2 + a2 * b3)
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
    public func difference(a1: CGFloat, a2: CGFloat) -> BernsteinPolynomial3 {
        return BernsteinPolynomial3(b0: a1 * b0 + a2 * b1,
                           b1: a1 * b1 + a2 * b2,
                           b2: a1 * b2 + a2 * b3,
                           b3: a1 * b3 + a2 * b4)
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
    public func difference(a1: CGFloat, a2: CGFloat) -> BernsteinPolynomial4 {
        return BernsteinPolynomial4(b0: a1 * b0 + a2 * b1,
                           b1: a1 * b1 + a2 * b2,
                           b2: a1 * b2 + a2 * b3,
                           b3: a1 * b3 + a2 * b4,
                           b4: a1 * b4 + a2 * b5)
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

public func findDistinctRootsInUnitInterval<P: BernsteinPolynomial>(of polynomial: P) -> [CGFloat] {
    return findDistinctRoots(of: polynomial, between: 0, and: 1)
}

internal func findDistinctRoots<P: BernsteinPolynomial>(of polynomial: P, between start: CGFloat, and end: CGFloat) -> [CGFloat] {
    assert(start < end)
    if let analytical = polynomial as? AnalyticalRoots {
        return analytical.distinctAnalyticalRoots(between: start, and: end)
    }
    let derivative = polynomial.derivative
    let criticalPoints: [CGFloat] = findDistinctRoots(of: derivative, between: start, and: end)
    let intervals: [CGFloat] = [start] + criticalPoints + [end]
    var lastFoundRoot: CGFloat?
    let roots = (0..<intervals.count-1).compactMap { (i: Int) -> CGFloat? in
        let start   = intervals[i]
        let end     = intervals[i+1]
        let fStart  = polynomial.value(at: start)
        let fEnd    = polynomial.value(at: end)
        let root: CGFloat
        if fStart * fEnd < 0 {
            // TODO: if a critical point is a root we take this
            // codepath due to roundoff and  converge only linearly to one end of interval
            let guess = (start + end) / 2
            let newtonRoot = newton(polynomial: polynomial, derivative: derivative, guess: guess)
            if start < newtonRoot, newtonRoot < end {
                root = newtonRoot
            } else {
                // newton's method failed / converged to the wrong root!
                // rare, but can happen roughly 5% of the time
                // see unit test: `testDegree4RealWorldIssue`
                root = findRootBisection(of: polynomial, start: start, end: end)
            }
        } else {
            let guess = end
            let value = newton(polynomial: polynomial, derivative: derivative, guess: guess)
            guard Swift.abs(value - guess) < 1.0e-5 else {
                return nil // did not converge near guess
            }
            guard Swift.abs(polynomial.value(at: value)) < 1.0e-10 else {
                return nil // not actually a root
            }
            root = value
        }
        if let lastFoundRoot = lastFoundRoot {
            guard lastFoundRoot + 1.0e-5 < root else {
                return nil // ensures roots are unique and ordered
            }
        }
        lastFoundRoot = root
        return root
    }
    return roots
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
