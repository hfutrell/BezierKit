#include "interval_tree.h"
#include <stdio.h>
#include <math.h>
#include <assert.h>

// From Emin Martinian, licenced LGPL and MPL with permission


using namespace std;

// If the symbol CHECK_INTERVAL_TREE_ASSUMPTIONS is defined then the
// code does a lot of extra checking to make sure certain assumptions
// are satisfied.  This only needs to be done if you suspect bugs are
// present or if you make significant changes and want to make sure
// your changes didn't mess anything up.
//#define CHECK_INTERVAL_TREE_ASSUMPTIONS 1


const int MIN_INT=-MAX_INT;

IntervalTreeNode::IntervalTreeNode(){}

IntervalTreeNode::IntervalTreeNode(Interval * newInterval) 
  : storedInterval (newInterval) ,
    key(newInterval->GetLowPoint()), 
    high(newInterval->GetHighPoint()) , 
    maxHigh(high) {
}
IntervalTreeNode::~IntervalTreeNode(){}
Interval::Interval(){}
Interval::~Interval(){}
void Interval::Print() const {
  cout << "No Print Method defined for instance of Interval" << endl;
}

IntervalTree::IntervalTree()
{
  nil = new IntervalTreeNode;
  nil->left = nil->right = nil->parent = nil;
  nil->red = 0;
  nil->key = nil->high = nil->maxHigh = MIN_INT;
  nil->storedInterval = NULL;
  
  root = new IntervalTreeNode;
  root->parent = root->left = root->right = nil;
  root->key = root->high = root->maxHigh = MAX_INT;
  root->red=0;
  root->storedInterval = NULL;

  /* the following are used for the Enumerate function */
  recursionNodeStackSize = 8; // the tree depth is approximately lg(n), this is a 256 element tree.  The code will adapt to deeper trees, but this saves considerable space for small trees.
  recursionNodeStack = new it_recursion_node[recursionNodeStackSize];
  recursionNodeStackTop = 1;
  recursionNodeStack[0].start_node = NULL;
  
}

/***********************************************************************/
/*  FUNCTION:  LeftRotate */
/**/
/*  INPUTS:  the node to rotate on */
/**/
/*  OUTPUT:  None */
/**/
/*  Modifies Input: this, x */
/**/
/*  EFFECTS:  Rotates as described in _Introduction_To_Algorithms by */
/*            Cormen, Leiserson, Rivest (Chapter 14).  Basically this */
/*            makes the parent of x be to the left of x, x the parent of */
/*            its parent before the rotation and fixes other pointers */
/*            accordingly. Also updates the maxHigh fields of x and y */
/*            after rotation. */
/***********************************************************************/

void IntervalTree::LeftRotate(IntervalTreeNode* x) {
  IntervalTreeNode* y;
 
  /*  I originally wrote this function to use the sentinel for */
  /*  nil to avoid checking for nil.  However this introduces a */
  /*  very subtle bug because sometimes this function modifies */
  /*  the parent pointer of nil.  This can be a problem if a */
  /*  function which calls LeftRotate also uses the nil sentinel */
  /*  and expects the nil sentinel's parent pointer to be unchanged */
  /*  after calling this function.  For example, when DeleteFixUP */
  /*  calls LeftRotate it expects the parent pointer of nil to be */
  /*  unchanged. */

  y=x->right;
  x->right=y->left;

  if (y->left != nil) y->left->parent=x; /* used to use sentinel here */
  /* and do an unconditional assignment instead of testing for nil */
  
  y->parent=x->parent;   

  /* instead of checking if x->parent is the root as in the book, we */
  /* count on the root sentinel to implicitly take care of this case */
  if( x == x->parent->left) {
    x->parent->left=y;
  } else {
    x->parent->right=y;
  }
  y->left=x;
  x->parent=y;

  x->maxHigh=std::max(x->left->maxHigh,std::max(x->right->maxHigh,x->high));
  y->maxHigh=std::max(x->maxHigh,std::max(y->right->maxHigh,y->high));
#ifdef CHECK_INTERVAL_TREE_ASSUMPTIONS
  CheckAssumptions();
#elif defined(DEBUG_ASSERT)
  assert(!nil->red,"nil not red in ITLeftRotate");
  assert((nil->maxHigh=MIN_INT),
	 "nil->maxHigh != MIN_INT in ITLeftRotate");
#endif
}


/***********************************************************************/
/*  FUNCTION:  RighttRotate */
/**/
/*  INPUTS:  node to rotate on */
/**/
/*  OUTPUT:  None */
/**/
/*  Modifies Input?: this, y */
/**/
/*  EFFECTS:  Rotates as described in _Introduction_To_Algorithms by */
/*            Cormen, Leiserson, Rivest (Chapter 14).  Basically this */
/*            makes the parent of x be to the left of x, x the parent of */
/*            its parent before the rotation and fixes other pointers */
/*            accordingly. Also updates the maxHigh fields of x and y */
/*            after rotation. */
/***********************************************************************/


void IntervalTree::RightRotate(IntervalTreeNode* y) {
  IntervalTreeNode* x;

  /*  I originally wrote this function to use the sentinel for */
  /*  nil to avoid checking for nil.  However this introduces a */
  /*  very subtle bug because sometimes this function modifies */
  /*  the parent pointer of nil.  This can be a problem if a */
  /*  function which calls LeftRotate also uses the nil sentinel */
  /*  and expects the nil sentinel's parent pointer to be unchanged */
  /*  after calling this function.  For example, when DeleteFixUP */
  /*  calls LeftRotate it expects the parent pointer of nil to be */
  /*  unchanged. */

  x=y->left;
  y->left=x->right;

  if (nil != x->right)  x->right->parent=y; /*used to use sentinel here */
  /* and do an unconditional assignment instead of testing for nil */

  /* instead of checking if x->parent is the root as in the book, we */
  /* count on the root sentinel to implicitly take care of this case */
  x->parent=y->parent;
  if( y == y->parent->left) {
    y->parent->left=x;
  } else {
    y->parent->right=x;
  }
  x->right=y;
  y->parent=x;

  y->maxHigh=std::max(y->left->maxHigh,std::max(y->right->maxHigh,y->high));
  x->maxHigh=std::max(x->left->maxHigh,std::max(y->maxHigh,x->high));
#ifdef CHECK_INTERVAL_TREE_ASSUMPTIONS
  CheckAssumptions();
#elif defined(DEBUG_ASSERT)
  assert(!nil->red,"nil not red in ITRightRotate");
  assert((nil->maxHigh=MIN_INT),
	 "nil->maxHigh != MIN_INT in ITRightRotate");
#endif
}

/***********************************************************************/
/*  FUNCTION:  TreeInsertHelp  */
/**/
/*  INPUTS:  z is the node to insert */
/**/
/*  OUTPUT:  none */
/**/
/*  Modifies Input:  this, z */
/**/
/*  EFFECTS:  Inserts z into the tree as if it were a regular binary tree */
/*            using the algorithm described in _Introduction_To_Algorithms_ */
/*            by Cormen et al.  This function is only intended to be called */
/*            by the InsertTree function and not by the user */
/***********************************************************************/

void IntervalTree::TreeInsertHelp(IntervalTreeNode* z) {
  /*  This function should only be called by InsertITTree (see above) */
  IntervalTreeNode* x;
  IntervalTreeNode* y;
    
  z->left=z->right=nil;
  y=root;
  x=root->left;
  while( x != nil) {
    y=x;
    if ( x->key > z->key) { 
      x=x->left;
    } else { /* x->key <= z->key */
      x=x->right;
    }
  }
  z->parent=y;
  if ( (y == root) ||
       (y->key > z->key) ) { 
    y->left=z;
  } else {
    y->right=z;
  }


#if defined(DEBUG_ASSERT)
  assert(!nil->red,"nil not red in ITTreeInsertHelp");
  assert((nil->maxHigh=MIN_INT),
	 "nil->maxHigh != MIN_INT in ITTreeInsertHelp");
#endif
}


/***********************************************************************/
/*  FUNCTION:  FixUpMaxHigh  */
/**/
/*  INPUTS:  x is the node to start from*/
/**/
/*  OUTPUT:  none */
/**/
/*  Modifies Input:  this */
/**/
/*  EFFECTS:  Travels up to the root fixing the maxHigh fields after */
/*            an insertion or deletion */
/***********************************************************************/

void IntervalTree::FixUpMaxHigh(IntervalTreeNode * x) {
  while(x != root) {
    x->maxHigh=std::max(x->high,std::max(x->left->maxHigh,x->right->maxHigh));
    x=x->parent;
  }
#ifdef CHECK_INTERVAL_TREE_ASSUMPTIONS
  CheckAssumptions();
#endif
}

/*  Before calling InsertNode the node x should have its key set */

/***********************************************************************/
/*  FUNCTION:  InsertNode */
/**/
/*  INPUTS:  newInterval is the interval to insert*/
/**/
/*  OUTPUT:  This function returns a pointer to the newly inserted node */
/*           which is guarunteed to be valid until this node is deleted. */
/*           What this means is if another data structure stores this */
/*           pointer then the tree does not need to be searched when this */
/*           is to be deleted. */
/**/
/*  Modifies Input: tree */
/**/
/*  EFFECTS:  Creates a node node which contains the appropriate key and */
/*            info pointers and inserts it into the tree. */
/***********************************************************************/

IntervalTreeNode * IntervalTree::Insert(Interval * newInterval)
{
  IntervalTreeNode * y;
  IntervalTreeNode * x;
  IntervalTreeNode * newNode;

  x = new IntervalTreeNode(newInterval);
  TreeInsertHelp(x);
  FixUpMaxHigh(x->parent);
  newNode = x;
  x->red=1;
  while(x->parent->red) { /* use sentinel instead of checking for root */
    if (x->parent == x->parent->parent->left) {
      y=x->parent->parent->right;
      if (y->red) {
	x->parent->red=0;
	y->red=0;
	x->parent->parent->red=1;
	x=x->parent->parent;
      } else {
	if (x == x->parent->right) {
	  x=x->parent;
	  LeftRotate(x);
	}
	x->parent->red=0;
	x->parent->parent->red=1;
	RightRotate(x->parent->parent);
      } 
    } else { /* case for x->parent == x->parent->parent->right */
             /* this part is just like the section above with */
             /* left and right interchanged */
      y=x->parent->parent->left;
      if (y->red) {
	x->parent->red=0;
	y->red=0;
	x->parent->parent->red=1;
	x=x->parent->parent;
      } else {
	if (x == x->parent->left) {
	  x=x->parent;
	  RightRotate(x);
	}
	x->parent->red=0;
	x->parent->parent->red=1;
	LeftRotate(x->parent->parent);
      } 
    }
  }
  root->left->red=0;
  return(newNode);

#ifdef CHECK_INTERVAL_TREE_ASSUMPTIONS
  CheckAssumptions();
#elif defined(DEBUG_ASSERT)
  assert(!nil->red,"nil not red in ITTreeInsert");
  assert(!root->red,"root not red in ITTreeInsert");
  assert((nil->maxHigh=MIN_INT),
	 "nil->maxHigh != MIN_INT in ITTreeInsert");
#endif
}

/***********************************************************************/
/*  FUNCTION:  GetSuccessorOf  */
/**/
/*    INPUTS:  x is the node we want the successor of */
/**/
/*    OUTPUT:  This function returns the successor of x or NULL if no */
/*             successor exists. */
/**/
/*    Modifies Input: none */
/**/
/*    Note:  uses the algorithm in _Introduction_To_Algorithms_ */
/***********************************************************************/
  
IntervalTreeNode * IntervalTree::GetSuccessorOf(IntervalTreeNode * x) const
{ 
  IntervalTreeNode* y;

  if (nil != (y = x->right)) { /* assignment to y is intentional */
    while(y->left != nil) { /* returns the minimum of the right subtree of x */
      y=y->left;
    }
    return(y);
  } else {
    y=x->parent;
    while(x == y->right) { /* sentinel used instead of checking for nil */
      x=y;
      y=y->parent;
    }
    if (y == root) return(nil);
    return(y);
  }
}

/***********************************************************************/
/*  FUNCTION:  GetPredecessorOf  */
/**/
/*    INPUTS:  x is the node to get predecessor of */
/**/
/*    OUTPUT:  This function returns the predecessor of x or NULL if no */
/*             predecessor exists. */
/**/
/*    Modifies Input: none */
/**/
/*    Note:  uses the algorithm in _Introduction_To_Algorithms_ */
/***********************************************************************/

IntervalTreeNode * IntervalTree::GetPredecessorOf(IntervalTreeNode * x) const {
  IntervalTreeNode* y;

  if (nil != (y = x->left)) { /* assignment to y is intentional */
    while(y->right != nil) { /* returns the maximum of the left subtree of x */
      y=y->right;
    }
    return(y);
  } else {
    y=x->parent;
    while(x == y->left) { 
      if (y == root) return(nil); 
      x=y;
      y=y->parent;
    }
    return(y);
  }
}

/***********************************************************************/
/*  FUNCTION:  Print */
/**/
/*    INPUTS:  none */
/**/
/*    OUTPUT:  none  */
/**/
/*    EFFECTS:  This function recursively prints the nodes of the tree */
/*              inorder. */
/**/
/*    Modifies Input: none */
/**/
/*    Note:    This function should only be called from ITTreePrint */
/***********************************************************************/

void IntervalTreeNode::Print(IntervalTreeNode * nil,
			     IntervalTreeNode * root) const {
  storedInterval->Print();
  printf(", k=%i, h=%i, mH=%i",key,high,maxHigh);
  printf("  l->key=");
  if( left == nil) printf("NULL"); else printf("%i",left->key);
  printf("  r->key=");
  if( right == nil) printf("NULL"); else printf("%i",right->key);
  printf("  p->key=");
  if( parent == root) printf("NULL"); else printf("%i",parent->key);
  printf("  red=%i\n",red);
}

void IntervalTree::TreePrintHelper( IntervalTreeNode* x) const {
  
  if (x != nil) {
    TreePrintHelper(x->left);
    x->Print(nil,root);
    TreePrintHelper(x->right);
  }
}

IntervalTree::~IntervalTree() {
  IntervalTreeNode * x = root->left;
  vector<IntervalTreeNode *> stuffToFree;

  if (x != nil) {
    if (x->left != nil) {
      stuffToFree.push_back(x->left);
    }
    if (x->right != nil) {
      stuffToFree.push_back(x->right);
    }
    // delete x->storedInterval;
    delete x;
    while(! stuffToFree.empty() ) {
      x = stuffToFree.back();
      stuffToFree.pop_back();
      if (x->left != nil) {
	stuffToFree.push_back(x->left);
      }
      if (x->right != nil) {
	stuffToFree.push_back(x->right);
      }
      // delete x->storedInterval;
      delete x;
    }
  }
  delete nil;
  delete root;
  delete[] recursionNodeStack;
}


/***********************************************************************/
/*  FUNCTION:  Print */
/**/
/*    INPUTS:  none */
/**/
/*    OUTPUT:  none */
/**/
/*    EFFECT:  This function recursively prints the nodes of the tree */
/*             inorder. */
/**/
/*    Modifies Input: none */
/**/
/***********************************************************************/

void IntervalTree::Print() const {
  TreePrintHelper(root->left);
}

/***********************************************************************/
/*  FUNCTION:  DeleteFixUp */
/**/
/*    INPUTS:  x is the child of the spliced */
/*             out node in DeleteNode. */
/**/
/*    OUTPUT:  none */
/**/
/*    EFFECT:  Performs rotations and changes colors to restore red-black */
/*             properties after a node is deleted */
/**/
/*    Modifies Input: this, x */
/**/
/*    The algorithm from this function is from _Introduction_To_Algorithms_ */
/***********************************************************************/

void IntervalTree::DeleteFixUp(IntervalTreeNode* x) {
  IntervalTreeNode * w;
  IntervalTreeNode * rootLeft = root->left;

  while( (!x->red) && (rootLeft != x)) {
    if (x == x->parent->left) {
      w=x->parent->right;
      if (w->red) {
	w->red=0;
	x->parent->red=1;
	LeftRotate(x->parent);
	w=x->parent->right;
      }
      if ( (!w->right->red) && (!w->left->red) ) { 
	w->red=1;
	x=x->parent;
      } else {
	if (!w->right->red) {
	  w->left->red=0;
	  w->red=1;
	  RightRotate(w);
	  w=x->parent->right;
	}
	w->red=x->parent->red;
	x->parent->red=0;
	w->right->red=0;
	LeftRotate(x->parent);
	x=rootLeft; /* this is to exit while loop */
      }
    } else { /* the code below is has left and right switched from above */
      w=x->parent->left;
      if (w->red) {
	w->red=0;
	x->parent->red=1;
	RightRotate(x->parent);
	w=x->parent->left;
      }
      if ( (!w->right->red) && (!w->left->red) ) { 
	w->red=1;
	x=x->parent;
      } else {
	if (!w->left->red) {
	  w->right->red=0;
	  w->red=1;
	  LeftRotate(w);
	  w=x->parent->left;
	}
	w->red=x->parent->red;
	x->parent->red=0;
	w->left->red=0;
	RightRotate(x->parent);
	x=rootLeft; /* this is to exit while loop */
      }
    }
  }
  x->red=0;

#ifdef CHECK_INTERVAL_TREE_ASSUMPTIONS
  CheckAssumptions();
#elif defined(DEBUG_ASSERT)
  assert(!nil->red,"nil not black in ITDeleteFixUp");
  assert((nil->maxHigh=MIN_INT),
	 "nil->maxHigh != MIN_INT in ITDeleteFixUp");
#endif
}


/***********************************************************************/
/*  FUNCTION:  DeleteNode */
/**/
/*    INPUTS:  tree is the tree to delete node z from */
/**/
/*    OUTPUT:  returns the Interval stored at deleted node */
/**/
/*    EFFECT:  Deletes z from tree and but don't call destructor */
/*             Then calls FixUpMaxHigh to fix maxHigh fields then calls */
/*             ITDeleteFixUp to restore red-black properties */
/**/
/*    Modifies Input:  z */
/**/
/*    The algorithm from this function is from _Introduction_To_Algorithms_ */
/***********************************************************************/

Interval * IntervalTree::DeleteNode(IntervalTreeNode * z){
  IntervalTreeNode* y;
  IntervalTreeNode* x;
  Interval * returnValue = z->storedInterval;

  y= ((z->left == nil) || (z->right == nil)) ? z : GetSuccessorOf(z);
  x= (y->left == nil) ? y->right : y->left;
  if (root == (x->parent = y->parent)) { /* assignment of y->p to x->p is intentional */
    root->left=x;
  } else {
    if (y == y->parent->left) {
      y->parent->left=x;
    } else {
      y->parent->right=x;
    }
  }
  if (y != z) { /* y should not be nil in this case */

#ifdef DEBUG_ASSERT
    assert( (y!=nil),"y is nil in DeleteNode \n");
#endif
    /* y is the node to splice out and x is its child */
  
    y->maxHigh = MIN_INT;
    y->left=z->left;
    y->right=z->right;
    y->parent=z->parent;
    z->left->parent=z->right->parent=y;
    if (z == z->parent->left) {
      z->parent->left=y; 
    } else {
      z->parent->right=y;
    }
    FixUpMaxHigh(x->parent); 
    if (!(y->red)) {
      y->red = z->red;
      DeleteFixUp(x);
    } else
      y->red = z->red; 
    delete z;
#ifdef CHECK_INTERVAL_TREE_ASSUMPTIONS
    CheckAssumptions();
#elif defined(DEBUG_ASSERT)
    assert(!nil->red,"nil not black in ITDelete");
    assert((nil->maxHigh=MIN_INT),"nil->maxHigh != MIN_INT in ITDelete");
#endif
  } else {
    FixUpMaxHigh(x->parent);
    if (!(y->red)) DeleteFixUp(x);
    delete y;
#ifdef CHECK_INTERVAL_TREE_ASSUMPTIONS
    CheckAssumptions();
#elif defined(DEBUG_ASSERT)
    assert(!nil->red,"nil not black in ITDelete");
    assert((nil->maxHigh=MIN_INT),"nil->maxHigh != MIN_INT in ITDelete");
#endif
  }
  return returnValue;
}


/***********************************************************************/
/*  FUNCTION:  Overlap */
/**/
/*    INPUTS:  [a1,a2] and [b1,b2] are the low and high endpoints of two */
/*             closed intervals.  */
/**/
/*    OUTPUT:  stack containing pointers to the nodes between [low,high] */
/**/
/*    Modifies Input: none */
/**/
/*    EFFECT:  returns 1 if the intervals overlap, and 0 otherwise */
/***********************************************************************/

int Overlap(int a1, int a2, int b1, int b2) {
  if (a1 <= b1) {
    return( (b1 <= a2) );
  } else {
    return( (a1 <= b2) );
  }
}


/***********************************************************************/
/*  FUNCTION:  Enumerate */
/**/
/*    INPUTS:  tree is the tree to look for intervals overlapping the */
/*             closed interval [low,high]  */
/**/
/*    OUTPUT:  stack containing pointers to the nodes overlapping */
/*             [low,high] */
/**/
/*    Modifies Input: none */
/**/
/*    EFFECT:  Returns a stack containing pointers to nodes containing */
/*             intervals which overlap [low,high] in O(max(N,k*log(N))) */
/*             where N is the number of intervals in the tree and k is  */
/*             the number of overlapping intervals                      */
/**/
/*    Note:    This basic idea for this function comes from the  */
/*              _Introduction_To_Algorithms_ book by Cormen et al, but */
/*             modifications were made to return all overlapping intervals */
/*             instead of just the first overlapping interval as in the */
/*             book.  The natural way to do this would require recursive */
/*             calls of a basic search function.  I translated the */
/*             recursive version into an interative version with a stack */
/*             as described below. */
/***********************************************************************/



/*  The basic idea for the function below is to take the IntervalSearch */
/*  function from the book and modify to find all overlapping intervals */
/*  instead of just one.  This means that any time we take the left */
/*  branch down the tree we must also check the right branch if and only if */
/*  we find an overlapping interval in that left branch.  Note this is a */
/*  recursive condition because if we go left at the root then go left */
/*  again at the first left child and find an overlap in the left subtree */
/*  of the left child of root we must recursively check the right subtree */
/*  of the left child of root as well as the right child of root. */

vector<void *> IntervalTree::Enumerate(int low, int high)  {
  vector<void *> enumResultStack;
  IntervalTreeNode* x=root->left;
  int stuffToDo = (x != nil);
  
  // Possible speed up: add min field to prune right searches //

#ifdef DEBUG_ASSERT
  assert((recursionNodeStackTop == 1),
	 "recursionStack not empty when entering IntervalTree::Enumerate");
#endif
  currentParent = 0;

  while(stuffToDo) {
    if (Overlap(low,high,x->key,x->high) ) {
      enumResultStack.push_back(x->storedInterval);
      recursionNodeStack[currentParent].tryRightBranch=true;
    }
    if(x->left->maxHigh >= low) { // implies x != nil 
      if ( recursionNodeStackTop == recursionNodeStackSize ) {
	recursionNodeStackSize *= 2;
	recursionNodeStack = (it_recursion_node *) 
	  realloc(recursionNodeStack,
		  recursionNodeStackSize * sizeof(it_recursion_node));
	if (recursionNodeStack == NULL) 
	  assert("realloc failed in IntervalTree::Enumerate\n");
      }
      recursionNodeStack[recursionNodeStackTop].start_node = x;
      recursionNodeStack[recursionNodeStackTop].tryRightBranch = 0;
      recursionNodeStack[recursionNodeStackTop].parentIndex = currentParent;
      currentParent = recursionNodeStackTop++;
      x = x->left;
    } else {
      x = x->right;
    }
    stuffToDo = (x != nil);
    while( (!stuffToDo) && (recursionNodeStackTop > 1) ) {
	if(recursionNodeStack[--recursionNodeStackTop].tryRightBranch) {
	  x=recursionNodeStack[recursionNodeStackTop].start_node->right;
	  currentParent=recursionNodeStack[recursionNodeStackTop].parentIndex;
	  recursionNodeStack[currentParent].tryRightBranch=true;
	  stuffToDo = ( x != nil);
	}
    }
  }
#ifdef DEBUG_ASSERT
  assert((recursionNodeStackTop == 1),
	 "recursionStack not empty when exiting IntervalTree::Enumerate");
#endif
  return enumResultStack;   
}
	


int IntervalTree::CheckMaxHighFieldsHelper(IntervalTreeNode * y, 
				    const int currentHigh,
				    int match) const
{
  if (y != nil) {
    match = CheckMaxHighFieldsHelper(y->left,currentHigh,match) ?
      1 : match;
    assert(y->high <= currentHigh);
    if (y->high == currentHigh)
      match = 1;
    match = CheckMaxHighFieldsHelper(y->right,currentHigh,match) ?
      1 : match;
  }
  return match;
}

	  

/* Make sure the maxHigh fields for everything makes sense. *
 * If something is wrong, print a warning and exit */
void IntervalTree::CheckMaxHighFields(IntervalTreeNode * x) const {
  if (x != nil) {
    CheckMaxHighFields(x->left);
    if(!(CheckMaxHighFieldsHelper(x,x->maxHigh,0) > 0)) {
      assert("error found in CheckMaxHighFields.\n");
    }
    CheckMaxHighFields(x->right);
  }
}

void IntervalTree::CheckAssumptions() const {
 assert(nil->key == MIN_INT);
 assert(nil->high == MIN_INT);
 assert(nil->maxHigh == MIN_INT);
 assert(root->key == MAX_INT);
 assert(root->high == MAX_INT);
 assert(root->maxHigh == MAX_INT);
 assert(nil->storedInterval == NULL);
 assert(root->storedInterval == NULL);
 assert(nil->red == 0);
 assert(root->red == 0);
 CheckMaxHighFields(root->left);
}
 


