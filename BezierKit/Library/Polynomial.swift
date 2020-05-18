//
//  Polynomial.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/15/20.
//  Copyright © 2020 Holmes Futrell. All rights reserved.
//

import Foundation

protocol Polynomial {
    associatedtype Derivative: Polynomial
    func f(_ x: Double) -> Double
    var derivative: Derivative { get }
    func criticalPoints(between start: Double, and end: Double) -> [Double]
}

protocol AnalyticRoots: Polynomial {
    var roots: [Double] { get }
}

struct PolynomialDegree0: Polynomial, AnalyticRoots {
    typealias Derivative = Self
    var a0: Double
    func f(_ x: Double) -> Double { return a0 }
    var roots: [Double] { return [] }
    var derivative: Derivative {
        return PolynomialDegree0(a0: 0.0)
    }
}

struct PolynomialDegree1: Polynomial, AnalyticRoots {
    typealias Derivative = PolynomialDegree0
    var a1, a0: Double
    func f(_ x: Double) -> Double { return a1 * x + a0 }
    var roots: [Double] {
        guard a1 != 0.0 else { return [] }
        return [-a0 / a1]
    }
    var derivative: Derivative {
        return PolynomialDegree0(a0: a1)
    }
}

struct PolynomialDegree2: Polynomial {
    typealias Derivative = PolynomialDegree1
    var a2, a1, a0: Double
    func f(_ x: Double) -> Double { return a2 * x * x + a1 * x + a0 }
    var derivative: Derivative {
        return PolynomialDegree1(a1: 2 * a2, a0: a1)
    }
}

struct PolynomialDegree3: Polynomial {
    typealias Derivative = PolynomialDegree2
    var a3, a2, a1, a0: Double
    func f(_ x: Double) -> Double {
        return a3 * x * x * x + a2 * x * x + a1 * x + a0
    }
    var derivative: Derivative {
        return PolynomialDegree2(a2: 3 * a3, a1: 2 * a2, a0: a1)
    }
}

struct PolynomialDegree4: Polynomial {
    typealias Derivative = PolynomialDegree3
    var a4, a3, a2, a1, a0: Double
    func f(_ x: Double) -> Double {
        return a4 * x * x * x * x + a3 * x * x * x + a2 * x * x + a1 * x + a0
    }
    var derivative: Derivative {
        return PolynomialDegree3(a3: 4 * a4, a2: 3 * a3, a1: 2 * a2, a0: a1)
    }
}

struct PolynomialDegree5: Polynomial {
    typealias Derivative = PolynomialDegree4
    var a5, a4, a3, a2, a1, a0: Double
    func f(_ x: Double) -> Double {
        return a5 * x * x * x * x * x + a4 * x * x * x * x + a3 * x * x * x + a2 * x * x + a1 * x + a0
    }
    var derivative: Derivative {
        return PolynomialDegree4(a4: 5 * a5, a3: 4 * a4, a2: 3 * a3, a1: 2 * a2, a0: a1)
    }
}

func findRootBisection<P: Polynomial>(of polynomial: P, start: Double, end: Double) -> Double {
    var guess = (start + end) / 2
    var low = start
    var high = end
    let lowSign = polynomial.f(low).sign
    let highSign = polynomial.f(high).sign
    assert(lowSign != highSign)
   // let derivative = polynomial.derivative
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
    }
    return guess
}

extension Polynomial where Derivative: AnalyticRoots {
    func criticalPoints(between start: Double, and end: Double) -> [Double] {
        return self.derivative.roots.filter { $0 > start && $0 < end }
    }
}

extension Polynomial {
    func criticalPoints(between start: Double, and end: Double) -> [Double] {
        return findRoots(of: self.derivative, between: start, and: end)
    }
}

func findRoots<P: Polynomial>(of polynomial: P, between start: Double, and end: Double) -> [Double] {
    assert(start < end)
    let criticalPoints: [Double] = polynomial.criticalPoints(between: start, and: end)
    let intervals: [Double] = ([start, end] + criticalPoints).sorted()
    let possibleRoots = (0..<intervals.count-1).compactMap { (i: Int) -> Double? in
        let start   = intervals[i]
        let end     = intervals[i+1]
        let fStart  = polynomial.f(start)
        let fEnd    = polynomial.f(end)
        if abs(fStart) < 1.0e-5 {
            return start
        } else if fEnd != 0, fStart.sign != fEnd.sign {
            return findRootBisection(of: polynomial, start: start, end: end)
        }
        return nil
    }
    return possibleRoots
}
