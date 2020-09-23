/*
 * Copyright (C) 1995 by Sam Rushing <rushing@nightmare.com>
 */

/* $Id: avl.h,v 2.3 1997/02/21 23:27:19 rushing Exp $ */

#ifdef __cplusplus
extern "C" {
#endif

#include <sys/queue.h>	// [PAS]
#include "ipkTypes.h"	// [PAS]

typedef struct avl_node_tag {
  void *		key;
  struct avl_node_tag *	left;
  struct avl_node_tag *	right;  
  struct avl_node_tag *	parent;
  /*
   * The lower 2 bits of <rank_and_balance> specify the balance
   * factor: 00==-1, 01==0, 10==+1.
   * The rest of the bits are used for <rank>
   */
  unsigned long		rank_and_balance;
  SLIST_ENTRY(avl_node_tag) entries;	// free list [PAS]
} avl_node;

#define GET_BALANCE(n)	((int)(((n)->rank_and_balance & 3) - 1))

#define GET_RANK(n)	(((n)->rank_and_balance >> 2))

#define SET_BALANCE(n,b) \
  ((n)->rank_and_balance) = \
    (((n)->rank_and_balance & (~3)) | ((int)((b) + 1)))

#define SET_RANK(n,r) \
  ((n)->rank_and_balance) = \
    (((n)->rank_and_balance & 3) | (r << 2))

struct _avl_tree;

typedef int (*avl_key_compare_fun_type)	(void * compare_arg, void * a, void * b);
typedef int (*avl_iter_fun_type)	(void * key, void * iter_arg);
typedef int (*avl_iter_index_fun_type)	(unsigned long index, void * key, void * iter_arg);
typedef int (*avl_free_key_fun_type)	(void * key);
typedef int (*avl_key_printer_fun_type)	(char *, void *);

/*
 * <compare_fun> and <compare_arg> let us associate a particular compare
 * function with each tree, separately.
 */

typedef struct _avl_tree {
  avl_node *			root;
  unsigned long			height;
  unsigned long			length;
  avl_key_compare_fun_type	compare_fun;
  void * 			compare_arg;
} avl_tree;

// functions
KFT_memStat_t* KFT_avlMemStat(KFT_memStat_t* record);	// [PAS]
void KFT_avlExternalType(int type);	// [PAS]
void avl_free_all();	// [PAS]

avl_tree * new_avl_tree (avl_key_compare_fun_type compare_fun, void * compare_arg);
avl_node * new_avl_node (void * key, avl_node * parent);

void free_avl_tree (
  avl_tree *		tree,
  avl_free_key_fun_type	free_key_fun
  );

int insert_by_key (
  avl_tree *		ob,
  void *		key
  );

int remove_by_key (
  avl_tree *		tree,
  void *		key,
  avl_free_key_fun_type	free_key_fun
  );

int get_item_by_index (
  avl_tree *		tree,
  unsigned long		index,
  void **		value_address
  );

int get_item_by_key (
  avl_tree *		tree,
  void *		key,
  void **		value_address
  );

int iterate_inorder (
  avl_tree *		tree,
  avl_iter_fun_type	iter_fun,
  void *		iter_arg
  );

int iterate_index_range (
  avl_tree *		tree,
  avl_iter_index_fun_type iter_fun,
  unsigned long		low,
  unsigned long		high,
  void *		iter_arg
  );

int get_span_by_key (
  avl_tree *		tree,
  void *		key,
  unsigned long *	low,
  unsigned long *	high
  );

int get_span_by_two_keys (
  avl_tree *		tree,
  void *		key_a,
  void *		key_b,
  unsigned long *	low,
  unsigned long *	high
  );

avl_node * get_predecessor (avl_node * node);

avl_node * get_successor (avl_node * node);

avl_node * get_index_by_key (avl_tree * tree, void * key, unsigned long * index);
		  
/* These two are from David Ascher <david_ascher@brown.edu> */

int get_item_by_key_most (
  avl_tree *		tree,
  void *		key,
  void **		value_address
  );

int get_item_by_key_least (
  avl_tree *		tree,
  void *		key,
  void **		value_address
  );

//#if !IPK_NKE
#if 0
int verify (avl_tree * tree);

void print_tree (
  avl_tree *		tree,
  avl_key_printer_fun_type key_printer
  );
#endif

#ifdef __cplusplus
}
#endif
