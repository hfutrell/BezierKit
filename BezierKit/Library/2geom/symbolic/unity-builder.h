/*
 * Routines to make up "zero" and "one" elements of a ring
 *
 * Authors:
 *      Marco Cecchetti <mrcekets at gmail.com>
 *
 * Copyright 2008  authors
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
 * in the file COPYING-LGPL-2.1; if not, write to the Free Software
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

#ifndef _GEOM_SL_UNITY_BUILDER_H_
#define _GEOM_SL_UNITY_BUILDER_H_


#include <boost/type_traits/is_arithmetic.hpp>



namespace Geom { namespace SL {


/*
 *  zero builder function class type
 *
 *  made up a zero element, in the algebraic ring theory meaning,
 *  for the type T
 */

template< typename T, bool numeric = boost::is_arithmetic<T>::value >
struct zero
{};

// specialization for basic numeric type
template< typename T >
struct zero<T, true>
{
    T operator() () const
    {
        return 0;
    }
};


/*
 *  one builder function class type
 *
 *  made up a one element, in the algebraic ring theory meaning,
 *  for the type T
 */

template< typename T, bool numeric = boost::is_arithmetic<T>::value >
struct one
{};

// specialization for basic numeric type
template< typename T >
struct one<T, true>
{
    T operator() ()
    {
        return 1;
    }
};

} /*end namespace Geom*/  } /*end namespace SL*/


#endif // _GEOM_SL_UNITY_BUILDER_H_


/*
  Local Variables:
  mode:c++
  c-file-style:"stroustrup"
  c-file-offsets:((innamespace . 0)(inline-open . 0)(case-label . +))
  indent-tabs-mode:nil
  fill-column:99
  End:
*/
// vim: filetype=cpp:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:fileencoding=utf-8:textwidth=99 :
