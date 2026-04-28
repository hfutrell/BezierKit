//
//  ChebyshevRootFinding.swift
//  BezierKit
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

// MARK: - Entry point on BernsteinPolynomialN

extension BernsteinPolynomialN {

    /// Root finding via Chebyshev colleague matrix + Francis QR.
    /// No external dependencies — pure Double arithmetic.
    func forEachDistinctRootInUnitIntervalChebyshev(
        configuration: RootFindingConfiguration = .default,
        _ callback: (CGFloat) -> Void
    ) {
        let b = coefficients.map { Double($0) }
        let n = b.count - 1
        guard n >= 1 else { return }
        let tol = Double(configuration.errorThreshold)
        let roots = chebyshevCompanionRoots(bernsteinCoefficients: b, degree: n)
        var last = -Double.infinity
        for r in roots {
            guard r - last >= tol else { continue }
            last = r
            callback(CGFloat(r))
        }
    }

    func distinctRealRootsInUnitIntervalChebyshev(
        configuration: RootFindingConfiguration = .default
    ) -> [CGFloat] {
        var result = [CGFloat]()
        forEachDistinctRootInUnitIntervalChebyshev(configuration: configuration) {
            result.append($0)
        }
        return result
    }
}

// MARK: - Top-level pipeline

/// Bernstein coefficients on [0,1] → real roots in [0,1] via Chebyshev colleague matrix.
private func chebyshevCompanionRoots(bernsteinCoefficients b: [Double], degree n: Int) -> [Double] {
    let N = n + 1
    // Phase 1: evaluate at Chebyshev nodes and check for uniform sign.
    // If all n+1 node values share the same sign there are no simple real roots → skip QR.
    // This is an O(n²) check vs the O(n³) QR, so worth doing eagerly.
    var c = [Double](repeating: 0, count: N)
    var cosTheta = [Double](repeating: 0, count: N)
    withUnsafeTemporaryAllocation(of: Double.self, capacity: N) { scratch in
        var allPos = true, allNeg = true, scale = 0.0
        // Include Bernstein endpoint values b[0]=p(0) and b[n]=p(1) in the sign check:
        // Chebyshev interior nodes don't reach t=0 or t=1 exactly, so a root right at a
        // boundary would otherwise go undetected by the sign-change test.
        for v in [b[0], b[n]] {
            scale = Swift.max(scale, abs(v))
            if v < 0 { allPos = false }
            if v > 0 { allNeg = false }
        }
        for j in 0...n {
            let theta = (Double(2 * j + 1) * Double.pi) / Double(2 * N)
            cosTheta[j] = cos(theta)
            let tj = (cosTheta[j] + 1.0) * 0.5
            let fj = deCasteljau(b, degree: n, at: tj, scratch: scratch.baseAddress!)
            c[j] = fj          // reuse c[] as f[] for now
            scale = Swift.max(scale, abs(fj))
            if fj < 0 { allPos = false }
            if fj > 0 { allNeg = false }
        }
        guard scale > 0 else { c[0] = .infinity; return }  // signal "zero poly"
        // Nodes near zero could be roots — only skip if all values are clearly same-sign.
        let threshold = scale * 1e-10
        if allPos || allNeg {
            var safeToSkip = true
            if abs(b[0]) <= threshold || abs(b[n]) <= threshold { safeToSkip = false }
            if safeToSkip {
                for j in 0...n { if abs(c[j]) <= threshold { safeToSkip = false; break } }
            }
            if safeToSkip { c[0] = .infinity; return }  // signal "no roots"
        }
        // Phase 2: DCT — compute Chebyshev coefficients from node values via recurrence.
        // c[j] currently holds f[j]; overwrite with Chebyshev coefficients.
        let f = Array(c[0...n])   // save node values
        for k in 0...n { c[k] = 0 }
        for j in 0...n {
            let xj = cosTheta[j]
            let fj = f[j]
            var T0 = 1.0, T1 = xj
            c[0] += fj
            if n >= 1 { c[1] += fj * xj }
            for k in 2...n {
                let T2 = 2 * xj * T1 - T0
                c[k] += fj * T2
                T0 = T1; T1 = T2
            }
        }
        let factor = 2.0 / Double(N)
        c[0] *= factor * 0.5
        for k in 1...n { c[k] *= factor }
    }
    guard c[0] != .infinity else { return [] }

    // Trim leading near-zero Chebyshev coefficients to find effective degree
    let scale2 = c.map(abs).max() ?? 0
    guard scale2 > 0 else { return [] }
    var deg = n
    while deg > 0 && abs(c[deg]) < 1e-14 * scale2 { deg -= 1 }
    guard deg >= 1 else { return [] }
    c = Array(c[0...deg])

    // Linear case: c[0] + c[1]*x = 0
    if deg == 1 {
        let x = -c[0] / c[1]
        guard x >= -1 - 1e-9 && x <= 1 + 1e-9 else { return [] }
        return [chebyshevClamp((x + 1) / 2)]
    }

    // Allocate companion matrix (deg²) + Hessenberg scratch (deg) from the stack.
    let eigenvalues: [Double] = withUnsafeTemporaryAllocation(
        of: Double.self, capacity: deg * deg + deg
    ) { buf in
        let mat = buf.baseAddress!
        let scratch = mat + deg * deg
        buildColleagueMatrix(c: c, deg: deg, into: mat)
        hessenbergReduce(mat, n: deg, scratch: scratch)
        return qrEigenvalues(mat, n: deg)
    }

    let cScale = c.map(abs).max() ?? 1
    var result = [Double]()
    result.reserveCapacity(deg)
    for ev in eigenvalues {
        guard ev >= -1 - 1e-9 && ev <= 1 + 1e-9 else { continue }
        let polished = newtonPolishChebyshev(c, start: ev)
        guard polished >= -1 - 1e-9 && polished <= 1 + 1e-9 else { continue }
        guard abs(evalChebyshev(c, at: polished)) <= 1e-6 * cScale else { continue }
        result.append(chebyshevClamp((polished + 1) / 2))
    }
    result.sort()
    return result
}

private func chebyshevClamp(_ x: Double) -> Double {
    return Swift.max(0.0, Swift.min(1.0, x))
}

private func evalChebyshev(_ c: [Double], at x: Double) -> Double {
    var T0 = 1.0, T1 = x
    var result = c[0]
    if c.count > 1 { result += c[1] * T1 }
    for k in 2..<c.count {
        let T2 = 2 * x * T1 - T0
        result += c[k] * T2
        T0 = T1; T1 = T2
    }
    return result
}

private func evalChebyshevAndDeriv(_ c: [Double], at x: Double) -> (Double, Double) {
    var T0 = 1.0, T1 = x, dT0 = 0.0, dT1 = 1.0
    var val = c[0], deriv = 0.0
    if c.count > 1 { val += c[1] * T1; deriv += c[1] * dT1 }
    for k in 2..<c.count {
        let T2 = 2 * x * T1 - T0
        let dT2 = 2 * T1 + 2 * x * dT1 - dT0
        val += c[k] * T2; deriv += c[k] * dT2
        T0 = T1; T1 = T2; dT0 = dT1; dT1 = dT2
    }
    return (val, deriv)
}

private func newtonPolishChebyshev(_ c: [Double], start x0: Double) -> Double {
    var x = x0
    for _ in 0..<20 {
        let (f, fp) = evalChebyshevAndDeriv(c, at: x)
        guard abs(fp) > 1e-30 else { break }
        let dx = f / fp
        x -= dx
        if abs(dx) < 1e-14 { break }
    }
    return x
}

// MARK: - Stage 1: de Casteljau evaluation

/// Evaluate the Bernstein polynomial at t via de Casteljau (numerically stable).
/// scratch must point to at least degree+1 Doubles of temporary storage.
@inline(__always)
private func deCasteljau(_ b: [Double], degree n: Int, at t: Double, scratch: UnsafeMutablePointer<Double>) -> Double {
    let s = 1.0 - t
    b.withUnsafeBufferPointer { bp in
        for i in 0...n { scratch[i] = bp[i] }
    }
    for j in 1...n {
        for i in 0...(n - j) { scratch[i] = s * scratch[i] + t * scratch[i + 1] }
    }
    return scratch[0]
}

// MARK: - Stage 2: Colleague (Chebyshev companion) matrix

/// Build the deg×deg colleague matrix (row-major) whose eigenvalues are
/// the roots of p(x) = Σ_{k=0}^{deg} c[k] T_k(x).
///
/// Structure:
///   Row 0:       C[0,1] = 1
///   Row k (0 < k < deg−1):  C[k,k−1] = 1/2,  C[k,k+1] = 1/2
///   Row deg−1:   C[deg−1,k] = −c[k]/(2c[deg]),  plus C[deg−1,deg−2] += 1/2
private func buildColleagueMatrix(c: [Double], deg: Int, into A: UnsafeMutablePointer<Double>) {
    let n = deg
    A.initialize(repeating: 0, count: n * n)
    A[0 * n + 1] = 1.0
    for k in 1..<(n - 1) {
        A[k * n + (k - 1)] = 0.5
        A[k * n + (k + 1)] = 0.5
    }
    let cn2 = 2.0 * c[n]
    for k in 0..<n { A[(n - 1) * n + k] = -c[k] / cn2 }
    A[(n - 1) * n + (n - 2)] += 0.5
}

// MARK: - Stage 3a: Hessenberg reduction

/// Reduce A (n×n, row-major) to upper Hessenberg form in place
/// via Householder similarity: A ← P A P for each column.
/// scratch must point to at least n Doubles of temporary storage.
private func hessenbergReduce(_ A: UnsafeMutablePointer<Double>, n: Int, scratch v: UnsafeMutablePointer<Double>) {
    guard n > 2 else { return }
    for j in 0..<(n - 2) {
        // Build Householder vector v for column j, rows j+1..n−1
        var norm2 = 0.0
        for i in (j + 1)..<n { norm2 += A[i * n + j] * A[i * n + j] }
        let norm = norm2.squareRoot()
        guard norm > 1e-15 else { continue }

        for i in 0..<n { v[i] = 0.0 }
        for i in (j + 1)..<n { v[i] = A[i * n + j] }
        let s = v[j + 1] >= 0 ? norm : -norm
        v[j + 1] += s
        var vNorm2 = 0.0
        for i in (j + 1)..<n { vNorm2 += v[i] * v[i] }
        guard vNorm2 > 1e-30 else { continue }
        let beta = 2.0 / vNorm2

        // Apply P from left: A ← P A  (modifies rows j+1..n−1)
        // Cols 0..j-1 are already zero in rows j+1..n-1 due to prior steps.
        for col in j..<n {
            var dot = 0.0
            for i in (j + 1)..<n { dot += v[i] * A[i * n + col] }
            dot *= beta
            for i in (j + 1)..<n { A[i * n + col] -= dot * v[i] }
        }

        // Apply P from right: A ← A P  (modifies cols j+1..n−1)
        for row in 0..<n {
            var dot = 0.0
            for i in (j + 1)..<n { dot += A[row * n + i] * v[i] }
            dot *= beta
            for i in (j + 1)..<n { A[row * n + i] -= dot * v[i] }
        }

        // Explicitly zero sub-Hessenberg entries for numerical cleanliness
        for i in (j + 2)..<n { A[i * n + j] = 0.0 }
    }
}

// MARK: - Stage 3b: Francis implicit double-shift QR

/// Compute real eigenvalues of upper Hessenberg H (n×n, modified in place).
private func qrEigenvalues(_ H: UnsafeMutablePointer<Double>, n: Int) -> [Double] {
    var eigenvalues = [Double]()
    eigenvalues.reserveCapacity(n)
    var q = n - 1
    var iter = 0
    let maxIter = 30 * n

    while q >= 0 {
        if q == 0 {
            eigenvalues.append(H[0])
            break
        }

        if iter > maxIter {
            for i in 0...q { eigenvalues.append(H[i * n + i]) }
            return eigenvalues
        }

        // Bottom deflation
        let sc0 = abs(H[(q - 1) * n + (q - 1)]) + abs(H[q * n + q])
        if sc0 == 0 || abs(H[q * n + (q - 1)]) <= 1e-13 * sc0 {
            H[q * n + (q - 1)] = 0
            eigenvalues.append(H[q * n + q])
            q -= 1; iter = 0
            continue
        }

        // Find p: top of active unreduced block
        var p = q - 1
        while p > 0 {
            let sc1 = abs(H[(p - 1) * n + (p - 1)]) + abs(H[p * n + p])
            if sc1 == 0 || abs(H[p * n + (p - 1)]) <= 1e-13 * sc1 {
                H[p * n + (p - 1)] = 0
                break
            }
            p -= 1
        }

        // 2×2 block: solve analytically
        if q - p == 1 {
            let a = H[p * n + p],     b = H[p * n + q]
            let c = H[q * n + p],     d = H[q * n + q]
            let tr = a + d
            let disc = tr * tr - 4 * (a * d - b * c)
            if disc >= 0 {
                let sq = disc.squareRoot()
                eigenvalues.append((tr + sq) * 0.5)
                eigenvalues.append((tr - sq) * 0.5)
            }
            q = p - 1; iter = 0
            continue
        }

        // Block size ≥ 3: apply Francis double-shift step
        francisStep(H, n: n, p: p, q: q)
        iter += 1
    }

    return eigenvalues
}

// MARK: - Stage 3c: Francis double-shift bulge chase

/// One Francis implicit double-shift QR step on the active block H[p..q, p..q].
/// Uses 3-element Householder reflections at every chase position.
@inline(__always)
private func francisStep(_ H: UnsafeMutablePointer<Double>, n: Int, p: Int, q: Int) {
    // Double shift from trailing 2×2
    let s = H[(q - 1) * n + (q - 1)] + H[q * n + q]
    let t = H[(q - 1) * n + (q - 1)] * H[q * n + q]
           - H[(q - 1) * n + q] * H[q * n + (q - 1)]

    // Initial 3-vector: first column of (H − λ₁I)(H − λ₂I)
    // Using M = H² − sH + tI and the fact that for upper Hessenberg,
    // M[p,p]   = H[p,p]² + H[p,p+1]·H[p+1,p] − s·H[p,p] + t
    // M[p+1,p] = H[p+1,p]·(H[p,p] + H[p+1,p+1] − s)
    // M[p+2,p] = H[p+2,p+1]·H[p+1,p]   (H[p+2,p]=0 for Hessenberg)
    var x = H[p * n + p] * H[p * n + p]
           + H[p * n + (p + 1)] * H[(p + 1) * n + p]
           - s * H[p * n + p] + t
    var y = H[(p + 1) * n + p] * (H[p * n + p] + H[(p + 1) * n + (p + 1)] - s)
    var z = H[(p + 2) * n + (p + 1)] * H[(p + 1) * n + p]

    for k in p...(q - 2) {
        let r = (x * x + y * y + z * z).squareRoot()
        guard r > 1e-15 else {
            if k < q - 2 {
                x = H[(k + 1) * n + k]
                y = H[(k + 2) * n + k]
                z = k + 3 <= q ? H[(k + 3) * n + k] : 0.0
            }
            continue
        }
        let sig = x >= 0 ? 1.0 : -1.0
        let v0 = x + sig * r, v1 = y, v2 = z
        let beta = 2.0 / (v0 * v0 + v1 * v1 + v2 * v2)

        // Apply Householder from left: rows k, k+1, k+2.
        // Hessenberg structure: cols 0..k-2 are zero in these rows, so start from k-1.
        let colStart = k > 0 ? k - 1 : 0
        for col in colStart..<n {
            let d = (v0 * H[k * n + col] + v1 * H[(k + 1) * n + col] + v2 * H[(k + 2) * n + col]) * beta
            H[k * n + col]       -= d * v0
            H[(k + 1) * n + col] -= d * v1
            H[(k + 2) * n + col] -= d * v2
        }

        // Apply Householder from right: cols k, k+1, k+2.
        // The bulge is at most at row k+3; rows k+4..n-1 have zero entries in these cols.
        let rowEnd = n < k + 4 ? n : k + 4
        for row in 0..<rowEnd {
            let d = (v0 * H[row * n + k] + v1 * H[row * n + (k + 1)] + v2 * H[row * n + (k + 2)]) * beta
            H[row * n + k]       -= d * v0
            H[row * n + (k + 1)] -= d * v1
            H[row * n + (k + 2)] -= d * v2
        }

        // Update bulge vector for next step (entries in column k after the step)
        if k < q - 2 {
            x = H[(k + 1) * n + k]
            y = H[(k + 2) * n + k]
            z = k + 3 <= q ? H[(k + 3) * n + k] : 0.0
        }
    }
}
