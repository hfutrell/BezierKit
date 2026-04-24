//
//  BezierCurve+SylvesterIntersection.swift
//  BezierKit
//
// Cubic Bezier curve intersection via the Sylvester resultant.
//
// Reference: "The Method of Finding Points of Intersection of Two Cubic Bezier
// Curves Using the Sylvester Matrix", B. Biły,
// Silesian J. Pure Appl. Math. vol. 6, is. 1 (2016), pp. 155–176.
//
// Given curves P(s) and Q(t), the system P(s) = Q(t) is written as two
// polynomials in s:
//   F(s, t) = Px(s) - Qx(t) = 0
//   G(s, t) = Py(s) - Qy(t) = 0
//
// The Sylvester resultant Res_s(F, G) — the determinant of the (m+n)×(m+n)
// Sylvester matrix, where m = deg_s(F) and n = deg_s(G) — is a polynomial in
// t of degree ≤ m·n (Bézout bound).  Its real roots in [0, 1] are the curve2
// parameter values at all intersections.  For each such t, the corresponding
// curve1 parameter s is recovered by root-finding on the cubic Bernstein
// polynomial curve1.x(s) − Qx(t) = 0 (or the y-component when better
// conditioned): the "reverse-inverse" step described in the paper.
//
// Both curves are normalised to the unit box before computing the resultant.
// Curve parameters t and s are invariant under affine transformations, so the
// roots are then used directly against the original (un-normalised) curves.

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

// MARK: - Polynomial arithmetic in the power (monomial) basis

// poly[k] = coefficient of t^k, lowest degree first.
private typealias Poly = [Double]

private let zeroPoly: Poly = [0]

@inline(__always)
private func padd(_ a: Poly, _ b: Poly) -> Poly {
    let n = max(a.count, b.count)
    var r = Poly(repeating: 0, count: n)
    for (i, v) in a.enumerated() { r[i] += v }
    for (i, v) in b.enumerated() { r[i] += v }
    return r
}

@inline(__always)
private func psub(_ a: Poly, _ b: Poly) -> Poly {
    let n = max(a.count, b.count)
    var r = Poly(repeating: 0, count: n)
    for (i, v) in a.enumerated() { r[i] += v }
    for (i, v) in b.enumerated() { r[i] -= v }
    return r
}

@inline(__always)
private func pmul(_ a: Poly, _ b: Poly) -> Poly {
    guard !a.isEmpty, !b.isEmpty else { return zeroPoly }
    var r = Poly(repeating: 0, count: a.count + b.count - 1)
    for (i, ai) in a.enumerated() {
        guard ai != 0 else { continue }
        for (j, bj) in b.enumerated() {
            r[i + j] += ai * bj
        }
    }
    return r
}

// MARK: - Determinant via cofactor expansion (generic size)

// Recursively expand the determinant along the first row, skipping zero entries.
private func pdet(_ m: [[Poly]], n: Int) -> Poly {
    switch n {
    case 1:
        return m[0][0]
    case 2:
        return psub(pmul(m[0][0], m[1][1]), pmul(m[0][1], m[1][0]))
    default:
        var result = zeroPoly
        for j in 0..<n {
            let elem = m[0][j]
            guard elem.contains(where: { $0 != 0 }) else { continue }
            // Minor: delete row 0 and column j.
            let minor: [[Poly]] = (1..<n).map { i in
                var row = m[i]; row.remove(at: j); return row
            }
            let cofactor = pdet(minor, n: n - 1)
            let term = pmul(elem, cofactor)
            result = j.isMultiple(of: 2) ? padd(result, term) : psub(result, term)
        }
        return result
    }
}

// MARK: - Basis conversion and helpers

// C(n, k) as a Double.
private func binom(_ n: Int, _ k: Int) -> Double {
    if k <= 0 || k >= n { return k == 0 || k == n ? 1 : 0 }
    let k = min(k, n - k)
    var r = 1.0
    for i in 0..<k { r *= Double(n - i) / Double(i + 1) }
    return r
}

// Convert a power-basis polynomial to a Bernstein polynomial of degree `n`.
// b[i] = Σ_{k=0}^{i} c[k] · C(i,k) / C(n,k)
private func powerToBernstein(_ c: Poly, degree n: Int) -> BernsteinPolynomialN {
    let padded = c + Poly(repeating: 0, count: max(0, n + 1 - c.count))
    let b: [CGFloat] = (0...n).map { i in
        var sum = 0.0
        for k in 0...i { sum += padded[k] * binom(i, k) / binom(n, k) }
        return CGFloat(sum)
    }
    return BernsteinPolynomialN(coefficients: b)
}

// Convert Bezier control values to power-basis coefficients (ascending degree).
// P(t) = p0·(1-t)^3 + 3p1·(1-t)^2·t + 3p2·(1-t)·t^2 + p3·t^3
//       = c0 + c1·t + c2·t² + c3·t³
private func cubicPower(_ p0: Double, _ p1: Double, _ p2: Double, _ p3: Double)
    -> (c0: Double, c1: Double, c2: Double, c3: Double) {
    return (p0, -3*p0 + 3*p1, 3*p0 - 6*p1 + 3*p2, -p0 + 3*p1 - 3*p2 + p3)
}

// MARK: - Sylvester intersection

// Find intersections of two cubic Bezier curves via the Sylvester resultant.
internal func sylvesterIntersections(_ c1: CubicCurve, _ c2: CubicCurve, accuracy: CGFloat) -> [Intersection] {

    // Normalise both curves to the unit box.  Curve parameters (t and s) are
    // invariant under affine transformations, so the roots can be used
    // directly against the original curves.  Normalisation keeps polynomial
    // coefficients in [0, 1] and avoids catastrophic cancellation for curves
    // with large (e.g. screen-pixel) coordinate values.
    let xs = [c1.p0.x, c1.p1.x, c1.p2.x, c1.p3.x, c2.p0.x, c2.p1.x, c2.p2.x, c2.p3.x]
    let ys = [c1.p0.y, c1.p1.y, c1.p2.y, c1.p3.y, c2.p0.y, c2.p1.y, c2.p2.y, c2.p3.y]
    let ox = Double(xs.min()!)
    let oy = Double(ys.min()!)
    let scale = max(Double(xs.max()!) - ox, Double(ys.max()!) - oy, 1.0)
    let inv = 1.0 / scale

    func nx(_ v: CGFloat) -> Double { (Double(v) - ox) * inv }
    func ny(_ v: CGFloat) -> Double { (Double(v) - oy) * inv }

    // Power-basis coefficients of the normalised curves' x and y components.
    let (px0, px1, px2, px3) = cubicPower(nx(c1.p0.x), nx(c1.p1.x), nx(c1.p2.x), nx(c1.p3.x))
    let (py0, py1, py2, py3) = cubicPower(ny(c1.p0.y), ny(c1.p1.y), ny(c1.p2.y), ny(c1.p3.y))
    let (qx0, qx1, qx2, qx3) = cubicPower(nx(c2.p0.x), nx(c2.p1.x), nx(c2.p2.x), nx(c2.p3.x))
    let (qy0, qy1, qy2, qy3) = cubicPower(ny(c2.p0.y), ny(c2.p1.y), ny(c2.p2.y), ny(c2.p3.y))

    // F(s,t) = Px(s) - Qx(t); the s^0 coefficient is f0(t).
    // G(s,t) = Py(s) - Qy(t); the s^0 coefficient is g0(t).
    let f0: Poly = [px0 - qx0, -qx1, -qx2, -qx3]
    let g0: Poly = [py0 - qy0, -qy1, -qy2, -qy3]

    // Determine the effective polynomial degree in s for F and G.
    // The s^k coefficient of F is pxk (a scalar); drop leading zero coefficients.
    // Threshold is relative to normalised-coordinate scale of 1.
    let eps = 1e-10
    let fCoeffs: [Poly]
    if abs(px3) > eps      { fCoeffs = [[px3], [px2], [px1]] }
    else if abs(px2) > eps { fCoeffs = [[px2], [px1]] }
    else if abs(px1) > eps { fCoeffs = [[px1]] }
    else                   { fCoeffs = [] }

    let gCoeffs: [Poly]
    if abs(py3) > eps      { gCoeffs = [[py3], [py2], [py1]] }
    else if abs(py2) > eps { gCoeffs = [[py2], [py1]] }
    else if abs(py1) > eps { gCoeffs = [[py1]] }
    else                   { gCoeffs = [] }

    // If either polynomial is constant in s the parameter cannot be eliminated.
    guard !fCoeffs.isEmpty, !gCoeffs.isEmpty else { return [] }

    let m = fCoeffs.count   // effective degree of F in s
    let n = gCoeffs.count   // effective degree of G in s
    let size = m + n        // Sylvester matrix dimension

    // Build the (m+n)×(m+n) Sylvester matrix.
    // First n rows are shifts of F; last m rows are shifts of G.
    var M = [[Poly]](repeating: [Poly](repeating: zeroPoly, count: size), count: size)
    for k in 0..<n {
        for (i, coeff) in fCoeffs.enumerated() { M[k][k + i] = coeff }
        M[k][k + m] = f0
    }
    for k in 0..<m {
        for (i, coeff) in gCoeffs.enumerated() { M[n + k][k + i] = coeff }
        M[n + k][k + n] = g0
    }

    // Resultant: degree ≤ m·n polynomial in t (Bézout bound).
    let resultant = pdet(M, n: size)
    guard resultant.contains(where: { $0 != 0 }) else { return [] }

    // Trim trailing near-zero coefficients so the Bernstein conversion uses the
    // actual degree of the resultant, not the Bézout upper bound.  Near-zero
    // high-degree terms produce spurious roots when padded into a higher-degree
    // Bernstein polynomial.
    let maxMag = resultant.map { abs($0) }.max() ?? 0
    let trimTol = maxMag * 1e-8
    var trimmed = resultant
    while trimmed.count > 1 && abs(trimmed.last!) < trimTol {
        trimmed.removeLast()
    }
    let effectiveDegree = min(trimmed.count - 1, m * n)
    let bernstein = powerToBernstein(trimmed, degree: effectiveDegree)
    let t2Roots = bernstein.distinctRealRootsInUnitInterval(
        configuration: RootFindingConfiguration(errorThreshold: RootFindingConfiguration.minimumErrorThreshold)
    )

    let insignificantDistance: CGFloat = 0.5 * accuracy
    let t1Tol = insignificantDistance / c1.derivativeBounds
    let t2Tol = insignificantDistance / c2.derivativeBounds

    // For a candidate t2 on curve2, recover t1 on curve1 via the reverse-inverse step:
    // solve curve1.coord(s) = Q(t2).coord for s ∈ [0,1], choosing the coordinate
    // axis with the larger control-point spread for better numerical conditioning.
    func intersectionIfCloseEnough(at t2: CGFloat) -> Intersection? {
        let pt = c2.point(at: t2)
        guard c1.boundingBox.contains(pt) else { return nil }

        let xSpread = max(c1.p0.x, c1.p1.x, c1.p2.x, c1.p3.x) -
                      min(c1.p0.x, c1.p1.x, c1.p2.x, c1.p3.x)
        let ySpread = max(c1.p0.y, c1.p1.y, c1.p2.y, c1.p3.y) -
                      min(c1.p0.y, c1.p1.y, c1.p2.y, c1.p3.y)

        let sRoots: [CGFloat]
        if xSpread >= ySpread {
            let X = pt.x
            sRoots = BernsteinPolynomialN(
                coefficients: [c1.p0.x - X, c1.p1.x - X, c1.p2.x - X, c1.p3.x - X])
                .distinctRealRootsInUnitInterval(
                    configuration: RootFindingConfiguration(
                        errorThreshold: RootFindingConfiguration.minimumErrorThreshold))
        } else {
            let Y = pt.y
            sRoots = BernsteinPolynomialN(
                coefficients: [c1.p0.y - Y, c1.p1.y - Y, c1.p2.y - Y, c1.p3.y - Y])
                .distinctRealRootsInUnitInterval(
                    configuration: RootFindingConfiguration(
                        errorThreshold: RootFindingConfiguration.minimumErrorThreshold))
        }

        // Pick the s root that minimises the 2-D distance to the query point.
        var bestT1: CGFloat?
        var bestDist = accuracy
        for s in sRoots {
            let d = distance(c1.point(at: s), pt)
            if d < bestDist { bestDist = d; bestT1 = s }
        }
        guard var t1 = bestT1 else { return nil }

        if t1 < t1Tol          { t1 = 0 }
        else if t1 > 1 - t1Tol { t1 = 1 }
        return Intersection(t1: t1, t2: t2)
    }

    var intersections = t2Roots.compactMap { t2 -> Intersection? in
        guard t2 >= t2Tol, t2 <= 1 - t2Tol else { return nil }
        return intersectionIfCloseEnough(at: t2)
    }

    // Explicitly test endpoints of curve2 (t2 = 0 and t2 = 1).
    if !intersections.contains(where: { $0.t2 == 0 }),
       let i = intersectionIfCloseEnough(at: 0) { intersections.append(i) }
    if !intersections.contains(where: { $0.t2 == 1 }),
       let i = intersectionIfCloseEnough(at: 1) { intersections.append(i) }

    return intersections.sortedAndUniqued()
}
