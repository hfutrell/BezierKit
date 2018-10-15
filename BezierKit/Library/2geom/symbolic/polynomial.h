/*
 * Polynomial<CoeffT> class template
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

#ifndef _GEOM_SL_POLYNOMIAL_H_
#define _GEOM_SL_POLYNOMIAL_H_


#include <2geom/symbolic/unity-builder.h>

#include <vector>
#include <string>

#include <2geom/exception.h>




namespace Geom { namespace SL {

/*
 * Polynomial<CoeffT> class template
 *
 * It represents a generic univariate polynomial with coefficients
 * of type CoeffT. One way to get a multi-variate polynomial is
 * to utilize a Polynomial instantiation as coefficient type
 * in a recursive style.
 *
 */

template< typename CoeffT >
class Polynomial
{
  public:
    typedef CoeffT coeff_type;
    typedef std::vector<coeff_type> coeff_container_t;
    typedef typename coeff_container_t::iterator iterator;
    typedef typename coeff_container_t::const_iterator const_iterator;

    /*
     * a Polynomial should be never empty
     */
    Polynomial()
    {
        m_coeff.push_back(zero_coeff);
    }

    explicit
    Polynomial(CoeffT const& c, size_t i = 0)
    {
        m_coeff.resize(i, zero_coeff);
        m_coeff.push_back(c);
    }

    /*
     *  forwarding of some std::vector methods
     */

    size_t size() const
    {
        return m_coeff.size();
    }

    const_iterator begin() const
    {
        return m_coeff.begin();
    }

    const_iterator end() const
    {
        return m_coeff.end();
    }

    iterator begin()
    {
        return m_coeff.begin();
    }

    iterator end()
    {
        return m_coeff.end();
    }

    void reserve(size_t n)
    {
        m_coeff.reserve(n);
    }

    size_t capacity() const
    {
        return m_coeff.capacity();
    }

    /*
     *  degree of the term with the highest degree
     *  and an initialized coefficient (even if zero)
     */
    size_t max_degree() const
    {
        if (size() == 0)
            THROW_INVARIANTSVIOLATION (0);

        return (size() - 1);
    }

    void max_degree(size_t n)
    {
        m_coeff.resize(n+1, zero_coeff);
    }

    /*
     *  degree of the term with the highest degree
     *  and an initialized coefficient that is not null
     */
    size_t real_degree() const
    {
        if (size() == 0)
            THROW_INVARIANTSVIOLATION (0);

        const_iterator it = end() - 1;
        for (; it != begin(); --it)
        {
            if (*it != zero_coeff) break;
        }
        size_t i = static_cast<size_t>(it - begin());
        return i;
    }

    bool is_zero() const
    {
        if (size() == 0)
            THROW_INVARIANTSVIOLATION (0);

        if (real_degree() != 0) return false;
        if (m_coeff[0] != zero_coeff) return false;
        return true;
    }

    /*
     * trim leading zero coefficients
     * after calling normalize max_degree == real_degree
     */
    void normalize()
    {
        size_t rd = real_degree();
        if (rd != max_degree())
        {
            m_coeff.erase(begin() + rd + 1, end());
        }
    }

    coeff_type const& operator[] (size_t i) const
    {
        return m_coeff[i];
    }

    coeff_type & operator[] (size_t i)
    {
        return m_coeff[i];
    }

    // safe coefficient getter routine
    coeff_type const& coefficient(size_t i) const
    {
        if (i > max_degree())
        {
            return zero_coeff;
        }
        else
        {
            return m_coeff[i];
        }
    }

    // safe coefficient setter routine
    void coefficient(size_t i, coeff_type const& c)
    {
        //std::cerr << "i: " << i << " c: " << c << std::endl;
        if (i > max_degree())
        {
            if (c == zero_coeff) return;
            reserve(i+1);
            m_coeff.resize(i, zero_coeff);
            m_coeff.push_back(c);
        }
        else
        {
            m_coeff[i] = c;
        }
    }

    coeff_type const& leading_coefficient() const
    {
        return m_coeff[real_degree()];
    }

    coeff_type & leading_coefficient()
    {
        return m_coeff[real_degree()];
    }

    /*
     * polynomail evaluation:
     * T can be any type that is able to be + and * with the coefficient type
     */
    template <typename T>
    T operator() (T const& x) const
    {
        T r = zero<T>()();
        for(size_t i = max_degree(); i > 0; --i)
        {
            r += (*this)[i];
            r *= x;
        }
        r += (*this)[0];
        return r;
    }

    // opposite polynomial
    Polynomial operator-() const
    {
        Polynomial r;
        // we need r.m_coeff to be empty so we can utilize push_back
        r.m_coeff.pop_back();
        r.reserve(size());
        for(size_t i = 0; i < size(); ++i)
        {
            r.m_coeff.push_back( -(*this)[i] );
        }
        return r;
    }

    /*
     *  polynomial-polynomial mutating operators
     */

    Polynomial& operator+=(Polynomial const& p)
    {
        size_t sz = std::min(size(), p.size());
        for (size_t i = 0; i < sz; ++i)
        {
            (*this)[i] += p[i];
        }
        if (size() < p.size())
        {
            m_coeff.insert(end(), p.begin() + size(), p.end());
        }
        return (*this);
    }

    Polynomial& operator-=(Polynomial const& p)
    {
        size_t sz = std::min(size(), p.size());
        for (size_t i = 0; i < sz; ++i)
        {
            (*this)[i] -= p[i];
        }
        reserve(p.size());
        for(size_t i = sz; i < p.size(); ++i)
        {
            m_coeff.push_back( -p[i] );
        }
        return (*this);
    }

    Polynomial& operator*=(Polynomial const& p)
    {
        Polynomial r;
        r.m_coeff.resize(size() + p.size() - 1, zero_coeff);

        for (size_t i = 0; i < size(); ++i)
        {
            for (size_t j = 0; j < p.size(); ++j)
            {
                r[i+j] += (*this)[i] * p[j];
            }
        }
        (*this) = r;
        return (*this);
    }

    /*
     *  equivalent to multiply by x^n
     */
    Polynomial& operator<<=(size_t n)
    {
        m_coeff.insert(begin(), n, zero_coeff);
        return (*this);
    }

    /*
     *  polynomial-coefficient mutating operators
     */

    Polynomial& operator=(coeff_type const& c)
    {
        m_coeff[0] = c;
        return (*this);
    }

    Polynomial& operator+=(coeff_type const& c)
    {
        (*this)[0] += c;
        return (*this);
    }

    Polynomial& operator-=(coeff_type const& c)
    {
        (*this)[0] -= c;
        return (*this);
    }

    Polynomial& operator*=(coeff_type const& c)
    {
        for (size_t i = 0; i < size(); ++i)
        {
            (*this)[i] *= c;
        }
        return (*this);
    }

    // return the poly in a string form
    std::string str() const;

  private:
    // with zero_coeff defined as a static data member
    // coefficient(size_t i) safe get method can always
    // return a (const) reference
    static const coeff_type zero_coeff;
    coeff_container_t m_coeff;

}; // end class Polynomial


/*
 *  zero and one element spezcialization for Polynomial
 */

template< typename CoeffT >
struct zero<Polynomial<CoeffT>, false>
{
    Polynomial<CoeffT> operator() () const
    {
        CoeffT zc = zero<CoeffT>()();
        Polynomial<CoeffT> z(zc);
        return z;
    }
};

template< typename CoeffT >
struct one<Polynomial<CoeffT>, false>
{
    Polynomial<CoeffT> operator() ()
    {
        CoeffT _1c = one<CoeffT>()();
        Polynomial<CoeffT> _1(_1c);
        return _1;
    }
};


/*
 * initialization of Polynomial static data members
 */

template< typename CoeffT >
const typename Polynomial<CoeffT>::coeff_type Polynomial<CoeffT>::zero_coeff
    = zero<typename Polynomial<CoeffT>::coeff_type>()();

/*
 * Polynomial - Polynomial binary mathematical operators
 */

template< typename CoeffT >
inline
bool operator==(Polynomial<CoeffT> const& p, Polynomial<CoeffT> const& q)
{
    size_t d = p.real_degree();
    if (d != q.real_degree()) return false;
    for (size_t i = 0; i <= d; ++i)
    {
        if (p[i] != q[i]) return false;
    }
    return true;
}

template< typename CoeffT >
inline
bool operator!=(Polynomial<CoeffT> const& p, Polynomial<CoeffT> const& q)
{
    return !(p == q);
}

template< typename CoeffT >
inline
Polynomial<CoeffT>
operator+( Polynomial<CoeffT> const& p, Polynomial<CoeffT> const& q )
{
    Polynomial<CoeffT> r(p);
    r += q;
    return r;
}

template< typename CoeffT >
inline
Polynomial<CoeffT>
operator-( Polynomial<CoeffT> const& p, Polynomial<CoeffT> const& q )
{
    Polynomial<CoeffT> r(p);
    r -= q;
    return r;
}

template< typename CoeffT >
inline
Polynomial<CoeffT>
operator*( Polynomial<CoeffT> const& p, Polynomial<CoeffT> const& q )
{
    Polynomial<CoeffT> r(p);
    r *= q;
    return r;
}

template< typename CoeffT >
inline
Polynomial<CoeffT> operator<<(Polynomial<CoeffT> const& p, size_t n)
{
    Polynomial<CoeffT> r(p);
    r <<= n;
    return r;
}


/*
 *  polynomial-coefficient and coefficient-polynomial mathematical operators
 */

template< typename CoeffT >
inline
Polynomial<CoeffT>
operator+( Polynomial<CoeffT> const& p, CoeffT const& c )
{
    Polynomial<CoeffT> r(p);
    r += c;
    return r;
}

template< typename CoeffT >
inline
Polynomial<CoeffT>
operator+( CoeffT const& c, Polynomial<CoeffT> const& p)
{
    return (p + c);
}

template< typename CoeffT >
inline
Polynomial<CoeffT>
operator-( Polynomial<CoeffT> const& p, CoeffT const& c )
{
    Polynomial<CoeffT> r(p);
    r -= c;
    return r;
}

template< typename CoeffT >
inline
Polynomial<CoeffT>
operator-( CoeffT const& c, Polynomial<CoeffT> const& p)
{
    return (p - c);
}

template< typename CoeffT >
inline
Polynomial<CoeffT>
operator*( Polynomial<CoeffT> const& p, CoeffT const& c )
{
    Polynomial<CoeffT> r(p);
    r *= c;
    return r;
}

template< typename CoeffT >
inline
Polynomial<CoeffT>
operator*( CoeffT const& c, Polynomial<CoeffT> const& p)
{
    return (p * c);
}


/*
 *  operator<< extension for printing Polynomial
 *  and str() method for transforming a Polynomial into a string
 */

template< typename charT, typename CoeffT >
inline
std::basic_ostream<charT> &
operator<< (std::basic_ostream<charT> & os, const Polynomial<CoeffT> & p)
{
    if (p.size() == 0) return os;
    os << "{" << p[0];
    for (size_t i = 1; i < p.size(); ++i)
    {
        os << ", " << p[i];
    }
    os << "}";
    return os;
}


template< typename CoeffT >
inline
std::string Polynomial<CoeffT>::str() const
{
    std::ostringstream oss;
    oss << (*this);
    return oss.str();
}


} /*end namespace Geom*/  } /*end namespace SL*/




#endif // _GEOM_SL_POLYNOMIAL_H_


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
