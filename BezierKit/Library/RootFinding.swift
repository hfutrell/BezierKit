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
    /// Zero-allocation beyond the arena (which is heap-allocated when count is a runtime value).
    func forEachDistinctRootInUnitInterval(configuration: RootFindingConfiguration = .default, _ callback: (CGFloat) -> Void) {
        guard coefficients.contains(where: { $0 != .zero }) else { return }
        let count = coefficients.count
        let maxDepth = 48
        coefficients.withUnsafeBufferPointer { inputPtr in
            withUnsafeTemporaryAllocation(of: CGFloat.self, capacity: maxDepth * 4 * count) { arenaPtr in
                // Wrap callback with inline deduplication so rootsCore stays at 8 parameters.
                // lastRoot is captured by reference across all recursive rootsCore calls.
                var lastRoot = CGFloat.infinity
                BernsteinPolynomialN.rootsCore(
                    coefficients: inputPtr,
                    count: count,
                    start: 0, end: 1,
                    configuration: configuration,
                    arena: arenaPtr,
                    depth: 0,
                    callback: {
                        guard $0 != lastRoot else { return }
                        lastRoot = $0
                        callback($0)
                    }
                )
            }
        }
    }

    /// Returns the unique, ordered real roots of the curve that fall within the unit interval `0 <= t <= 1`
    /// the roots are unique and ordered so that for  `i < j` they satisfy `root[i] < root[j]`
    /// - Returns: the array of roots
    func distinctRealRootsInUnitInterval(configuration: RootFindingConfiguration = .default) -> [CGFloat] {
        var results: [CGFloat] = []
        forEachDistinctRootInUnitInterval(configuration: configuration) { results.append($0) }
        return results
    }

    // In-place de Casteljau split into pre-allocated left/right/scratch buffers.
    private static func deCasteljauSplit(
        input: UnsafeBufferPointer<CGFloat>,
        count: Int,
        at t: CGFloat,
        left: UnsafeMutableBufferPointer<CGFloat>,
        right: UnsafeMutableBufferPointer<CGFloat>,
        scratch: UnsafeMutableBufferPointer<CGFloat>
    ) {
        let n = count - 1
        for i in 0..<count { scratch[i] = input[i] }
        left[0] = scratch[0]
        right[n] = scratch[n]
        for j in 1...n {
            for i in 0...(n - j) {
                scratch[i] = Utils.linearInterpolate(scratch[i], scratch[i + 1], t)
            }
            left[j] = scratch[0]
            right[n - j] = scratch[n - j]
        }
    }

    // Arena layout per depth level (base = depth * 4 * count):
    //   slotA = base + 0*count  (scratch / temp)
    //   slotB = base + 1*count  (left or result)
    //   slotC = base + 2*count  (right or intermediate)
    //   slotD = base + 3*count  (secondary right, discarded)
    // Children at depth+1 write to (depth+1)*4*count onward, never touching this level's slots.
    private static func rootsCore(
        coefficients: UnsafeBufferPointer<CGFloat>,
        count: Int,
        start rangeStart: CGFloat,
        end rangeEnd: CGFloat,
        configuration: RootFindingConfiguration,
        arena: UnsafeMutableBufferPointer<CGFloat>,
        depth: Int,
        callback: (CGFloat) -> Void
    ) {
        let n = count - 1
        var lowerBound = CGFloat.infinity
        var upperBound = -CGFloat.infinity
        for i in 0..<n {
            for j in i+1...n {
                let p1 = CGPoint(x: CGFloat(i) / CGFloat(n), y: coefficients[i])
                let p2 = CGPoint(x: CGFloat(j) / CGFloat(n), y: coefficients[j])
                guard p1.y != 0 || p2.y != 0 else {
                    assert(p2.x >= p1.x)
                    if p1.x < lowerBound { lowerBound = p1.x }
                    if p2.x > upperBound { upperBound = p2.x }
                    continue
                }
                let tLine = -p1.y / (p2.y - p1.y)
                if tLine >= 0, tLine <= 1 {
                    let t = Utils.linearInterpolate(p1.x, p2.x, tLine)
                    if t < lowerBound { lowerBound = t }
                    if t > upperBound { upperBound = t }
                }
            }
        }
        guard lowerBound.isFinite, upperBound.isFinite else { return }
        let nextRangeStart = Utils.linearInterpolate(rangeStart, rangeEnd, lowerBound)
        let nextRangeEnd = Utils.linearInterpolate(rangeStart, rangeEnd, upperBound)
        guard nextRangeEnd - nextRangeStart > configuration.errorThreshold else {
            callback(Utils.linearInterpolate(nextRangeStart, nextRangeEnd, 0.5))
            return
        }
        let base = arena.baseAddress! + depth * 4 * count
        let slotA = UnsafeMutableBufferPointer(start: base,              count: count)
        let slotB = UnsafeMutableBufferPointer(start: base + count,      count: count)
        let slotC = UnsafeMutableBufferPointer(start: base + 2 * count,  count: count)
        let slotD = UnsafeMutableBufferPointer(start: base + 3 * count,  count: count)
        guard upperBound - lowerBound < 0.8 else {
            // Convergence too slow — split in half and handle each side separately.
            let rangeMid = Utils.linearInterpolate(rangeStart, rangeEnd, 0.5)
            deCasteljauSplit(input: coefficients, count: count, at: 0.5,
                             left: slotB, right: slotC, scratch: slotA)
            rootsCore(coefficients: UnsafeBufferPointer(slotB), count: count,
                      start: rangeStart, end: rangeMid,
                      configuration: configuration, arena: arena, depth: depth + 1, callback: callback)
            rootsCore(coefficients: UnsafeBufferPointer(slotC), count: count,
                      start: rangeMid, end: rangeEnd,
                      configuration: configuration, arena: arena, depth: depth + 1, callback: callback)
            return
        }
        // Narrow the curve to [lowerBound, upperBound] (equivalent to split(from:to:)).
        // lowerBound and upperBound are always in [0,1] and lowerBound <= upperBound by construction.
        let subcurvePtr: UnsafeBufferPointer<CGFloat>
        if lowerBound == 0 {
            // Only need the left portion of split at upperBound.
            deCasteljauSplit(input: coefficients, count: count, at: upperBound,
                             left: slotC, right: slotB, scratch: slotA)
            subcurvePtr = UnsafeBufferPointer(slotC)
        } else if upperBound == 1 {
            // Only need the right portion of split at lowerBound.
            deCasteljauSplit(input: coefficients, count: count, at: lowerBound,
                             left: slotB, right: slotC, scratch: slotA)
            subcurvePtr = UnsafeBufferPointer(slotC)
        } else {
            // General case: split at lowerBound, take right; then split right at mapped t2, take left.
            deCasteljauSplit(input: coefficients, count: count, at: lowerBound,
                             left: slotB, right: slotC, scratch: slotA)
            let t2Mapped = (upperBound - lowerBound) / (1 - lowerBound)
            deCasteljauSplit(input: UnsafeBufferPointer(slotC), count: count, at: t2Mapped,
                             left: slotB, right: slotD, scratch: slotA)
            subcurvePtr = UnsafeBufferPointer(slotB)
        }
        func skippedRoot(between first: CGFloat, and second: CGFloat) -> Bool {
            return first > 0 && second < 0 || first < 0 && second > 0
        }
        if skippedRoot(between: coefficients[0], and: subcurvePtr[0]) {
            callback(nextRangeStart)
        }
        rootsCore(coefficients: subcurvePtr, count: count,
                  start: nextRangeStart, end: nextRangeEnd,
                  configuration: configuration, arena: arena, depth: depth + 1, callback: callback)
        if skippedRoot(between: subcurvePtr[count - 1], and: coefficients[count - 1]) {
            callback(nextRangeEnd)
        }
    }
}
