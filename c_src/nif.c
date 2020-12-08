#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include "erl_nif.h"

#define MAX_DIM 2
#define CACHE_MAX_SZ  1000000
/* #define DEBUG_OUTPUT */

/* Based on kd-tree implementation : 
   https://rosettacode.org/wiki/K-d_tree#C 
*/

struct kd_node_t{
  long x[MAX_DIM];
  const char* data;
  struct kd_node_t *left, *right;
};

static FILE * DEBUG_FILE = NULL;
static ErlNifRWLock * rwlock;
static int NODES_ARRAY_LEN = 0;
static struct kd_node_t *THE_ROOT = NULL, *NODES_ARRAY = NULL;

inline void swap(struct kd_node_t *x, struct kd_node_t *y) {
    long tmp[MAX_DIM];
    const char* tmp_data = x->data;
    
    memcpy(tmp,  x->x, sizeof(tmp));
    x->data = y->data;
    memcpy(x->x, y->x, sizeof(tmp));
    y->data = tmp_data;
    memcpy(y->x, tmp,  sizeof(tmp));
}

/* see quickselect method */
struct kd_node_t*
find_median(struct kd_node_t *start, struct kd_node_t *end, int idx)
{
    if (end <= start) return NULL;
    if (end == start + 1)
        return start;
 
    struct kd_node_t *p, *store, *md = start + (end - start) / 2;
    long pivot;
    while (1) {
        pivot = md->x[idx];
 
        swap(md, end - 1);
        for (store = p = start; p < end; p++) {
            if (p->x[idx] < pivot) {
                if (p != store)
                    swap(p, store);
                store++;
            }
        }
        swap(store, end - 1);
 
        /* median has duplicate values */
        if (store->x[idx] == md->x[idx])
            return md;
 
        if (store > md) end = store;
        else        start = store;
    }
}

struct kd_node_t*    
make_tree(struct kd_node_t *t, int len, int i, int dim)
{
    struct kd_node_t *n;
 
    if (!len) return 0;
 
    if ((n = find_median(t, t + len, i))) {
        i = (i + 1) % dim;
        n->left  = make_tree(t, n - t, i, dim);
        n->right = make_tree(n + 1, t + len - (n + 1), i, dim);
    }
    return n;
}

static  ERL_NIF_TERM
debug_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  int i, b = 10;
  
  if(b >= NODES_ARRAY_LEN) b = NODES_ARRAY_LEN -1;

#ifdef DEBUG_OUTPUT
  for(i =0; i < b && NODES_ARRAY; i++) {
    enif_fprintf(DEBUG_FILE, "\tnode %d %p -> {%ld, %ld, \"%s\"}\n",
		 i, &NODES_ARRAY[i], (long int)trunc(NODES_ARRAY[i].x[0]), (long int)trunc(NODES_ARRAY[i].x[1]),NODES_ARRAY[i].data);
  }
#endif

  return enif_make_int(env, NODES_ARRAY_LEN);
 
}
static  ERL_NIF_TERM
debug2_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  int i, a, b;
  
  enif_get_int(env, argv[0], &a);
  enif_get_int(env, argv[1], &b);

  if(b >= NODES_ARRAY_LEN) b = NODES_ARRAY_LEN -1;
  if(a >= NODES_ARRAY_LEN) a = NODES_ARRAY_LEN -1;

#ifdef DEBUG_OUTPUT
  for(i =a; i <= b && NODES_ARRAY; i++) {
    enif_fprintf(DEBUG_FILE, "\tnode %d %p -> {%ld, %ld, \"%s\"}\n",
		 i, &NODES_ARRAY[i], NODES_ARRAY[i].x[0], NODES_ARRAY[i].x[1],NODES_ARRAY[i].data);
  }
#endif

  return enif_make_int(env, NODES_ARRAY_LEN);
 
}

/* expect an entry of the form {{ld_lat, ld_lng}, "address"} */
static ERL_NIF_TERM
new_tree(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ERL_NIF_TERM term, addresses;
  ErlNifBinary addr;
  const ERL_NIF_TERM* tuple;
  int tuple_size,  current = 0;
  struct kd_node_t *root, *found, *million;
  
   addresses = argv[0];
  
   if (!NODES_ARRAY) {
     NODES_ARRAY =(struct kd_node_t*) calloc(CACHE_MAX_SZ, sizeof(struct kd_node_t));

#ifdef DEBUG_OUTPUT
     DEBUG_FILE = fopen("/tmp/geo_outputs.txt", "w");
     setbuf(DEBUG_FILE, NULL);	
#endif
     rwlock =  enif_rwlock_create((char *)"sauber");
#ifdef DEBUG_OUTPUT
     enif_fprintf(DEBUG_FILE, ">> CALLOC %d ENTRIES at %p\n", CACHE_MAX_SZ, NODES_ARRAY);
#endif
   }

   enif_rwlock_rwlock(rwlock);

  if( enif_is_empty_list(env, addresses)) {
      NODES_ARRAY_LEN = 0;
      enif_rwlock_rwunlock(rwlock);
      return enif_make_int(env, NODES_ARRAY_LEN);
    }
   
  while (enif_get_list_cell(env, addresses, &term, &addresses) != 0 && current < CACHE_MAX_SZ) {
    
    if (enif_get_tuple(env, term, &tuple_size, &tuple) != 0) {
      if (tuple_size > 1) {
	
	/* enif_fprintf(DEBUG_FILE, "\n\r cell #1 : %T\r\n",  term); */
  	if (enif_inspect_binary(env, tuple[1], &addr) == 0) {
  	  return enif_make_badarg(env);
  	}
	
	if (enif_get_tuple(env, tuple[0], &tuple_size, &tuple) != 0) {
	  kd_node_t* node = &NODES_ARRAY[current];
 	  
	  enif_get_int64(env, tuple[0], &node->x[0]);
	  enif_get_int64(env, tuple[1], &node->x[1]);

	  if( node->data) {
	    free((void*)node->data);
	  }
	  node->data = strndup( (const char*)addr.data, addr.size);
	}
	 enif_release_binary(&addr);
      }
    }
    current++;    
  }
  NODES_ARRAY_LEN = current;
  
  THE_ROOT = make_tree(NODES_ARRAY, current, 0, 2);
  enif_rwlock_rwunlock(rwlock);

#ifdef DEBUG_OUTPUT
  enif_fprintf(DEBUG_FILE, ">> %d entries for NEW ROOT {%ld, %ld, %s} \n", current, THE_ROOT->x[0], THE_ROOT->x[1], THE_ROOT->data);
#endif

  return enif_make_int(env, NODES_ARRAY_LEN);

}

/* DO NOT WORK FOR geolocations along the 180° longitude axis */
inline long long
dist(struct kd_node_t *a, struct kd_node_t *b, int dim)
{
  long t;
  long long d = 0;
  
    while (dim--) {
        t = a->x[dim] - b->x[dim];
        d += t * t;
    }
    return d;
}
 


/* global variable, so sue me */
int visited;
 
void nearest(struct kd_node_t *root, struct kd_node_t *nd, int i, int dim,
	     struct kd_node_t **best, long long *best_dist)
{
  long long d;
  long  dx, dx2;
 
  if (!root) return;
  d = dist(root, nd, dim);
 
  dx = root->x[i] - nd->x[i];
  dx2 = dx * dx;
 
  visited ++;
 
  if (!*best || d < *best_dist) {
    *best_dist = d;
    *best = root;
  }
 
  /* if chance of exact match is high */
  if (!*best_dist) return;
 
  if (++i >= dim) i = 0;
 
  nearest(dx > 0 ? root->left : root->right, nd, i, dim, best, best_dist);
  if (dx2 >= *best_dist) return;
  nearest(dx > 0 ? root->right : root->left, nd, i, dim, best, best_dist);
}

#define N 1000000
#define rand1() (rand() / (double)RAND_MAX)
#define rand_pt(v) { v.x[0] = rand1(); v.x[1] = rand1(); }
#define MULT 11930464

// returns -1 | {addr, dist, time}
static  ERL_NIF_TERM
nearest_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  long lat, lng;
  struct kd_node_t testNode;
  struct kd_node_t *found;
  long long best_dist, acceptable_dist; 
  ErlNifBinary addr_output;
  int addr_output_size = 0;
  clock_t t;
 
  if(!NODES_ARRAY || !NODES_ARRAY_LEN)
    return enif_make_tuple2(env,
			    enif_make_atom(env, "error"),
			    enif_make_atom(env, "unitialized tree"));
  
  enif_get_int64(env, argv[0], &testNode.x[0]);
  enif_get_int64(env, argv[1], &testNode.x[1]);
         
  visited = 0;  // debug purpose
  found = 0;
  
  t = clock();
  enif_rwlock_rlock(rwlock);
  nearest(THE_ROOT, &testNode, 0, 2, &found, &best_dist);
  t = clock() - t;
  enif_rwlock_runlock(rwlock);
  double time_taken = ((double)t*1000000)/CLOCKS_PER_SEC;

  addr_output_size = strlen(found->data);
  enif_alloc_binary(addr_output_size, &addr_output);
  memcpy(addr_output.data, found->data, addr_output_size);
  return enif_make_tuple3(env, enif_make_binary(env, &addr_output),
			  enif_make_int64(env, trunc(best_dist)),
			  enif_make_double(env, time_taken));
}

static  ERL_NIF_TERM
bench_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  int i;
    struct kd_node_t wp[] = {
     {{2, 3}, "aa"}, {{5, 4}, "aa1"}, {{9, 6}, "aa2"}, {{4, 7}, "aa3"}, {{-8, 1}, "aa4"}, {{7, 2}, "aa5"}
    };
    struct kd_node_t testNode = {{-9, 2}, "add_x"};
    struct kd_node_t *root, *found, *million;
    long long best_dist;
    clock_t t;
 
    root = make_tree(wp, sizeof(wp) / sizeof(wp[1]), 0, 2);
 
    visited = 0;
    found = 0;
    nearest(root, &testNode, 0, 2, &found, &best_dist);
 
    printf(">> WP tree\nsearching for (%ld, %ld) "
            "found (%ld, %ld) dist %g\nseen %d nodes\n",
            testNode.x[0], testNode.x[1],
            found->x[0], found->x[1], sqrt(best_dist), visited);
 
   /*  million =(struct kd_node_t*) calloc(N, sizeof(struct kd_node_t)); */
   /*  srand(time(0)); */
   /*  for (i = 0; i < N; i++) rand_pt(million[i]); */
 
   /*  root = make_tree(million, N, 0, 2); */
   /* printf(">> GOT THE_ROOT %p \n\r", root); */
   /* printf(">> GOT ROOT  {%g, %g, %s} \n\r", root->x[0], root->x[1], root->data); */
   /* printf(">> GOT ROOT LEFT %s \n\r", root->left->data); */
   /* printf(">> GOT ROOT LEFT %s \n\r", root->right->data); */
   /* rand_pt(testNode); */
 
   /*  visited = 0; */
   /*  found = 0; */
   /*  nearest(root, &testNode, 0, 2, &found, &best_dist); */
 
   /*  printf(">> Million tree searching for (%g, %g)" */
   /*          "found (%g, %g) dist %g\nseen %d nodes\n\r", */
   /*          testNode.x[0], testNode.x[1], */
   /*          found->x[0], found->x[1], */
   /*          sqrt(best_dist), visited); */
 
   /*  /\* search many random points in million tree to see average behavior. */
   /*     tree size vs avg nodes visited: */
   /*     10      ~  7 */
   /*     100     ~ 16.5 */
   /*     1000        ~ 25.5 */
   /*     10000       ~ 32.8 */
   /*     100000      ~ 38.3 */
   /*     1000000     ~ 42.6 */
   /*     10000000    ~ 46.7              *\/ */
   /*  int sum = 0, test_runs = 100000; */
   /*   t = clock(); */
   /*  enif_fprintf(stderr, "test_runs : %d", test_runs); */
   /*  for (i = 0; i < test_runs; i++) { */
   /*       found = 0; */
   /*      visited = 0; */
   /*      rand_pt(testNode); */
   /*      nearest(root, &testNode, 0, 2, &found, &best_dist); */
   /*     sum += visited; */
   /*  } */
   /*  t = clock() - t; */
   /*  double time_taken = ((double)t*1000000)/CLOCKS_PER_SEC/ test_runs; */
   /*  enif_fprintf(stderr,">> Million tree " */
   /*          "visited %d nodes for %d random findings (%f per lookup) time: %f us.", */
   /* 	   sum, test_runs, sum/(double)test_runs, time_taken); */
 
   /*   free(million); */

    return enif_make_int(env, 3333);
}

int main(void)
{
    int i;
    struct kd_node_t wp[] = {
        {{2, 3}}, {{5, 4}}, {{9, 6}}, {{4, 7}}, {{8, 1}}, {{7, 2}}
    };
    struct kd_node_t testNode = {{9, 2}};
    struct kd_node_t *root, *found, *million;
    long long best_dist;
    clock_t t;
 
    root = make_tree(wp, sizeof(wp) / sizeof(wp[1]), 0, 2);
 
    visited = 0;
    found = 0;
    nearest(root, &testNode, 0, 2, &found, &best_dist);
 
    printf(">> WP tree\nsearching for (%ld, %ld)\n"
            "found (%ld, %ld) dist %g\nseen %d nodes\n\n",
            testNode.x[0], testNode.x[1],
            found->x[0], found->x[1], sqrt(best_dist), visited);
 
    million =(struct kd_node_t*) calloc(N, sizeof(struct kd_node_t));
    srand(time(0));
    for (i = 0; i < N; i++) rand_pt(million[i]);
 
    root = make_tree(million, N, 0, 2);
    rand_pt(testNode);
 
    visited = 0;
    found = 0;
    nearest(root, &testNode, 0, 2, &found, &best_dist);
 
    printf(">> Million tree\nsearching for (%ld, %ld)\n"
            "found (%ld, %ld) dist %g\nseen %d nodes\n",
	   testNode.x[0], testNode.x[1],
	   found->x[0], found->x[1],
            sqrt(best_dist), visited);
 
    /* search many random points in million tree to see average behavior.
       tree size vs avg nodes visited:
       10      ~  7
       100     ~ 16.5
       1000        ~ 25.5
       10000       ~ 32.8
       100000      ~ 38.3
       1000000     ~ 42.6
       10000000    ~ 46.7              */
    int sum = 0, test_runs = 100000;
     /* t = clock(); */
    for (i = 0; i < test_runs; i++) {
        found = 0;
        visited = 0;
        rand_pt(testNode);
        nearest(root, &testNode, 0, 2, &found, &best_dist);
        sum += visited;
    }
    /* t = clock() - t; */
    double time_taken = 0.0; // ((double)t*1000000)/CLOCKS_PER_SEC/ test_runs;
    printf("\n>> Million tree\n"
            "visited %d nodes for %d random findings (%f per lookup) time: %f us.\n",
	   sum, test_runs, sum/(double)test_runs, time_taken);
 
    free(million);
 
    return 0;
}


static ErlNifFunc nif_funcs[] = {
				 {"new_tree", 1, new_tree, ERL_NIF_DIRTY_JOB_CPU_BOUND},
				 {"bench", 0, bench_nif},
				 {"debug", 0, debug_nif},
				 {"debug2", 2, debug2_nif},
				 {"nearest", 2, nearest_nif}
};



ERL_NIF_INIT(Elixir.Nif, nif_funcs, NULL, NULL, NULL, NULL);
