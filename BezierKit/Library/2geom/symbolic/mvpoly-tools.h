/*
 * Routines that extend univariate polynomial functions
 * to multi-variate polynomial exploiting recursion at compile time
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

#ifndef _GEOM_SL_MVPOLY_TOOLS_H_
#define _GEOM_SL_MVPOLY_TOOLS_H_


#include <2geom/exception.h>

#include <2geom/symbolic/multi-index.h>
#include <2geom/symbolic/unity-builder.h>
#include <2geom/symbolic/polynomial.h>

#include <boost/utility/enable_if.hpp>
#include <boost/function.hpp>
#include <boost/array.hpp>

#include <iostream>


namespace Geom { namespace SL {

/*
 *  rank<PolyT>::value == total amount of indeterminates
 *  x_(0),x_(1),...,x_(rank-1) that belong to type PolyT
 */

template <typename T>
struct rank
{
    static const size_t value = 0;
};

template <typename CoeffT>
struct rank< Polynomial<CoeffT> >
{
    static const size_t value = rank<CoeffT>::value + 1;
};


/*
 *  mvpoly<N, CoeffT> creates a multi-variate polynomial type
 *  by nesting N-1 Polynomial class template and setting
 *  the coefficient type of the most nested Polynomial to CoeffT
 *  example: mvpoly<3, double>::type is the same than
 *  Polynomial< Polynomial< Polynomial<double> > >
 */

template <size_t N, typename CoeffT>
struct mvpoly
{
    typedef Polynomial<typename mvpoly<N-1, CoeffT>::type> type;
    typedef CoeffT coeff_type;
    static const size_t rank = N;

    /*
     * computes the lexicographic degree of the mv polynomial p
     */
    static
    multi_index_type lex_degree (type const& p)
    {
        multi_index_type D(N);
        lex_degree_impl<0>(p, D);
        return D;
    }

    /*
     *  Returns in the out-parameter D an N-sequence where each entry value
     *  represents the max degree of the polynomial related to the passed
     *  index I, if one index value in I is greater than the related max degree
     *  the routine returns false otherwise it returns true.
     *  This routine can be used to test if a given multi-index I is related
     *  to an actual initialized coefficient.
     */
    static
    bool max_degree (type const& p,
                     multi_index_type& D,
                     multi_index_type const& I)
    {
        if (I.size() != N)
            THROW_RANGEERROR ("multi-index with wrong length");
        D.resize(N);
        return max_degree_impl<0>(p, D, I);
    }

    /*
     *  Returns in the out-parameter D an N-sequence where each entry value
     *  represents the real degree of the polynomial related to the passed
     *  index I, if one index value in I is greater than the related real degree
     *  the routine returns false otherwise it returns true.
     *  This routine can be used to test if a given multi-index I is related
     *  to an actual initialized and non-zero coefficient.
     */

    static
    bool real_degree (type const& p,
                      multi_index_type& D,
                      multi_index_type const& I)
    {
        if (I.size() != N)
            THROW_RANGEERROR ("multi-index with wrong length");
        D.resize(N);
        return real_degree_impl<0>(p, D, I);
    }

    /*
     *  Multiplies p by X^I
     */
    static
    void shift(type & p, multi_index_type const& I)
    {
        if (I.size() != N)
            THROW_RANGEERROR ("multi-index with wrong length");
        shift_impl<0>(p, I);
    }

    /*
     * mv poly evaluation:
     * T can be any type that is able to be += with the coefficient type
     * and that can be *= with the same type T moreover a specialization
     * of zero struct for the type T is needed
     */
    template <typename T>
    static
    T evaluate(type const& p, boost::array<T, N> const& X)
    {
        return evaluate_impl<T, 0>(p, X);
    }

    /*
     * trim leading zero coefficients
     */
    static
    void normalize(type & p)
    {
        p.normalize();
        for (size_t k = 0; k < p.size(); ++k)
            mvpoly<N-1, CoeffT>::normalize(p[k]);
    }

    /*
     * Applies the unary operator "op" to each coefficient of p with rank M.
     * For instance when M = 0 op is applied to each coefficient
     * of the multi-variate polynomial p.
     * When M < N the function call recursively the for_each routine
     * for p.real_degree() times, when M == N the operator "op" is invoked on p;
     */
    template <size_t M>
    static
    void for_each
        (type & p,
         boost::function<void (typename mvpoly<M, CoeffT>::type &)> const& op,
         typename boost::enable_if_c<(M < N)>::type* = 0)
    {
        for (size_t k = 0; k <= p.real_degree(); ++k)
        {
            mvpoly<N-1, CoeffT>::template for_each<M>(p[k], op);
        }
    }

    template <size_t M>
    static
    void for_each
        (type & p,
         boost::function<void (typename mvpoly<M, CoeffT>::type &)> const& op,
         typename boost::enable_if_c<(M == N)>::type* = 0)
    {
        op(p);
    }

    // this is only an helper function to be passed to the for_each routine
    static
    void multiply_to (type& p, type const& q)
    {
        p *= q;
    }

  private:
    template <size_t i>
    static
    void lex_degree_impl (type const& p, multi_index_type& D)
    {
        D[i] = p.real_degree();
        mvpoly<N-1, CoeffT>::template lex_degree_impl<i+1>(p[D[i]], D);
    }

    template <size_t i>
    static
    bool max_degree_impl (type const& p,
                          multi_index_type& D,
                          multi_index_type const& I)
    {
        D[i] = p.max_degree();
        if (I[i] > D[i]) return false;
        return
          mvpoly<N-1, CoeffT>::template max_degree_impl<i+1>(p[I[i]], D, I);
    }

    template <size_t i>
    static
    bool real_degree_impl (type const& p,
                           multi_index_type& D,
                           multi_index_type const& I)
    {
        D[i] = p.real_degree();
        if (I[i] > D[i]) return false;
        return
          mvpoly<N-1, CoeffT>::template real_degree_impl<i+1>(p[I[i]], D, I);
    }

    template <size_t i>
    static
    void shift_impl(type & p, multi_index_type const& I)
    {
        p <<= I[i];
        for (size_t k = 0; k < p.size(); ++k)
        {
            mvpoly<N-1, CoeffT>::template shift_impl<i+1>(p[k], I);
        }
    }

    template <typename T, size_t i>
    static
    T evaluate_impl(type const& p, boost::array<T, N+i> const& X)
    {
//        T r = zero<T>()();
//        for (size_t k = p.max_degree(); k > 0; --k)
//        {
//            r += mvpoly<N-1, CoeffT>::template evaluate_impl<T, i+1>(p[k], X);
//            r *= X[i];
//        }
//        r += mvpoly<N-1, CoeffT>::template evaluate_impl<T, i+1>(p[0], X);

        int n = p.max_degree();
        T r = mvpoly<N-1, CoeffT>::template evaluate_impl<T, i+1>(p[n], X);
        for (int k = n - 1; k >= 0; --k)
        {
            r *= X[i];
            r += mvpoly<N-1, CoeffT>::template evaluate_impl<T, i+1>(p[k], X);
        }
        return r;
    }

    template <size_t M, typename C>
    friend struct mvpoly;
};

/*
 * rank 0 mv poly, that is a scalar value (usually a numeric value),
 * the routines implemented here are used only to stop recursion
 * (but for_each)
 */
template< typename CoeffT >
struct mvpoly<0, CoeffT>
{
    typedef CoeffT type;
    typedef CoeffT coeff_type;
    static const size_t rank = 0;

    template <size_t M>
    static
    void for_each
        (type & p,
         boost::function<void (typename mvpoly<M, CoeffT>::type &)> const& op,
         typename boost::enable_if_c<(M == 0)>::type* = 0)
    {
        op(p);
    }

    // multiply_to and divide_to are only helper functions
    // to be passed to the for_each routine
    static
    void multiply_to (type& p, type const& q)
    {
        p *= q;
    }

    static
    void divide_to (type& p, type const& c)
    {
        p /= c;
    }

  private:
    template <size_t i>
    static
    void lex_degree_impl (type const &/*p*/, multi_index_type&/*D*/)
    {
        return;
    }

    template <size_t i>
    static
    bool max_degree_impl (type const &/*p*/,
                          multi_index_type &/*D*/,
                          multi_index_type const &/*I*/)
    {
        return true;
    }

    template <size_t i>
    static
    bool real_degree_impl (type const &/*p*/,
                           multi_index_type &/*D*/,
                           multi_index_type const &/*I*/)
    {
        return true;
    }

    template <size_t i>
    static
    void shift_impl(type &/*p*/, multi_index_type const &/*I*/)
    {}

    template <typename T, size_t i>
    static
    T evaluate_impl(type const &p, boost::array<T, i> const &/*X*/)
    {
        return p;
    }

    static
    void normalize(type &/*p*/)
    {}


    template <size_t M, typename C>
    friend struct mvpoly;
};


/*
 *  monomial::make generate a mv-poly made up by a single term:
 *  monomial::make<N>(I,c) == c*X^I, where X=(x_(0), .., x_(N-1))
 */

template <size_t N, typename CoeffT>
struct monomial
{
    typedef typename mvpoly<N, CoeffT>::type poly_type;

    static inline
    poly_type make(multi_index_type const& I, CoeffT c)
    {
        if (I.size() != N)      // an exponent for each indeterminate
            THROW_RANGEERROR ("multi-index with wrong length");

        return make_impl<0>(I, c);
    }

  private:
    // at i-th level of recursion I need to pick up the i-th exponent in "I"
    // so I pass i as a template parameter, this trick is needed to avoid
    // to create a new multi-index at each recursion level:
    // (J = I[std::slice[1, I.size()-1, 1)]) that will be more expensive
    template <size_t i>
    static
    poly_type make_impl(multi_index_type const& I, CoeffT c)
    {
        poly_type p(monomial<N-1,CoeffT>::template make_impl<i+1>(I, c), I[i]);
        return p;
    }

    // make_impl private require that monomial classes to be each other friend
    template <size_t M, typename C>
    friend struct monomial;
};


// case N = 0 for stopping recursion
template <typename CoeffT>
struct monomial<0, CoeffT>
{
  private:
    template <size_t i>
    static
    CoeffT make_impl(multi_index_type const &/*I*/, CoeffT c)
    {
        return c;
    }

    template<size_t N, typename C>
    friend struct monomial;
};


/*
 *  coefficient<N, PolyT>
 *
 *  N should be in the range [0, rank<PolyT>-1]
 *
 *  "type" == the type of the coefficient of the polynomial with
 *  rank = rank<PolyT> - N - 1, that is it is the type of the object returned
 *  by applying the operator[] of a Polynomial object N+1 times;
 *
 *  "zero" rapresents the zero element (in the group theory meaning)
 *  for the coefficient type "type"; having it as a static class member
 *  allows to return always a (const) reference by the "get_safe" method
 *
 *  get(p, I) returns the coefficient of the monomial X^I
 *  this method doesn't check if such a coefficient really exists,
 *  so it's up to the user checking that the passed multi-index I is
 *  not out of range
 *
 *  get_safe(p, I) returns the coefficient of the monomial X^I
 *  in case such a coefficient doesn't really exist  "zero" is returned
 *
 *  set_safe(p, I, c) set the coefficient of the monomial X^I to "c"
 *  in case such a coefficient doesn't really exist this method creates it
 *  and creates all monomials X^J with J < I that don't exist yet, setting
 *  their coefficients to "zero";
 *  (with J < I we mean "<" wrt the lexicographic order)
 *
 */

template <size_t N, typename T>
struct coefficient
{
};


template <size_t N, typename CoeffT>
struct coefficient< N, Polynomial<CoeffT> >
{
    typedef typename coefficient<N-1, CoeffT>::type type;
    typedef Polynomial<CoeffT> poly_type;

    static const type zero;

    static
    type const& get(poly_type const& p, multi_index_type const& I)
    {
        if (I.size() != N+1)
            THROW_RANGEERROR ("multi-index with wrong length");

        return get_impl<0>(p, I);
    }

    static
    type & get(poly_type & p, multi_index_type const& I)
    {
        if (I.size() != N+1)
            THROW_RANGEERROR ("multi-index with wrong length");

        return get_impl<0>(p, I);
    }

    static
    type const& get_safe(poly_type const& p, multi_index_type const& I)
    {
        if (I.size() != N+1)
            THROW_RANGEERROR ("multi-index with wrong length");

        return get_safe_impl<0>(p, I);
    }

    static
    void set_safe(poly_type & p, multi_index_type const& I, type const& c)
    {
        if (I.size() != N+1)
            THROW_RANGEERROR ("multi-index with wrong length");

        return set_safe_impl<0>(p, I, c);
    }

  private:
    template <size_t i>
    static
    type const& get_impl(poly_type const& p, multi_index_type const& I)
    {
        return coefficient<N-1, CoeffT>::template get_impl<i+1>(p[I[i]], I);
    }

    template <size_t i>
    static
    type & get_impl(poly_type & p, multi_index_type const& I)
    {
        return coefficient<N-1, CoeffT>::template get_impl<i+1>(p[I[i]], I);
    }

    template <size_t i>
    static
    type const& get_safe_impl(poly_type const& p, multi_index_type const& I)
    {
        if (I[i] > p.max_degree())
        {
            return zero;
        }
        else
        {
            return
            coefficient<N-1, CoeffT>::template get_safe_impl<i+1>(p[I[i]], I);
        }
    }

    template <size_t i>
    static
    void set_safe_impl(poly_type & p, multi_index_type const& I, type const& c)
    {
        if (I[i] > p.max_degree())
        {
            multi_index_type J = shift(I, i+1);
            CoeffT m = monomial<N, type>::make(J, c);
            p.coefficient(I[i], m);
        }
        else
        {
            coefficient<N-1, CoeffT>::template set_safe_impl<i+1>(p[I[i]], I, c);
        }
    }

    template<size_t M, typename T>
    friend struct coefficient;

};

// initialization of static member zero
template <size_t N, typename CoeffT>
const typename coefficient< N, Polynomial<CoeffT> >::type
coefficient< N, Polynomial<CoeffT> >::zero
    = Geom::SL::zero<typename coefficient< N, Polynomial<CoeffT> >::type >()();


// case N = 0 for stopping recursion
template <typename CoeffT>
struct coefficient< 0, Polynomial<CoeffT> >
{
    typedef CoeffT type;
    typedef Polynomial<CoeffT> poly_type;

    static const type zero;

    static
    type const& get(poly_type const& p, multi_index_type const& I)
    {
        if (I.size() != 1)
            THROW_RANGEERROR ("multi-index with wrong length");

        return p[I[0]];
    }

    static
    type & get(poly_type & p, multi_index_type const& I)
    {
        if (I.size() != 1)
            THROW_RANGEERROR ("multi-index with wrong length");

        return p[I[0]];
    }

    static
    type const& get_safe(poly_type const& p, multi_index_type const& I)
    {
        if (I.size() != 1)
            THROW_RANGEERROR ("multi-index with wrong length");

        return p.coefficient(I[0]);
    }

    static
    void set_safe(poly_type & p, multi_index_type const& I, type const& c)
    {
        if (I.size() != 1)
            THROW_RANGEERROR ("multi-index with wrong length");

         p.coefficient(I[0], c);
    }

  private:
    template <size_t i>
    static
    type const& get_impl(poly_type const& p, multi_index_type const& I)
    {
        return p[I[i]];
    }

    template <size_t i>
    static
    type & get_impl(poly_type & p, multi_index_type const& I)
    {
        return p[I[i]];
    }

    template <size_t i>
    static
    type const& get_safe_impl(poly_type const& p, multi_index_type const& I)
    {
        return p.coefficient(I[i]);
    }

    template <size_t i>
    static
    void set_safe_impl(poly_type & p, multi_index_type const& I, type const& c)
    {
        p.coefficient(I[i], c);
    }

    template<size_t M, typename T>
    friend struct coefficient;
};

// initialization of static member zero
template <typename CoeffT>
const typename coefficient< 0, Polynomial<CoeffT> >::type
coefficient< 0, Polynomial<CoeffT> >::zero
    = Geom::SL::zero<typename coefficient< 0, Polynomial<CoeffT> >::type >()();


/*
 * ordering types:
 * lex  : lexicographic ordering
 * ilex : inverse lexicographic ordering
 * max_lex : max degree + lexicographic ordering for disambiguation
 *
 */

namespace ordering
{
    struct lex;         // WARNING: at present only lex ordering is supported
    struct ilex;
    struct max_lex;
}


/*
 *  degree of a mv poly wrt a given ordering
 */

template <size_t N, typename CoeffT, typename OrderT = ordering::lex>
struct mvdegree
{};

template <size_t N, typename CoeffT>
struct mvdegree<N, CoeffT, ordering::lex>
{
    typedef typename mvpoly<N, CoeffT>::type poly_type;
    typedef ordering::lex ordering;

    static
    multi_index_type value(poly_type const& p)
    {
        return Geom::SL::mvpoly<N, CoeffT>::lex_degree(p);
    }
};

} /*end namespace Geom*/  } /*end namespace SL*/


#endif // _GEOM_SL_MVPOLY_TOOLS_H_


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
