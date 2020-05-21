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
    var order: Int { get }
    func analyticalRoots(between start: Double, and end: Double) -> [Double]?
}

extension Array: Polynomial where Element == Double {
    typealias Derivative = Self
    var order: Int { return self.count - 1 }
    func f(_ x: Double) -> Double {
        assert(self.count <= 16, "_FixedArray16 will fail here.")
        var scratchPad = _FixedArray16<Double>()
        self.forEach { scratchPad.append($0) }
        return scratchPad.withUnsafeMutableBufferPointer { buffer in
            let oneMinusX = 1.0 - x
            self.withUnsafeBufferPointer { points in
                for i in (0..<points.count).reversed() {
                    for j in 0..<i {
                        buffer[j] = oneMinusX * buffer[j] + x * buffer[j+1]
                    }
                }
            }
            return buffer[0]
        }
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
        if order == 0 {
            return []
        } else if order == 1 {
            let p0 = self[0]
            let p1 = self[1]
            guard p0 * p1 < 0 else { return [] }
            let t = p0 / (p0 - p1)
            guard t > start, t < end else { return [] }
            return [t]
        }
        return nil
    }
}

func newton<P: Polynomial>(polynomial: P, derivative: P.Derivative, guess: Double, relaxation: Double = 1) -> Double {
    let maxIterations = 20
    var x = guess
    for _ in 0..<maxIterations {
        let f = polynomial.f(x)
        guard f != 0.0 else { break }
        let fPrime = derivative.f(x)
        let delta = relaxation * f / fPrime
        guard abs(delta) > 1.0e-10 else { break }
        x -= delta
    }
    return x
}

func findRoots<P: Polynomial>(of polynomial: P, between start: Double, and end: Double) -> [Double] {
    assert(start < end)
    if let roots = polynomial.analyticalRoots(between: start, and: end) {
        return roots
    }
    let derivative = polynomial.derivative
    let criticalPoints: [Double] = findRoots(of: derivative, between: start, and: end)
    let intervals: [Double] = ([start, end] + criticalPoints).sorted()
    let possibleRoots = (0..<intervals.count-1).compactMap { (i: Int) -> Double? in
        let start   = intervals[i]
        let end     = intervals[i+1]
        let fStart  = polynomial.f(start)
        let fEnd    = polynomial.f(end)
        if fStart * fEnd < 0 {
            return newton(polynomial: polynomial, derivative: derivative, guess: (start + end ) / 2)
        } else {
            let value = newton(polynomial: polynomial, derivative: derivative, guess: end)
            guard value > start, value <= end else {
                return nil // possibly converged to wrong root
            }
            guard abs(end - value) < abs(start - value) else {
                return nil // possibly converged to wrong root
            }
            guard polynomial.f(value) < 1.0e-10 else {
                return nil // not actually a root
            }
            return value
        }
    }
    return possibleRoots
}
