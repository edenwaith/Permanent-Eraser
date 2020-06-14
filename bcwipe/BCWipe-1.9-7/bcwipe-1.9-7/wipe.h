/*******************************************************************
 *  Copyright (c) 1994-2008 Jetico, Inc., Finland
 *  All rights reserved.
 *
 *  File:          wipe.h
 *
 *  Description:   BestCrypt wipe utility
 *
 *  Author:        Vitaliy Zolotarev
 *
 *  Created:       20-Nov-1999
 *
 *  Revision:      $Id: wipe.h 300 2010-04-22 05:02:20Z inso $ 
 *
 *
 *******************************************************************/

#ifndef _WIPE_H_
#define _WIPE_H_

#define OK          0
#define ERROR       -1

#define BUFFSIZE    1024*1024

#define NAME_MAX_PASSES 10
#define NAME_TRIES      200

#define BCWIPE_RAND	0
#define BCWIPE_SHA1	1
#define BCWIPE_ISAAC	2

#include <time.h>

typedef time_t	seed_t;

typedef void (*stop_random_f)(void  *ctx);
typedef void (*restart_random_f)(void *ctx, int seed);
typedef void (*get_random_f)(void *ctx, unsigned char *buf, int size);

typedef struct {
	stop_random_f     stop_random;
	restart_random_f  restart_random;
	get_random_f      get_random;
	void              *random_context;
	unsigned char     *buffer;
	unsigned char     *verify_buffer;
	seed_t            seed;
	int               pass;
	int               written;
	int               status;
} data_context_t;

extern int init_random(data_context_t *ctx, int type);

typedef struct wipe_task
{
	long long int	 size;		/* actual size, may be 0 for devices */
	long long int	 slack_size;	/* file slack size */

	/* wiping task information */
	long long int    start;
	long long int    end;
	long long int    pos;
	int              flags;
		
	char		 *filename;	/* name */
	mode_t		 st_mode;	/* st_mode from stat()/lstat() call */
	int		 pass;		/* current pass */
	seed_t		 seed;		/* seed to initialize pseudo-random sequence */
	seed_t		 prev_seed;	/* seed for previous pass */
	int		 skip;		/* an error occured, error number here */
	struct wipe_task *next;
	data_context_t   *data_context;
	
} wipe_task_t;

#endif  /* _WIPE_H_ */

