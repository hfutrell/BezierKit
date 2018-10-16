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

/// Convex hull based on the Andrew's monotone chain algorithm
internal func computeConvexHull(from points: [CGPoint]) -> [CGPoint] {
    
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
