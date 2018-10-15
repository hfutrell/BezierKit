/*
 *  GiNaC Copyright (C) 1999-2008 Johannes Gutenberg University Mainz, Germany
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#ifndef _GEOM_SL_DETERMINANT_MINOR_H_
#define _GEOM_SL_DETERMINANT_MINOR_H_

#include <map>


namespace Geom { namespace SL {

/*
 * determinant_minor
 * This routine has been taken from the ginac project
 * and adapted as needed; comments are the original ones.
 */

/** Recursive determinant for small matrices having at least one symbolic
 *  entry.  The basic algorithm, known as Laplace-expansion, is enhanced by
 *  some bookkeeping to avoid calculation of the same submatrices ("minors")
 *  more than once.  According to W.M.Gentleman and S.C.Johnson this algorithm
 *  is better than elimination schemes for matrices of sparse multivariate
 *  polynomials and also for matrices of dense univariate polynomials if the
 *  matrix' dimesion is larger than 7.
 *
 *  @return the determinant as a new expression (in expanded form)
 *  @see matrix::determinant() */

template< typename Coeff >
Coeff determinant_minor(Matrix<Coeff> const& M)
{
    assert(M.rows() == M.columns());
    // for small matrices the algorithm does not make any sense:
    const unsigned int n = M.columns();
    if (n == 1)
        return M(0,0);
    if (n == 2)
        return (M(0,0) * M(1,1) - M(0,1) * M(1,0));
    if (n == 3)
        return ( M(0,0)*M(1,1)*M(2,2) + M(0,2)*M(1,0)*M(2,1)
                + M(0,1)*M(1,2)*M(2,0) - M(0,2)*M(1,1)*M(2,0)
                - M(0,0)*M(1,2)*M(2,1) - M(0,1)*M(1,0)*M(2,2) );

    // This algorithm can best be understood by looking at a naive
    // implementation of Laplace-expansion, like this one:
    // ex det;
    // matrix minorM(this->rows()-1,this->cols()-1);
    // for (unsigned r1=0; r1<this->rows(); ++r1) {
    //     // shortcut if element(r1,0) vanishes
    //     if (m[r1*col].is_zero())
    //         continue;
    //     // assemble the minor matrix
    //     for (unsigned r=0; r<minorM.rows(); ++r) {
    //         for (unsigned c=0; c<minorM.cols(); ++c) {
    //             if (r<r1)
    //                 minorM(r,c) = m[r*col+c+1];
    //             else
    //                 minorM(r,c) = m[(r+1)*col+c+1];
    //         }
    //     }
    //     // recurse down and care for sign:
    //     if (r1%2)
    //         det -= m[r1*col] * minorM.determinant_minor();
    //     else
    //         det += m[r1*col] * minorM.determinant_minor();
    // }
    // return det.expand();
    // What happens is that while proceeding down many of the minors are
    // computed more than once.  In particular, there are binomial(n,k)
    // kxk minors and each one is computed factorial(n-k) times.  Therefore
    // it is reasonable to store the results of the minors.  We proceed from
    // right to left.  At each column c we only need to retrieve the minors
    // calculated in step c-1.  We therefore only have to store at most
    // 2*binomial(n,n/2) minors.

    // Unique flipper counter for partitioning into minors
    std::vector<unsigned int> Pkey;
    Pkey.reserve(n);
    // key for minor determinant (a subpartition of Pkey)
    std::vector<unsigned int> Mkey;
    Mkey.reserve(n-1);
    // we store our subminors in maps, keys being the rows they arise from
    typedef typename std::map<std::vector<unsigned>, Coeff> Rmap;
    typedef typename std::map<std::vector<unsigned>, Coeff>::value_type Rmap_value;
    Rmap A;
    Rmap B;
    Coeff det;
    // initialize A with last column:
    for (unsigned int r = 0; r < n; ++r)
    {
        Pkey.erase(Pkey.begin(),Pkey.end());
        Pkey.push_back(r);
        A.insert(Rmap_value(Pkey,M(r,n-1)));
    }
    // proceed from right to left through matrix
    for (int c = n-2; c >= 0; --c)
    {
        Pkey.erase(Pkey.begin(),Pkey.end());  // don't change capacity
        Mkey.erase(Mkey.begin(),Mkey.end());
        for (unsigned int i = 0; i < n-c; ++i)
            Pkey.push_back(i);
        unsigned int fc = 0;  // controls logic for our strange flipper counter
        do
        {
            det = Geom::SL::zero<Coeff>()();
            for (unsigned int r = 0; r < n-c; ++r)
            {
                // maybe there is nothing to do?
                if (M(Pkey[r], c).is_zero())
                    continue;
                // create the sorted key for all possible minors
                Mkey.erase(Mkey.begin(),Mkey.end());
                for (unsigned int i = 0; i < n-c; ++i)
                    if (i != r)
                        Mkey.push_back(Pkey[i]);
                // Fetch the minors and compute the new determinant
                if (r % 2)
                    det -= M(Pkey[r],c)*A[Mkey];
                else
                    det += M(Pkey[r],c)*A[Mkey];
            }
            // store the new determinant at its place in B:
            if (!det.is_zero())
                B.insert(Rmap_value(Pkey,det));
            // increment our strange flipper counter
            for (fc = n-c; fc > 0; --fc)
            {
                ++Pkey[fc-1];
                if (Pkey[fc-1]<fc+c)
                    break;
            }
            if (fc < n-c && fc > 0)
                for (unsigned int j = fc; j < n-c; ++j)
                    Pkey[j] = Pkey[j-1]+1;
        } while(fc);
        // next column, so change the role of A and B:
        A.swap(B);
        B.clear();
    }

    return det;
}



} /*end namespace Geom*/  } /*end namespace SL*/

#endif  // _GEOM_SL_DETERMINANT_MINOR_H_


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
