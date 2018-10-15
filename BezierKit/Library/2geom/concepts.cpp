/**
 * \file
 * \brief Concept checking
 *//*
 * Copyright 2015 Krzysztof Kosiński <tweenk.pl@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it either under the terms of the GNU Lesser General Public
 * License version 2.1 as published by the Free Software Foundation
 * (the "LGPL") or, at your option, under the terms of the Mozilla
 * Public License Version 1.1 (the "MPL"). If you do not alter this
 * notice, a recipient may use your version of this file under either
 * the MPL or the LGPL.
 *
 * You should have received a copy of the LGPL along with this library
 * in the file COPYING-LGPL-2.1; if not, output to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 * You should have received a copy of the MPL along with this library
 * in the file COPYING-MPL-1.1
 *
 * The contents of this file are subject to the Mozilla Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTY
 * OF ANY KIND, either express or implied. See the LGPL or the MPL for
 * the specific language governing rights and limitations.
 */

#include <boost/concept/assert.hpp>
#include <2geom/concepts.h>

#include <2geom/line.h>
#include <2geom/circle.h>
#include <2geom/ellipse.h>
#include <2geom/curves.h>
#include <2geom/convex-hull.h>
#include <2geom/path.h>
#include <2geom/pathvector.h>

#include <2geom/bezier.h>
#include <2geom/sbasis.h>
#include <2geom/linear.h>
#include <2geom/d2.h>

namespace Geom {

void concept_checks()
{
    BOOST_CONCEPT_ASSERT((ShapeConcept<Line>));
    //BOOST_CONCEPT_ASSERT((ShapeConcept<Circle>));
    //BOOST_CONCEPT_ASSERT((ShapeConcept<Ellipse>));
    BOOST_CONCEPT_ASSERT((ShapeConcept<BezierCurve>));
    BOOST_CONCEPT_ASSERT((ShapeConcept<EllipticalArc>));
    //BOOST_CONCEPT_ASSERT((ShapeConcept<SBasisCurve>));
    //BOOST_CONCEPT_ASSERT((ShapeConcept<ConvexHull>));
    //BOOST_CONCEPT_ASSERT((ShapeConcept<Path>));
    //BOOST_CONCEPT_ASSERT((ShapeConcept<PathVector>));

    BOOST_CONCEPT_ASSERT((NearConcept<Coord>));
    BOOST_CONCEPT_ASSERT((NearConcept<Point>));

    BOOST_CONCEPT_ASSERT((FragmentConcept<Bezier>));
    BOOST_CONCEPT_ASSERT((FragmentConcept<Linear>));
    BOOST_CONCEPT_ASSERT((FragmentConcept<SBasis>));
}

} // end namespace Geom
