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

protocol BernsteinPolynomial: Equatable {
    func f(_ x: Double) -> Double
    var order: Int { get }
    var coefficients: [Double] { get }
//    var last: Double { get }
//    var first: Double { get }
//    func enumerated(block: (Int, Double) -> Void)
    associatedtype Difference: BernsteinPolynomial
    func difference(a1: Double, a2: Double) -> Difference
    func reduce(a1: Double, a2: Double) -> Double
    var derivative: Difference { get }
//    init(_ d: Difference, last: Double)
//    init(first: Double, _ d: Difference)
//    func reversed() -> Self
//    func split(to x: Double) -> Self
//    func split(from x: Double) -> Self
//    func split(from tMin: Double, to tMax: Double) -> Self
}

extension BernsteinPolynomial {
    func f(_ x: Double) -> Double {
        let oneMinusX = 1.0 - x
        return self.reduce(a1: oneMinusX, a2: x)
    }
    var derivative: Difference {
        let order = Double(self.order)
        return self.difference(a1: -order, a2: order)
    }
    func reduce(a1: Double, a2: Double) -> Double {
        return self.difference(a1: a1, a2: a2).reduce(a1: a1, a2: a2)
    }
//    func split(to x: Double) -> Self {
//        let oneMinusX = 1.0 - x
//        let difference = self.difference(a1: oneMinusX, a2: x)
//        let differenceSplit: Difference = difference.split(to: x)
//        return Self(first: self.first, differenceSplit)
//    }
//    func split(from x: Double) -> Self {
//        let oneMinusX = 1.0 - x
//        let difference = self.difference(a1: oneMinusX, a2: x)
//        let differenceSplit: Difference = difference.split(from: x)
//        return Self(differenceSplit, last: self.last)
//    }
//    func split(from tMin: Double, to tMax: Double) -> Self {
//        guard tMax > tMin else {
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

struct BernsteinPolynomial0: BernsteinPolynomial {
//    func enumerated(block: (Int, Double) -> Void) {
//        block(0, b0)
//    }
//    var last: Double { return b0 }
//    var first: Double { return b0 }
//    init(_ d: BernsteinPolynomial0, last: Double) { self.b0 = last }
//    init(first: Double, _ d: BernsteinPolynomial0) { self.b0 = first }
//    func reversed() -> BernsteinPolynomial0 { return self }
//    func split(to x: Double) -> Self { return self }
//    func split(from x: Double) -> Self { return self }
    init(b0: Double) { self.b0 = b0 }
    var b0: Double
    var coefficients: [Double] { return [b0] }
    func f(_ x: Double) -> Double {
        return b0
    }
    var order: Int { return 0 }
    func reduce(a1: Double, a2: Double) -> Double { return 0.0 }
    func difference(a1: Double, a2: Double) -> BernsteinPolynomial0 {
        return BernsteinPolynomial0(b0: 0.0)
    }
}

struct BernsteinPolynomial1: BernsteinPolynomial {
//    func enumerated(block: (Int, Double) -> Void) {
//        block(0, b0)
//        block(1, b1)
//    }
//
//    var last: Double { return b1 }
//    var first: Double { return b0 }
//
//    init(_ d: BernsteinPolynomial0, last: Double) {
//        self.b0 = d.b0
//        self.b1 = last
//    }
//
//    init(first: Double, _ d: BernsteinPolynomial0) {
//        self.b0 = first
//        self.b1 = d.b0
//    }
//    func reversed() -> BernsteinPolynomial1 { BernsteinPolynomial1(b0: b1, b1: b0) }
    init(b0: Double, b1: Double) {
        self.b0 = b0
        self.b1 = b1
    }
    typealias Difference = BernsteinPolynomial0
    var b0, b1: Double
    var coefficients: [Double] { return [b0, b1] }
    func reduce(a1: Double, a2: Double) -> Double {
        return a1 * b0 + a2 * b1
    }
    func difference(a1: Double, a2: Double) -> BernsteinPolynomial0 {
        return BernsteinPolynomial0(b0: self.reduce(a1: a1, a2: a2))
    }
    var order: Int { return 1 }
}

struct BernsteinPolynomial2: BernsteinPolynomial {
//    func enumerated(block: (Int, Double) -> Void) {
//        block(0, b0)
//        block(1, b1)
//        block(2, b2)
//    }
//    var last: Double { return b2 }
//    var first: Double { return b0 }
//    init(_ d: BernsteinPolynomial1, last: Double) {
//        self.b0 = d.b0
//        self.b1 = d.b1
//        self.b2 = last
//    }
//    init(first: Double, _ d: BernsteinPolynomial1) {
//        self.b0 = first
//        self.b1 = d.b0
//        self.b2 = d.b1
//    }
    init(b0: Double, b1: Double, b2: Double) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
    }
    typealias Difference = BernsteinPolynomial1
    var b0, b1, b2: Double
    var coefficients: [Double] { return [b0, b1, b2] }
    func difference(a1: Double, a2: Double) -> BernsteinPolynomial1 {
        return BernsteinPolynomial1(b0: a1 * b0 + a2 * b1,
                           b1: a1 * b1 + a2 * b2)
    }
    var order: Int { return 2 }
}

struct BernsteinPolynomial3: BernsteinPolynomial {
//    func enumerated(block: (Int, Double) -> Void) {
//        block(0, b0)
//        block(1, b1)
//        block(2, b2)
//        block(3, b3)
//    }
//    var last: Double { return b3 }
//    var first: Double { return b0 }
//    init(_ d: BernsteinPolynomial2, last: Double) {
//        self.b0 = d.b0
//        self.b1 = d.b1
//        self.b2 = d.b2
//        self.b3 = last
//    }
//    init(first: Double, _ d: BernsteinPolynomial2) {
//        self.b0 = first
//        self.b1 = d.b0
//        self.b2 = d.b1
//        self.b3 = d.b2
//    }
    init(b0: Double, b1: Double, b2: Double, b3: Double) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.b3 = b3
    }
    typealias Difference = BernsteinPolynomial2
    var b0, b1, b2, b3: Double
    var coefficients: [Double] { return [b0, b1, b2, b3] }
    func difference(a1: Double, a2: Double) -> BernsteinPolynomial2 {
        return BernsteinPolynomial2(b0: a1 * b0 + a2 * b1,
                           b1: a1 * b1 + a2 * b2,
                           b2: a1 * b2 + a2 * b3)
    }
    var order: Int { return 3 }
}

struct BernsteinPolynomial4: BernsteinPolynomial {
//    func enumerated(block: (Int, Double) -> Void) {
//        block(0, b0)
//        block(1, b1)
//        block(2, b2)
//        block(3, b3)
//        block(4, b4)
//    }
//    var last: Double { return b4 }
//    var first: Double { return b0 }
//    init(_ d: BernsteinPolynomial3, last: Double) {
//        self.b0 = d.b0
//        self.b1 = d.b1
//        self.b2 = d.b2
//        self.b3 = d.b3
//        self.b4 = last
//    }
//    init(first: Double, _ d: BernsteinPolynomial3) {
//        self.b0 = first
//        self.b1 = d.b0
//        self.b2 = d.b1
//        self.b3 = d.b2
//        self.b4 = d.b3
//    }
    init(b0: Double, b1: Double, b2: Double, b3: Double, b4: Double) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.b3 = b3
        self.b4 = b4
    }
    typealias Difference = BernsteinPolynomial3
    var b0, b1, b2, b3, b4: Double
    var coefficients: [Double] { return [b0, b1, b2, b3, b4] }
    func difference(a1: Double, a2: Double) -> BernsteinPolynomial3 {
        return BernsteinPolynomial3(b0: a1 * b0 + a2 * b1,
                           b1: a1 * b1 + a2 * b2,
                           b2: a1 * b2 + a2 * b3,
                           b3: a1 * b3 + a2 * b4)
    }
    var order: Int { return 4 }
}

struct BernsteinPolynomial5: BernsteinPolynomial {
//    func enumerated(block: (Int, Double) -> Void) {
//        block(0, b0)
//        block(1, b1)
//        block(2, b2)
//        block(3, b3)
//        block(4, b4)
//        block(5, b5)
//    }
//    var last: Double { return b5 }
//    var first: Double { return b0 }
//    init(_ d: BernsteinPolynomial4, last: Double) {
//        self.b0 = d.b0
//        self.b1 = d.b1
//        self.b2 = d.b2
//        self.b3 = d.b3
//        self.b4 = d.b4
//        self.b5 = last
//    }
//    init(first: Double, _ d: BernsteinPolynomial4) {
//        self.b0 = first
//        self.b1 = d.b0
//        self.b2 = d.b1
//        self.b3 = d.b2
//        self.b4 = d.b3
//        self.b5 = d.b4
//    }
    init(b0: Double, b1: Double, b2: Double, b3: Double, b4: Double, b5: Double) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.b3 = b3
        self.b4 = b4
        self.b5 = b5
    }
    typealias Difference = BernsteinPolynomial4
    var b0, b1, b2, b3, b4, b5: Double
    var coefficients: [Double] { return [b0, b1, b2, b3, b4, b5] }
    func difference(a1: Double, a2: Double) -> BernsteinPolynomial4 {
        return BernsteinPolynomial4(b0: a1 * b0 + a2 * b1,
                           b1: a1 * b1 + a2 * b2,
                           b2: a1 * b2 + a2 * b3,
                           b3: a1 * b3 + a2 * b4,
                           b4: a1 * b4 + a2 * b5)
    }
    var order: Int { return 5 }
}

extension BernsteinPolynomial {
    func analyticalRoots(between start: Double, and end: Double) -> [Double]? {
        let order = self.order
        guard order > 0 else { return [] }
        guard order < 4 else { return nil } // cannot solve
        return Utils.droots(self.coefficients.map { CGFloat($0) }).compactMap {
            let t = Double($0)
            guard t > start, t < end else { return nil }
            return t
        }
    }
}

private func newton<P: BernsteinPolynomial>(polynomial: P, derivative: P.Difference, guess: Double, relaxation: Double = 1) -> Double {
    let maxIterations = 20
    var x = guess
    for _ in 0..<maxIterations {
        let f = polynomial.f(x)
        guard f != 0.0 else { break }
        let fPrime = derivative.f(x)
        let delta = relaxation * f / fPrime
        let previous = x
        x -= delta
        guard abs(x - previous) > 1.0e-10 else { break }
    }
    return x
}

private func findRootBisection<P: BernsteinPolynomial>(of polynomial: P, start: Double, end: Double) -> Double {
    var guess = (start + end) / 2
    var low = start
    var high = end
    let lowSign = polynomial.f(low).sign
    let highSign = polynomial.f(high).sign
    assert(lowSign != highSign)
    let maxIterations = 20
    var iterations = 0
    while high - low > 1.0e-5 {
        let midGuess = (low + high) / 2
        guess = midGuess
        let nextGuessF = polynomial.f(guess)
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

func findRoots<P: BernsteinPolynomial>(of polynomial: P, between start: Double, and end: Double) -> [Double] {
    assert(start < end)
    if let roots = polynomial.analyticalRoots(between: start, and: end) {
        return roots
    }
    let derivative = polynomial.derivative
    let criticalPoints: [Double] = findRoots(of: derivative, between: start, and: end)
    let intervals: [Double] = [start] + criticalPoints + [end]
    var lastFoundRoot: Double?
    let roots = (0..<intervals.count-1).compactMap { (i: Int) -> Double? in
        let start   = intervals[i]
        let end     = intervals[i+1]
        let fStart  = polynomial.f(start)
        let fEnd    = polynomial.f(end)
        let root: Double
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
            guard abs(value - guess) < 1.0e-5 else {
                return nil // did not converge near guess
            }
            guard abs(polynomial.f(value)) < 1.0e-10 else {
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

//func findRoots<P: BernsteinPolynomial>(of polynomial: P, between start: Double, and end: Double) -> [Double] {
//    assert(start < end)
//
//    var tMin: Double = Double.infinity
//    var tMax: Double = -Double.infinity
//    var intersected = false
//
//    func x(_ i: Int) -> Double {
//        return Double(i) / Double(polynomial.order)
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
//    func adjustedT(_ t: Double) -> Double {
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
//}
