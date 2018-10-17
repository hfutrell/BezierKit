//
//  ConvexHull.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/14/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

private func _is_clockwise_turn(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Bool {
    if (b == c) {
        return false
    }
    return cross(b-a, c-a) > 0
}

private func _is_clockwise_turn2(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Bool {
    if (a == b) {
        return false
    }
    let bMinusA = b-a
    let cMinusA = c-a
    let crossProduct = cross(bMinusA, cMinusA)
    return crossProduct < 0 || (crossProduct == 0 && (b-a).length < (c-a).length)
}

internal func computeConvexHull(from points: [CGPoint]) -> [CGPoint] {
    // naive (marching) Jarvis algorithm. Ok for n <= 4 as for Cubic Bezier curves
    let C = points.count

    guard C > 0 else {
        return []
    }

    var P = [CGPoint]()
    P.reserveCapacity(C)

    points.withUnsafeBufferPointer {(S: UnsafeBufferPointer<CGPoint>) in
        var firstIndex = 0
        for i in 1..<C {
            if S[i].x < S[firstIndex].x {
                firstIndex = i
            }
        }
        var pointOnHull = S[firstIndex]
        var i = 0
        while(true) {
            P.append(pointOnHull)
            var endPoint = S[0]
            for j in 1..<C {
                if endPoint == pointOnHull || _is_clockwise_turn2(P[i], endPoint, S[j]) {
                    endPoint = S[j]
                }
            }
            if endPoint == P[0] {
                break
            }
            pointOnHull = endPoint
            i += 1
        }
    }
    
   // assert(P == computeConvexHull2(from: points))
    
//    if ( P != computeConvexHull2(from: points) ) {
//        print("ugh")
//    }
    
    return P
}

/// Convex hull based on the Andrew's monotone chain algorithm
internal func computeConvexHull2(from points: [CGPoint]) -> [CGPoint] {
 
    var _boundary = points.sorted { // sorted in LexLess<X> order
        $0.x < $1.x || ($0.x == $1.x && $0.y < $1.y)
    }

    // _boundary must already be sorted in LexLess<X> order
    if _boundary.isEmpty {
        return _boundary
    }
    if _boundary.count == 1 || (_boundary.count == 2 && _boundary[0] == _boundary[1]) {
        return [_boundary[0]]
    }
    if _boundary.count == 2 {
        return _boundary
    }
 
    var k = 2
    for i in 2..<_boundary.count {
        while k >= 2 && !_is_clockwise_turn(_boundary[k-2], _boundary[k-1], _boundary[i]) {
            k -= 1
        }
        _boundary.swapAt(k, i)
        k += 1
    }
 
    let _lower = k
    if k < _boundary.endIndex-1 {
        _boundary = [CGPoint](_boundary[0..<k] + _boundary[k..<_boundary.endIndex].sorted { // sort LexGreater<X>
            $0.x > $1.x || ($0.x == $1.x && $0.y > $1.y)
        })
    }
 
    _boundary.append(_boundary.first!)
    for i in _lower..<_boundary.count {
        while k > _lower && !_is_clockwise_turn(_boundary[k-2], _boundary[k-1], _boundary[i]) {
            k -= 1
        }
        _boundary.swapAt(k, i)
        k += 1
    }
    _boundary.removeLast(_boundary.count - k + 1)
    return _boundary
 
}
