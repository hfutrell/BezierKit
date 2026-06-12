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

/// Represents an implicit polynomial (an algebraic curve): the zero set of f(x, y) = 0.
/// Used only by the curve/curve intersection fallback when monotone subdivision cannot
/// resolve a near-coincident pair. Composing the implicit polynomial of one curve with the
/// parametric polynomials of the other yields a univariate polynomial whose roots are the
/// intersection parameters; those roots are found with the fixed-degree Bézier-clipping root
/// finder (BernsteinPolynomial4/6/9), so there is a single root-finding implementation.
internal struct ImplicitPolynomial {

    private let coefficients: [CGFloat]
    private let order: Int

    fileprivate init(_ lineProduct: ImplicitLineProduct) {
        coefficients = [lineProduct.a00, lineProduct.a01, lineProduct.a02,
                        lineProduct.a10, lineProduct.a11, 0,
                        lineProduct.a20, 0, 0]
        order = 2
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

    fileprivate static func + (left: ImplicitPolynomial, right: ImplicitPolynomial) -> ImplicitPolynomial {
        assert(left.order == right.order)
        return ImplicitPolynomial(coefficients: zip(left.coefficients, right.coefficients).map(+), order: left.order)
    }

    fileprivate static func - (left: ImplicitPolynomial, right: ImplicitPolynomial) -> ImplicitPolynomial {
        assert(left.order == right.order)
        return ImplicitPolynomial(coefficients: zip(left.coefficients, right.coefficients).map(-), order: left.order)
    }

    /// Composes the implicit polynomial with a parametric curve whose coordinate polynomials have
    /// Bernstein coefficients x[0..paramOrder] and y[0..paramOrder], and invokes `callback` for each
    /// distinct root in (0, 1) of the resulting degree (order × paramOrder) polynomial.
    func forEachRootOfComposition(xCoeffs: UnsafePointer<CGFloat>, yCoeffs: UnsafePointer<CGFloat>,
                                  paramOrder p: Int, _ callback: (CGFloat) -> Void) {
        let resultOrder = order * p
        withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: resultOrder + 1) { out in
            compose(xCoeffs: xCoeffs, yCoeffs: yCoeffs, paramOrder: p, into: out.baseAddress!)
            switch resultOrder {
            case 4:
                findDistinctRootsCallbackBezierClipping(
                    BernsteinPolynomial4(b0: out[0], b1: out[1], b2: out[2], b3: out[3], b4: out[4]), callback)
            case 6:
                findDistinctRootsCallbackBezierClipping(
                    BernsteinPolynomial6(b0: out[0], b1: out[1], b2: out[2], b3: out[3],
                                         b4: out[4], b5: out[5], b6: out[6]), callback)
            case 9:
                findDistinctRootsCallbackBezierClipping(
                    BernsteinPolynomial9(b0: out[0], b1: out[1], b2: out[2], b3: out[3], b4: out[4],
                                         b5: out[5], b6: out[6], b7: out[7], b8: out[8], b9: out[9]), callback)
            default:
                assertionFailure("unexpected composed degree \(resultOrder)")
            }
        }
    }

    /// Writes the Bernstein coefficients of f(x(t), y(t)) (degree order × paramOrder) into `out`.
    private func compose(xCoeffs: UnsafePointer<CGFloat>, yCoeffs: UnsafePointer<CGFloat>,
                         paramOrder p: Int, into out: UnsafeMutablePointer<CGFloat>) {
        let m = order
        let resultOrder = m * p
        for k in 0...resultOrder { out[k] = 0 }
        // Scratch: x powers (m+1 slots of stride 10), y powers (same), one term and one elevated term.
        withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 110) { buf in
            let base = buf.baseAddress!
            let xPow = base          // x^i at xPow + i*10 (degree i*p)
            let yPow = base + 40     // y^j at yPow + j*10 (degree j*p)
            let term = base + 80     // x^i·y^j (degree (i+j)*p)
            let elev = base + 90     // term elevated to resultOrder
            xPow[0] = 1; yPow[0] = 1
            for k in 0...p { xPow[10 + k] = xCoeffs[k]; yPow[10 + k] = yCoeffs[k] }
            if m >= 2 {
                for i in 2...m {
                    bernsteinMul(xPow + 10, p, xPow + (i - 1) * 10, (i - 1) * p, into: xPow + i * 10)
                    bernsteinMul(yPow + 10, p, yPow + (i - 1) * 10, (i - 1) * p, into: yPow + i * 10)
                }
            }
            for i in 0...m {
                for j in 0...m {
                    let c = coefficient(i, j)
                    guard c != 0 else { continue }
                    let termOrder = (i + j) * p
                    if i == 0 && j == 0 {
                        term[0] = 1
                    } else if i == 0 {
                        for k in 0...termOrder { term[k] = yPow[j * 10 + k] }
                    } else if j == 0 {
                        for k in 0...termOrder { term[k] = xPow[i * 10 + k] }
                    } else {
                        bernsteinMul(xPow + i * 10, i * p, yPow + j * 10, j * p, into: term)
                    }
                    let e = resultOrder - termOrder
                    let src: UnsafeMutablePointer<CGFloat>
                    if e > 0 {
                        bernsteinElevate(term, termOrder, by: e, into: elev)
                        src = elev
                    } else {
                        src = term
                    }
                    for k in 0...resultOrder { out[k] += c * src[k] }
                }
            }
        }
    }
}

// MARK: - Zero-allocation Bernstein arithmetic for implicit-polynomial composition

private func bernsteinMul(
    _ left: UnsafePointer<CGFloat>, _ m: Int,
    _ right: UnsafePointer<CGFloat>, _ n: Int,
    into result: UnsafeMutablePointer<CGFloat>
) {
    withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 30) { tmp in
        let mRow = tmp.baseAddress!
        let nRow = tmp.baseAddress! + 10
        let mnRow = tmp.baseAddress! + 20
        for i in 0 ... m { mRow[i] = Utils.binomialCoefficient(m, choose: i) }
        for i in 0 ... n { nRow[i] = Utils.binomialCoefficient(n, choose: i) }
        for i in 0 ... m + n { mnRow[i] = Utils.binomialCoefficient(m + n, choose: i) }
        for k in 0 ... m + n {
            let lo = max(k - n, 0)
            let hi = min(m, k)
            var s = CGFloat.zero
            for i in lo ... hi {
                s += mRow[i] * nRow[k - i] * left[i] * right[k - i]
            }
            result[k] = s / mnRow[k]
        }
    }
}

private func bernsteinElevate(
    _ src: UnsafePointer<CGFloat>, _ d: Int, by e: Int,
    into result: UnsafeMutablePointer<CGFloat>
) {
    withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 30) { tmp in
        let dRow = tmp.baseAddress!
        let eRow = tmp.baseAddress! + 10
        let deRow = tmp.baseAddress! + 20
        for i in 0 ... d { dRow[i] = Utils.binomialCoefficient(d, choose: i) }
        for i in 0 ... e { eRow[i] = Utils.binomialCoefficient(e, choose: i) }
        for i in 0 ... d + e { deRow[i] = Utils.binomialCoefficient(d + e, choose: i) }
        for k in 0 ... d + e {
            let lo = max(k - e, 0)
            let hi = min(d, k)
            var s = CGFloat.zero
            for l in lo ... hi {
                s += dRow[l] * eRow[k - l] * src[l]
            }
            result[k] = s / deRow[k]
        }
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
