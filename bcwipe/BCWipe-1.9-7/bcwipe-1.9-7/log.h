/*******************************************************************
*  Copyright (c) 1994-2009 Jetico, Inc., Finland
*  All rights reserved.
*
*  File:          log.h
*
*  Description:   logging
*
*  Author:        Nail Kaipov
*
*  Created:       03-Apr-2009
*
*  Revision:      $Id$
*
*
*******************************************************************/
#ifndef _log_H_
#define _log_H_

#define LOG_FILE	1
#define	LOG_INFO	2
#define LOG_WARN	3
#define LOG_ERR		4
#define LOG_FATAL	5

void log_message(int severity, char *message, ... );
int  create_log(char *filename);
void close_log();

#endif

