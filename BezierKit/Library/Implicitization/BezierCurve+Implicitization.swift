//
//  BezierCurve+Implicitization.swift
//  BezierKit
//
//  Created by Holmes Futrell on 4/1/21.
//  Copyright © 2021 Holmes Futrell. All rights reserved.
//

import Foundation

public protocol Implicitize {
    var implicitPolynomial: ImplicitPolynomial { get }
}

public struct ImplicitPolynomial {

    fileprivate let coefficients: [CGFloat]
    public let order: Int

    /// get the coefficient aij for x^i y^j
    public func coefficient(_ i: Int, _ j: Int) -> CGFloat {
        assert(i >= 0 && i <= order && j >= 0 && j <= order)
        return coefficients[(order + 1) * i + j]
    }

    // the equation for the line a * x + b * y + c = 0
    public static func line(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat) -> ImplicitPolynomial {
        return ImplicitPolynomial(coefficients: [c, b, a, 0], order: 1)
    }

    public func value(_ x: BernsteinPolynomialN, _ y: BernsteinPolynomialN) -> BernsteinPolynomialN {

        var xPowers: [BernsteinPolynomialN] = [BernsteinPolynomialN(coefficients: [1])]
        var yPowers: [BernsteinPolynomialN] = [BernsteinPolynomialN(coefficients: [1])]
        for i in 1...order {
            xPowers.append(xPowers[i - 1] * x)
            yPowers.append(yPowers[i - 1] * y)
        }

        let resultOrder = order * order
        var sum: BernsteinPolynomialN = BernsteinPolynomialN(coefficients: [CGFloat](repeating: 0, count: resultOrder + 1))
        for i in 0...order {
            let xPower: BernsteinPolynomialN = xPowers[i]
            for j in 0...order {
                let yPower: BernsteinPolynomialN = yPowers[j]

                var term: BernsteinPolynomialN = (xPower * yPower)

                let k = resultOrder - xPower.order - yPower.order
                if k > 0 {
                    // bring the term up to degree k
                    term = term * BernsteinPolynomialN(coefficients: [CGFloat](repeating: 1, count: k + 1))
                } else if k < 0 {
                    assert(coefficient(i, j) == 0)
                    continue
                }
                // swiftlint:disable shorthand_operator
                let c: CGFloat = coefficient(i, j)
                sum = sum + c * term
                // swiftlint:enable shorthand_operator
            }
        }
        return sum
    }

    public func value(_ point: CGPoint) -> CGFloat {
        let x = point.x
        let y = point.y
        var sum: CGFloat = 0
        for i in 0...order {
            for j in 0...order {
                sum += coefficient(i, j) * pow(x, CGFloat(i)) * pow(y, CGFloat(j))
            }
        }
        return sum
    }

    public static func * (left: CGFloat, right: ImplicitPolynomial) -> ImplicitPolynomial {
        return ImplicitPolynomial(coefficients: right.coefficients.map { left * $0 }, order: right.order)
    }

    public static func + (left: ImplicitPolynomial, right: ImplicitPolynomial) -> ImplicitPolynomial {
        assert(left.order == right.order)
        return ImplicitPolynomial(coefficients: zip(left.coefficients, right.coefficients).map(+), order: left.order)
    }

    public static func - (left: ImplicitPolynomial, right: ImplicitPolynomial) -> ImplicitPolynomial {
        assert(left.order == right.order)
        return ImplicitPolynomial(coefficients: zip(left.coefficients, right.coefficients).map(-), order: left.order)
    }

    public static func * (left: ImplicitPolynomial, right: ImplicitPolynomial) -> ImplicitPolynomial {
        let order = left.order + right.order
        var coefficients = [CGFloat](repeating: CGFloat.zero, count: (order+1)*(order+1))
        for i in 0...order {
            for j in 0...order {
                // for each entry in left, see if there is an entry in right such that the power of the x term sums to i
                // and the power of the y term sums to j
                var sum: CGFloat = 0
                for iil in 0...left.order {
                    for jjl in 0...left.order {
                        let iir = i - iil
                        let jjr = j - jjl
                        guard iir >= 0, iir <= right.order else { continue }
                        guard jjr >= 0, jjr <= right.order else { continue }
                        sum += left.coefficient(iil, jjl) * right.coefficient(iir, jjr)
                    }
                }
                coefficients[(order + 1) * i + j] = sum
            }
        }
        return ImplicitPolynomial(coefficients: coefficients, order: order)
    }
}

private extension BezierCurve {
    func l(_ i: Int, _ j: Int) -> ImplicitPolynomial {
        let n = self.order
        let pi = points[i]
        let pj = points[j]
        let b = CGFloat(binomialCoefficient(n, choose: i) * binomialCoefficient(n, choose: j))
        return b * ImplicitPolynomial.line(pi.y - pj.y, pj.x - pi.x, pi.x * pj.y - pj.x * pi.y)
    }
}

extension QuadraticCurve: Implicitize {
    public var implicitPolynomial: ImplicitPolynomial {
        let l20 = l(2, 0)
        let l21 = l(2, 1)
        let l10 = l(1, 0)
        return l21 * l10 - l20 * l20
    }
}

extension CubicCurve: Implicitize {
    public var implicitPolynomial: ImplicitPolynomial {
        let l32 = l(3, 2)
        let l31 = l(3, 1)
        let l30 = l(3, 0)
        let l21 = l(2, 1)
        let l20 = l(2, 0)
        let l10 = l(1, 0)
        let m00 = l32
        let m01 = l31
        let m02 = l30
        let m10 = l31
        let m11 = l30 + l21
        let m12 = l20
        let m20 = l30
        let m21 = l20
        let m22 = l10
        return m00 * (m11 * m22 - m12 * m21)
            - m01 * (m10 * m22 - m12 * m20)
            + m02 * (m10 * m21 - m11 * m20)
    }
}
