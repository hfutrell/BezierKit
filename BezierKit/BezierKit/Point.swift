//
//  Point.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/17/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

public protocol Point: VectorSpace, Normed {
    associatedtype F: RealNumber // as in VectorSpace we have an associated type F. But F conforms to RealNumber, not just Field.
}

extension Point {
    // this extension implements Normed protocol for all point types
    public var length: F {
        return F.sqrt(self.lengthSquared)
    }
    private var lengthSquared: F {
        return self.dot(self)
    }
    public func normalize() -> Self {
        return self / self.length
    }
}

public protocol RealNumber: Field, Rootable {
    // intentionally empty (just defines a composite protocol)
}

public protocol Rootable {
    static func sqrt(_ x: Self) -> Self
}

private let badSubscriptError = "bad subscript (out of bounds)"

public struct Point2<S>: Point where S: RealNumber {
    public typealias F = S // specify the type used by VectorSpace protocol
    public var x : S, y : S
    // conformance to VectorSpace protocol
    public init(x: S, y: S) {
        self.x = x
        self.y = y
    }
    static public var dimensions: Int {
        return 2
    }
    public func dot(_ other: Point2<S>) -> S {
        return self.x * other.x + self.y * other.y
    }
    public subscript(index: Int) -> S {
        get {
            if index == 0 {
                return self.x
            }
            else if index == 1 {
                return self.y
            }
            else {
                fatalError(badSubscriptError)
            }
        }
        set(newValue) {
            if index == 0 {
                self.x = newValue
            }
            else if index == 1 {
                self.y = newValue
            }
            else {
                fatalError(badSubscriptError)
            }
        }
    }
    public static func + (left: Point2<S>, right: Point2<S>) -> Point2<S> {
        return Point2<S>(x: left.x + right.x, y: left.y + right.y)
    }
    public static func - (left: Point2<S>, right: Point2<S>) -> Point2<S> {
        return Point2<S>(x: left.x - right.x, y: left.y - right.y)
    }
    public static func / (left: Point2<S>, right: S) -> Point2<S> {
        return Point2<S>(x: left.x / right, y: left.y / right)
    }
    public static func * (left: S, right: Point2<S>) -> Point2<S> {
        return Point2<S>(x: left * right.x, y: left * right.y)
    }
    public static prefix func - (point: Point2<S>) -> Point2<S> {
        return Point2<S>(x: -point.x, y: -point.y)
    }
}

public struct Point3<S>: Point where S: RealNumber {
    public typealias F = S // specify the type used by VectorSpace protocol
    public var x : S, y: S, z: S
    public init(x: S, y: S, z: S) {
        self.x = x
        self.y = y
        self.z = z
    }
    // conformance to VectorSpace protocol
    static public var dimensions: Int {
        return 3
    }
    public func dot(_ other: Point3<S>) -> S {
        return self.x * other.x + self.y * other.y + self.z * other.z
    }
    public subscript(index: Int) -> S {
        get {
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
                fatalError(badSubscriptError)
            }
        }
        set(newValue) {
            if index == 0 {
                self.x = newValue
            }
            else if index == 1 {
                self.y = newValue
            }
            else if index == 2 {
                self.z = newValue
            }
            else {
                fatalError(badSubscriptError)
            }
        }
    }
    public static func + (left: Point3<S>, right: Point3<S>) -> Point3<S> {
        return Point3<S>(x: left.x + right.x, y: left.y + right.y, z: left.z + right.z)
    }
    public static func - (left: Point3<S>, right: Point3<S>) -> Point3<S> {
        return Point3<S>(x: left.x - right.x, y: left.y - right.y, z: left.z - right.z)
    }
    public static func / (left: Point3<S>, right: S) -> Point3<S> {
        return Point3<S>(x: left.x / right, y: left.y / right, z: left.z / right)
    }
    public static func * (left: S, right: Point3<S>) -> Point3<S> {
        return Point3<S>(x: left * right.x, y: left * right.y, z: left * right.z)
    }
    public static prefix func - (point: Point3<S>) -> Point3<S> {
        return Point3<S>(x: -point.x, y: -point.y, z: -point.z)
    }
}
