//
//  RootFinding.swift
//  GraphicsPathNearest
//
//  Created by Holmes Futrell on 2/23/21.
//

import CoreGraphics

public struct RootFindingConfiguration {
    public static let defaultErrorThreshold: CGFloat = 1e-5
    public static let minimumErrorThreshold: CGFloat = 1e-12
    private(set) var errorThreshold: CGFloat
    public init(errorThreshold: CGFloat) {
        precondition(errorThreshold >= RootFindingConfiguration.minimumErrorThreshold)
        self.errorThreshold = errorThreshold
    }
    public static var `default`: RootFindingConfiguration {
        return Self(errorThreshold: RootFindingConfiguration.defaultErrorThreshold)
    }
}

extension BernsteinPolynomialN {
    /// Returns the unique, ordered real roots of the curve that fall within the unit interval `0 <= t <= 1`
    /// the roots are unique and ordered so that for  `i < j` they satisfy `root[i] < root[j]`
    /// - Returns: the array of roots
    public func distinctRealRootsInUnitInterval(configuration: RootFindingConfiguration = .default) -> [CGFloat] {
        guard coefficients.contains(where: { $0 != .zero }) else { return [] }
        let result = BernsteinPolynomialN.rootsOfCurveMappedToRange(self, start: 0, end: 1, configuration: configuration)
        guard result.isEmpty == false else { return [] }
        assert(result == result.sorted())
        // eliminate non-unique roots by comparing against neighbors
        return result.indices.compactMap { i in
            guard i == 0 || result[i] != result[i - 1] else { return nil }
            return result[i]
        }
    }
    private static func rootsOfCurveMappedToRange(_ curve: BernsteinPolynomialN, start rangeStart: CGFloat, end rangeEnd: CGFloat, configuration: RootFindingConfiguration) -> [CGFloat] {
        let n = curve.order
        // find the range where the convex hull of `curve2D` intersects the x-Axis
        var lowerBound = CGFloat.infinity
        var upperBound = -CGFloat.infinity
        for i in 0..<n {
            for j in i+1...n {
                let p1 = CGPoint(x: CGFloat(i) / CGFloat(n), y: curve.coefficients[i])
                let p2 = CGPoint(x: CGFloat(j) / CGFloat(n), y: curve.coefficients[j])
                guard p1.y != 0 || p2.y != 0 else {
                    assert(p2.x >= p1.x)
                    if p1.x < lowerBound { lowerBound = p1.x }
                    if p2.x > upperBound { upperBound = p2.x }
                    continue
                }
                let tLine = -p1.y / (p2.y - p1.y)
                if tLine >= 0, tLine <= 1 {
                    let t = linearInterpolate(p1.x, p2.x, tLine)
                    if t < lowerBound { lowerBound = t }
                    if t > upperBound { upperBound = t }
                }
            }
        }
        // if the range is empty then convex hull doesn't intersect x-Axis, so we're done.
        guard lowerBound.isFinite, upperBound.isFinite else { return [] }
        // if the range where the convex hull intersects the x-Axis is too large
        // we aren't converging quickly, perhaps due to multiple roots.
        // split the curve in half and handle each half separately.
        guard upperBound - lowerBound < 0.8 else {
            let rangeMid = linearInterpolate(rangeStart, rangeEnd, 0.5)
            var curveRoots: [CGFloat] = []
            let (left, right) = curve.split(at: 0.5)
            curveRoots += rootsOfCurveMappedToRange(left, start: rangeStart, end: rangeMid, configuration: configuration)
            curveRoots += rootsOfCurveMappedToRange(right, start: rangeMid, end: rangeEnd, configuration: configuration)
            return curveRoots
        }
        // if the range is small enough that it's within the accuracy threshold
        // we've narrowed it down to a root and we're done
        let nextRangeStart = linearInterpolate(rangeStart, rangeEnd, lowerBound)
        let nextRangeEnd = linearInterpolate(rangeStart, rangeEnd, upperBound)
        guard nextRangeEnd - nextRangeStart > configuration.errorThreshold else {
            let nextRangeMid = linearInterpolate(nextRangeStart, nextRangeEnd, 0.5)
            return [nextRangeMid]
        }
        // split the curve over the range where the convex hull intersected the
        // x-Axis and iterate.
        var curveRoots: [CGFloat] = []
        let subcurve = curve.split(from: lowerBound, to: upperBound)
        func skippedRoot(between first: CGFloat, and second: CGFloat) -> Bool {
            // due to floating point roundoff, it is possible (although rare)
            // for the algorithm to sneak past a root. To avoid this problem
            // we make sure the curve doesn't change sign between the
            // boundaries of the current and next range
            return first > 0 && second < 0 || first < 0 && second > 0
        }
        if skippedRoot(between: curve.coefficients.first!, and: subcurve.coefficients.first!) {
            curveRoots.append(nextRangeStart)
        }
        curveRoots += rootsOfCurveMappedToRange(subcurve, start: nextRangeStart, end: nextRangeEnd, configuration: configuration)
        if skippedRoot(between: subcurve.coefficients.last!, and: curve.coefficients.last!) {
            curveRoots.append(nextRangeEnd)
        }
        return curveRoots
    }
}
