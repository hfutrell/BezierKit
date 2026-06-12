//
//  Polynomial.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/15/20.
//  Copyright © 2020 Holmes Futrell. All rights reserved.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

protocol AnalyticalRootsCallback {
    func forEachAnalyticalDistinctRoot(between start: CGFloat, and end: CGFloat, _ callback: (CGFloat) -> Void)
}

public protocol BernsteinPolynomial: Equatable, Sendable {
    associatedtype NextLowerOrderPolynomial: BernsteinPolynomial
    func value(at x: CGFloat) -> CGFloat
    var derivative: NextLowerOrderPolynomial { get }
}

/// Default split/value-and-derivative behavior for the concrete BP types (declared as
/// requirements on BezierClippingPolynomial in BernsteinPolynomial+RootFinding.swift).
internal extension BezierClippingPolynomial {
    func valueAndDerivative(at x: CGFloat) -> (CGFloat, CGFloat) {
        (value(at: x), derivative.value(at: x))
    }
    func split(from t1: CGFloat, to t2: CGFloat) -> Self {
        guard t1 != 0 else { return split(at: t2).left }
        let right = split(at: t1).right
        guard t2 != 1 else { return right }
        return right.split(at: (t2 - t1) / (1 - t1)).left
    }
}

extension BernsteinPolynomial0: AnalyticalRootsCallback {
    func forEachAnalyticalDistinctRoot(between start: CGFloat, and end: CGFloat, _ callback: (CGFloat) -> Void) {}
}

extension BernsteinPolynomial1: AnalyticalRootsCallback {
    func forEachAnalyticalDistinctRoot(between start: CGFloat, and end: CGFloat, _ callback: (CGFloat) -> Void) {
        Utils.droots(b0, b1) {
            guard $0 >= start, $0 <= end else { return }
            callback($0)
        }
    }
}

extension BernsteinPolynomial2: AnalyticalRootsCallback {
    func forEachAnalyticalDistinctRoot(between start: CGFloat, and end: CGFloat, _ callback: (CGFloat) -> Void) {
        Utils.droots(b0, b1, b2) {
            guard $0 >= start, $0 <= end else { return }
            callback($0)
        }
    }
}

extension BernsteinPolynomial3: AnalyticalRootsCallback {
    func forEachAnalyticalDistinctRoot(between start: CGFloat, and end: CGFloat, _ callback: (CGFloat) -> Void) {
        Utils.droots(b0, b1, b2, b3) {
            guard $0 >= start, $0 <= end else { return }
            callback($0)
        }
    }
}

public struct BernsteinPolynomial0: BernsteinPolynomial {
    public init(b0: CGFloat) { self.b0 = b0 }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial0
    public var b0: CGFloat
    public func value(at x: CGFloat) -> CGFloat { b0 }
    public var derivative: BernsteinPolynomial0 { BernsteinPolynomial0(b0: 0.0) }
    public func split(at t: CGFloat) -> (left: BernsteinPolynomial0, right: BernsteinPolynomial0) {
        (left: self, right: self)
    }
}

public struct BernsteinPolynomial1: BernsteinPolynomial {
    public init(b0: CGFloat, b1: CGFloat) {
        self.b0 = b0
        self.b1 = b1
    }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial0
    public var b0, b1: CGFloat
    public func value(at x: CGFloat) -> CGFloat { (1.0 - x) * b0 + x * b1 }
    public var derivative: BernsteinPolynomial0 { BernsteinPolynomial0(b0: b1 - b0) }
    public func split(at t: CGFloat) -> (left: BernsteinPolynomial1, right: BernsteinPolynomial1) {
        let h = Utils.linearInterpolate(b0, b1, t)
        return (left: BernsteinPolynomial1(b0: b0, b1: h),
                right: BernsteinPolynomial1(b0: h, b1: b1))
    }
}

public struct BernsteinPolynomial2: BernsteinPolynomial {
    public init(b0: CGFloat, b1: CGFloat, b2: CGFloat) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
    }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial1
    public var b0, b1, b2: CGFloat
    public func value(at x: CGFloat) -> CGFloat {
        let s = 1 - x, t = x
        return s * (s * b0 + t * b1) + t * (s * b1 + t * b2)
    }
    public var derivative: BernsteinPolynomial1 {
        BernsteinPolynomial1(b0: 2 * (b1 - b0), b1: 2 * (b2 - b1))
    }
    public func split(at t: CGFloat) -> (left: BernsteinPolynomial2, right: BernsteinPolynomial2) {
        let h00 = Utils.linearInterpolate(b0, b1, t)
        let h01 = Utils.linearInterpolate(b1, b2, t)
        let h10 = Utils.linearInterpolate(h00, h01, t)
        return (left: BernsteinPolynomial2(b0: b0, b1: h00, b2: h10),
                right: BernsteinPolynomial2(b0: h10, b1: h01, b2: b2))
    }
}

public struct BernsteinPolynomial3: BernsteinPolynomial {
    public init(b0: CGFloat, b1: CGFloat, b2: CGFloat, b3: CGFloat) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.b3 = b3
    }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial2
    public var b0, b1, b2, b3: CGFloat
    public func value(at x: CGFloat) -> CGFloat {
        let s = 1 - x, t = x
        let c10 = s * b0 + t * b1; let c11 = s * b1 + t * b2; let c12 = s * b2 + t * b3
        let c20 = s * c10 + t * c11; let c21 = s * c11 + t * c12
        return s * c20 + t * c21
    }
    public var derivative: BernsteinPolynomial2 {
        BernsteinPolynomial2(b0: 3 * (b1 - b0), b1: 3 * (b2 - b1), b2: 3 * (b3 - b2))
    }
    public func split(at t: CGFloat) -> (left: BernsteinPolynomial3, right: BernsteinPolynomial3) {
        let h00 = Utils.linearInterpolate(b0, b1, t)
        let h01 = Utils.linearInterpolate(b1, b2, t)
        let h02 = Utils.linearInterpolate(b2, b3, t)
        let h10 = Utils.linearInterpolate(h00, h01, t)
        let h11 = Utils.linearInterpolate(h01, h02, t)
        let h20 = Utils.linearInterpolate(h10, h11, t)
        return (left: BernsteinPolynomial3(b0: b0, b1: h00, b2: h10, b3: h20),
                right: BernsteinPolynomial3(b0: h20, b1: h11, b2: h02, b3: b3))
    }
}

public struct BernsteinPolynomial4: BernsteinPolynomial {
    public init(b0: CGFloat, b1: CGFloat, b2: CGFloat, b3: CGFloat, b4: CGFloat) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.b3 = b3
        self.b4 = b4
    }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial3
    public var b0, b1, b2, b3, b4: CGFloat
    public var derivative: BernsteinPolynomial3 {
        BernsteinPolynomial3(b0: 4 * (b1 - b0), b1: 4 * (b2 - b1), b2: 4 * (b3 - b2), b3: 4 * (b4 - b3))
    }
    public func value(at x: CGFloat) -> CGFloat {
        valueAndDerivative(at: x).0
    }
    public func valueAndDerivative(at x: CGFloat) -> (CGFloat, CGFloat) {
        let s = 1 - x, t = x
        let c10 = s * b0 + t * b1; let c11 = s * b1 + t * b2
        let c12 = s * b2 + t * b3; let c13 = s * b3 + t * b4
        let c20 = s * c10 + t * c11; let c21 = s * c11 + t * c12; let c22 = s * c12 + t * c13
        let c30 = s * c20 + t * c21; let c31 = s * c21 + t * c22
        return (s * c30 + t * c31, 4 * (c31 - c30))
    }
    public func split(at t: CGFloat) -> (left: BernsteinPolynomial4, right: BernsteinPolynomial4) {
        let h00 = Utils.linearInterpolate(b0, b1, t)
        let h01 = Utils.linearInterpolate(b1, b2, t)
        let h02 = Utils.linearInterpolate(b2, b3, t)
        let h03 = Utils.linearInterpolate(b3, b4, t)
        let h10 = Utils.linearInterpolate(h00, h01, t)
        let h11 = Utils.linearInterpolate(h01, h02, t)
        let h12 = Utils.linearInterpolate(h02, h03, t)
        let h20 = Utils.linearInterpolate(h10, h11, t)
        let h21 = Utils.linearInterpolate(h11, h12, t)
        let h30 = Utils.linearInterpolate(h20, h21, t)
        return (left: BernsteinPolynomial4(b0: b0, b1: h00, b2: h10, b3: h20, b4: h30),
                right: BernsteinPolynomial4(b0: h30, b1: h21, b2: h12, b3: h03, b4: b4))
    }
}

public struct BernsteinPolynomial5: BernsteinPolynomial {
    public init(b0: CGFloat, b1: CGFloat, b2: CGFloat, b3: CGFloat, b4: CGFloat, b5: CGFloat) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.b3 = b3
        self.b4 = b4
        self.b5 = b5
    }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial4
    public var b0, b1, b2, b3, b4, b5: CGFloat
    public var derivative: BernsteinPolynomial4 {
        BernsteinPolynomial4(b0: 5 * (b1 - b0), b1: 5 * (b2 - b1), b2: 5 * (b3 - b2), b3: 5 * (b4 - b3), b4: 5 * (b5 - b4))
    }
    public func value(at x: CGFloat) -> CGFloat {
        valueAndDerivative(at: x).0
    }
    public func valueAndDerivative(at x: CGFloat) -> (CGFloat, CGFloat) {
        let s = 1 - x, t = x
        let c10 = s * b0 + t * b1; let c11 = s * b1 + t * b2
        let c12 = s * b2 + t * b3; let c13 = s * b3 + t * b4; let c14 = s * b4 + t * b5
        let c20 = s * c10 + t * c11; let c21 = s * c11 + t * c12
        let c22 = s * c12 + t * c13; let c23 = s * c13 + t * c14
        let c30 = s * c20 + t * c21; let c31 = s * c21 + t * c22; let c32 = s * c22 + t * c23
        let c40 = s * c30 + t * c31; let c41 = s * c31 + t * c32
        return (s * c40 + t * c41, 5 * (c41 - c40))
    }
    public func split(at t: CGFloat) -> (left: BernsteinPolynomial5, right: BernsteinPolynomial5) {
        let h00 = Utils.linearInterpolate(b0, b1, t)
        let h01 = Utils.linearInterpolate(b1, b2, t)
        let h02 = Utils.linearInterpolate(b2, b3, t)
        let h03 = Utils.linearInterpolate(b3, b4, t)
        let h04 = Utils.linearInterpolate(b4, b5, t)
        let h10 = Utils.linearInterpolate(h00, h01, t)
        let h11 = Utils.linearInterpolate(h01, h02, t)
        let h12 = Utils.linearInterpolate(h02, h03, t)
        let h13 = Utils.linearInterpolate(h03, h04, t)
        let h20 = Utils.linearInterpolate(h10, h11, t)
        let h21 = Utils.linearInterpolate(h11, h12, t)
        let h22 = Utils.linearInterpolate(h12, h13, t)
        let h30 = Utils.linearInterpolate(h20, h21, t)
        let h31 = Utils.linearInterpolate(h21, h22, t)
        let h40 = Utils.linearInterpolate(h30, h31, t)
        return (left: BernsteinPolynomial5(b0: b0, b1: h00, b2: h10, b3: h20, b4: h30, b5: h40),
                right: BernsteinPolynomial5(b0: h40, b1: h31, b2: h22, b3: h13, b4: h04, b5: b5))
    }
}

// MARK: - High-degree polynomials (6–9) for the curve/curve implicitization fallback.
// These run only when monotone subdivision cannot resolve a near-coincident pair, so they
// favor a compact iterative de Casteljau over the unrolled scalar form used for degree ≤ 5.

// Iterative de Casteljau evaluation. `c` (count = degree + 1) is consumed.
private func deCasteljauValueAndDerivative(_ c: UnsafeMutableBufferPointer<CGFloat>, at x: CGFloat) -> (CGFloat, CGFloat) {
    let n = c.count - 1
    let s = 1 - x
    var count = n
    while count > 1 {
        for i in 0..<count { c[i] = s * c[i] + x * c[i + 1] }
        count -= 1
    }
    return (s * c[0] + x * c[1], CGFloat(n) * (c[1] - c[0]))
}

// Iterative de Casteljau split at t. `c` is consumed; `left`/`right` (each count = degree + 1) receive the halves.
private func deCasteljauSplit(_ c: UnsafeMutableBufferPointer<CGFloat>, at t: CGFloat,
                              left: UnsafeMutableBufferPointer<CGFloat>, right: UnsafeMutableBufferPointer<CGFloat>) {
    let n = c.count - 1
    let s = 1 - t
    left[0] = c[0]; right[n] = c[n]
    for r in 1...n {
        for i in 0...(n - r) { c[i] = s * c[i] + t * c[i + 1] }
        left[r] = c[0]
        right[n - r] = c[n - r]
    }
}

public struct BernsteinPolynomial6: BernsteinPolynomial {
    public init(b0: CGFloat, b1: CGFloat, b2: CGFloat, b3: CGFloat, b4: CGFloat, b5: CGFloat, b6: CGFloat) {
        self.b0 = b0; self.b1 = b1; self.b2 = b2; self.b3 = b3; self.b4 = b4; self.b5 = b5; self.b6 = b6
    }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial5
    public var b0, b1, b2, b3, b4, b5, b6: CGFloat
    public var derivative: BernsteinPolynomial5 {
        BernsteinPolynomial5(b0: 6 * (b1 - b0), b1: 6 * (b2 - b1), b2: 6 * (b3 - b2),
                             b3: 6 * (b4 - b3), b4: 6 * (b5 - b4), b5: 6 * (b6 - b5))
    }
    public func value(at x: CGFloat) -> CGFloat { valueAndDerivative(at: x).0 }
    public func valueAndDerivative(at x: CGFloat) -> (CGFloat, CGFloat) {
        withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 7) { c in
            c[0] = b0; c[1] = b1; c[2] = b2; c[3] = b3; c[4] = b4; c[5] = b5; c[6] = b6
            return deCasteljauValueAndDerivative(c, at: x)
        }
    }
    public func split(at t: CGFloat) -> (left: BernsteinPolynomial6, right: BernsteinPolynomial6) {
        withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 21) { buf in
            let c = UnsafeMutableBufferPointer(start: buf.baseAddress!, count: 7)
            let l = UnsafeMutableBufferPointer(start: buf.baseAddress! + 7, count: 7)
            let r = UnsafeMutableBufferPointer(start: buf.baseAddress! + 14, count: 7)
            c[0] = b0; c[1] = b1; c[2] = b2; c[3] = b3; c[4] = b4; c[5] = b5; c[6] = b6
            deCasteljauSplit(c, at: t, left: l, right: r)
            return (BernsteinPolynomial6(b0: l[0], b1: l[1], b2: l[2], b3: l[3], b4: l[4], b5: l[5], b6: l[6]),
                    BernsteinPolynomial6(b0: r[0], b1: r[1], b2: r[2], b3: r[3], b4: r[4], b5: r[5], b6: r[6]))
        }
    }
}

public struct BernsteinPolynomial7: BernsteinPolynomial {
    public init(b0: CGFloat, b1: CGFloat, b2: CGFloat, b3: CGFloat, b4: CGFloat, b5: CGFloat, b6: CGFloat, b7: CGFloat) {
        self.b0 = b0; self.b1 = b1; self.b2 = b2; self.b3 = b3; self.b4 = b4; self.b5 = b5; self.b6 = b6; self.b7 = b7
    }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial6
    public var b0, b1, b2, b3, b4, b5, b6, b7: CGFloat
    public var derivative: BernsteinPolynomial6 {
        BernsteinPolynomial6(b0: 7 * (b1 - b0), b1: 7 * (b2 - b1), b2: 7 * (b3 - b2), b3: 7 * (b4 - b3),
                             b4: 7 * (b5 - b4), b5: 7 * (b6 - b5), b6: 7 * (b7 - b6))
    }
    public func value(at x: CGFloat) -> CGFloat { valueAndDerivative(at: x).0 }
    public func valueAndDerivative(at x: CGFloat) -> (CGFloat, CGFloat) {
        withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 8) { c in
            c[0] = b0; c[1] = b1; c[2] = b2; c[3] = b3; c[4] = b4; c[5] = b5; c[6] = b6; c[7] = b7
            return deCasteljauValueAndDerivative(c, at: x)
        }
    }
    public func split(at t: CGFloat) -> (left: BernsteinPolynomial7, right: BernsteinPolynomial7) {
        withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 24) { buf in
            let c = UnsafeMutableBufferPointer(start: buf.baseAddress!, count: 8)
            let l = UnsafeMutableBufferPointer(start: buf.baseAddress! + 8, count: 8)
            let r = UnsafeMutableBufferPointer(start: buf.baseAddress! + 16, count: 8)
            c[0] = b0; c[1] = b1; c[2] = b2; c[3] = b3; c[4] = b4; c[5] = b5; c[6] = b6; c[7] = b7
            deCasteljauSplit(c, at: t, left: l, right: r)
            return (BernsteinPolynomial7(b0: l[0], b1: l[1], b2: l[2], b3: l[3], b4: l[4], b5: l[5], b6: l[6], b7: l[7]),
                    BernsteinPolynomial7(b0: r[0], b1: r[1], b2: r[2], b3: r[3], b4: r[4], b5: r[5], b6: r[6], b7: r[7]))
        }
    }
}

public struct BernsteinPolynomial8: BernsteinPolynomial {
    public init(b0: CGFloat, b1: CGFloat, b2: CGFloat, b3: CGFloat, b4: CGFloat, b5: CGFloat, b6: CGFloat, b7: CGFloat, b8: CGFloat) {
        self.b0 = b0; self.b1 = b1; self.b2 = b2; self.b3 = b3; self.b4 = b4; self.b5 = b5; self.b6 = b6; self.b7 = b7; self.b8 = b8
    }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial7
    public var b0, b1, b2, b3, b4, b5, b6, b7, b8: CGFloat
    public var derivative: BernsteinPolynomial7 {
        BernsteinPolynomial7(b0: 8 * (b1 - b0), b1: 8 * (b2 - b1), b2: 8 * (b3 - b2), b3: 8 * (b4 - b3),
                             b4: 8 * (b5 - b4), b5: 8 * (b6 - b5), b6: 8 * (b7 - b6), b7: 8 * (b8 - b7))
    }
    public func value(at x: CGFloat) -> CGFloat { valueAndDerivative(at: x).0 }
    public func valueAndDerivative(at x: CGFloat) -> (CGFloat, CGFloat) {
        withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 9) { c in
            c[0] = b0; c[1] = b1; c[2] = b2; c[3] = b3; c[4] = b4; c[5] = b5; c[6] = b6; c[7] = b7; c[8] = b8
            return deCasteljauValueAndDerivative(c, at: x)
        }
    }
    public func split(at t: CGFloat) -> (left: BernsteinPolynomial8, right: BernsteinPolynomial8) {
        withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 27) { buf in
            let c = UnsafeMutableBufferPointer(start: buf.baseAddress!, count: 9)
            let l = UnsafeMutableBufferPointer(start: buf.baseAddress! + 9, count: 9)
            let r = UnsafeMutableBufferPointer(start: buf.baseAddress! + 18, count: 9)
            c[0] = b0; c[1] = b1; c[2] = b2; c[3] = b3; c[4] = b4; c[5] = b5; c[6] = b6; c[7] = b7; c[8] = b8
            deCasteljauSplit(c, at: t, left: l, right: r)
            return (BernsteinPolynomial8(b0: l[0], b1: l[1], b2: l[2], b3: l[3], b4: l[4], b5: l[5], b6: l[6], b7: l[7], b8: l[8]),
                    BernsteinPolynomial8(b0: r[0], b1: r[1], b2: r[2], b3: r[3], b4: r[4], b5: r[5], b6: r[6], b7: r[7], b8: r[8]))
        }
    }
}

public struct BernsteinPolynomial9: BernsteinPolynomial {
    public init(b0: CGFloat, b1: CGFloat, b2: CGFloat, b3: CGFloat, b4: CGFloat, b5: CGFloat, b6: CGFloat, b7: CGFloat, b8: CGFloat, b9: CGFloat) {
        self.b0 = b0; self.b1 = b1; self.b2 = b2; self.b3 = b3; self.b4 = b4
        self.b5 = b5; self.b6 = b6; self.b7 = b7; self.b8 = b8; self.b9 = b9
    }
    public typealias NextLowerOrderPolynomial = BernsteinPolynomial8
    public var b0, b1, b2, b3, b4, b5, b6, b7, b8, b9: CGFloat
    public var derivative: BernsteinPolynomial8 {
        BernsteinPolynomial8(b0: 9 * (b1 - b0), b1: 9 * (b2 - b1), b2: 9 * (b3 - b2), b3: 9 * (b4 - b3), b4: 9 * (b5 - b4),
                             b5: 9 * (b6 - b5), b6: 9 * (b7 - b6), b7: 9 * (b8 - b7), b8: 9 * (b9 - b8))
    }
    public func value(at x: CGFloat) -> CGFloat { valueAndDerivative(at: x).0 }
    public func valueAndDerivative(at x: CGFloat) -> (CGFloat, CGFloat) {
        withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 10) { c in
            c[0] = b0; c[1] = b1; c[2] = b2; c[3] = b3; c[4] = b4; c[5] = b5; c[6] = b6; c[7] = b7; c[8] = b8; c[9] = b9
            return deCasteljauValueAndDerivative(c, at: x)
        }
    }
    public func split(at t: CGFloat) -> (left: BernsteinPolynomial9, right: BernsteinPolynomial9) {
        withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: 30) { buf in
            let c = UnsafeMutableBufferPointer(start: buf.baseAddress!, count: 10)
            let l = UnsafeMutableBufferPointer(start: buf.baseAddress! + 10, count: 10)
            let r = UnsafeMutableBufferPointer(start: buf.baseAddress! + 20, count: 10)
            c[0] = b0; c[1] = b1; c[2] = b2; c[3] = b3; c[4] = b4; c[5] = b5; c[6] = b6; c[7] = b7; c[8] = b8; c[9] = b9
            deCasteljauSplit(c, at: t, left: l, right: r)
            return (BernsteinPolynomial9(b0: l[0], b1: l[1], b2: l[2], b3: l[3], b4: l[4], b5: l[5], b6: l[6], b7: l[7], b8: l[8], b9: l[9]),
                    BernsteinPolynomial9(b0: r[0], b1: r[1], b2: r[2], b3: r[3], b4: r[4], b5: r[5], b6: r[6], b7: r[7], b8: r[8], b9: r[9]))
        }
    }
}

// Finds roots in [0, 1]. Uses analytical formulas for degree ≤ 3, bezier clipping for degree ≥ 4.
// With WMO (whole-module optimization) the conformance check is a compile-time constant and generates no branch overhead.
public func findDistinctRootsInUnitInterval<P: BernsteinPolynomial>(of polynomial: P) -> [CGFloat] {
    var result: [CGFloat] = []
    if let analytical = polynomial as? AnalyticalRootsCallback {
        // Expand the search window by a tiny epsilon so roots that land just outside
        // [0,1] due to floating-point rounding in the analytical formula aren't silently
        // dropped, then clamp back. Roots come in sorted order from the analytical path,
        // so deduplication via result.last is safe.
        let eps: CGFloat = 1e-10
        analytical.forEachAnalyticalDistinctRoot(between: -eps, and: 1 + eps) {
            let t = Swift.max(0, Swift.min(1, $0))
            if result.last.map({ t - $0 > eps }) ?? true { result.append(t) }
        }
    } else if let clippable = polynomial as? any BezierClippingPolynomial {
        // degree ≥ 4 (BernsteinPolynomial4 … BernsteinPolynomial9): every concrete type conforms
        // to BezierClippingPolynomial, so route through the clipping root finder generically.
        findDistinctRootsCallbackBezierClipping(clippable) { result.append($0) }
    }
    return result
}
