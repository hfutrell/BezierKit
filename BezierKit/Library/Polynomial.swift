//
//  Polynomial.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/15/20.
//  Copyright © 2020 Holmes Futrell. All rights reserved.
//

import CoreGraphics

protocol Polynomial {
    associatedtype Derivative: Polynomial
    func f(_ x: Double, _ scratchPad: UnsafeMutableBufferPointer<Double>) -> Double
    var derivative: Derivative { get }
    var order: Int { get }
    func analyticalRoots(between start: Double, and end: Double) -> [Double]?
}

extension Array: Polynomial where Element == Double {
    typealias Derivative = Self
    var order: Int { return self.count - 1 }
    func f(_ x: Double, _ scratchPad: UnsafeMutableBufferPointer<Double>) -> Double {
        assert(scratchPad.count >= self.count, "scratchpad will fail here.")
        let count = self.count
        guard count > 0 else { return 0 }
        let oneMinusX = 1.0 - x
        self.withUnsafeBufferPointer { (points: UnsafeBufferPointer<Double>) in
            var i = 0
            while i < count {
                scratchPad[i] = points[i]
                i += 1
            }
            i = count - 1
            while i > 0 {
                var j = 0
                repeat {
                    scratchPad[j] = oneMinusX * scratchPad[j] + x * scratchPad[j+1]
                    j += 1
                } while j < i
                i -= 1
            }
        }
        return scratchPad[0]
    }
    var derivative: [Double] {
        let bufferCapacity = self.order
        guard bufferCapacity > 0 else { return [] }
        let n = Double(bufferCapacity)
        return [Double](unsafeUninitializedCapacity: bufferCapacity) { (buffer: inout UnsafeMutableBufferPointer<Double>, count: inout Int) in
            for i in 0..<bufferCapacity {
                buffer[i] = n * (self[i+1] - self[i])
            }
            count = bufferCapacity
        }
    }
    func analyticalRoots(between start: Double, and end: Double) -> [Double]? {
        let order = self.order
        guard order > 0 else { return [] }
        guard order < 4 else { return nil } // cannot solve
        return Utils.droots(self.map { CGFloat($0) }).compactMap {
            let t = Double($0)
            guard t > start, t < end else { return nil }
            return t
        }.sortedAndUniqued()
    }
}

private func newton<P: Polynomial>(polynomial: P, derivative: P.Derivative, guess: Double, relaxation: Double = 1, scratchPad: UnsafeMutableBufferPointer<Double>) -> Double {
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

func findRoots<P: Polynomial>(of polynomial: P, between start: Double, and end: Double, scratchPad: UnsafeMutableBufferPointer<Double>) -> [Double] {
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
            let mid = (start + end ) / 2
            root = newton(polynomial: polynomial, derivative: derivative, guess: mid, scratchPad: scratchPad)
            guard start < root, root < end else { return nil }
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
