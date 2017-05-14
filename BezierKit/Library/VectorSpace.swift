//
//  VectorField.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/17/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//
public protocol Field {
    static func + (left: Self, right: Self) -> Self
    static func - (left: Self, right: Self) -> Self
    static func * (left: Self, right: Self) -> Self
    static func / (left: Self, right: Self) -> Self
    static prefix func - (value: Self) -> Self
}

public protocol VectorSpace: Equatable {
    // a vector space (in the Mathematical sense) over a scalar Field F
    associatedtype F: Field
    static var dimensions: Int { get }
    func dot(_ other: Self) -> F
    subscript(index: Int) -> F {get set}
    static func + (left: Self, right: Self) -> Self
    static func - (left: Self, right: Self) -> Self
    static func * (left: F, right: Self) -> Self
    static func / (left: Self, right: F) -> Self
    static prefix func - (value: Self) -> Self
}
