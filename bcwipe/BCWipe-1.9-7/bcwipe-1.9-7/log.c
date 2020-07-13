/*******************************************************************
*  Copyright (c) 1994-2009 Jetico, Inc., Finland
*  All rights reserved.
*
*  File:          log.c
*
*  Description:   implementation of logging
*
*  Author:        Nail Kaipov
*
*  Created:       03-Apr-2009
*
*  Revision:      $Id$
*
*
*******************************************************************/
#include "config.h"
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <time.h>
#include <errno.h>
#include <string.h>

#include "log.h"
#include "options.h"

static FILE *flog = 0;

void log_message(int severity, char *message, ... )
{
	time_t     t;
	struct tm *ptm;
	char       buf[1024];	
	va_list    var;
	
	va_start(var, message);
	
	if (flog) {
		time(&t);
		ptm = localtime(&t);
		if (ptm) {
			fprintf(flog, "%04d/%02d/%02d %02d:%02d:%02d  ", 
			        ptm->tm_year+1900, ptm->tm_mon+1, ptm->tm_mday, 
				ptm->tm_hour, ptm->tm_min, ptm->tm_sec);
		} else {
			fprintf(flog, "Unable to get time. ");
		}
		vsnprintf(buf, sizeof(buf), message, var);
		fprintf(flog, "%s", buf);
		fflush(flog);
		
		if (LOG_ERR <= severity) {
			fprintf(stderr, "%s", buf);
		}
	} else if (LOG_INFO < severity || (LOG_INFO == severity && o_log)) {
		vfprintf(stderr, message, var);
	}

	va_end(var);
}

void close_log() 
{
	if (o_log_file) {
		free(o_log_file);
	}
	if (flog) {
		fclose(flog); 
	}
	o_log_file = NULL;	
	flog = NULL;
}

int create_log(char *filename) 
{
	if (!filename) return -1;
	
	
	flog = fopen(filename, "a");
	if (!flog) {
		fprintf(stderr, "Could not open %s log file. %s\n", filename, strerror(errno));
		return -1;
	}	

	o_log_file = strdup(filename);
	
	return 0;	
}

