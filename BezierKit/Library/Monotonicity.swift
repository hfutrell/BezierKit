//
//  Monotonicity.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/4/21.
//  Copyright © 2021 Holmes Futrell. All rights reserved.
//

import Foundation

public protocol ComponentMonotonicity {
    var xMonotonic: Bool { get }
    var yMonotonic: Bool { get }
}

extension LineSegment: ComponentMonotonicity {
    public var xMonotonic: Bool { return xPolynomial.isMonotonic }
    public var yMonotonic: Bool { return yPolynomial.isMonotonic }
}

extension QuadraticCurve: ComponentMonotonicity {
    public var xMonotonic: Bool { return xPolynomial.isMonotonic }
    public var yMonotonic: Bool { return yPolynomial.isMonotonic }
}

extension CubicCurve: ComponentMonotonicity {
    public var xMonotonic: Bool { return xPolynomial.isMonotonic }
    public var yMonotonic: Bool { return yPolynomial.isMonotonic }
}

public protocol Monotonicity {
    var isMonotonic: Bool { get }
}

extension BernsteinPolynomial1: Monotonicity {
    public var isMonotonic: Bool { return true }
}

extension BernsteinPolynomial2: Monotonicity {
    // needs unit tests
    public var isMonotonic: Bool {
        if b0 <= b2 {
            return b1 >= b0 && b1 <= b2
        } else {
            return b1 >= b2 && b1 <= b0
        }
    }
}

extension BernsteinPolynomial3: Monotonicity {
    // needs unit tests
    public var isMonotonic: Bool {
        let derivative = self.derivative
        // first check that the derivative
        if derivative.b0 < 0 {
            guard derivative.b2 < 0 else { return false } // derivative changes signs
            guard derivative.b1 > 0 else { return true }  // derivative can't change signs
            let max = derivative.b1 - 0.5 * (derivative.b2 + derivative.b0)
            return max <= 0
        } else {
            guard derivative.b2 >= 0 else { return false } // derivative changes signs
            guard derivative.b1 <= 0 else { return true }  // derivative can't change signs
            let min = derivative.b1 - 0.5 * (derivative.b2 + derivative.b0)
            return min > 0
        }
    }
}
