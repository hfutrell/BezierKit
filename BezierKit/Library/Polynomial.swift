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

protocol Differenceable {
    associatedtype Difference: BerenStein
    func difference(a1: Double, a2: Double) -> Difference
}

extension Differenceable where Self.Difference: Reduceable {
    func reduce(a1: Double, a2: Double) -> Double {
        return self.difference(a1: a1, a2: a2).reduce(a1: a1, a2: a2)
    }
}

protocol Reduceable {
    func reduce(a1: Double, a2: Double) -> Double
}

extension Reduceable {
    func f(_ x: Double) -> Double {
        let oneMinusX = 1.0 - x
        return self.reduce(a1: oneMinusX, a2: x)
    }
}

protocol BerenStein: Equatable, Differenceable, Reduceable {
    func f(_ x: Double) -> Double
    var order: Int { get }
    var coefficients: [Double] { get }
}

extension BerenStein where Self: Differenceable {
    var derivative: Difference {
        let order = Double(self.order)
        return self.difference(a1: -order, a2: order)
    }
}

struct BerenStein0: BerenStein, Differenceable, Reduceable {
    var b0: Double
    var coefficients: [Double] { return [b0] }
    func f(_ x: Double) -> Double {
        return b0
    }
    var order: Int { return 0 }
    func reduce(a1: Double, a2: Double) -> Double { return 0.0 }
    func difference(a1: Double, a2: Double) -> BerenStein0 {
        return BerenStein0(b0: 0.0)
    }
}

struct BerenStein1: BerenStein, Differenceable, Reduceable {
    typealias Difference = BerenStein0
    var b0, b1: Double
    var coefficients: [Double] { return [b0, b1] }
    func reduce(a1: Double, a2: Double) -> Double {
        return a1 * b0 + a2 * b1
    }
    func difference(a1: Double, a2: Double) -> BerenStein0 {
        return BerenStein0(b0: self.reduce(a1: a1, a2: a2))
    }
    var order: Int { return 1 }
}

struct BerenStein2: BerenStein, Differenceable, Reduceable {
    typealias Difference = BerenStein1
    var b0, b1, b2: Double
    var coefficients: [Double] { return [b0, b1, b2] }
    func difference(a1: Double, a2: Double) -> BerenStein1 {
        return BerenStein1(b0: a1 * b0 + a2 * b1,
                           b1: a1 * b1 + a2 * b2)
    }
    var order: Int { return 2 }
}

struct BerenStein3: BerenStein, Differenceable, Reduceable {
    typealias Difference = BerenStein2
    var b0, b1, b2, b3: Double
    var coefficients: [Double] { return [b0, b1, b2, b3] }
    func difference(a1: Double, a2: Double) -> BerenStein2 {
        return BerenStein2(b0: a1 * b0 + a2 * b1,
                           b1: a1 * b1 + a2 * b2,
                           b2: a1 * b2 + a2 * b3)
    }
    var order: Int { return 3 }
}

struct BerenStein4: BerenStein, Differenceable, Reduceable {
    typealias Difference = BerenStein3
    var b0, b1, b2, b3, b4: Double
    var coefficients: [Double] { return [b0, b1, b2, b3, b4] }
    func difference(a1: Double, a2: Double) -> BerenStein3 {
        return BerenStein3(b0: a1 * b0 + a2 * b1,
                           b1: a1 * b1 + a2 * b2,
                           b2: a1 * b2 + a2 * b3,
                           b3: a1 * b3 + a2 * b4)
    }
    var order: Int { return 4 }
}

struct BerenStein5: BerenStein, Differenceable, Reduceable {
    typealias Difference = BerenStein4
    var b0, b1, b2, b3, b4, b5: Double
    var coefficients: [Double] { return [b0, b1, b2, b3, b4, b5] }
    func difference(a1: Double, a2: Double) -> BerenStein4 {
        return BerenStein4(b0: a1 * b0 + a2 * b1,
                           b1: a1 * b1 + a2 * b2,
                           b2: a1 * b2 + a2 * b3,
                           b3: a1 * b3 + a2 * b4,
                           b4: a1 * b4 + a2 * b5)
    }
    var order: Int { return 5 }
}

extension BerenStein {
    func f(_ x: Double, _ scratchPad: UnsafeMutableBufferPointer<Double>) -> Double {
        return self.f(x)
    }
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

private func newton<P: BerenStein>(polynomial: P, derivative: P.Difference, guess: Double, relaxation: Double = 1, scratchPad: UnsafeMutableBufferPointer<Double>) -> Double {
    let maxIterations = 20
    var x = guess
    for _ in 0..<maxIterations {
        let f = polynomial.f(x, scratchPad)
        guard f != 0.0 else { break }
        let fPrime = derivative.f(x, scratchPad)
        let delta = relaxation * f / fPrime
        let previous = x
        x -= delta
        guard abs(x - previous) > 1.0e-10 else { break }
    }
    return x
}

private func findRootBisection<P: BerenStein>(of polynomial: P, start: Double, end: Double, scratchPad: UnsafeMutableBufferPointer<Double>) -> Double {
    var guess = (start + end) / 2
    var low = start
    var high = end
    let lowSign = polynomial.f(low, scratchPad).sign
    let highSign = polynomial.f(high, scratchPad).sign
    assert(lowSign != highSign)
    let maxIterations = 20
    var iterations = 0
    while high - low > 1.0e-5 {
        let midGuess = (low + high) / 2
        guess = midGuess
        let nextGuessF = polynomial.f(guess, scratchPad)
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


func findRoots<P: BerenStein>(of polynomial: P, between start: Double, and end: Double, scratchPad: UnsafeMutableBufferPointer<Double>) -> [Double] {
    assert(start < end)
    if let roots = polynomial.analyticalRoots(between: start, and: end) {
        return roots
    }
    let derivative = polynomial.derivative
    let criticalPoints: [Double] = findRoots(of: derivative, between: start, and: end, scratchPad: scratchPad)
    let intervals: [Double] = [start] + criticalPoints + [end]
    var lastFoundRoot: Double?
    let roots = (0..<intervals.count-1).compactMap { (i: Int) -> Double? in
        let start   = intervals[i]
        let end     = intervals[i+1]
        let fStart  = polynomial.f(start, scratchPad)
        let fEnd    = polynomial.f(end, scratchPad)
        let root: Double
        if fStart * fEnd < 0 {
            // TODO: if a critical point is a root we take this
            // codepath due to roundoff and  converge only linearly to one end of interval
            let guess = (start + end) / 2
            let newtonRoot = newton(polynomial: polynomial, derivative: derivative, guess: guess, scratchPad: scratchPad)
            if start < newtonRoot, newtonRoot < end {
                root = newtonRoot
            } else {
                // newton's method failed / converged to the wrong root!
                // rare, but can happen roughly 5% of the time
                // see unit test: `testDegree4RealWorldIssue`
                root = findRootBisection(of: polynomial, start: start, end: end, scratchPad: scratchPad)
            }
        } else {
            let guess = end
            let value = newton(polynomial: polynomial, derivative: derivative, guess: guess, scratchPad: scratchPad)
            guard abs(value - guess) < 1.0e-5 else {
                return nil // did not converge near guess
            }
            guard abs(polynomial.f(value, scratchPad)) < 1.0e-10 else {
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
