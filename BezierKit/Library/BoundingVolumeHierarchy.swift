//
//  BoundingVolumeHierarchy.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/6/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import Foundation

private class BVHNode<A> where A: BoundingBoxProtocol {
    let boundingBox: BoundingBox
    let nodeType: NodeType
    enum NodeType {
        case leaf(object: A)
        case `internal`(children: [BVHNode<A>])
    }
    init(object: A, boundingBox: BoundingBox) {
        self.nodeType = .leaf(object: object)
        self.boundingBox = boundingBox
    }
    init(children: [BVHNode<A>], boundingBox: BoundingBox) {
        self.nodeType = .internal(children: children)
        self.boundingBox = boundingBox
    }
    
//    init(objects: [A], boundingBox: BoundingBox) {
//        
//        var children: [BVHNode<A>]
//        
//        var child: [A] = []
//        
//        func areaHeuristicSatisfied() -> Bool {
//            
//        }
//        
//        if areaHeuristicSatisfied(child + object) {
//            child.append(object)
//        }
//        else {
//            children.append(child)
//            child = [object]
//        }
//        if child.empty == false {
//            children.append(child)
//        }
//        
//        func mapping(objects: [A]) {
//            if objects.count == 1 {
//                return BVHNode(object: objects[0], boundingBox: objects[0].boundingBox)
//            }
//            else {
//                return
//            }
//        }
//        
//        self.nodeType = .internal(children: [])
//        self.boundingBox = boundingBox
//
//    }
    
}

public class BoundingVolumeHierarchy<A> where A: BoundingBoxProtocol {
    private let root: BVHNode<A>
    
    public init(objects: [A]) {
        
        
        
    }
}

//class BVHNode {
//    let boundingBox: BoundingBox
//    let     init(children: [BVHNode]) {
//        self.node = .list(children: children)
//    }
//    init(object: BezierCurve, box) {
//        self.node = .leaf(object: object)
//    }
//}
