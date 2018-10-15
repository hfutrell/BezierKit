//
//  libgeom-bridge.c
//  BezierKit
//
//  Created by Holmes Futrell on 10/15/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

#include "libgeom-bridge.h"
#import <2geom/basic-intersection.h>

void libgeomIntersect(double *c1, int n1, double *c2, int n2, double *i1, double *i2, int *solutionsCount) {
    
    assert(solutionsCount != NULL);
    assert(c1 != NULL);
    assert(c2 != NULL);
    assert(i1 != NULL);
    assert(i2 != NULL);
    
    std::vector<Geom::Point> A;
    for (int i=0; i<n1; i++) {
        A.push_back(Geom::Point(c1[2*i+0], c1[2*i+1]));
    }
    std::vector<Geom::Point> B;
    for (int i=0; i<n2; i++) {
        B.push_back(Geom::Point(c2[2*i+0], c2[2*i+1]));
    }

    std::vector<std::pair<double, double>> solutions;
    
    Geom::find_intersections_bezier_clipping(solutions, A, B);
    
    for (int i=0; i<solutions.size(); i++) {
        i1[i] = solutions[i].first;
        i2[i] = solutions[i].second;
    }
    *solutionsCount = (int)solutions.size();
    
    
}
