#include "config.h"
#include <stdlib.h>
#include <time.h>
#include "wipe.h"
#include "options.h"
#include "log.h"

/* ISAAC prng */
#include "standard.h"
#include "rand.h"

/* SHA-1 prng */
#include "sha1random.h"


void sha1_stop_random(void *p)
{
	data_context_t *ctx = (data_context_t*)p;
	if (!ctx->random_context) {
		return;
	}
	SHA1RandomFinalize(ctx->random_context);
	SHA1RandomFree(&(ctx->random_context));
	ctx->random_context = NULL;
}

void sha1_restart_random(void *p, int seed) 
{
	data_context_t *ctx = (data_context_t*)p;
	SHA1RandomFinalize(ctx->random_context);
	SHA1RandomInitialize(ctx->random_context);
	SHA1RandomRandomize(ctx->random_context, (byte*)&seed, sizeof(seed));
}

void sha1_get_random(void *p, unsigned char *buf, int size) 
{
	data_context_t *ctx = (data_context_t*)p;
	SHA1RandomGetRandomBytes(ctx->random_context, buf, size);
}

int  sha1_init_random(data_context_t *ctx) 
{
	int     res, t;
	
	t = time(NULL); /* ? */
	
	res = SHA1RandomAllocate(&(ctx->random_context));
	if (0 != res) {
		log_message(LOG_FATAL, "Could not allocate memory for SHA1 random generator\n");
		return res;
	}
	
	res = SHA1RandomInitialize(ctx->random_context);
	if (0 != res) {
		log_message(LOG_FATAL, "Could not initialize SHA1 random generator\n");
		SHA1RandomFree(&(ctx->random_context));
		return res;
	}
	
	res = SHA1RandomRandomize(ctx->random_context, (byte*)&t, sizeof(t));
	if (0 != res) {
		log_message(LOG_FATAL, "Could not start SHA1 random generator\n");
		SHA1RandomFree(&(ctx->random_context));
		return res;
	}
	
	ctx->stop_random = sha1_stop_random;
	ctx->restart_random = sha1_restart_random;
	ctx->get_random = sha1_get_random;
	return 0;
} 


void isaac_stop_random(void *p) 
{
	data_context_t *ctx = (data_context_t*)p;
	if (ctx->random_context) {
		free(ctx->random_context);
		ctx->random_context = NULL;
	}
}

void isaac_restart_random(void *p, int seed) 
{
	data_context_t *ctx = (data_context_t*)p;
	randctx *prx = (randctx*)ctx->random_context;
	int      i;

	prx->randa = 0;
	prx->randb = 0;
	prx->randc = 0;
	prx->randcnt = 0;
	
	for (i = 0; i < RANDSIZ; i++) {
		prx->randrsl[i] = (seed >> (i % 32)) & 0xFF;
	}
	randinit(prx);
}

void isaac_get_random(void *p, unsigned char *buf, int size) 
{
	data_context_t *ctx = (data_context_t*)p;
	randctx *prx = (randctx*)ctx->random_context;

	int     i, x, cnt;

	cnt = size / RANDSIZ;
	
	for (x = 0; x < cnt; x++) {
		isaac(prx);
		for (i = 0; i < RANDSIZ; i++) {
			buf[i+x*RANDSIZ] = prx->randrsl[i];
		}
	}
}

int  isaac_init_random(data_context_t *ctx) 
{
	ctx->random_context = malloc(sizeof(randctx));
	if (!ctx->random_context) {
		log_message(LOG_FATAL, "Could not allocate memory for ISAAC random generator\n");
		return -1;
	}
	isaac_restart_random(ctx, 0);	
	
	ctx->stop_random = isaac_stop_random;
	ctx->restart_random = isaac_restart_random;
	ctx->get_random = isaac_get_random;
	
	return 0;
} 

/*
    rand_xxxx functions are not thread-safe!
*/

void rand_stop_random(void *p)
{
}

void rand_restart_random(void *p, int seed) 
{
	srand(seed);
}

void rand_get_random(void *p, unsigned char *buf, int size) 
{
	int i;
	
	for (i = 0; i < size; i++) {
		buf[i] = (unsigned char) rand();
	}
}

int  rand_init_random(data_context_t *ctx) 
{
	ctx->random_context = NULL;
	ctx->stop_random = rand_stop_random;
	ctx->restart_random = rand_restart_random;
	ctx->get_random = rand_get_random;

	return 0;
} 

int init_random(data_context_t *ctx, int type)
{
	int ret;
	
	switch (type) {
	case BCWIPE_RAND:
#ifndef WIPE_THREADS
		ret = rand_init_random(ctx);
		break;
#endif
	case BCWIPE_ISAAC:
		ret = isaac_init_random(ctx);
		break;
	default:
		ret = sha1_init_random(ctx);
		break;
	}
	return ret;
}

