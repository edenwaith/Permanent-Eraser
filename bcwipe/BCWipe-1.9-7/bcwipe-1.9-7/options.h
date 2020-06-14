/*******************************************************************
 *  Copyright (c) 2007-2008 Jetico, Inc., Finland
 *  All rights reserved.
 *
 *  File:          options.h
 *
 *  Description:   BestCrypt wipe utility
 *
 *  Author:        Alexander Pichuev
 *
 *  Created:       10-Sep-2007
 *
 *  Revision:      $Id: options.h 297 2010-04-16 11:46:10Z nail $ 
 *
 *
 *******************************************************************/

#ifndef _options_H_
#define _options_H_

#define TRUE        1
#define FALSE       0

#define OPTSTRING   "a:bBdDfFhiIl::m:n:prsSt:vVw"

extern int o_bufsize;			/* = 0; -a, setup the buffer size */
extern int o_wipe_dev;			/* = FALSE; -b, wipe devices */
extern int o_direct_io;			/* = TRUE;  -B to disable direct IO on devices */
extern int o_dont_delete;		/* = FALSE; -d, do not delete files after wiping */
extern int o_dont_wipe_fn;		/* = FALSE; -D, do not wipe file names */
extern int o_force;			/* = FALSE; -f, */
extern int o_wipe_free_space;           /* = FALSE; -F, wipe free space  */
extern int o_interactive;		/* = TRUE;  -i, ask confirmation for wiping, -I disable interactive */
extern char *o_log_file;		/* = NULL;  -l, log file (filename) */
extern int o_log;			/* = 0;     -l, no other options */

extern int o_scheme;			/* = SCHEME_GUTMANN  -m d and -n switch on using DoD standart */
extern int o_use_zero;			/* = FALSE; -m z */
extern int o_use_sector_number;		/* = FALSE; -m t */
extern int o_pas_num;			/* = DPASSES;    */
extern char *o_scheme_file;		/* = NULL; -mf<filename> */

extern int o_nas_wiping;		/* = FALSE; n, NAS wiping        */
extern int o_nas_delay;			/* = 0;     n, NAS wiping delay  */

extern int o_use_buff;			/* = FALSE; -p, use 64Kb random buffer instead of full random */
extern int o_recurse;			/* = FALSE; -r, */
extern int o_use_rand;			/* = FALSE; -s, use system random instead of SHA-1 */
extern int o_wipe_slacks;		/* = FALSE; -S, wipe file slacks */

extern int o_threads;		        /* = 0; -t, wipe large files in multi-thread mode */ 

extern int o_verbose;			/* = FALSE; -v, */
extern int o_verify_last_pass;		/* = TRUE;  -w to disable  */


extern int parseOptions( int *pArgc, char** pArgv[] );

#endif
