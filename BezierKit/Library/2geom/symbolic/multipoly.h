/*
 * MultiPoly<N, CoeffT> class template
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

#ifndef _GEOM_SL_MULTIPOLY_H_
#define _GEOM_SL_MULTIPOLY_H_


#include <2geom/symbolic/unity-builder.h>
#include <2geom/symbolic/mvpoly-tools.h>

#include <boost/bind.hpp> // needed for generating for_each operator argument




namespace Geom { namespace SL {

/*
 * MultiPoly<N, CoeffT> class template
 *
 * It represents a multi-variate polynomial with N indeterminates
 * and coefficients of type CoeffT, but it doesn't support explicit
 * symbol attaching; the indeterminates should be thought as implicitly
 * defined in an automatic enumerative style: x_(0),...,x_(N-1) .
 *
 */

template <size_t N, typename CoeffT>
class MultiPoly
{
public:
    typedef typename mvpoly<N, CoeffT>::type poly_type;
    typedef CoeffT coeff_type;
    static const size_t rank = N;

public:
    MultiPoly()
    {
    }

    MultiPoly(poly_type const& p)
        : m_poly(p)
    {
    }

    // create a mv polynomial of type c*X^I
    MultiPoly(coeff_type c, multi_index_type const& I = multi_index_zero(N))
        : m_poly(monomial<N, coeff_type>::make(I, c))
    {
    }

    // create a mv polynomial p(x_(N-M),...,x_(N-1))*X'^I
    // where I.size() == N-M and X'=(x_(0),...,x_(N-M-1))
    template <size_t M>
    MultiPoly (MultiPoly<M, CoeffT> const& p,
               multi_index_type const& I = multi_index_zero(N-M),
               typename boost::enable_if_c<(M > 0) && (M < N)>::type* = 0)
    {
        Geom::SL::coefficient<N-M-1, poly_type>::set_safe(m_poly, I, p.m_poly);
    }

    /*
     *  assignment operators
     */
    MultiPoly& operator=(poly_type const& p)
    {
        m_poly = p;
        return (*this);
    }

    MultiPoly& operator=(coeff_type const& c)
    {
        multi_index_type I = multi_index_zero(N);
        (*this) = MultiPoly(c);
        return (*this);
    }

    // return the degree of the mv polynomial wrt the ordering OrderT
    template <typename OrderT>
    multi_index_type degree() const
    {
        return  Geom::SL::mvdegree<N, CoeffT, OrderT>::value(m_poly);
    }

    // return the coefficient of the term with the highest degree
    // wrt the ordering OrderT
    template <typename OrderT>
    coeff_type const& leading_coefficient() const
    {
        return  (*this)(degree<OrderT>());
    }

    template <typename OrderT>
    coeff_type & leading_coefficient()
    {
        return  (*this)(degree<OrderT>());
    }

    // return the coefficient of the term of degree 0 (wrt all indeterminates)
    coeff_type const& trailing_coefficient() const
    {
        return (*this)(multi_index_zero(N));
    }

    coeff_type & trailing_coefficient()
    {
        return (*this)(multi_index_zero(N));
    }

    // access coefficient methods with no out-of-range checking
    coeff_type const& operator() (multi_index_type const& I) const
    {
        return Geom::SL::coefficient<N-1, poly_type>::get(m_poly, I);
    }

    coeff_type & operator() (multi_index_type const& I)
    {
        return Geom::SL::coefficient<N-1, poly_type>::get(m_poly, I);
    }

    // safe coefficient get method
    coeff_type const& coefficient(multi_index_type const& I) const
    {
        return Geom::SL::coefficient<N-1, poly_type>::get_safe(m_poly, I);
    }

    // safe coefficient set method
    void coefficient(multi_index_type const& I, coeff_type const& c)
    {
        Geom::SL::coefficient<N-1, poly_type>::set_safe(m_poly, I, c);
    }

    // access the mv poly of rank N-1 with no out-of-range checking
    typename poly_type::coeff_type const&
    operator[] (size_t const& i) const
    {
        return m_poly[i];
    }

    typename poly_type::coeff_type &
    operator[] (size_t const& i)
    {
        return m_poly[i];
    }

    // safe access to the mv poly of rank N-1
    typename poly_type::coeff_type const&
    coefficient(size_t const& i) const
    {
        return m_poly.coefficient(i);
    }

    void coefficient (size_t const& i,
                      typename poly_type::coeff_type const& c)
    {
        m_poly.coefficient(i, c);
    }

    /*
     * polynomail evaluation:
     * T can be any type that is able to be + and * with the coefficient type
     */
    template <typename T>
    T operator() (boost::array<T, N> const& X) const
    {
        return Geom::SL::mvpoly<N, CoeffT>::evaluate(m_poly, X);
    }

    template <typename T>
    typename boost::enable_if_c<(N == 1), T>::type
    operator() (T const& x0) const
    {
        boost::array<T, N> X = {{x0}};
        return Geom::SL::mvpoly<N, CoeffT>::evaluate(m_poly, X);
    }

    template <typename T>
    typename boost::enable_if_c<(N == 2), T>::type
    operator() (T const& x0, T const& x1) const
    {
        boost::array<T, N> X = {{x0, x1}};
        return Geom::SL::mvpoly<N, CoeffT>::evaluate(m_poly, X);
    }

    template <typename T>
    typename boost::enable_if_c<(N == 3), T>::type
    operator() (T const& x0, T const& x1, T const& x2) const
    {
        boost::array<T, N> X = {{x0, x1, x2}};
        return Geom::SL::mvpoly<N, CoeffT>::evaluate(m_poly, X);
    }

    /*
     * trim leading zero coefficients
     */
    void normalize()
    {
        Geom::SL::mvpoly<N, CoeffT>::normalize(m_poly);
    }

    /*
     *  select the sub multi-variate polynomial with rank M
     *  which is unambiguously characterized by the multi-index I
     *  requirements:
     *  - M > 0 && M < N;
     *  - multi-index size == N-M
     */
    template <size_t M>
    typename mvpoly<M, CoeffT>::type const&
    select (multi_index_type const& I= multi_index_zero(N-M),
            typename boost::enable_if_c<(M > 0) && (M < N)>::type* = 0) const
    {
        return Geom::SL::coefficient<N-M-1, poly_type>::get_safe(m_poly, I);
    }

    poly_type const& get_poly() const
    {
        return m_poly;
    }

    bool is_zero() const
    {
        return ((*this) == zero);
    }

    // return the opposite mv poly
    MultiPoly operator-() const
    {
        MultiPoly r(-m_poly);
        return r;
    }

    /*
     * multipoly-multipoly mutating operators
     */
    MultiPoly& operator+=(MultiPoly const& p)
    {
        m_poly += p.m_poly;
        return (*this);
    }

    MultiPoly& operator-=(MultiPoly const& p)
    {
        m_poly -= p.m_poly;
        return (*this);
    }

    MultiPoly& operator*=(MultiPoly const& p)
    {
        m_poly *= p.m_poly;
        return (*this);
    }

    MultiPoly& operator<<=(multi_index_type const& I)
    {
        Geom::SL::mvpoly<N, CoeffT>::shift(m_poly, I);
        return (*this);
    }

    bool operator==(MultiPoly const& q) const
    {
        return (m_poly == q.m_poly);
    }

    bool operator!=(MultiPoly const& q) const
    {
        return !((*this) == q);
    }

    /*
     * multipoly-coefficient mutating operators
     */
    MultiPoly& operator+=(CoeffT const& c)
    {
        trailing_coefficient() += c;
        return (*this);
    }

    MultiPoly& operator-=(CoeffT const& c)
    {
        trailing_coefficient() -= c;
        return (*this);
    }

    MultiPoly& operator*=(CoeffT const& c)
    {
        mvpoly<N, CoeffT>::template
        for_each<0>(m_poly, boost::bind(mvpoly<0, CoeffT>::multiply_to, _1, c));
        return (*this);
    }

    MultiPoly& operator/=(CoeffT const& c)
    {
        mvpoly<N, CoeffT>::template
        for_each<0>(m_poly, boost::bind(mvpoly<0, CoeffT>::divide_to, _1, c));
        return (*this);
    }

    /*
     * multipoly-polynomial mutating operators
     */
    MultiPoly& operator+=(poly_type const& p)
    {
        m_poly += p;
        return (*this);
    }

    MultiPoly& operator-=(poly_type const& p)
    {
        m_poly -= p;
        return (*this);
    }

    MultiPoly& operator*=(poly_type const& p)
    {
        m_poly *= p;
        return (*this);
    }

    /*
     *  multipoly<N>-multipoly<M> mutating operators
     *  requirements:
     *  - M > 0 && M < N;
     *  - they must have the same coefficient type.
     */

    template <size_t M>
    typename boost::enable_if_c<(M > 0) && (M < N), MultiPoly>::type &
    operator+= (MultiPoly<M, CoeffT> const& p)
    {
        multi_index_type I = multi_index_zero(N-M);
        Geom::SL::coefficient<N-M-1, poly_type>::get(m_poly, I) += p.m_poly;
        return (*this);
    }

    template <size_t M>
    typename boost::enable_if_c<(M > 0) && (M < N), MultiPoly>::type &
    operator-= (MultiPoly<M, CoeffT> const& p)
    {
        multi_index_type I = multi_index_zero(N-M);
        Geom::SL::coefficient<N-M-1, poly_type>::get(m_poly, I) -= p.m_poly;
        return (*this);
    }

    template <size_t M>
    typename boost::enable_if_c<(M > 0) && (M < N), MultiPoly>::type &
    operator*= (MultiPoly<M, CoeffT> const& p)
    {
        mvpoly<N, CoeffT>::template
        for_each<M>(m_poly, boost::bind(mvpoly<M, CoeffT>::multiply_to, _1, p.m_poly));
        return (*this);
    }

    /*
     *  we need MultiPoly instantiations to be each other friend
     *  in order to be able of implementing operations between
     *  MultiPoly instantiations with a different ranks
     */
    template<size_t M, typename C>
    friend class MultiPoly;

    template< typename charT, size_t M, typename C>
    friend
    std::basic_ostream<charT> &
    operator<< (std::basic_ostream<charT> & os, const MultiPoly<M, C> & p);

    static const MultiPoly zero;
    static const MultiPoly one;
    static const coeff_type zero_coeff;
    static const coeff_type one_coeff;

private:
    poly_type m_poly;

}; //  end class MultiPoly


/*
 *  zero and one element spezcialization for MultiPoly
 */
template <size_t N, typename CoeffT>
struct zero<MultiPoly<N, CoeffT>, false>
{
    MultiPoly<N, CoeffT> operator() ()
    {
        CoeffT _0c = zero<CoeffT>()();
        MultiPoly<N, CoeffT> _0(_0c);
        return _0;
    }
};


template <size_t N, typename CoeffT>
struct one<MultiPoly<N, CoeffT>, false>
{
    MultiPoly<N, CoeffT> operator() ()
    {
        CoeffT _1c = one<CoeffT>()();
        MultiPoly<N, CoeffT> _1(_1c);
        return _1;
    }
};


/*
 * initialization of MultiPoly static data members
 */
template <size_t N, typename CoeffT>
const MultiPoly<N, CoeffT> MultiPoly<N, CoeffT>::one
    = Geom::SL::one< MultiPoly<N, CoeffT> >()();

template <size_t N, typename CoeffT>
const MultiPoly<N, CoeffT> MultiPoly<N, CoeffT>::zero
    = Geom::SL::zero< MultiPoly<N, CoeffT> >()();

template <size_t N, typename CoeffT>
const typename MultiPoly<N, CoeffT>::coeff_type MultiPoly<N, CoeffT>::zero_coeff
    = Geom::SL::zero<typename MultiPoly<N, CoeffT>::coeff_type>()();

template <size_t N, typename CoeffT>
const typename MultiPoly<N, CoeffT>::coeff_type MultiPoly<N, CoeffT>::one_coeff
    = Geom::SL::one<typename MultiPoly<N, CoeffT>::coeff_type>()();


/*
 *  operator<< extended to print out a mv poly type
 */
template <typename charT, size_t N, typename CoeffT>
inline
std::basic_ostream<charT> &
operator<< (std::basic_ostream<charT> & os, const MultiPoly<N, CoeffT> & p)
{
    return operator<<(os, p.m_poly);
}

/*
 *  equivalent to multiply by X^I
 */
template <size_t N, typename CoeffT>
inline
MultiPoly<N, CoeffT>
operator<< (MultiPoly<N, CoeffT> const& p, multi_index_type const& I)
{
    MultiPoly<N, CoeffT> r(p);
    r <<= I;
    return r;
}

/*
 * MultiPoly<M, CoeffT> - MultiPoly<N, CoeffT> binary mathematical operators
 */

template <size_t M, size_t N, typename CoeffT>
inline
typename boost::enable_if_c<(M > 0) && (M <= N), MultiPoly<N, CoeffT> >::type
operator+ (MultiPoly<N, CoeffT> const& p,
           MultiPoly<M, CoeffT> const& q )
{
    MultiPoly<N, CoeffT> r(p);
    r += q;
    return r;
}

template <size_t M, size_t N, typename CoeffT>
inline
typename boost::enable_if_c<(N > 0) && (M > N), MultiPoly<M, CoeffT> >::type
operator+ (MultiPoly<N, CoeffT> const& p,
           MultiPoly<M, CoeffT> const& q )
{
    MultiPoly<M, CoeffT> r(q);
    r += p;
    return r;
}

template <size_t M, size_t N, typename CoeffT>
inline
typename boost::enable_if_c<(M > 0) && (M <= N), MultiPoly<N, CoeffT> >::type
operator- (MultiPoly<N, CoeffT> const& p,
           MultiPoly<M, CoeffT> const& q )
{
    MultiPoly<N, CoeffT> r(p);
    r -= q;
    return r;
}

template <size_t M, size_t N, typename CoeffT>
inline
typename boost::enable_if_c<(N > 0) && (M > N), MultiPoly<M, CoeffT> >::type
operator- (MultiPoly<N, CoeffT> const& p,
           MultiPoly<M, CoeffT> const& q )
{
    MultiPoly<M, CoeffT> r(-q);
    r += p;
    return r;
}


template <size_t M, size_t N, typename CoeffT>
inline
typename boost::enable_if_c<(M > 0) && (M <= N), MultiPoly<N, CoeffT> >::type
operator* (MultiPoly<N, CoeffT> const& p,
           MultiPoly<M, CoeffT> const& q )
{
    MultiPoly<N, CoeffT> r(p);
    r *= q;
    return r;
}

template <size_t M, size_t N, typename CoeffT>
inline
typename boost::enable_if_c<(N > 0) && (M > N), MultiPoly<M, CoeffT> >::type
operator* (MultiPoly<N, CoeffT> const& p,
           MultiPoly<M, CoeffT> const& q )
{
    MultiPoly<M, CoeffT> r(q);
    r *= p;
    return r;
}

/*
 * MultiPoly-coefficient and coefficient-MultiPoly binary mathematical operators
 */

template <size_t N, typename CoeffT>
inline
MultiPoly<N, CoeffT> operator+(MultiPoly<N, CoeffT> const& p, CoeffT const& c)
{
    MultiPoly<N, CoeffT> r(p);
    r += c;
    return r;
}

template <size_t N, typename CoeffT>
inline
MultiPoly<N, CoeffT> operator+(CoeffT const& c, MultiPoly<N, CoeffT> const& p)
{
    MultiPoly<N, CoeffT> r(p);
    r += c;
    return r;
}

template <size_t N, typename CoeffT>
inline
MultiPoly<N, CoeffT> operator-(MultiPoly<N, CoeffT> const& p, CoeffT const& c)
{
    MultiPoly<N, CoeffT> r(p);
    r -= c;
    return r;
}

template <size_t N, typename CoeffT>
inline
MultiPoly<N, CoeffT> operator-(CoeffT const& c, MultiPoly<N, CoeffT> const& p)
{
    MultiPoly<N, CoeffT> r(-p);
    r += c;
    return r;
}

template <size_t N, typename CoeffT>
inline
MultiPoly<N, CoeffT> operator*(MultiPoly<N, CoeffT> const& p, CoeffT const& c)
{
    MultiPoly<N, CoeffT> r(p);
    r *= c;
    return r;
}

template <size_t N, typename CoeffT>
inline
MultiPoly<N, CoeffT> operator*(CoeffT const& c, MultiPoly<N, CoeffT> const& p)
{
    MultiPoly<N, CoeffT> r(p);
    r *= c;
    return r;
}


template <size_t N, typename CoeffT>
inline
MultiPoly<N, CoeffT> operator/(MultiPoly<N, CoeffT> const& p, CoeffT const& c)
{
    MultiPoly<N, CoeffT> r(p);
    r /= c;
    return r;
}




/*
template< size_t N, typename CoeffT >
MultiPoly<N, CoeffT>
factor( MultiPoly<N, CoeffT> const& f,
               MultiPoly<N, CoeffT> const& g )
{
    typedef MultiPoly<N, CoeffT> poly_type;

    if (g == poly_type::one) return f;
    poly_type h(g), q, r(f);
    multi_index_type deg_r = r.template degree<ordering::lex>();
    multi_index_type deg_g = g.template degree<ordering::lex>();
    multi_index_type deg0 = multi_index_zero(deg_g.size());
    CoeffT ltg = g(deg_g);
    if (is_equal(deg_g, deg0)) return (f / ltg);
    //h(deg_g) = 0;
//    std::cout << "deg_g = " << deg_g << std::endl;
//    std::cout << "ltg = " << ltg << std::endl;
    CoeffT lt, ltr;
    multi_index_type deg(1, deg_g.size());
    size_t iter = 0;
    while (!is_equal(deg, deg0) && iter < 10000)
    {
        ++iter;
        deg = deg_r - deg_g;
        ltr = r(deg_r);
        lt = ltr / ltg;
        q.coefficient(deg, lt);
        //r(deg_r) = 0;
        r -= ((lt * g) << deg);
        deg_r = r.template degree<ordering::lex>();
//        std::cout << "deg_r = " << deg_r << std::endl;
//        std::cout << "ltr = " << ltr << std::endl;
//        std::cout << "deg = " << deg << std::endl;
//        std::cout << "lt = " << lt << std::endl;
//        std::cout << "q = " << q << std::endl;
//        std::cout << "r = " << r << std::endl;

//        break;
    }
    //std::cout << "iter = " << iter << std::endl;
    return q;
}
*/


} /*end namespace Geom*/  } /*end namespace SL*/




#endif /* _MULTIPOLY_H_ */


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
