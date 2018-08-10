//
//  BoundingVolumeHierarchy.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/6/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import Foundation

private class BVHConstructionContext {
    let boundingBoxes: [[BoundingBox]]
    init(objects: [BoundingBoxProtocol]) {
        
        // table[i][j] stores the bounding box of objects i...j, for j<i it is the union of i..<count union 0..<=j
        
        guard objects.count > 0 else {
            boundingBoxes = [[]]
            return
        }
        
        let emptyTableRow = [BoundingBox](repeating: BoundingBox.empty, count: objects.count)
        
        var table: [[BoundingBox]] = [[BoundingBox]](repeating: emptyTableRow, count: objects.count)
        for i in 0..<objects.count {
            table[i][i] = objects[i].boundingBox
            for j in i+1..<objects.count {
                table[i][j] = BoundingBox(first: table[i][j-1], second: objects[j].boundingBox)
            }
            if i > 0 {
                table[i][0] = BoundingBox(first: table[i][objects.count-1], second: objects[0].boundingBox)
            }
            if i > 1 {
                for j in 1..<i {
                    table[i][j] = BoundingBox(first: table[i][j-1], second: objects[j].boundingBox)
                }
            }
                
        }
        
        // check the results
        
//        for i in 0..<objects.count {
//            for j in 0..<objects.count {
//                var expected = BoundingBox.empty
//
//                for ip in 0..<objects.count {
//                    if (ip >= i && ip <= j) || (j < i && (ip <= j || ip >= i) ) {
//                        expected = BoundingBox(first: expected, second: objects[ip].boundingBox)
//                    }
//                }
//                assert(expected == table[i][j])
//
//            }
//        }
        
        boundingBoxes = table
    }
}

public class BVHNode {
    let boundingBox: BoundingBox
    let nodeType: NodeType
    enum NodeType {
        case leaf(object: BoundingBoxProtocol)
        case `internal`(left: BVHNode, right: BVHNode)
    }
    public func visit(callback: (BVHNode, Int) -> Void, currentDepth depth: Int) {
        callback(self, depth)
        if case let .`internal`(left: left, right: right) = self.nodeType {
            left.visit(callback: callback, currentDepth: depth+1)
            right.visit(callback: callback, currentDepth: depth+1)
        }
    }
    fileprivate init(objects: ArraySlice<BoundingBoxProtocol>, context: BVHConstructionContext) {
      
        assert(objects.isEmpty == false, "unexpectedly empty array slice!")
        
        self.boundingBox = context.boundingBoxes[objects.startIndex][objects.endIndex-1]
        
        if objects.count == 1 {
            self.nodeType = .leaf(object: objects.first!)
            return
        }
        
        // determine where to split the node between left and right
        
        var split = objects.startIndex+1
        var minArea = context.boundingBoxes[objects.startIndex][split-1].area + context.boundingBoxes[split][objects.endIndex-1].area
        
        if objects.count > 2 {
            for j in objects.startIndex+2..<objects.endIndex {
                let area = context.boundingBoxes[objects.startIndex][j-1].area + context.boundingBoxes[j][objects.endIndex-1].area
                if area < minArea {
                    split = j
                    minArea = area
                }
            }
        }
        
        // now that we've found the optimal split, recurse to compute children
        
        let left = BVHNode(objects: objects[objects.startIndex..<split], context: context)
        let right = BVHNode(objects: objects[split..<objects.endIndex], context: context)
        self.nodeType = .internal(left: left, right: right)
    }
    public func intersects(node other: BVHNode, callback: (BoundingBoxProtocol, BoundingBoxProtocol) -> Void) {
        
        guard self.boundingBox.overlaps(other.boundingBox) else {
            return // nothing to do
        }
        
        if case let .leaf(object1) = self.nodeType {
            if case let .leaf(object2) = other.nodeType {
                callback(object1, object2)
            }
            else if case let .internal(left2, right2) = other.nodeType {
                self.intersects(node: left2,    callback: callback)
                self.intersects(node: right2,   callback: callback)
            }
        }
        else if case let .`internal`(left1, right1) = self.nodeType {
            if case .leaf(_) = other.nodeType {
                left1.intersects(node:  other, callback: callback)
                right1.intersects(node: other, callback: callback)
            }
            else if case let .`internal`(left2, right2) = other.nodeType {
                left1.intersects(node:   left2,  callback: callback)
                left1.intersects(node:   right2, callback: callback)
                right1.intersects(node:  left2,  callback: callback)
                right1.intersects(node:  right2, callback: callback)
            }
        }
    }
}

public class BoundingVolumeHierarchy {
    private let root: BVHNode
    
    public init(objects: [BoundingBoxProtocol]) {
        let context = BVHConstructionContext(objects: objects)
        self.root = BVHNode(objects: objects[0..<objects.count], context: context)
    }
    
    public func intersects(boundingVolumeHierarchy other: BoundingVolumeHierarchy, callback: (BoundingBoxProtocol, BoundingBoxProtocol) -> Void) {
        self.root.intersects(node: other.root, callback: callback)
    }
    
    public func visit(callback: (BVHNode, Int) -> Void) {
        self.root.visit(callback: callback, currentDepth: 0)
    }
    
}
