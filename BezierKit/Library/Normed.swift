//
//  Normed.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/17/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

public protocol Normed {
    associatedtype F
    var length: F { get }
    func normalize() -> Self
}
