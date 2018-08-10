//
//  BoundingVolumeHierarchy.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/6/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import Foundation

private class BVHConstructionContext<A> where A: BoundingBoxProtocol {
    let boundingBoxes: [[BoundingBox]]
    init(objects: [A]) {
        
        // table[i][j] stores the bounding box of objects i...j, for j<i it is the union of i..<count union 0..<=j
        
        guard objects.count > 0 else {
            boundingBoxes = [[]]
            return
        }
        
        var table: [[BoundingBox]] = []
        for i in 0..<objects.count {
            table[i] = []
            table[i][i] = objects[i].boundingBox
            for j in i+1..<objects.count {
                table[i][j] = BoundingBox(first: table[i][j-1], second: objects[j].boundingBox)
            }
            table[i][0] = BoundingBox(first: table[i][objects.count-1], second: objects[0].boundingBox)
            for j in 1..<i {
                table[i][j] = BoundingBox(first: table[i][j-1], second: objects[j].boundingBox)
            }
        }
        boundingBoxes = table
    }
}

private class BVHNode<A> where A: BoundingBoxProtocol {
    let boundingBox: BoundingBox
    let nodeType: NodeType
    enum NodeType {
        case leaf(object: A)
        case `internal`(left: BVHNode<A>, right: BVHNode<A>)
    }
    init(object: A, boundingBox: BoundingBox) {
        self.nodeType = .leaf(object: object)
        self.boundingBox = boundingBox
    }
    init(left: BVHNode<A>, right: BVHNode<A>, boundingBox: BoundingBox) {
        self.nodeType = .internal(left: left, right: right)
        self.boundingBox = boundingBox
    }
    init(objects: ArraySlice<A>, context: BVHConstructionContext<A>) {
      
        assert(objects.isEmpty == false, "unexpectedly empty array slice!")
        
        self.boundingBox = context.boundingBoxes[objects.startIndex][objects.endIndex-1]
        
        if objects.count == 1 {
            self.nodeType = .leaf(object: objects.first!)
            return
        }
        
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
        
        let left = BVHNode<A>(objects: objects[objects.startIndex..<split], context: context)
        let right = BVHNode<A>(objects: objects[split..<objects.endIndex], context: context)
        self.nodeType = .internal(left: left, right: right)
    }
}

public class BoundingVolumeHierarchy<A> where A: BoundingBoxProtocol {
    private let root: BVHNode<A>
    
    public init(objects: [A]) {
        let context = BVHConstructionContext(objects: objects)
        self.root = BVHNode<A>(objects: objects[0..<objects.count], context: context)
    }
}
