//
//  BezierCurve+Polynomial.swift
//  BezierKit
//
//  Created by Holmes Futrell on 1/22/21.
//  Copyright © 2021 Holmes Futrell. All rights reserved.
//

import Foundation

/// a parametric function whose x and y coordinates can be considered as separate polynomial functions
/// eg `f(t) = (xPolynomial(t), yPolynomial(t))`
public protocol ComponentPolynomials {
    associatedtype Polynomial: BernsteinPolynomial
    var xPolynomial: Polynomial { get }
    var yPolynomial: Polynomial { get }
}

extension LineSegment: ComponentPolynomials {
    public var xPolynomial: BernsteinPolynomial1 { return BernsteinPolynomial1(b0: self.p0.x, b1: self.p1.x) }
    public var yPolynomial: BernsteinPolynomial1 { return BernsteinPolynomial1(b0: self.p0.y, b1: self.p1.y) }
}

extension QuadraticCurve: ComponentPolynomials {
    public var xPolynomial: BernsteinPolynomial2 { return BernsteinPolynomial2(b0: self.p0.x, b1: self.p1.x, b2: self.p2.x) }
    public var yPolynomial: BernsteinPolynomial2 { return BernsteinPolynomial2(b0: self.p0.y, b1: self.p1.y, b2: self.p2.y) }
}

extension CubicCurve: ComponentPolynomials {
    public var xPolynomial: BernsteinPolynomial3 { return BernsteinPolynomial3(b0: self.p0.x, b1: self.p1.x, b2: self.p2.x, b3: self.p3.x) }
    public var yPolynomial: BernsteinPolynomial3 { return BernsteinPolynomial3(b0: self.p0.y, b1: self.p1.y, b2: self.p2.y, b3: self.p3.y) }
}

extension BezierCurve where Self: ComponentPolynomials {
    /// default implementation of `extrema` by finding roots of component polynomials
    public func extrema() -> (x: [CGFloat], y: [CGFloat], all: [CGFloat]) {
        func rootsForPolynomial<B: BernsteinPolynomial>(_ polynomial: B) -> [CGFloat] {
            let firstOrderDerivative = polynomial.derivative
            var roots = findDistinctRootsInUnitInterval(of: firstOrderDerivative)
            if self.order >= 3 {
                let secondOrderDerivative = firstOrderDerivative.derivative
                roots += findDistinctRootsInUnitInterval(of: secondOrderDerivative)
            }
            return roots.sortedAndUniqued()
        }
        let xRoots = rootsForPolynomial(self.xPolynomial)
        let yRoots = rootsForPolynomial(self.yPolynomial)
        let allRoots = (xRoots + yRoots).sortedAndUniqued()
        return (x: xRoots, y: yRoots, all: allRoots)
    }
}
