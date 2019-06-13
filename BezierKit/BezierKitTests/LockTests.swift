//
//  LockTests.swift
//  MacDemos
//
//  Created by Holmes Futrell on 6/12/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class LockTests: XCTestCase {
    func testPathPropertyAtomicity() {
        // ensure that lazy properties of Path are only initialized once
        let squareCGPath = CGPath(rect: CGRect(x: 0, y: 0, width: 1, height: 1), transform: nil)
        let path = Path(cgPath: squareCGPath)

        let threadCount = 10000
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = threadCount

        var cgPaths: [Int: CGPath] = [:]
        var boundingBoxes: [Int: BoundingBox] = [:]

        for i in 0..<threadCount {
            let index = i
            DispatchQueue.global(qos: .default).async {
                let pathValue = path.cgPath
                let boundingBoxValue = path.boundingBox
                DispatchQueue.main.async {
                    cgPaths[index] = pathValue
                    boundingBoxes[index] = boundingBoxValue
                    expectation.fulfill()
                }
            }
        }
        wait(for: [expectation], timeout: 10.0)

        XCTAssertEqual(cgPaths.values.count, threadCount)
        XCTAssertEqual(cgPaths[0], Path(cgPath: squareCGPath).cgPath)
        XCTAssertTrue(cgPaths.values.allSatisfy { $0 === cgPaths[0] }, "cgPaths should all refer to the same instance (was it initialized more than once?)")

        let expectedBoundingBox = Path(cgPath: squareCGPath).boundingBox
        XCTAssertEqual(boundingBoxes.values.count, threadCount)
        XCTAssertTrue(boundingBoxes.values.allSatisfy { $0 == expectedBoundingBox })
    }
}
