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
struct ConvexHull {
    
    public let boundary: [CGPoint]
    
    init(points: [CGPoint]) {
 
        var _boundary = points.sorted { // sorted in LexLess<X> order
            $0.x < $1.x
        }
        
        // _boundary must already be sorted in LexLess<X> order
        if _boundary.isEmpty {
            self.boundary = _boundary
            return
        }
        if _boundary.count == 1 || (_boundary.count == 2 && _boundary[0] == _boundary[1]) {
            self.boundary = [_boundary[0]]
            return
        }
        if _boundary.count == 2 {
            self.boundary = _boundary
            return
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
        if k < _boundary.endIndex {
            _boundary = [CGPoint](_boundary[0..<k] + _boundary[k..<_boundary.endIndex].sorted { // sort LexGreater<X>
                $0.x > $1.x
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
        
        self.boundary = [CGPoint](_boundary[0..<k-1])
        
    }
}
