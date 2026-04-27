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

extension BernsteinPolynomialN {

    // Convert Bernstein coefficients to power basis coefficients.
    // a[m] = C(n,m) * sum_{k=0}^{m} (-1)^{m-k} * C(m,k) * b[k]
    private func bernsteinToPowerBasis() -> [Double] {
        let count = coefficients.count
        let n = count - 1
        var a = [Double](repeating: 0, count: count)
        for m in 0...n {
            var sum = 0.0
            var sign = (m % 2 == 0) ? 1.0 : -1.0
            for k in 0...m {
                sum += sign * Double(Utils.binomialCoefficient(m, choose: k)) * Double(coefficients[k])
                sign = -sign
            }
            a[m] = Double(Utils.binomialCoefficient(n, choose: m)) * sum
        }
        return a
    }

    /// Finds real roots in [0,1] using the Aberth-Ehrlich simultaneous iteration.
    /// No LAPACK required. O(n × iterations) per call using power basis + Horner evaluation.
    internal func distinctRootsAberth(imagThreshold: Double = 1e-5) -> [CGFloat] {
        let n = order  // degree; polynomial has n+1 coefficients
        guard n >= 1 else { return [] }

        let coeffD = coefficients.map { Double($0) }

        // Descartes' rule: zero sign changes in Bernstein coefficients → no real roots in (0,1).
        let scale = coeffD.reduce(0.0) { Swift.max($0, Swift.abs($1)) }
        guard scale > 0 else { return [] }
        let signThreshold = scale * 1e-10
        var lastSign = 0
        var hasSignChange = false
        for c in coeffD {
            guard Swift.abs(c) > signThreshold else { continue }
            let s = c > 0 ? 1 : -1
            if lastSign != 0, s != lastSign { hasSignChange = true; break }
            lastSign = s
        }
        guard hasSignChange else { return [] }

        // Convert to power basis for O(n) Horner evaluation.
        let powCoeffs = bernsteinToPowerBasis()  // a[0] + a[1]*t + ... + a[n]*t^n
        let derivPow: [Double] = (0..<n).map { Double($0 + 1) * powCoeffs[$0 + 1] }

        // Buffer: [re[n] | im[n]] — root approximations only.
        return withUnsafeTemporaryAllocation(of: Double.self, capacity: 2 * n) { buf in
            let rePtr = buf.baseAddress!
            let imPtr = buf.baseAddress! + n

            // Initialise roots equally spaced on a circle centred at 0.5, radius 0.45.
            for k in 0..<n {
                let theta = 2.0 * Double.pi * Double(k) / Double(n)
                rePtr[k]  = 0.5 + 0.45 * cos(theta)
                imPtr[k]  = 0.45 * sin(theta)
            }

            let maxIter = 50
            let tolSq   = 1.0e-24

            for _ in 0..<maxIter {
                var maxWMag2 = 0.0
                for k in 0..<n {
                    let zre = rePtr[k], zim = imPtr[k]

                    // Evaluate p(z) via Horner.
                    var pre = powCoeffs[n], pim = 0.0
                    for j in stride(from: n - 1, through: 0, by: -1) {
                        let newre = pre*zre - pim*zim + powCoeffs[j]
                        let newim = pre*zim + pim*zre
                        pre = newre; pim = newim
                    }

                    // Evaluate p'(z) via Horner.
                    var dre = derivPow[n - 1], dim = 0.0
                    for j in stride(from: n - 2, through: 0, by: -1) {
                        let newre = dre*zre - dim*zim + derivPow[j]
                        let newim = dre*zim + dim*zre
                        dre = newre; dim = newim
                    }

                    let dMag2 = dre*dre + dim*dim
                    guard dMag2 > 0 else { continue }

                    // Newton ratio: nr = p(z) / p'(z)
                    let nrRe = ( pre*dre + pim*dim) / dMag2
                    let nrIm = (pim*dre  - pre*dim) / dMag2

                    // Aberth correction sum: Σ_{j≠k} 1 / (z_k − z_j)
                    var sumRe = 0.0, sumIm = 0.0
                    for j in 0..<n where j != k {
                        let dRe = zre - rePtr[j], dIm = zim - imPtr[j]
                        let d2  = dRe*dRe + dIm*dIm
                        if d2 > 0 { sumRe += dRe/d2; sumIm -= dIm/d2 }
                    }

                    // Aberth step: w = nr / (1 − nr · sum)
                    let prodRe  = nrRe*sumRe - nrIm*sumIm
                    let prodIm  = nrRe*sumIm + nrIm*sumRe
                    let denomRe = 1.0 - prodRe, denomIm = -prodIm
                    let denom2  = denomRe*denomRe + denomIm*denomIm
                    guard denom2 > 0 else { continue }
                    let wRe = (nrRe*denomRe + nrIm*denomIm) / denom2
                    let wIm = (nrIm*denomRe - nrRe*denomIm) / denom2

                    rePtr[k] -= wRe
                    imPtr[k] -= wIm
                    maxWMag2 = Swift.max(maxWMag2, wRe*wRe + wIm*wIm)
                }
                if maxWMag2 < tolSq { break }
            }

            // Post-process: near-coincident real pairs indicate a double root.
            // Aberth repulsion keeps them apart; midpoint + multiplicity-2 Newton converges quadratically.
            for k in 0..<n {
                guard Swift.abs(imPtr[k]) <= imagThreshold else { continue }
                for j in (k+1)..<n {
                    guard Swift.abs(imPtr[j]) <= imagThreshold else { continue }
                    guard Swift.abs(rePtr[k] - rePtr[j]) < 1e-4 else { continue }
                    var t = (rePtr[k] + rePtr[j]) * 0.5
                    for _ in 0..<15 {
                        var fv = powCoeffs[n]
                        for j2 in stride(from: n - 1, through: 0, by: -1) { fv = fv * t + powCoeffs[j2] }
                        var dv = derivPow[n - 1]
                        for j2 in stride(from: n - 2, through: 0, by: -1) { dv = dv * t + derivPow[j2] }
                        guard Swift.abs(dv) > 0 else { break }
                        let step = 2.0 * fv / dv
                        t -= step
                        if Swift.abs(step) < 1e-14 { break }
                    }
                    rePtr[k] = t; rePtr[j] = t
                }
            }

            // Collect roots that are real (small imaginary part) and lie in [0,1].
            var roots: [CGFloat] = []
            for k in 0..<n {
                let rk = rePtr[k], ik = imPtr[k]
                guard Swift.abs(ik) <= imagThreshold * (1.0 + Swift.abs(rk)) else { continue }
                guard rk >= 0.0, rk <= 1.0 else { continue }
                roots.append(CGFloat(rk))
            }
            return roots.sorted()
        }
    }
}
