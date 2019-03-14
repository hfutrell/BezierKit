//
//  ArcApproximateable.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/14/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import Foundation

#if os(iOS)
    import CoreGraphics
#endif

public struct Arc: Equatable {
    public var origin: CGPoint
    public var radius: CGFloat
    public var startAngle: CGFloat // starting angle (in radians)
    public var endAngle: CGFloat // ending angle (in radians)
    public var interval: Interval // represents t-values [0, 1] on curve
    public init(origin: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, interval: Interval = Interval(start: 0.0, end: 1.0)) {
        self.origin = origin
        self.radius = radius
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.interval = interval
    }
    public func compute(_ t: CGFloat) -> CGPoint {
        // computes a value on the arc with t in [0, 1]
        let theta: CGFloat = t * self.endAngle + (1.0 - t) * self.startAngle
        return self.origin + self.radius * CGPoint(x: cos(theta), y: sin(theta))
    }
}

public protocol ArcApproximateable: BezierCurve {
    func arcs(errorThreshold: CGFloat) -> [Arc]
}

extension ArcApproximateable {
    public func arcs(errorThreshold: CGFloat = 0.5) -> [Arc] {
        func iterate(errorThreshold: CGFloat, circles: [Arc]) -> [Arc] {
            
            var result: [Arc] = circles
            var s: CGFloat = 0.0
            var e: CGFloat = 1.0
            var safety: Int = 0
            // we do a binary search to find the "good `t` closest to no-longer-good"
            
            let error = {(pc: CGPoint, np1: CGPoint, s: CGFloat, e: CGFloat) -> CGFloat in
                let q = (e - s) / 4.0
                let c1 = self.compute(s + q)
                let c2 = self.compute(e - q)
                let ref = Utils.dist(pc, np1)
                let d1  = Utils.dist(pc, c1)
                let d2  = Utils.dist(pc, c2)
                return abs(d1-ref) + abs(d2-ref)
            }
            
            repeat {
                safety=0
                
                // step 1: start with the maximum possible arc
                e = 1.0
                
                // points:
                let np1 = self.compute(s)
                var prev_arc: Arc? = nil
                var arc: Arc? = nil
                
                // booleans:
                var curr_good = false
                var prev_good = false
                var done = false
                
                // numbers:
                var m = e
                var prev_e: CGFloat = 1.0
                
                // step 2: find the best possible arc
                repeat {
                    prev_good = curr_good
                    prev_arc = arc
                    m = (s + e)/2.0
                    
                    let np2 = self.compute(m)
                    let np3 = self.compute(e)
                    
                    arc = Utils.getccenter(np1, np2, np3, Interval(start: s, end: e))
                    
                    let errorAmount = error(arc!.origin, np1, s, e)
                    curr_good = errorAmount <= errorThreshold
                    
                    done = prev_good && !curr_good
                    if !done {
                        prev_e = e
                    }
                    
                    // this arc is fine: we can move 'e' up to see if we can find a wider arc
                    if curr_good {
                        // if e is already at max, then we're done for this arc.
                        if e >= 1.0 {
                            prev_e = 1.0
                            prev_arc = arc
                            break
                        }
                        // if not, move it up by half the iteration distance
                        e = e + (e-s)/2.0
                    }
                    else {
                        // this is a bad arc: we need to move 'e' down to find a good arc
                        e = m
                    }
                    safety += 1
                } while !done && safety <= 100
                
//                if safety >= 100 {
//                    NSLog("arc abstraction somehow failed...")
//                    break
//                }
            
                prev_arc = prev_arc != nil ? prev_arc : arc
                result.append(prev_arc!)
                s = prev_e
            } while e < 1.0
            
            return result
        }
        let circles: [Arc] = []
        return iterate(errorThreshold: errorThreshold, circles: circles)
    }
}
