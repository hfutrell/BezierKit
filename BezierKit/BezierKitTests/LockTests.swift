//
//  LockTests.swift
//  MacDemos
//
//  Created by Holmes Futrell on 6/12/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

@preconcurrency import XCTest
@testable import BezierKit

#if !os(WASI)
class LockTests: XCTestCase {
    func testPathPropertyAtomicity() async {

        @MainActor class Results: Sendable {
            #if canImport(CoreGraphics)
            var cgPaths: [Int: CGPath] = [:]
            #endif
            var boundingBoxes: [Int: BoundingBox] = [:]
        }

        // ensure that lazy properties of Path are only initialized once
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        let path = Path(rect: rect)

        let threadCount = 10000
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = threadCount

        let results = await Results()
        for i in 0..<threadCount {
            let index = i
            Task.detached {
#if canImport(CoreGraphics)
                let pathValue = path.cgPath
#endif
                let boundingBoxValue = path.boundingBox
                await MainActor.run {
#if canImport(CoreGraphics)
                    results.cgPaths[index] = pathValue
#endif
                    results.boundingBoxes[index] = boundingBoxValue
                    expectation.fulfill()
                }
            }
        }

        await fulfillment(of: [expectation], timeout: 10.0)

        await MainActor.run {
#if canImport(CoreGraphics)
            XCTAssertEqual(results.cgPaths.values.count, threadCount)
            XCTAssertEqual(results.cgPaths[0], Path(rect: rect).cgPath)
            XCTAssertTrue(results.cgPaths.values.allSatisfy { $0 === results.cgPaths[0] }, "cgPaths should all refer to the same instance (was it initialized more than once?)")
#endif
            let expectedBoundingBox = Path(rect: rect).boundingBox
            XCTAssertEqual(results.boundingBoxes.values.count, threadCount)
            XCTAssertTrue(results.boundingBoxes.values.allSatisfy { $0 == expectedBoundingBox })
        }
    }
}
#endif
