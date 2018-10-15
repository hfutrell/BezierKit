/*
 * A multi-index is an ordered sequence of unsigned int
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

#ifndef _GEOM_SL_MULTI_INDEX_H_
#define _GEOM_SL_MULTI_INDEX_H_


#include <2geom/exception.h>

#include <valarray>

#include <boost/preprocessor/cat.hpp>
#include <boost/preprocessor/repetition/enum_params.hpp>
#include <boost/preprocessor/repetition/repeat.hpp>
#include <boost/preprocessor/repetition/repeat_from_to.hpp>




/*
 *  an helper macro for generating function with declaration:
 *  multi_index_type make_multi_index (size_t i0, ..., size_t iN)
 *  that is a facility to make up a multi-index from a list of values
 */

#define GEOM_SL_MAX_RANK 10

#define GEOM_SL_ASSIGN_INDEX(z, k, unused)    I[k] = BOOST_PP_CAT(i, k);

#define GEOM_SL_MAKE_MULTI_INDEX(z, N, unused) \
inline                                                                         \
multi_index_type make_multi_index (BOOST_PP_ENUM_PARAMS(N, size_t i))          \
{                                                                              \
    multi_index_type I(N);                                                     \
    BOOST_PP_REPEAT(N, GEOM_SL_ASSIGN_INDEX, unused)                           \
    return I;                                                                  \
}
// end macro GEOM_SL_MAKE_MULTI_INDEX




namespace Geom { namespace SL {

/*
 *  A multi-index is an ordered sequence of unsigned int;
 *  it's useful for representing exponent, degree and coefficient index
 *  of a multi-variate polynomial;
 *  example: given a monomial x_(0)^i_(0)*x_(1)^i_(1)*...*x_(N-1)^i_(N-1)
 *  we can write it in the simpler form X^I where X=(x_(0), .., x_(N-1))
 *  and I=(i_(0), .., i_(N-1)) is a multi-index
 *  A multi-index is represented as a valarray this let us make simple
 *  arithmetic operations on a multi-index
 */

typedef std::valarray<size_t> multi_index_type;


// make up a multi-index of size N and fill it with zeroes
inline
multi_index_type multi_index_zero(size_t N)
{
    return multi_index_type(N);
}

// helper functions for generating a multi-index from a list of values
// we create an amount of GEOM_SL_MAX_RANK of suzh functions
BOOST_PP_REPEAT_FROM_TO(0, GEOM_SL_MAX_RANK, GEOM_SL_MAKE_MULTI_INDEX, unused)


// helper function for generating a multi-index of size N
// from a single index v that is placed at position i with i in [0,N[
template <size_t N>
inline
multi_index_type make_multi_index(size_t i, size_t v)
{
    if (!(i < N))
        THROW_RANGEERROR ("make_multi_index<N> from a single index: "
                          "out of range position");
    multi_index_type I(N);
    I[i] = v;
    return I;
}

// transform a N size multi-index in (N-1)-size multi-index
// by removing the first index: (i1, i2,...,iN) -> (i2,..,iN)
inline
multi_index_type shift(multi_index_type const& I, size_t i = 1)
{
    size_t N = I.size() - i;
    multi_index_type J = I[std::slice(i, N, 1)];
    return J;
}

// valarray operator== returns a valarray of bool
inline
bool is_equal(multi_index_type const& I, multi_index_type const& J)
{
    if (I.size() != J.size())  return false;
    for (size_t i = 0; i < I.size(); ++i)
        if (I[i] != J[i])  return false;
    return true;
}

// extended operator<< for printing a multi-index
template <typename charT>
inline
std::basic_ostream<charT> &
operator<< (std::basic_ostream<charT> & os,
            const Geom::SL::multi_index_type & I)
{
    if (I.size() == 0 ) return os;
    os << "[" << I[0];
    for (unsigned int i = 1; i < I.size(); ++i)
    {
        os << ", " << I[i];
    }
    os << "]";
    return os;
}

} /*end namespace Geom*/  } /*end namespace SL*/

// argument dependent name lookup doesn't work with typedef
using Geom::SL::operator<<;


#endif // _GEOM_SL_MULTI_INDEX_


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
