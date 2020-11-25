//
//  PathComponent+ProjectionTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/23/20.
//  Copyright © 2020 Holmes Futrell. All rights reserved.
//

@testable import BezierKit
import Foundation
import XCTest

class PathComponentProjectionTests: XCTestCase {
    func testProject() {
        let rectangle = Path(rect: CGRect(x: 1, y: 2, width: 8, height: 4))
        let result = rectangle.components.first!.project(CGPoint(x: 3, y: 3))
        XCTAssertEqual(result.point, CGPoint(x: 3, y: 2))
        XCTAssertEqual(result.location.t, 0.25)
        XCTAssertEqual(result.location.elementIndex, 0)
    }
}
