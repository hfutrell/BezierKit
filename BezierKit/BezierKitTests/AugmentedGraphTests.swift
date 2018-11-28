//
//  AugmentedGraphTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/29/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import XCTest
import CoreGraphics

@testable import BezierKit

class AugmentedGraphTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func intersectionsAreMutuallyLinked(_ vertex1: Vertex, _ vertex2: Vertex) -> Bool {
        if vertex1.intersectionInfo.neighbor !== vertex2 {
            return false
        }
        if vertex2.intersectionInfo.neighbor !== vertex1 {
            return false
        }
        return true
    }
    
    func crossingCountOnLinkedList(_ p: PathLinkedListRepresentation) -> Int {
        var count = 0
        p.forEachVertex {
            if $0.isCrossing {
                count += 1
            }
        }
        return count
    }
    
    func testMostBasic() {
        // this is the most basic test possible of the augmented graph
        // two squares that intersect at (1,0) and (0,1)
        let size = CGSize(width: 2.0, height: 2.0)
        let origin1 = CGPoint.zero
        let origin2 = CGPoint(x: -1.0, y: -1.0)
        let square1 = Path(cgPath: CGPath(rect: CGRect(origin: origin1, size: size), transform: nil))
        let square2 = Path(cgPath: CGPath(rect: CGRect(origin: origin2, size: size), transform: nil))

        let intersections = square1.intersects(path: square2)
        
        let augmentedGraph = AugmentedGraph(path1: square1, path2: square2, intersections: intersections)

        // check that there are two intersections
        XCTAssertEqual(crossingCountOnLinkedList(augmentedGraph.list1), 2)
        XCTAssertEqual(crossingCountOnLinkedList(augmentedGraph.list2), 2)

        let firstIntersectionLocation = CGPoint(x: 1.0, y: 0.0)
        let secondIntersectionLocation = CGPoint(x: 0.0, y: 1.0)
        
        // find the first intersection on the first path
        let intersection1Path1: Vertex = augmentedGraph.list1.startingVertex(forComponentIndex: 0, elementIndex: 0).next
        XCTAssertTrue(intersection1Path1.isCrossing)
        XCTAssertEqual(intersection1Path1.location, firstIntersectionLocation)
        XCTAssertTrue(intersection1Path1.intersectionInfo.isExit)
        
        // find the first intersection on the second path
        let intersection1Path2: Vertex = augmentedGraph.list2.startingVertex(forComponentIndex: 0, elementIndex: 1).next
        XCTAssertTrue(intersection1Path2.isCrossing)
        XCTAssertEqual(intersection1Path2.location, firstIntersectionLocation)
        XCTAssertTrue(intersection1Path2.intersectionInfo.isEntry)

        XCTAssertTrue(intersectionsAreMutuallyLinked(intersection1Path1, intersection1Path2))
        
        // find the second intersection on the first path
        let intersection2Path1: Vertex = augmentedGraph.list1.startingVertex(forComponentIndex: 0, elementIndex: 3).next
        XCTAssertTrue(intersection2Path1.isCrossing)
        XCTAssertEqual(intersection2Path1.location, secondIntersectionLocation)
        XCTAssertTrue(intersection2Path1.intersectionInfo.isEntry)
        
        // find the second intersection on the second path
        let intersection2Path2: Vertex = augmentedGraph.list2.startingVertex(forComponentIndex: 0, elementIndex: 2).next
        XCTAssertTrue(intersection2Path2.isCrossing)
        XCTAssertEqual(intersection2Path2.location, secondIntersectionLocation)
        XCTAssertTrue(intersection2Path2.intersectionInfo.isExit)
        
        XCTAssertTrue(intersectionsAreMutuallyLinked(intersection1Path1, intersection1Path2))
    }
    
    func testCornersIntersect() {
        // this tests two squares that intersect at two of their corners
        // the first square has the origin 0,0 and a width and height of 2
        // the second square has the origin of 0,0 and a width and height of sqrt(2). It is rotated -45 degrees
        // so that the squraes intersect at (0,0) and (2,0)
        let square1 = Path(cgPath: CGPath(rect: CGRect(origin: CGPoint.zero, size: CGSize(width: 2.0, height: 2.0)), transform: nil))

        let square2CGPath = CGMutablePath()
        square2CGPath.move(to: CGPoint.zero)
        square2CGPath.addLine(to: CGPoint(x: 1.0, y: -1.0))
        square2CGPath.addLine(to: CGPoint(x: 2.0, y: 0.0))
        square2CGPath.addLine(to: CGPoint(x: 1.0, y: 1.0))
        square2CGPath.closeSubpath()
        
        let square2 = Path(cgPath: square2CGPath)

        let intersections = square1.intersects(path: square2)
        let augmentedGraph = AugmentedGraph(path1: square1, path2: square2, intersections: intersections)
        
        // check that there are two intersections
        XCTAssertEqual(crossingCountOnLinkedList(augmentedGraph.list1), 2)
        XCTAssertEqual(crossingCountOnLinkedList(augmentedGraph.list2), 2)

        let firstIntersectionLocation = CGPoint(x: 0.0, y: 0.0)
        let secondIntersectionLocation = CGPoint(x: 2.0, y: 0.0)
        
        // find the first intersection on the first path
        let intersection1Path1: Vertex = augmentedGraph.list1.startingVertex(forComponentIndex: 0, elementIndex: 0)
        XCTAssertTrue(intersection1Path1.isCrossing)
        XCTAssertEqual(intersection1Path1.location, firstIntersectionLocation)
        XCTAssertTrue(intersection1Path1.intersectionInfo.isEntry)
        
        // find the first intersection on the second path
        let intersection1Path2: Vertex = augmentedGraph.list2.startingVertex(forComponentIndex: 0, elementIndex: 0)
        XCTAssertTrue(intersection1Path2.isCrossing)
        XCTAssertEqual(intersection1Path2.location, firstIntersectionLocation)
        XCTAssertTrue(intersection1Path2.intersectionInfo.isExit)
        
        XCTAssertTrue(intersectionsAreMutuallyLinked(intersection1Path1, intersection1Path2))
        
        // find the second intersection on the first path
        let intersection2Path1: Vertex = augmentedGraph.list1.startingVertex(forComponentIndex: 0, elementIndex: 1)
        XCTAssertTrue(intersection2Path1.isCrossing)
        XCTAssertEqual(intersection2Path1.location, secondIntersectionLocation)
        XCTAssertTrue(intersection2Path1.intersectionInfo.isExit)
        
        // find the second intersection on the second path
        let intersection2Path2: Vertex = augmentedGraph.list2.startingVertex(forComponentIndex: 0, elementIndex: 2)
        XCTAssertTrue(intersection2Path2.isCrossing)
        XCTAssertEqual(intersection2Path2.location, secondIntersectionLocation)
        XCTAssertTrue(intersection2Path2.intersectionInfo.isEntry)
        
        XCTAssertTrue(intersectionsAreMutuallyLinked(intersection1Path1, intersection1Path2))
    }
    
    func testBetween() {
        let v1 = CGPoint(x: 2, y: -1)
        let v2 = CGPoint(x: 1, y: 3)
        
        XCTAssertTrue( between(CGPoint(x: 3, y: -1), v1, v2)    )
        XCTAssertTrue( between(CGPoint(x: 1, y: 2), v1, v2)    )
        XCTAssertTrue( between(CGPoint(x: 3, y: -1), v1, v2)    )
       
        XCTAssertFalse( between(CGPoint(x: -1, y: 1), v1, v2)    )
        XCTAssertFalse( between(CGPoint(x: 1, y: 5), v1, v2)    )
        XCTAssertFalse( between(CGPoint(x: 1, y: -1), v1, v2)    )

        
    }
    
    func testWindingDirection() {
        // if this test fails it's likely that the increment / decrement of the winding direction in the augmented graph is flipped from what it should be
        // the first square begins its path *inside* the second square so only if the winding count is properly decremented (to zero) at the first crossing
        // will it be recognized as an exit
        let origin1 = CGPoint(x: 2, y: 1)
        let size1 = CGSize(width: 2, height: 1)
        let origin2 = CGPoint(x: 0, y: 0)
        let size2 = CGSize(width: 3, height: 3)

        let square1 = Path(cgPath: CGPath(rect: CGRect(origin: origin1, size: size1), transform: nil))
        let square2 = Path(cgPath: CGPath(rect: CGRect(origin: origin2, size: size2), transform: nil))
        
        let intersections = square1.intersects(path: square2)
        let augmentedGraph = AugmentedGraph(path1: square1, path2: square2, intersections: intersections)

        XCTAssertEqual(crossingCountOnLinkedList(augmentedGraph.list1), 2)
        let intersection1Path1: Vertex = augmentedGraph.list1.startingVertex(forComponentIndex: 0, elementIndex: 0).next
        XCTAssertTrue(intersection1Path1.intersectionInfo.isExit)
        let intersection2Path1: Vertex = augmentedGraph.list1.startingVertex(forComponentIndex: 0, elementIndex: 2).next
        XCTAssertTrue(intersection2Path1.intersectionInfo.isEntry)
    }
    
//    func testMultipleIntersectionsSameElement() {
//
//    }
    
}
