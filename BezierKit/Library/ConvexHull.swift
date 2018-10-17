//
//  ConvexHull.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/14/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

private func _is_clockwise_turn(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Bool {
    if (a == b) {
        return false
    }
    let bMinusA = b-a
    let cMinusA = c-a
    let crossProduct = cross(bMinusA, cMinusA)
    return crossProduct < 0 || (crossProduct == 0 && bMinusA.lengthSquared < cMinusA.lengthSquared)
}

internal func computeConvexHull(from points: [CGPoint]) -> [CGPoint] {
    let C = points.count
    return points.withUnsafeBufferPointer { S in
        var length = 0
        if let buffer = computeConvexHullUnsafe(S) {
            defer { buffer.deallocate() }
            return Array(buffer)
        }
        else {
            return []
        }
    }
}

internal func computeConvexHullUnsafe(_ S: UnsafeBufferPointer<CGPoint>) -> UnsafeBufferPointer<CGPoint>? {
    // naive (marching) Jarvis algorithm. Ok for n <= 4 as for Cubic Bezier curves
    let C = S.count
    guard C > 0 else {
        return nil
    }

    let P = UnsafeMutableBufferPointer<CGPoint>.allocate(capacity: C)

    var firstIndex = 0
    for i in 1..<C {
        if S[i].x < S[firstIndex].x {
            firstIndex = i
        }
    }
    var pointOnHull = S[firstIndex]
    var i = 0
    while(true) {
        P[i] = pointOnHull
        var endPoint = S[0]
        for j in 1..<C {
            if endPoint == pointOnHull || _is_clockwise_turn(P[i], endPoint, S[j]) {
                endPoint = S[j]
            }
        }
        if endPoint == P[0] {
            break
        }
        pointOnHull = endPoint
        i += 1
    }
    return UnsafeBufferPointer(rebasing: P[0...i])
}
