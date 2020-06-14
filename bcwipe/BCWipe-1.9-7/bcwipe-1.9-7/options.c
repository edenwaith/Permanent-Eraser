/*******************************************************************
*  Copyright (c) 2007-2010 Jetico, Inc., Finland
*  All rights reserved.
*
*  File:          optionc.c
*
*  Description:   Parses input options.
*
*  Author:        Alexander Pichuev
*
*  Created:       Sep 10, 2007
*
*  Revision:      $Id: options.c 310 2010-09-23 15:43:39Z nail $
*
*
*******************************************************************/

#include "config.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <ctype.h>
#include "wipe.h"
#include "options.h"
#include "schemes.h"
#include "log.h"

int o_verbose       = FALSE; /* -v,  */
int o_log           = FALSE; /* -l,  */
int o_recurse       = FALSE; /* -r, */
int o_force         = FALSE; /* -f, */
int o_pas_num       = 1;
int o_dont_delete   = FALSE; /* -d, do not delete files after wiping */
int o_wipe_dev      = FALSE; /* -b, wipe devices */
int o_direct_io     = TRUE;  /* Direct IO for devices. -B to disable */
int o_interactive   = TRUE;  /* -i, ask confirmation for wiping, -I disable interactive */
int o_scheme        = SCHEME_GUTMANN;     /* -m d and -n switch on using DoD standart */ 

int o_use_rand      = FALSE; /* -s, use system random instead of SHA-1 */
int o_use_buff      = FALSE; /* -p, use 64Kb random buffer instead of full random */
int o_dont_wipe_fn  = FALSE; /* -D, do not wipe file names */
int o_wipe_slacks   = FALSE; /* -S, wipe file slacks */
int o_wipe_free_space = FALSE; /* -F, wipe free space */
int o_nas_wiping    = FALSE; /*-n, NAS wiping */
int o_nas_delay     = 0;     /*-n, NAS wiping delay*/
char *o_log_file    = NULL;  /* -L, log file (filename) */
char *o_scheme_file = NULL;
int o_use_zero      = FALSE; /* -m z */
int o_use_sector_number  = FALSE; /* -m t */
int o_verify_last_pass = TRUE;
int o_threads       = 0;    /* -t <N> number of worker threads */
int o_bufsize       = 0;    /* -a <N> */

static char *usage_string=""
	"Usage: bcwipe [OPTIONS]... FILE...\n"
	"Remove FILE(s) with wiping.\n"
	"OPTIONS:\n"
	"  -mb       German BCI/VISTR 7-pass wiping\n"
	"  -md       U.S. DoD 5220-22M 7-pass extended character rotation wiping\n"
	"  -me       U.S. DoE 3-pass wiping\n"
	"  -mf<file> read wiping scheme from file. See *notes below\n"
	"  -mg       (default) 35-pass wiping by Peter Gutmann\n"
	"  -ms       7-pass wiping by Bruce Schneier\n"
	"  -mt       1-pass test mode: fill the start of 512-byte block with block number\n"
	"  -mz       1-pass zero wiping\n"
	"  -m N      U.S. DoD 5220-22M N-pass extended character rotation wiping\n"
	"\n"
	"  -w        disable verification\n"
	"  -n sec    NAS mode: wait sec seconds between wiping passes. See **notes below\n"
	"  -s        use ISAAC random instead of SHA-1\n"
	"  -p        use random pattern instead of full random\n"
	"  -r        process the contents directories recursively\n"
	"  -f        force wiping, never prompt        (use with caution)\n"
	"  -d        do not delete file(s) after wiping\n"
	"  -b        wipe contents of block devices    (use with caution)\n"
	"  -B        disable direct IO access mode for block devices"
	"  -t N      use N threads to wipe block devices. Useful for multiple disk devices."
	"  -S        wipe file slacks\n"
	"  -F        wipe free space on mounted filesystem\n"
	"  -i        prompt before any removal (y/[n]/a)\n"
	"              y - yes, n - no(default), a - yes for all\n"
	"  -I        disable interactive prompt\n"
	"  -v        verbose mode\n"
	"  -l[file]  write log to file. Log to console if file name is omitted\n"
	"  -V        output version information and exit\n"
	"  -h        display this help and exit\n"
	"\n"
	" *     scheme file line format: pass_number. {random|complementary|hex[,hex[,hex[,hex]]][, verify]}\n"
	"       Example:\n"
	"       1. random, verify\n"
	"       2. AA,00,55\n"
	" **    modern enterprise level storage systems (NAS, disk arrays etc.)\n"
	"       employ powerful caches. To avoid undesirable caching effects\n"
	"       use this option to insert delay before file deleting.\n"
	"\n"
	"Report bugs to support@jetico.com \n";
/*
//
//	ShowVersion
//		Reads revision text from wipe_c variable, it is more detailed information about file version.
//
*/
static void ShowVersion()
{
	char wipe_c[]="$Id: options.c 310 2010-09-23 15:43:39Z nail $";

	int i, j, x, len;
	char rev[ 20 ];

	len = strlen(wipe_c);

	for (i = 0, x = 0, j = 0; i < len; i++) {
		if (' ' == wipe_c[i]) {
			x++;
		}
		if (x > 3) {
			break;
		}
		if (x < 2) {
			continue;
		}
		rev[j++] = wipe_c[i];
	}
	rev[j] = 0;
	printf( "bcwipe version %s rev%s  Copyright 1994-2010 Jetico, Inc.\n", VERSION, rev );
}

int parseOptions( int *pArgc, char** pArgv[] )
{
	int c, result;
	int m_count = 0, ex_arg = 0;

	int argc = *pArgc;
	char **argv = *pArgv;

	while ( (c = getopt(argc, argv, OPTSTRING)) != -1 )
	{
		switch ( (char)c )
		{
			case 'V':
				ShowVersion();
				exit(0);
				return -1;
			case 'l':
				o_log = TRUE;
				if (optarg && optarg[0]) {
					result = create_log(optarg);
					if (result) {
						return result;
					}
				} else if (argv[optind] && '-' != argv[optind][0]) {
					result = create_log(argv[optind]);
					if (result) {
						return result;
					}
					optind++;
				}
				break;
			case 'v':
				o_verbose=TRUE;
				o_log = TRUE;
				break;
			case 'r':
				o_recurse=TRUE;
				break;
			case 'f':
				o_force=TRUE;
				break;
			case 'D':
				o_dont_wipe_fn=TRUE;
				break;
			case 'd':
				o_dont_delete=TRUE;
				break;
			case 'b':
				o_wipe_dev=TRUE;
				break;
			case 'B':
				o_direct_io=FALSE;
				break;
			case 'i':
				o_interactive=TRUE;
				break;
			case 'I':
				o_interactive=FALSE;
				break;
			case 'w':
				o_verify_last_pass = FALSE;
				break;
			case 'm':
				m_count++;
				if (1 == strlen(optarg)) {
					if        ('b' == optarg[0]) {
						o_scheme = SCHEME_BCI;
						break;
					} else if ('d' == optarg[0]) {
						o_scheme = SCHEME_DOD;
						o_pas_num = 7;		/* default DoD passes number is 7 */
						break;
					} else if ('e' == optarg[0]) {
						o_scheme = SCHEME_DOE;
						break;
					} else if ('g' == optarg[0]) {
						o_scheme = SCHEME_GUTMANN;
						break;
					} else if ('s' == optarg[0]) {
						o_scheme = SCHEME_SCHNEIER;
						break;
					} else if ('t' == optarg[0]) {
						o_scheme = SCHEME_TEST;
						break;
					} else if ('z' == optarg[0]) {
						o_scheme = SCHEME_ZERO;
						break;
					}
				} 
				if ('f' == optarg[0]) {
					if (optarg[1]) {
						o_scheme_file = strdup(optarg+1);
						o_scheme = SCHEME_FILE;
					} else if (argv[optind] && '-' != argv[optind][0]) {
						o_scheme_file = strdup(argv[optind]);
						o_scheme = SCHEME_FILE;
						optind++;
					}
					break;
				}
				o_pas_num = strtol(optarg, NULL, 0);
				o_scheme = SCHEME_DOD;
				if (0 == o_pas_num) {
					fprintf(stderr, "Unrecognized mode -m %s\n", optarg);
					return -1;
				}
				break;
			case 's':
				o_use_rand=TRUE;
				break;
			case 'S':
				o_wipe_slacks=TRUE;
				break;
			case 'F':
				o_wipe_free_space=TRUE;
				break;
			case 'p':
				o_use_buff=TRUE;
				break;
			case 'n':
				o_nas_wiping=TRUE;
				if (NULL == optarg || !isdigit(optarg[0]))
				{
					fprintf(stderr, "Wrong delay in -n option\n");
					return -1;
				}
				o_nas_delay=strtol(optarg, NULL, 0);
				break;
			case 't':
#ifndef WIPE_THREADS
				fprintf(stderr, "Multithreading not supported.\nRun ./configure with --enable-pthreads option, then rebuild BCWipe to enable multithreading.\n");
				o_threads = 0;
				break;
#endif			
				if (NULL == optarg || !isdigit(optarg[0]))
				{
					fprintf(stderr, "Wrong process count in -c option\n");
					return -1;
				}
				o_threads = strtol(optarg, NULL, 0);
				break;
			
			case 'a':
				if (NULL == optarg || !isdigit(optarg[0]))
				{
					fprintf(stderr, "Wrong allocation size in -a option\n");
					return -1;
				}
				o_bufsize = strtol(optarg, NULL, 0);
				break;

			case '?':
			case 'h':
			default:
				ShowVersion();
				fprintf(stdout, "%s", usage_string);
				exit(0);
				return -1;
		} /* end of switch */
	} /* end of while */

	argc -= optind+ex_arg;
	argv += optind+ex_arg;

	if ( 0 == argc )
	{
		ShowVersion();
		fprintf(stderr, "%s", usage_string);
		exit(0);
		return -1;
	}

	if (1 != argc && o_wipe_free_space) {
		fprintf(stderr, "Invalid number of parameters!\n"
		                "Usage example: bcwipe -v -F /mount/point\n");
		return -1;
	}
	
	if (1 < m_count) {
		fprintf(stderr,"Multiple defenition of wipe mode. Exiting\n");
	}

	/*
	// Version 1.6-8 
	//	allows wiping block devices in NAS mode
	//if ( o_nas_wiping && o_wipe_dev )
	//{
	//	fprintf( stderr, "Options \"-b\" and \"-n\" are incompatible\n");
	//	return -1;
	//}
	*/
	if (o_wipe_dev) {
	    if (o_wipe_free_space || o_wipe_slacks || o_recurse) {
		fprintf(stderr, "Wiping with \"-b\" option destroys filesystem information."
		                " \"-F\", \"-S\" and \"-r\" options are not compatible with \"-b\".\n");
		return -1;
	    }
	}
	
	if (o_force) {
		o_interactive = FALSE;
	}
	
	if (o_wipe_slacks) {
		o_dont_delete = TRUE;
	}

	/* check and setup the allocation size */	
	if (1 > o_bufsize) {
		o_bufsize = 1;
	}
	if (o_bufsize > 64) {
		o_bufsize = 64;	
	}	
	o_bufsize = o_bufsize * BUFFSIZE;
	
	/* validate and setup multithreaded mode */
	if (2 > o_threads) {
		o_threads = 0;
	}
	
	if (o_threads > 64) {
		o_threads = 64;
	}

#ifndef WIPE_THREADS
	o_threads = 0;
#endif
	*pArgc = argc;
	*pArgv = argv;

	return 0;
}

