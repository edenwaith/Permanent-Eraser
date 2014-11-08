/*******************************************************************
 *  Copyright (c) 2007-2008 Jetico, Inc., Finland
 *  All rights reserved.
 *
 *  File:          schemes.h
 *
 *  Description:   wiping schemes
 *
 *  Author:        Alexander Pichuev
 *
 *  Created:       10-Sep-2007
 *
 *  Revision:      $Id: schemes.h 296 2010-04-16 03:22:10Z nail $ 
 *
 *
 *******************************************************************/

#ifndef _schemes_H_
#define _schemes_H_

#define PASS_ZERO	0
#define PASS_TEST	1
#define PASS_RANDOM	2
#define PASS_COMPLEMENT	3

/* builtin schemes */
#define SCHEME_GUTMANN	0
#define SCHEME_DOD	1
#define SCHEME_ZERO	2
#define SCHEME_TEST	3
#define SCHEME_FILE	4
#define SCHEME_BCI	5
#define SCHEME_SCHNEIER	6
#define SCHEME_DOE	7

typedef struct type_pass_s {
	int            len;       /* if len==0 use type */
	int            verify;
	unsigned char *pat;
	long int       type;      /* must be large enough to store a pattern bytes */
} pass_s;

typedef struct wipe_scheme 
{
	char	*name;
	int     builtin;
	int	num_passes;
	pass_s	*pass;
	void	*random;
} wipe_scheme_t;

extern int init_scheme(wipe_scheme_t *scheme);
extern void cleanup_scheme(wipe_scheme_t *scheme);
extern int print_pass_name(char *buf, int buf_len, wipe_scheme_t *scheme, int pass);
extern int load_scheme(char *filename, wipe_scheme_t *scheme);

#endif /* _schemes_H_ */


