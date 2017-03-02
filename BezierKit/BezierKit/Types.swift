//
//  Types.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/3/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import Foundation

public struct Intersection {
    var t1: BKFloat
    var t2: BKFloat
}

public struct Line {
    var p1: BKPoint
    var p2: BKPoint
}

public struct Arc {
    struct Interval {
        var start: BKFloat
        var end: BKFloat
    }
    var origin: BKPoint
    var radius: BKFloat
    var start: BKFloat // starting angle
    var end: BKFloat // starting angle
    var interval: Interval // represents t-values [0, 1] on curve
}

public struct Shape {
    struct Cap {
        var curve: CubicBezierCurve
        var virtual: Bool
        init(curve: CubicBezierCurve) {
            self.curve = curve
            self.virtual = false
        }
    }
    var startcap: Cap
    var endcap: Cap
    var forward: BezierCurve
    var back: BezierCurve
    func boundingBox() -> BoundingBox { // TODO: convert me to a property that is computed once
        var mx =  BKFloat.infinity
        var my =  BKFloat.infinity
        var MX = -BKFloat.infinity
        var MY = -BKFloat.infinity
        for s: BezierCurve? in [startcap.virtual ? nil : startcap.curve, forward, back, endcap.virtual ? nil : endcap.curve] {
            if s != nil {
                let bbox: BoundingBox = s!.boundingBox
                if mx > bbox.min.x {
                    mx = bbox.min.x
                }
                if my > bbox.min.y {
                    my = bbox.min.y
                }
                if MX < bbox.max.x {
                    MX = bbox.max.x
                }
                if MY < bbox.max.y {
                    MY = bbox.max.y
                }
            }
        }
        return BoundingBox(min: BKPoint(x: mx, y: my), max: BKPoint(x: MX, y: MY))
    }
}

public struct BKPoint {
    var x : BKFloat
    var y : BKFloat
    var z : BKFloat
    init(x: BKFloat, y: BKFloat, z: BKFloat = 0.0) {
        self.x = x
        self.y = y
        self.z = z
    }
    init(_ p: CGPoint) {
        self.x = p.x
        self.y = p.y
        self.z = 0.0
    }
    func equalTo(_ other: BKPoint) -> Bool {
        if x != other.x {
            return false
        }
        if y != other.y {
            return false
        }
        if z != other.z {
            return false
        }
        return true
    }
    func dim(_ index: Int) -> BKFloat {
        if index == 0 {
            return self.x
        }
        else if index == 1 {
            return self.y
        }
        else if index == 2 {
            return self.z
        }
        else {
            assert(false, "bad dimension!")
            return 0.0
        }
    }
}

public struct BoundingBox {
    var min: BKPoint
    var max: BKPoint
    var mid: BKPoint {
        return (min + max)/2.0
    }
    var size: BKPoint {
        return max - min
    }

// TODO: write union method and use it in the shape bounding box constructor
    
//    func overlaps(_ other: BoundingBox) -> Bool {
//        for i in 0..<2 {
//            let l = self.mid.dim(i)
//            let t = other.mid.dim(i)
//            let d = (self.size.dim(i) + other.size.dim(i)) * 0.5
//            if abs(l-t) >= d {
//                return false
//            }
//        }
//        return true
//    }
    
    func overlaps(_ other: BoundingBox) -> Bool {
        for i in 0..<3 {
            if self.min.dim(i) > other.max.dim(i) {
                return false
            }
            if self.max.dim(i) < other.min.dim(i) {
                return false
            }
        }
        return true
    }
    var toCGRect: CGRect {
        let s = self.size
        return CGRect(origin: self.min.toCGPoint(), size: CGSize(width: s.x, height: s.y))
    }
}

public let BKPointZero: BKPoint = BKPoint(x: 0.0, y: 0.0, z: 0.0)

public extension CGPoint {
    init(_ p: BKPoint) {
        self.x = p.x
        self.y = p.y
    }
}

public typealias BKFloat = CGFloat
public typealias BKRect = CGRect

public extension BKPoint {
    var length: BKFloat {
        return sqrt(self.lengthSquared)
    }
    var lengthSquared: CGFloat {
        let x = self.x
        let y = self.y
        let z = self.z
        return x * x + y * y + z * z
    }
    func normalize() -> BKPoint {
        return self / self.length
    }
    func toCGPoint() -> CGPoint {
        return CGPoint(self)
    }
}
public func += ( left: inout BKPoint, right: BKPoint) {
    return left = left + right
}
public func -= ( left: inout BKPoint, right: BKPoint) {
    return left = left - right
}
public func + (left: BKPoint, right: BKPoint) -> BKPoint {
    return BKPoint(x: left.x + right.x, y: left.y + right.y, z: left.z + right.z)
}
public func - (left: BKPoint, right: BKPoint) -> BKPoint {
    return BKPoint(x: left.x - right.x, y: left.y - right.y, z: left.z - right.z)
}
public func / (left: BKPoint, right: BKFloat) -> BKPoint {
    return BKPoint(x: left.x / right, y: left.y / right, z: left.z / right)
}
public func * (left: BKPoint, right: BKFloat) -> BKPoint {
    return BKPoint(x: left.x * right, y: left.y * right, z: left.z * right)
}
