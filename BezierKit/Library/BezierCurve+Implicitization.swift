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
    /// composes the implicit polynomial with a parametric polynomial whose coordinates are x(t) and y(t)
    /// the roots of the resulting polynomial are the intersection between the implicit and parametric polynomials
    func value<P: BernsteinPolynomial>(_ x: P, _ y: P) -> BernsteinPolynomialN {
        if let x3 = x as? BernsteinPolynomial3, let y3 = y as? BernsteinPolynomial3 {
            return value(x3, y3)
        }
        return _valueGeneric(x, y)
    }

    /// Specialized zero-allocation path for cubic implicit polynomials (order == 3) composed with
    /// cubic parametric curves. Compared to the generic path, this avoids ~40 heap allocations by
    /// using withUnsafeTemporaryAllocation for all intermediates. The generic value<P> dispatches
    /// here at runtime via a conditional cast, ensuring this path is always taken for cubic curves.
    func value(_ x: BernsteinPolynomial3, _ y: BernsteinPolynomial3) -> BernsteinPolynomialN {
        guard order == 3 else { return _valueGeneric(x, y) }
        // Scratch layout (69 CGFloat slots, stack-allocated via withUnsafeTemporaryAllocation):
        //  [0..3]   x      (deg 3, 4 coefs)
        //  [4..7]   y      (deg 3, 4 coefs)
        //  [8..14]  x²     (deg 6, 7 coefs)
        //  [15..24] x³     (deg 9, 10 coefs)
        //  [25..31] y²     (deg 6, 7 coefs)
        //  [32..41] y³     (deg 9, 10 coefs)
        //  [42..48] x·y    (deg 6, 7 coefs)
        //  [49..58] temp   (10 coefs: x·y² first, then reused for degree elevations)
        //  [59..68] temp2  (10 coefs: x²·y)
        var result = [CGFloat](repeating: .zero, count: 10)
        result.withUnsafeMutableBufferPointer { resultBuf in
            let rp = resultBuf.baseAddress!
            withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 69) { buf in
                let bp = buf.baseAddress!
                bp[0] = x.b0; bp[1] = x.b1; bp[2] = x.b2; bp[3] = x.b3
                bp[4] = y.b0; bp[5] = y.b1; bp[6] = y.b2; bp[7] = y.b3
                bernsteinMul(bp, 3, bp, 3, into: bp + 8)           // x²
                bernsteinMul(bp + 8, 6, bp, 3, into: bp + 15)      // x³
                bernsteinMul(bp + 4, 3, bp + 4, 3, into: bp + 25)  // y²
                bernsteinMul(bp + 25, 6, bp + 4, 3, into: bp + 32) // y³
                bernsteinMul(bp, 3, bp + 4, 3, into: bp + 42)      // x·y
                bernsteinMul(bp, 3, bp + 25, 6, into: bp + 49)     // x·y² → temp[49]
                bernsteinMul(bp + 8, 6, bp + 4, 3, into: bp + 59)  // x²·y → temp[59]
                // Coefficients: c[4i+j] = a[i][j] for x^i * y^j (order=3, so 4×4 matrix)
                let c = self.coefficients
                let a00 = c[0], a01 = c[1], a02 = c[2], a03 = c[3]
                let a10 = c[4], a11 = c[5], a12 = c[6]
                let a20 = c[8], a21 = c[9]
                let a30 = c[12]
                // Degree-9 terms (no elevation needed) — consume temp before overwriting it.
                if a00 != 0 { for k in 0 ..< 10 { rp[k] += a00 } }
                if a12 != 0 { for k in 0 ..< 10 { rp[k] += a12 * bp[49 + k] } }
                if a21 != 0 { for k in 0 ..< 10 { rp[k] += a21 * bp[59 + k] } }
                if a03 != 0 { for k in 0 ..< 10 { rp[k] += a03 * bp[32 + k] } }
                if a30 != 0 { for k in 0 ..< 10 { rp[k] += a30 * bp[15 + k] } }
                // Lower-degree terms requiring elevation to degree 9, reusing temp[49].
                if a01 != 0 {
                    bernsteinElevate(bp + 4, 3, by: 6, into: bp + 49)
                    for k in 0 ..< 10 { rp[k] += a01 * bp[49 + k] }
                }
                if a02 != 0 {
                    bernsteinElevate(bp + 25, 6, by: 3, into: bp + 49)
                    for k in 0 ..< 10 { rp[k] += a02 * bp[49 + k] }
                }
                if a10 != 0 {
                    bernsteinElevate(bp, 3, by: 6, into: bp + 49)
                    for k in 0 ..< 10 { rp[k] += a10 * bp[49 + k] }
                }
                if a11 != 0 {
                    bernsteinElevate(bp + 42, 6, by: 3, into: bp + 49)
                    for k in 0 ..< 10 { rp[k] += a11 * bp[49 + k] }
                }
                if a20 != 0 {
                    bernsteinElevate(bp + 8, 6, by: 3, into: bp + 49)
                    for k in 0 ..< 10 { rp[k] += a20 * bp[49 + k] }
                }
            }
        }
        return BernsteinPolynomialN(coefficients: result)
    }

    private func _valueGeneric<P: BernsteinPolynomial>(_ x: P, _ y: P) -> BernsteinPolynomialN {
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

    fileprivate static func + (left: ImplicitPolynomial, right: ImplicitPolynomial) -> ImplicitPolynomial {
        assert(left.order == right.order)
        return ImplicitPolynomial(coefficients: zip(left.coefficients, right.coefficients).map(+), order: left.order)
    }

    fileprivate static func - (left: ImplicitPolynomial, right: ImplicitPolynomial) -> ImplicitPolynomial {
        assert(left.order == right.order)
        return ImplicitPolynomial(coefficients: zip(left.coefficients, right.coefficients).map(-), order: left.order)
    }
}

// MARK: - Zero-allocation Bernstein arithmetic for the cubic specialization of ImplicitPolynomial.value

private func bernsteinMul(
    _ left: UnsafePointer<CGFloat>, _ m: Int,
    _ right: UnsafePointer<CGFloat>, _ n: Int,
    into result: UnsafeMutablePointer<CGFloat>
) {
    for k in 0 ... m + n {
        let lo = max(k - n, 0)
        let hi = min(m, k)
        var s = CGFloat.zero
        for i in lo ... hi {
            s += Utils.binomialCoefficient(m, choose: i) *
                 Utils.binomialCoefficient(n, choose: k - i) *
                 left[i] * right[k - i]
        }
        result[k] = s / Utils.binomialCoefficient(m + n, choose: k)
    }
}

private func bernsteinElevate(
    _ src: UnsafePointer<CGFloat>, _ d: Int, by e: Int,
    into result: UnsafeMutablePointer<CGFloat>
) {
    for k in 0 ... d + e {
        let lo = max(k - e, 0)
        let hi = min(d, k)
        var s = CGFloat.zero
        for l in lo ... hi {
            s += Utils.binomialCoefficient(d, choose: l) *
                 Utils.binomialCoefficient(e, choose: k - l) *
                 src[l]
        }
        result[k] = s / Utils.binomialCoefficient(d + e, choose: k)
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
