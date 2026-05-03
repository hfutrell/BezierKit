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

// A Bernstein polynomial of dynamic degree, used only during implicit polynomial composition.
// Conforms to BezierClippingPolynomial so findDistinctRootsCallbackBezierClipping can find its roots.
private struct ImplicitizationPolynomial: BezierClippingPolynomial, Sendable {
    typealias NextLowerOrderPolynomial = ImplicitizationPolynomial

    let coefficients: [CGFloat]

    init(_ coefficients: [CGFloat]) {
        assert(!coefficients.isEmpty)
        self.coefficients = coefficients
    }

    var order: Int { coefficients.count - 1 }
    var degree: Int { order }
    var firstCoefficient: CGFloat { coefficients[0] }
    var lastCoefficient: CGFloat { coefficients[order] }

    func forEachCoefficient(_ body: (CGFloat) -> Void) { coefficients.forEach(body) }

    func value(at t: CGFloat) -> CGFloat { split(at: t).left.coefficients.last! }

    var derivative: ImplicitizationPolynomial {
        let n = order
        guard n > 0 else { return ImplicitizationPolynomial([0]) }
        return ImplicitizationPolynomial((0..<n).map { CGFloat(n) * (coefficients[$0 + 1] - coefficients[$0]) })
    }

    func split(at t: CGFloat) -> (left: ImplicitizationPolynomial, right: ImplicitizationPolynomial) {
        let n = order
        guard n > 0 else { return (self, self) }
        var scratch = coefficients
        var left = [CGFloat](repeating: 0, count: n + 1)
        var right = [CGFloat](repeating: 0, count: n + 1)
        left[0] = scratch[0]
        right[n] = scratch[n]
        for j in 1...n {
            for i in 0...(n - j) {
                scratch[i] = (1 - t) * scratch[i] + t * scratch[i + 1]
            }
            left[j] = scratch[0]
            right[n - j] = scratch[n - j]
        }
        return (ImplicitizationPolynomial(left), ImplicitizationPolynomial(right))
    }

    static func == (l: ImplicitizationPolynomial, r: ImplicitizationPolynomial) -> Bool {
        l.coefficients == r.coefficients
    }

    static func + (l: ImplicitizationPolynomial, r: ImplicitizationPolynomial) -> ImplicitizationPolynomial {
        assert(l.order == r.order)
        return ImplicitizationPolynomial(zip(l.coefficients, r.coefficients).map(+))
    }

    static func * (scalar: CGFloat, poly: ImplicitizationPolynomial) -> ImplicitizationPolynomial {
        ImplicitizationPolynomial(poly.coefficients.map { scalar * $0 })
    }

    // Multiplication in Bernstein form (Sederberg, CAGD §9.3)
    static func * (l: ImplicitizationPolynomial, r: ImplicitizationPolynomial) -> ImplicitizationPolynomial {
        let m = l.order
        let n = r.order
        let result = (0...(m + n)).map { k -> CGFloat in
            let sum = (max(k - n, 0)...min(m, k)).reduce(CGFloat.zero) { acc, i in
                let j = k - i
                return acc + CGFloat(Utils.binomialCoefficient(m, choose: i) * Utils.binomialCoefficient(n, choose: j))
                    * l.coefficients[i] * r.coefficients[j]
            }
            return sum / CGFloat(Utils.binomialCoefficient(m + n, choose: k))
        }
        return ImplicitizationPolynomial(result)
    }
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

    /// Composes the implicit polynomial with parametric coordinate polynomials x(t) and y(t),
    /// then returns the distinct roots in [0,1] — the parameter values where the parametric
    /// curve intersects the implicit curve.
    func findRoots<P: BernsteinPolynomial>(xPolynomial x: P, yPolynomial y: P) -> [CGFloat] {
        let poly = compose(xPolynomial: x, yPolynomial: y)
        var roots: [CGFloat] = []
        findDistinctRootsCallbackBezierClipping(poly) { roots.append($0) }
        return roots
    }

    /// Composes the implicit polynomial with parametric polynomials x(t) and y(t).
    private func compose<P: BernsteinPolynomial>(xPolynomial x: P, yPolynomial y: P) -> ImplicitizationPolynomial {
        assert(x.order == y.order, "x and y coordinate polynomials must have same degree")
        let polynomialOrder = x.order
        let xPoly = ImplicitizationPolynomial(x.coefficients)
        let yPoly = ImplicitizationPolynomial(y.coefficients)
        var xPowers: [ImplicitizationPolynomial] = [ImplicitizationPolynomial([1])]
        var yPowers: [ImplicitizationPolynomial] = [ImplicitizationPolynomial([1])]
        for i in 1...order {
            xPowers.append(xPowers[i - 1] * xPoly)
            yPowers.append(yPowers[i - 1] * yPoly)
        }

        let resultOrder = order * polynomialOrder
        var sum = ImplicitizationPolynomial([CGFloat](repeating: 0, count: resultOrder + 1))
        for i in 0...order {
            let xPower = xPowers[i]
            for j in 0...order {
                let c: CGFloat = coefficient(i, j)
                guard c != 0 else { continue }
                let yPower = yPowers[j]
                let k = resultOrder - xPower.order - yPower.order
                // swiftlint:disable shorthand_operator
                var term = xPower * yPower
                if k > 0 {
                    term = term * ImplicitizationPolynomial([CGFloat](repeating: 1, count: k + 1))
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

    fileprivate static func + (left: ImplicitPolynomial, right: ImplicitPolynomial) -> ImplicitPolynomial {
        assert(left.order == right.order)
        return ImplicitPolynomial(coefficients: zip(left.coefficients, right.coefficients).map(+), order: left.order)
    }

    fileprivate static func - (left: ImplicitPolynomial, right: ImplicitPolynomial) -> ImplicitPolynomial {
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
