//
//  BezierCurve+Implicitization.swift
//  BezierKit
//
//  Created by Holmes Futrell on 4/1/21.
//  Copyright © 2021 Holmes Futrell. All rights reserved.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

internal protocol Implicitizeable {
    var implicitPolynomial: ImplicitPolynomial { get }
}

/// represents an implicit polynomial, otherwise known as an algebraic curve.
/// The values on the polynomial are the zero set of the polynomial f(x, y) = 0
internal struct ImplicitPolynomial {

    private let coefficients: [CGFloat]

    private let order: Int

    fileprivate init(_ lineProduct: ImplicitLineProduct) {
        coefficients = [lineProduct.a00, lineProduct.a01, lineProduct.a02,
                        lineProduct.a10, lineProduct.a11, 0,
                        lineProduct.a20, 0, 0]
        order = 2
    }

    fileprivate init(_ line: ImplicitLine) {
        coefficients = [line.a00, line.a01, line.a10, 0]
        order = 1
    }

    fileprivate init(coefficients: [CGFloat], order: Int) {
        assert(coefficients.count == (order + 1) * (order + 1))
        self.coefficients = coefficients
        self.order = order
    }

    /// get the coefficient aij for x^i y^j
    private func coefficient(_ i: Int, _ j: Int) -> CGFloat {
        assert(i >= 0 && i <= order && j >= 0 && j <= order)
        return coefficients[(order + 1) * i + j]
    }

    func value<P: BernsteinPolynomial>(_ x: P, _ y: P) -> BernsteinPolynomialN {

        assert(x.order == y.order, "x and y coordinate polynomials must have same degree")
        let polynomialOrder = x.order
        let x = BernsteinPolynomialN(coefficients: x.coefficients)
        let y = BernsteinPolynomialN(coefficients: y.coefficients)
        var xPowers: [BernsteinPolynomialN] = [BernsteinPolynomialN(coefficients: [1])]
        var yPowers: [BernsteinPolynomialN] = [BernsteinPolynomialN(coefficients: [1])]
        for i in 1...order {
            xPowers.append(xPowers[i - 1] * x)
            yPowers.append(yPowers[i - 1] * y)
        }

        let resultOrder = order * polynomialOrder
        var sum: BernsteinPolynomialN = BernsteinPolynomialN(coefficients: [CGFloat](repeating: 0, count: resultOrder + 1))
        for i in 0...order {
            let xPower: BernsteinPolynomialN = xPowers[i]
            for j in 0...order {

                let c: CGFloat = coefficient(i, j)
                guard c != 0 else { continue }

                let yPower: BernsteinPolynomialN = yPowers[j]

                let k = resultOrder - xPower.order - yPower.order

                var term: BernsteinPolynomialN = (xPower * yPower)

                // swiftlint:disable shorthand_operator
                if k > 0 {
                    // bring the term up to degree k
                    term = term * BernsteinPolynomialN(coefficients: [CGFloat](repeating: 1, count: k + 1))
                } else {
                    assert(k == 0, "for k < 0 we should have c == 0")
                }
                sum = sum + c * term
                // swiftlint:enable shorthand_operator
            }
        }
        return sum
    }

    func value(at point: CGPoint) -> CGFloat {
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

    static func + (left: ImplicitPolynomial, right: ImplicitPolynomial) -> ImplicitPolynomial {
        assert(left.order == right.order)
        return ImplicitPolynomial(coefficients: zip(left.coefficients, right.coefficients).map(+), order: left.order)
    }

    static func - (left: ImplicitPolynomial, right: ImplicitPolynomial) -> ImplicitPolynomial {
        assert(left.order == right.order)
        return ImplicitPolynomial(coefficients: zip(left.coefficients, right.coefficients).map(-), order: left.order)
    }
}

private struct ImplicitLineProduct {
    var a20, a11, a10, a02, a01, a00: CGFloat
    static func * (left: ImplicitLine, right: ImplicitLineProduct) -> ImplicitPolynomial {
        let a00 = left.a00 * right.a00
        let a10 = left.a00 * right.a10 + left.a10 * right.a00
        let a20 = left.a10 * right.a10 + left.a00 * right.a20
        let a30 = left.a10 * right.a20

        let a01 = left.a01 * right.a00 + left.a00 * right.a01
        let a11 = left.a10 * right.a01 + left.a00 * right.a11 + left.a01 * right.a10
        let a21 = left.a01 * right.a20 + left.a10 * right.a11
        let a31 = CGFloat.zero

        let a02 = left.a01 * right.a01 + left.a00 * right.a02
        let a12 = left.a10 * right.a02 + left.a01 * right.a11
        let a22 = CGFloat.zero
        let a32 = CGFloat.zero

        let a03 = left.a01 * right.a02
        let a13 = CGFloat.zero
        let a23 = CGFloat.zero
        let a33 = CGFloat.zero

        return ImplicitPolynomial(coefficients: [a00, a01, a02, a03,
                                                 a10, a11, a12, a13,
                                                 a20, a21, a22, a23,
                                                 a30, a31, a32, a33
        ], order: 3)
    }
    static func - (left: ImplicitLineProduct, right: ImplicitLineProduct) -> ImplicitLineProduct {
        return ImplicitLineProduct(a20: left.a20 - right.a20,
                                   a11: left.a11 - right.a11,
                                   a10: left.a10 - right.a10,
                                   a02: left.a02 - right.a02,
                                   a01: left.a01 - right.a01,
                                   a00: left.a00 - right.a00)
    }
}

private struct ImplicitLine {
    var a10, a01, a00: CGFloat
    static func * (left: ImplicitLine, right: ImplicitLine) -> ImplicitLineProduct {
        return ImplicitLineProduct(a20: left.a10 * right.a10,
                                   a11: left.a01 * right.a10 + left.a10 * right.a01,
                                   a10: left.a10 * right.a00 + left.a00 * right.a10,
                                   a02: left.a01 * right.a01,
                                   a01: left.a01 * right.a00 + left.a00 * right.a01,
                                   a00: left.a00 * right.a00)
    }
    static func * (left: CGFloat, right: ImplicitLine) -> ImplicitLine {
        return ImplicitLine(a10: left * right.a10, a01: left * right.a01, a00: left * right.a00)
    }
    static func + (left: ImplicitLine, right: ImplicitLine) -> ImplicitLine {
        return ImplicitLine(a10: left.a10 + right.a10,
                            a01: left.a01 + right.a01,
                            a00: left.a00 + right.a00)
    }
}

private extension BezierCurve {
    func l(_ i: Int, _ j: Int) -> ImplicitLine {
        let n = self.order
        let pi = points[i]
        let pj = points[j]
        let b = CGFloat(Utils.binomialCoefficient(n, choose: i) * Utils.binomialCoefficient(n, choose: j))
        return b * ImplicitLine(a10: pi.y - pj.y, a01: pj.x - pi.x, a00: pi.x * pj.y - pj.x * pi.y)
    }
}

extension LineSegment: Implicitizeable {
    internal var implicitPolynomial: ImplicitPolynomial {
        return ImplicitPolynomial(l(0, 1))
    }
}

extension QuadraticCurve: Implicitizeable {
    internal var implicitPolynomial: ImplicitPolynomial {
        let l20 = l(2, 0)
        let l21 = l(2, 1)
        let l10 = l(1, 0)
        let lineProduct = l21 * l10 - l20 * l20
        return ImplicitPolynomial(lineProduct)
    }
}

extension CubicCurve: Implicitizeable {
    internal var implicitPolynomial: ImplicitPolynomial {
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
