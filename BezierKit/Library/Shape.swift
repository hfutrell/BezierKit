//
//  Shape.swift
//  BezierKit
//
//  Created by Holmes Futrell on 1/13/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import Foundation

public struct ShapeIntersection {
    let curve1: BezierCurve
    let curve2: BezierCurve
    let intersection: [Intersection]
}

public struct Shape {
    public struct Cap {
        let curve: BezierCurve
        let virtual: Bool // a cap is virtual if it is internal (not part of the outline of the boundary)
        init(curve: BezierCurve, virtual: Bool) {
            self.curve = curve
            self.virtual = virtual
        }
    }
    
    public static let defaultShapeIntersectionThreshold: BKFloat = 0.5
    public let startcap: Cap
    public let endcap: Cap
    public let forward: BezierCurve
    public let back: BezierCurve
    
    internal init(_ forward: BezierCurve, _ back: BezierCurve, _ startCapVirtual: Bool, _ endCapVirtual: Bool) {
        let start  = LineSegment(p0: back.endingPoint, p1: forward.startingPoint)
        let end    = LineSegment(p0: forward.endingPoint, p1: back.startingPoint)
        self.startcap = Shape.Cap(curve: start, virtual: startCapVirtual)
        self.endcap = Shape.Cap(curve: end, virtual: endCapVirtual)
        self.forward = forward
        self.back = back
    }
    
    public func boundingBox() -> BoundingBox {
        var result: BoundingBox = BoundingBox()
        for s: BezierCurve in self.nonvirtualSegments() {
            let bbox = s.boundingBox
            result = BoundingBox(first: result, second: bbox)
        }
        return result
    }

    private func nonvirtualSegments() -> [BezierCurve] {
        if startcap.virtual && endcap.virtual {
            return [forward, back]; // exclude both caps
        }
        else if startcap.virtual == true {
            return [forward, endcap.curve, back] // exclude the start cap
        }
        else if endcap.virtual == true {
            return [forward, back, startcap.curve,] // exclude the end cap
        }
        else {
            return [forward, endcap.curve, back, startcap.curve]; // include both caps
        }
    }
    
    public func intersects(shape other: Shape,_ curveIntersectionThreshold: BKFloat = Shape.defaultShapeIntersectionThreshold) -> [ShapeIntersection] {
        if self.boundingBox().overlaps(other.boundingBox()) == false {
            return []
        }
        var intersections: [ShapeIntersection] = []
        let a1: [BezierCurve] = self.nonvirtualSegments()
        let a2: [BezierCurve] = other.nonvirtualSegments()
        for l1 in a1 {
            for l2 in a2 {
                let iss = l1.intersects(curve: l2, curveIntersectionThreshold: curveIntersectionThreshold)
                if iss.count > 0 {
                    intersections.append(ShapeIntersection(curve1: l1, curve2: l2, intersection: iss))
                }
            }
        }
        return intersections
    }
    
}
