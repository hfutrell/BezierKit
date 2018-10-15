#include <iostream>

// Nathan Hurst and Emin Martinian, licenced LGPL and MPL with permission


#include "interval_tree.h"

class SimpleInterval : public Interval {
public:
  SimpleInterval() :
    _low(0),
    _high(0),
    _node(NULL)
    {}
  SimpleInterval(const int low,const int high)
    :_low(low),
    _high(high),
    _node(NULL)
    { }
  
  int GetLowPoint() const { return _low;}
  int GetHighPoint() const { return _high;}
  IntervalTreeNode * GetNode() { return _node;}
  void SetNode(IntervalTreeNode * node) {_node = node;}
  virtual void Print() const {
    printf("(%d, %d)", _low, _high);
  }
protected:
  int _low;
  int _high;
  IntervalTreeNode * _node;

};

using namespace std;

#include <stdlib.h>
#include <time.h>

int main() {
  const int N = 1L<<24;
  SimpleInterval *x = new SimpleInterval[N];
  for(int i = 0; i < N; i++) {
    x[i] = SimpleInterval(random(), random());
  }
  
  cout << "sizeof(SimpleInterval)" << sizeof(SimpleInterval) << endl;
  cout << "sizeof(IntervalTreeNode)" << sizeof(IntervalTreeNode) << endl;
  cout << "sizeof(it_recursion_node)" << sizeof(it_recursion_node) << endl;
  cout << "sizeof(IntervalTree)" << sizeof(IntervalTree) << endl;
  
  IntervalTree itree;
  int onn = 0;
  for(int nn = 1; nn < N; nn*=2) {
    for(int i = onn; i < nn; i++) {
      itree.Insert(&x[i]);
    }
    onn = nn;
    clock_t s = clock();
  
    int iters = 0;
    int outputs = 0;
    while(clock() - s < CLOCKS_PER_SEC/4) {
      vector<void *> n = itree.Enumerate(random(), random()) ;
      outputs += n.size();
      //cout << n.size() << endl;
      iters++;
    }
    clock_t e = clock();
    double total = double(e - s)/(CLOCKS_PER_SEC);
    cout << total << " " << outputs << " " << total/outputs << " " << nn << endl;
  }
  //itree.Print();
}
