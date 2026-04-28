//
//  RootFinding.swift
//  GraphicsPathNearest
//
//  Created by Holmes Futrell on 2/23/21.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

struct RootFindingConfiguration {
    static let defaultErrorThreshold: CGFloat = 1e-5
    static let minimumErrorThreshold: CGFloat = 1e-12
    private(set) var errorThreshold: CGFloat
    init(errorThreshold: CGFloat) {
        precondition(errorThreshold >= RootFindingConfiguration.minimumErrorThreshold)
        self.errorThreshold = errorThreshold
    }
    static var `default`: RootFindingConfiguration {
        return Self(errorThreshold: RootFindingConfiguration.defaultErrorThreshold)
    }
}

extension BernsteinPolynomialN {

    /// Calls `callback` for each unique, ordered real root in `[0, 1]`.
    /// Roots are emitted in ascending order with exact duplicates suppressed inline.
    func forEachDistinctRootInUnitInterval(configuration: RootFindingConfiguration = .default, _ callback: (CGFloat) -> Void) {
        guard coefficients.contains(where: { $0 != .zero }) else { return }
        var lastRoot = CGFloat.infinity
        BernsteinPolynomialN.rootsCore(
            polynomial: self,
            rangeStart: 0.0, rangeEnd: 1.0,
            configuration: configuration,
            callback: {
                guard $0 != lastRoot else { return }
                lastRoot = $0
                callback($0)
            }
        )
    }

    /// Returns the unique, ordered real roots of the curve that fall within the unit interval `0 <= t <= 1`
    /// the roots are unique and ordered so that for  `i < j` they satisfy `root[i] < root[j]`
    /// - Returns: the array of roots
    func distinctRealRootsInUnitInterval(configuration: RootFindingConfiguration = .default) -> [CGFloat] {
        var results: [CGFloat] = []
        forEachDistinctRootInUnitInterval(configuration: configuration) { results.append($0) }
        return results
    }

    // Counts sign changes in Bernstein coefficients (skipping zeros per Descartes' rule).
    private static func countSignChanges(_ coefficients: [CGFloat]) -> Int {
        var count = 0
        var lastSign: Int = 0
        for c in coefficients {
            guard c != 0 else { continue }
            let s = c > 0 ? 1 : -1
            if lastSign != 0 && s != lastSign { count += 1 }
            lastSign = s
        }
        return count
    }

    // Monotone-decomposition root finder for Bernstein polynomials.
    // polynomial is Bernstein-parameterized on [0,1], corresponding to [rangeStart, rangeEnd].
    //
    // By Descartes' rule for Bernstein form, the number of sign changes in the
    // coefficients is an upper bound on the number of roots in (0,1). When there
    // is exactly one sign change (strict crossing), there is exactly one interior
    // root and bisection is used. Otherwise the interval is subdivided at the
    // midpoint until each piece has zero or one sign change.
    private static func rootsCore(
        polynomial: BernsteinPolynomialN,
        rangeStart: CGFloat,
        rangeEnd: CGFloat,
        configuration: RootFindingConfiguration,
        callback: (CGFloat) -> Void
    ) {
        let n = polynomial.order
        let coeffs = polynomial.coefficients
        let b0 = coeffs[0]
        let bn = coeffs[n]

        // Roots exactly at endpoints.
        if b0 == 0 { callback(rangeStart) }
        if bn == 0 { callback(rangeEnd) }

        // Sign changes upper-bound the number of roots in the open interval (0, 1).
        let signChanges = countSignChanges(coeffs)
        guard signChanges > 0 else { return }

        guard rangeEnd - rangeStart > configuration.errorThreshold else {
            // Interval too small to subdivide further: emit midpoint for any crossing.
            if b0 * bn < 0 { callback(0.5 * (rangeStart + rangeEnd)) }
            return
        }

        // One sign change and a strict crossing: bisect to find the single interior root.
        if signChanges == 1, b0 * bn < 0 {
            bisectRoot(polynomial: polynomial,
                       rangeStart: rangeStart, rangeEnd: rangeEnd,
                       fa: b0, fb: bn,
                       configuration: configuration,
                       callback: callback)
            return
        }

        // Multiple sign changes (or endpoint zero with interior roots): subdivide at midpoint.
        let mid = 0.5 * (rangeStart + rangeEnd)
        let (left, right) = polynomial.split(at: 0.5)
        rootsCore(polynomial: left, rangeStart: rangeStart, rangeEnd: mid,
                  configuration: configuration, callback: callback)
        rootsCore(polynomial: right, rangeStart: mid, rangeEnd: rangeEnd,
                  configuration: configuration, callback: callback)
    }

    // Bisects a monotone interval known to contain exactly one root (fa * fb < 0).
    private static func bisectRoot(
        polynomial: BernsteinPolynomialN,
        rangeStart: CGFloat,
        rangeEnd: CGFloat,
        fa: CGFloat,
        fb: CGFloat,
        configuration: RootFindingConfiguration,
        callback: (CGFloat) -> Void
    ) {
        guard rangeEnd - rangeStart > configuration.errorThreshold else {
            callback(0.5 * (rangeStart + rangeEnd))
            return
        }
        let mid = 0.5 * (rangeStart + rangeEnd)
        let (left, right) = polynomial.split(at: 0.5)
        let fm = left.coefficients[left.order]
        if fm == 0 {
            callback(mid)
        } else if fa * fm < 0 {
            bisectRoot(polynomial: left, rangeStart: rangeStart, rangeEnd: mid,
                       fa: fa, fb: fm, configuration: configuration, callback: callback)
        } else {
            bisectRoot(polynomial: right, rangeStart: mid, rangeEnd: rangeEnd,
                       fa: fm, fb: fb, configuration: configuration, callback: callback)
        }
    }
}
