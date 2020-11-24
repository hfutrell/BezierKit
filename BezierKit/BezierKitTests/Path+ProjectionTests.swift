//
//  Path+ProjectionTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/23/20.
//  Copyright © 2020 Holmes Futrell. All rights reserved.
//

@testable import BezierKit
import Foundation
import XCTest

class PathProjectionTests: XCTestCase {
    func testProjection() {
        XCTAssertNil(Path().project(CGPoint.zero), "projection requires non-empty path.")
        let triangle1 = { () -> Path in
            let cgPath = CGMutablePath()
            cgPath.addLines(between: [CGPoint(x: 0, y: 2),
                                      CGPoint(x: 2, y: 4),
                                      CGPoint(x: 0, y: 4)])
            cgPath.closeSubpath()
            return Path(cgPath: cgPath)
        }()
        let triangle2 = { () -> Path in
            let cgPath = CGMutablePath()
            cgPath.addLines(between: [CGPoint(x: 2, y: 1),
                                      CGPoint(x: 3, y: 1),
                                      CGPoint(x: 3, y: 2)])
            cgPath.closeSubpath()
            return Path(cgPath: cgPath)
        }()
        let square = Path(rect: CGRect(x: 3, y: 3, width: 1, height: 1))
        let path = Path(components: triangle1.components + triangle2.components + square.components)
        let projection = path.project(CGPoint(x: 2, y: 2))
        XCTAssertEqual(projection?.location, IndexedPathLocation(componentIndex: 1, elementIndex: 2, t: 0.5))
        XCTAssertEqual(projection?.point, CGPoint(x: 2.5, y: 1.5))
    }
}
