/*
 * Routines to compute the implicit equation of a parametric polynomial curve
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


#ifndef _GEOM_SL_IMPLICIT_H_
#define _GEOM_SL_IMPLICIT_H_



#include <2geom/symbolic/multipoly.h>
#include <2geom/symbolic/matrix.h>


#include <2geom/exception.h>

#include <boost/array.hpp>


namespace Geom { namespace SL {

typedef MultiPoly<1, double> MVPoly1;
typedef MultiPoly<2, double> MVPoly2;
typedef MultiPoly<3, double> MVPoly3;
typedef boost::array<MVPoly1, 3> poly_vector_type;
typedef boost::array<poly_vector_type, 2> basis_type;
typedef boost::array<double, 3> coeff_vector_type;

namespace detail {

/*
 *  transform a univariate polynomial f(t) in a 3-variate polynomial
 *  p(t, x, y) = f(t) * x^i * y^j
 */
inline
void poly1_to_poly3(MVPoly3 & p3, MVPoly1 const& p1, size_t i, size_t j)
{
    multi_index_type I = make_multi_index(0, i, j);
    for (; I[0] < p1.get_poly().size(); ++I[0])
    {
        p3.coefficient(I, p1[I[0]]);
    }
}

/*
 *  evaluates the degree of a poly_vector_type, such a degree is defined as:
 *  deg({p[0](t), p[1](t), p[2](t)}) := {max(deg(p[i](t)), i = 0, 1, 2), k}
 *  here k is the index where the max is achieved,
 *  if deg(p[i](t)) == deg(p[j](t)) and i < j then k = i
 */
inline
std::pair<size_t, size_t> deg(poly_vector_type const& p)
{
    std::pair<size_t, size_t> d;
    d.first = p[0].get_poly().real_degree();
    d.second = 0;
    size_t k = p[1].get_poly().real_degree();
    if (d.first < k)
    {
        d.first = k;
        d.second = 1;
    }
    k = p[2].get_poly().real_degree();
    if (d.first < k)
    {
        d.first = k;
        d.second = 2;
    }
    return d;
}

} // end namespace detail


/*
 * A polynomial parametrization could be seen as 1-variety V in R^3,
 * intersection of two surfaces x = f(t), y = g(t), this variety V has
 * attached an ideal I in the ring of polynomials in t, x, y with coefficients
 * on reals; a basis of generators for I is given by p(t, x, y) = x - f(t),
 * q(t, x, y) = y - g(t); such a basis has the nice property that could be
 * written as a couple of vectors of dim 3 with entries in R[t]; the original
 * polinomials p and q can be obtained by doing a dot product between each
 * vector and the vector {x, y, 1}
 * As reference you can read the text book:
 * Ideals, Varieties and Algorithms by Cox, Little, O'Shea
 */
inline
void make_initial_basis(basis_type& b, MVPoly1 const& p, MVPoly1 const& q)
{
    // first basis vector
    b[0][0] = 1;
    b[0][1] = 0;
    b[0][2] = -p;

    // second basis vector
    b[1][0] = 0;
    b[1][1] = 1;
    b[1][2] = -q;
}

/*
 * Starting from the initial basis for the ideal I is possible to make up
 * a new basis, still showing off the nice property that each generator is
 * a moving line that is a linear combination of x, y, 1 where the coefficients
 * are polynomials in R[t], and moreover each generator is of minimal degree.
 * Can be proved that given a polynomial parametrization f(t), g(t)
 * we are able to make up a "micro" basis of generators p(t, x, y), q(t, x, y)
 * for the ideal I such that the deg(p, t) = m <= n/2 and deg(q, t) = n - m,
 * where n = max(deg(f(t)), deg(g(t))); this let us halve the order of
 * the Bezout matrix.
 * Reference:
 * Zheng, Sederberg - A Direct Approach to Computing the micro-basis
 *                    of a Planar Rational Curves
 * Deng, Chen, Shen - Computing micro-Basis of Rational Curves and Surfaces
 *                    Using Polynomial Matrix Factorization
 */
inline
void microbasis(basis_type& b, MVPoly1 const& p, MVPoly1 const& q)
{
    typedef std::pair<size_t, size_t> degree_pair_t;

    size_t n = std::max(p.get_poly().real_degree(), q.get_poly().real_degree());
    make_initial_basis(b, p, q);
    degree_pair_t n0 = detail::deg(b[0]);
    degree_pair_t n1 = detail::deg(b[1]);
    size_t d;
    double r0, r1;
    //size_t iter = 0;
    while ((n0.first + n1.first) > n)// && iter < 30)
    {
//        ++iter;
//        std::cout << "iter = " << iter << std::endl;
//        for (size_t i= 0; i < 2; ++i)
//            for (size_t j= 0; j < 3; ++j)
//                std::cout << b[i][j] << std::endl;
//        std::cout << n0.first << ", " << n0.second << std::endl;
//        std::cout << n1.first << ", " << n1.second << std::endl;
//        std::cout << "-----" << std::endl;
//        if (n0.first < n1.first)
//        {
//            d = n1.first - n0.first;
//            r = b[1][n1.second][n1.first] / b[0][n1.second][n0.first];
//            for (size_t i = 0; i < b[0].size(); ++i)
//                b[1][i] -= ((r * b[0][i]).get_poly() << d);
//            b[1][n1.second][n1.first] = 0;
//            n1 = detail::deg(b[1]);
//        }
//        else
//        {
//            d = n0.first - n1.first;
//            r = b[0][n0.second][n0.first] / b[1][n0.second][n1.first];
//            for (size_t i = 0; i < b[0].size(); ++i)
//                b[0][i] -= ((r * b[1][i]).get_poly() << d);
//            b[0][n0.second][n0.first] = 0;
//            n0 = detail::deg(b[0]);
//        }

        // this version shouldn't suffer of ill-conditioning due to
        // cancellation issue
        if (n0.first < n1.first)
        {
            d = n1.first - n0.first;
            r0 = b[0][n1.second][n0.first];
            r1 = b[1][n1.second][n1.first];
            for (size_t i = 0; i < b[0].size(); ++i)
            {
                b[1][i] *= r0;
                b[1][i] -= ((r1 * b[0][i]).get_poly() << d);
                // without the following division the modulus grows
                // beyond the limit of the double type
                b[1][i] /= r0;
            }
            n1 = detail::deg(b[1]);
        }
        else
        {
            d = n0.first - n1.first;
            r0 = b[0][n1.second][n0.first];
            r1 = b[1][n1.second][n1.first];

            for (size_t i = 0; i < b[0].size(); ++i)
            {
                b[0][i] *= r1;
                b[0][i] -= ((r0 * b[1][i]).get_poly() << d);
                b[0][i] /= r1;
            }
            n0 = detail::deg(b[0]);
        }

    }
}

/*
 *  computes the dot product:
 *  p(t, x, y) = {p0(t), p1(t), p2(t)} . {x, y, 1}
 */
inline
void basis_to_poly(MVPoly3 & p0, poly_vector_type const& v)
{
    MVPoly3 p1, p2;
    detail::poly1_to_poly3(p0, v[0], 1,0);
    detail::poly1_to_poly3(p1, v[1], 0,1);
    detail::poly1_to_poly3(p2, v[2], 0,0);
    p0 += p1;
    p0 += p2;
}


/*
 * Make up a Bezout matrix with two basis genarators as input.
 *
 * A Bezout matrix is the matrix related to the symmetric bilinear form
 * (f,g) -> B[f,g] where B[f,g](s,t) = (f(t)*g(s) - f(s)*g(t))/(s-t)
 * where f, g are polynomials, this function is called a bezoutian.
 * Given a basis of generators {p(t, x, y), q(t, x, y)} for the ideal I
 * related to our parametrization x = f(t), y = g(t), we are able to prove
 * that the implicit equation of such polynomial parametrization can be
 * evaluated computing the determinant of the Bezout matrix made up using
 * the polinomial p and q as univariate polynomials in t with coefficients
 * in R[x,y], so the resulting Bezout matix will be a matrix with bivariate
 * polynomials as entries. A Bezout matrix is always symmetric.
 * Reference:
 * Sederberg, Zheng - Algebraic Methods for Computer Aided Geometric Design
 */
Matrix<MVPoly2>
make_bezout_matrix (MVPoly3 const& p, MVPoly3 const& q)
{
    size_t pdeg = p.get_poly().real_degree();
    size_t qdeg = q.get_poly().real_degree();
    size_t n = std::max(pdeg, qdeg);

    Matrix<MVPoly2> BM(n, n);
    //std::cerr << "rows, columns " << BM.rows() << " , " << BM.columns() << std::endl;
    for (size_t i = n; i >= 1; --i)
    {
        for (size_t j = n; j >= i; --j)
        {
            size_t m = std::min(i, n + 1 - j);
            //std::cerr << "m = " << m << std::endl;
            for (size_t k = 1; k <= m; ++k)
            {
                //BM(i-1,j-1) += (p[j-1+k] * q[i-k] - p[i-k] * q[j-1+k]);
                BM(n-i,n-j) += (p.coefficient(j-1+k) * q.coefficient(i-k)
                                - p.coefficient(i-k) * q.coefficient(j-1+k));
            }
        }
    }

    for (size_t i = 0; i < n; ++i)
    {
        for (size_t j = 0; j < i; ++j)
            BM(j,i) = BM(i,j);
    }
    return BM;
}

/*
 *  Make a matrix that represents a main minor (i.e. with the diagonal
 *  on the diagonal of the matrix to which it owns) of the Bezout matrix
 *  with order n-1 where n is the order of the Bezout matrix.
 *  The minor is obtained by removing the "h"-th row and the "h"-th column,
 *  and as the Bezout matrix is symmetric.
 */
Matrix<MVPoly2>
make_bezout_main_minor (MVPoly3 const& p, MVPoly3 const& q, size_t h)
{
    size_t pdeg = p.get_poly().real_degree();
    size_t qdeg = q.get_poly().real_degree();
    size_t n = std::max(pdeg, qdeg);

    Matrix<MVPoly2> BM(n-1, n-1);
    size_t u = 0, v;
    for (size_t i = 1; i <= n; ++i)
    {
        v = 0;
        if (i == h)
        {
            u = 1;
            continue;
        }
        for (size_t j = 1; j <= i; ++j)
        {
            if (j == h)
            {
                v = 1;
                continue;
            }
            size_t m = std::min(i, n + 1 - j);
            for (size_t k = 1; k <= m; ++k)
            {
                //BM(i-u-1,j-v-1) += (p[j-1+k] * q[i-k] - p[i-k] * q[j-1+k]);
                BM(i-u-1,j-v-1) += (p.coefficient(j-1+k) * q.coefficient(i-k)
                                  - p.coefficient(i-k) * q.coefficient(j-1+k));
            }
        }
    }

    --n;
    for (size_t i = 0; i < n; ++i)
    {
        for (size_t j = 0; j < i; ++j)
            BM(j,i) = BM(i,j);
    }
    return BM;
}


} /*end namespace Geom*/  } /*end namespace SL*/




#endif // _GEOM_SL_IMPLICIT_H_


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
