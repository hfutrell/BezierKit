//
//  libgeom-bridge.h
//  BezierKit
//
//  Created by Holmes Futrell on 10/15/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

#ifndef libgeom_bridge_h
#define libgeom_bridge_h

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif
    
    void libgeomIntersect(double *c1, int n1, double *c2, int n2, double *i1, double *i2, int *solutionsCount);
    
#ifdef __cplusplus
}
#endif

#endif /* libgeom_bridge_h */
