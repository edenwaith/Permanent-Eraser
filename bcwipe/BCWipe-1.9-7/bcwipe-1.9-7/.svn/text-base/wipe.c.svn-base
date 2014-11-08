/*******************************************************************
*  Copyright (c) 1994-2008 Jetico, Inc., Finland
*  All rights reserved.
*
*  File:          wipe.c
*
*  Description:   implementation of BestCrypt wipe utility
*
*  Author:        Vitaliy Zolotarev
*
*  Created:       20-Nov-1999
*
*  Revision:      $Id: wipe.c 309 2010-09-23 15:35:38Z nail $
*
*
*******************************************************************/
#include "config.h"
#include <stdio.h>
#include <limits.h>
#include <stdlib.h>
#include <sys/types.h>
#include <stdarg.h>
#include <dirent.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <string.h>
#include <utime.h>

#ifdef HAVE_PTHREAD_H
#include <pthread.h>
#endif

#if   defined(OS_LINUX)
#include <linux/fs.h>
#elif defined(OS_AIX)
#include <sys/devinfo.h>
#endif

#include <sys/ioctl.h>
#include <signal.h>
#include <time.h>
#include <ctype.h>

#if HAVE_SYS_DISKIO_H /* HP-UX */
#include <sys/diskio.h>
#endif

#if HAVE_SYS_STATVFS_H
#include <sys/statvfs.h>
#endif

#if HAVE_SYS_DISK_H
#include <sys/disk.h>
#endif

#ifndef NAME_MAX
#if defined(MAXNAMELEN)
#define NAME_MAX MAXNAMELEN
#elif defined(FILENAME_MAX) 
#define NAME_MAX FILENAME_MAX
#endif 
#endif 

#ifndef PATH_MAX
#ifdef MAXPATHLEN
#define PATH_MAX MAXPATHLEN
#endif 
#endif 

#ifndef S_BLKSIZE
#define S_BLKSIZE   512
#endif    

#include "wipe.h"
#include "options.h"
#include "schemes.h"
#include "log.h"

#ifdef WIPE_THREADS

typedef struct thread_task {
	pthread_t    thread;
	wipe_task_t  wipe_task;
	int          fd;
} thread_task_t;

static thread_task_t          *Threads = NULL;
#endif

static data_context_t         *DataContext = NULL;
static unsigned long long int total_size_of_slacks=0;
static wipe_task_t            *FileListHead = NULL;
static wipe_scheme_t          scheme;
static char                   free_space_dir[PATH_MAX+1];
static int                    free_space_dir_created = 0;

/* ---------------------------------------------------------------------------------------------- */


long long int get_size_of_device( int fd );

int wipe_file(char *filename);
int wipe_filename(char *filename, int delete_file_contents);
int wipe_dir(char *dirname);
int wipe_dirname(char *dirname);

int nas_wiping(int argc, char *argv[]);

int add_file_to_list(char *FileName);
int add_dir_to_list(char *DirName);

int remove_from_list(wipe_task_t *ptr);
int free_list(wipe_task_t *head);

int wipe_files_in_list( int pass, int verify );
int wipe_filenames_in_list();
int wipe_file_nas( wipe_task_t *ctx, int pass, int verify );
int wipe_file_slack_nas( wipe_task_t *ctx, int pass, int verify );

static long long int get_timestamp() 
{
	long long int time;

#ifdef HAVE_GETTIMEOFDAY	
	struct timeval	tv;
	
	gettimeofday(&tv, NULL);
	
	time = (long long int)tv.tv_sec * 1000LL;
	time += (long long int)tv.tv_usec / 1000LL;
#else
	time = (long long int)time(NULL) * 1000LL;
#endif
	return time;
}

static unsigned char *get_buffer(wipe_task_t *ctx) 
{
	return ctx->data_context->buffer;
}

static unsigned char *get_verify_buffer(wipe_task_t *ctx) 
{
	return ctx->data_context->verify_buffer;
}
/*****************************************/

static int free_data_context(data_context_t *ptr, int count) 
{
	int i;
	for (i = 0; i < count; i++) {
		if (!ptr[i].status) {
			continue;
		}
		if (!ptr[i].buffer) {
			free(ptr[i].buffer);
		}
		if (!ptr[i].verify_buffer) {
			free(ptr[i].verify_buffer);
		}
		ptr[i].stop_random(ptr+i);
	}
#ifdef WIPE_THREADS
	if (Threads) {
		free(Threads);
	}
	Threads = NULL;
#endif	
}

static data_context_t * init_data_context(int count, int rng_type, int bufsize) 
{
	int i, res;
	data_context_t *ptr;
	
	ptr = (data_context_t *)malloc(count * sizeof(data_context_t));
	if (!ptr) {
	
		return NULL;
	}
	memset(ptr, 0, count * sizeof(data_context_t));
	
	for (i = 0; i < count; i++) {
		res = init_random(ptr+i, rng_type);
		if (0 != res) {
			log_message(LOG_FATAL, "Failed to initialize wiping data\n");
			break;
		}
		ptr[i].pass = -1;
		ptr[i].written = 0;
		
		/* allocate page-aligned buffers */
		ptr[i].buffer = (unsigned char *)valloc(bufsize);
		ptr[i].verify_buffer = (unsigned char *)valloc(bufsize);
		if (!ptr[i].buffer || !ptr[i].verify_buffer) {
			log_message(LOG_FATAL, "Failed to allocate buffers\n");
			break;
		}
		ptr[i].status = 1;
	}
	
#ifdef WIPE_THREADS
	Threads = (thread_task_t *)malloc(count * sizeof(thread_task_t));
	if (Threads) {
		memset(Threads, 0, count * sizeof(thread_task_t));
	}
#endif	
	if (i != count) {
		free_data_context(ptr, count);
		ptr = NULL;
	} 
	return ptr;
}

/*****************************************/

static ssize_t bcwipe_read(int fd, void *buf, size_t count) 
{
	ssize_t	rc, n;
	off_t	offset;
	
	n = 0;
	offset = lseek_f(fd, 0, SEEK_CUR);
	do {
		rc = read(fd, (void *)((char *)buf+n), count-n);
		if (-1 == rc) {
			if (EINTR == errno || EAGAIN == errno || EWOULDBLOCK == errno) {
				lseek_f(fd, offset+n, SEEK_SET);
				continue;
			}
			return -1;
		}
		n += rc; 
		if (0 == rc) {
		    return n;
		}
	} while (count > n);
	
	return n;
}

#ifdef HAVE_PREAD

static ssize_t bcwipe_pread(int fd, void *buf, size_t count, off_t pos) 
{
	ssize_t	rc, n;
	
	n = 0;
	do {
		rc = pread(fd, (void *)((char *)buf+n), count-n, pos+n);
		if (-1 == rc) {
			if (EINTR == errno || EAGAIN == errno || EWOULDBLOCK == errno) {
				continue;
			}
			return -1;
		}
		n += rc; 
		if (0 == rc) {
		    return n;
		}
	} while (count > n);
	
	return n;
}

#endif

static ssize_t bcwipe_write(int fd, void *buf, size_t count) 
{
#ifndef SAFE_BCWIPE_WRITE
	return write(fd, buf, count);
#else
	ssize_t	rc, n;
	off_t	offset;
	
	n = 0;
	offset = lseek_f(fd, 0, SEEK_CUR);
	do {
		rc = write(fd, (void *)((char *)buf+n), count-n);
		if (-1 == rc) {
			if (EINTR == errno || EAGAIN == errno || EWOULDBLOCK == errno) {
				lseek_f(fd, offset+n, SEEK_SET);
				continue;
			}
			return -1;
		}
		n += rc; 
		if (0 == rc) {
		    return n;
		}
	} while (count > n);
	return n;
#endif
}

#ifdef HAVE_PWRITE

static ssize_t bcwipe_pwrite(int fd, void *buf, size_t count, off_t pos) 
{
#ifndef SAFE_BCWIPE_WRITE
	return pwrite(fd, buf, count, pos);
#else
	ssize_t	rc, n;
	
	n = 0;
	do {
		rc = pwrite(fd, (void *)((char *)buf+n), count-n, pos+n);
		if (-1 == rc) {
			if (EINTR == errno || EAGAIN == errno || EWOULDBLOCK == errno) {
				continue;
			}
			return -1;
		}
		n += rc; 
		if (0 == rc) {
		    return n;
		}
	} while (count > n);
	return n;
#endif
}

#endif

static ssize_t verify_buffer(unsigned char *buf, unsigned char *pattern, ssize_t len) 
{
	ssize_t i;

	if (0 == memcmp(buf, pattern, len)) {
		return 0;
	}
	
	for (i = 0; i < len; i++) {
		if (buf[i] != pattern[i])
			break;
	
	}
	return i+1;
}

static int bcwipe_unlink(char *name, int attempts) 
{
	int i, ret;
	
	for (i = 0; i < attempts; i++) {
		if (i) {
			sleep(1);
		}
		ret = unlink(name);
    		if (OK == ret) {
			return ret;
		}
	    
		switch(errno) {
		case EIO:
		case EBUSY:
		case ENOMEM:
		case ENOSPC:
			break;
	    	default:
			return ret;
		}
	}
	return ret;
}



int ask_y_n(char *message, ... )
{
	va_list var;
	char	c;
	
	va_start(var, message);
	vfprintf(stderr, message, var);
	va_end(var);

	c = tolower(fgetc(stdin));
	if ( '\n' == c ) return FALSE;
	while ( '\n' != fgetc(stdin) );
	if ( 'y' == c ) return TRUE;
	if ( 'a' == c )
	{
		o_interactive=FALSE;
		return TRUE;
	}

	return FALSE;
}

static void print_wiping_progress(long long int total_size, long long int file_size, long long int start_time, int pass) 
{
	long long int cur_time;
	int    percent;
	
	cur_time = get_timestamp();
	percent = (int)(file_size * 100 / total_size);

	fprintf( stdout, "\rwipe pass %2d/%-2d:%10ld/%ld kB (%3d%%)", 
	pass+1, o_pas_num, (long int)(file_size >> 10), (long int)(total_size >> 10), percent );

	if ( cur_time != start_time ) {
		fprintf(stdout,"   Rate: %ld kB/s          ", (long int)((1000LL * file_size/(cur_time - start_time)) >> 10));
	} else	{
		fprintf(stdout,"                        ");
	}
}

static void print_verification_progress(long long int total_size, long long int file_size, long long int start_time, int pass)
{
	long long int cur_time;
	int    percent;

	cur_time = get_timestamp();
	percent =(int)(file_size * 100 / total_size);
			
	fprintf( stdout, "\rverify pass %-2d :%10ld/%ld kB (%3d%%)",pass+1, (long int)(file_size >> 10),(long int)(total_size >> 10), percent );
	if ( start_time != cur_time ) {
		fprintf(stdout, "   Rate: %ld kB/s          ",
		(long int)((file_size*1000LL/(cur_time - start_time)) >> 10));
	} else {
		fprintf(stdout, "                                ");
	}
}

static char *get_type_str(mode_t st_mode) 
{
	if ( S_ISDIR(st_mode) ) {
		return "directory";
	} else if ( S_ISREG(st_mode) ) {
		return "file";
	} else if ( S_ISLNK(st_mode) ) {
		return "link";
	} else if ( S_ISCHR(st_mode) ) {
		return "char device";
	} else if ( S_ISBLK(st_mode) ) {
		return "block device";
	} else if ( S_ISFIFO(st_mode) ) {
		return "pipe";
	} else if ( S_ISSOCK(st_mode) ) {
		return "socket";
	}
	return "";
}

static int is_device(mode_t st_mode) 
{
	/*
	//	v. 1.7-2 Solaris does not recognize link as block device.
	//	So we try to force block device reading if o_wipe_dev flag is assigned
	*/
	return ( S_ISBLK(st_mode) || S_ISCHR(st_mode) || (o_wipe_dev && S_ISLNK(st_mode)) );
}

/*
	fill_buff - prepare buffer for wiping/verification
	
	return values:	1 - buffer overwritten with new values
			0 - buffer kept intact
			-1 - an error occured
*/
int fill_buff(wipe_task_t *ctx, size_t size) 
{
	int i, j, len, pass = ctx->pass;
	wipe_task_t	info;
	data_context_t  *pdc = ctx->data_context;
	unsigned char   *buff = pdc->buffer;
	
	if (pass > scheme.num_passes) {
		return -1;
	}

	len = scheme.pass[pass].len;
	if (len) {
	    	if (pdc->written >= size && pdc->pass == pass) {
			return 1;
		}

		for (i = 0, j = 0; i < size; i++) {
			buff[i] = scheme.pass[pass].pat[j++ % len];
		}
		pdc->written = size;
		pdc->seed = ctx->seed;
		pdc->pass = pass;
		return 1;
	}
	
	switch (scheme.pass[pass].type) {
	case PASS_RANDOM:
		/* pattern mode && same pass && same seed && enough data */
		if (o_use_buff && ctx->seed == pdc->seed && pdc->pass == pass && pdc->written >= size) {
			return 1;
		}
		pdc->restart_random(pdc, ctx->seed);
		pdc->get_random(pdc, buff, size);
		break;

	case PASS_COMPLEMENT:
		if (0 == pass) {
			memset(buff, 0, size);
			break;
		}
		info = *ctx;
		info.pass -= 1;
		info.seed = info.prev_seed;
		info.prev_seed = 0;
		i = fill_buff(&info, size);
		if (1 > i) {
			return -1;
		}
		for (i = 0; i < size; i++) {
			buff[i]=~buff[i];
		}
		break;

	case PASS_ZERO:
		if (pdc->pass == pass && pdc->written >= size) {
			return 1;
		}
		memset(buff, 0, size);
		break;
	
	case PASS_TEST:
		memset( buff, 0, size );
		for (i = 0; i < size; i += 512) {
			j = (ctx->pos+i)/512;
			buff[i+0] = (j >> 24) & 0xff;
			buff[i+1] = (j >> 16) & 0xff;
			buff[i+2] = (j >> 8)  & 0xff;
			buff[i+3] =  j        & 0xff;
		}
		break;
		
	default:
		return -1;
	}
	
	pdc->written = size;
	pdc->seed = ctx->seed;
	pdc->pass = pass;
	
	return 1;
}

/*****************************************/
/*
static void showBuffer( char *bfName, char *bf, int size )
{
    int col,i;

    printf( "Buffer %s: \n", bfName );
    
    for( col = 0, i = 0; i < size; i++, col++ )
    {
	if ( col >= 16 )
	{
	    printf( "\n" );
	    col = 0;
	}
	
	if ( col == 0 )
	    printf( "%08d ", i );
	
	unsigned int ch = (unsigned int)bf[i];
	printf( "%X%X ", (ch>>4)&0xF, (ch)&0xF );
    }
    
    printf("\n");
}


int print_list(WipeFileEntry *ListHead)
{
    while (NULL != ListHead) {
	printf("%s\ttype=%d\tsize=%Ld\tslack=%Ld\n",
		ListHead->FileName,
		ListHead->Type,
		ListHead->FileSize,
		ListHead->SlackSize);
	ListHead=ListHead->Next;
    }
    return OK;
}
*/

int nas_wiping(int argc, char *argv[])
{
	int i, pass, save;

	log_message(LOG_INFO, "Wiping in NAS mode\n");

	/* fill wiping list */
	for ( i = argc; i; i-- ) {
		add_file_to_list( argv[i-1] );
	}
	if (NULL == FileListHead) {
		log_message(LOG_ERR, "Could not build list of files for wiping\n");
		return ERROR;
	}

	save = o_dont_delete;
	o_dont_delete = TRUE;

	for (pass = 0; pass < o_pas_num; pass++) {
		wipe_files_in_list(pass, FALSE);
		log_message( LOG_INFO, "Sleeping %d seconds\n", o_nas_delay );
		sleep(o_nas_delay);
		if (o_verify_last_pass && scheme.pass[pass].verify) {
			wipe_files_in_list(pass, TRUE);
		}
	}

	o_dont_delete = save;

	if ( !o_wipe_dev ) {
		wipe_filenames_in_list();
	}
	
	free_list(FileListHead);
	FileListHead = NULL;

	return OK;
}


int add_file_to_list(char *filename)
{
	struct stat buff;
	wipe_task_t *ptr = NULL;

	if (!filename)	
		return ERROR;

	if ( OK != lstat(filename, &buff) ) {
		log_message (LOG_ERR, "Skipping '%s': %s\n", filename, strerror(errno));
		return ERROR;
	}

	if ( is_device(buff.st_mode) ) {
		/* Get stat instead of lstat. */
		if ( ERROR == stat( filename, &buff ) )	{
			log_message (LOG_ERR, "Skipping '%s': %s\n", filename, strerror(errno));
			return ERROR;
		}
		
		if ( !S_ISBLK( buff.st_mode ) && !S_ISCHR( buff.st_mode ) ) {
			log_message(LOG_ERR, "'%s': is not a special device - skipping\n", filename );
			return ERROR;	
		}
	}

	ptr = (wipe_task_t *)malloc( sizeof( wipe_task_t ) );
	if (!ptr) {
		log_message(LOG_ERR, "Memory allocation error. Skipping '%s'\n", filename, strerror(errno));
		return ERROR;
	}
	memset( ptr, 0, sizeof(wipe_task_t) );

	if ( S_ISDIR(buff.st_mode) ) {
		if (OK != add_dir_to_list( filename ) ) {
			free(ptr);
			return ERROR;
		}
	} else if ( S_ISREG(buff.st_mode) ) {
		ptr->size  = buff.st_size;
		ptr->slack_size = buff.st_size % buff.st_blksize ? buff.st_blksize - (buff.st_size % buff.st_blksize) : 0;
	} else if ( S_ISLNK(buff.st_mode)  || 
		    S_ISCHR(buff.st_mode)  ||
		    S_ISBLK(buff.st_mode)  ||
		    S_ISFIFO(buff.st_mode) ||
		    S_ISSOCK(buff.st_mode) ) {
		;
	} else { 
		log_message(LOG_ERR, "Unsupported type of file: '%s'\n", filename);
		free(ptr);
		return ERROR;
	}

	if ( o_interactive && 
	     !ask_y_n("Add %s '%s' to wiping list (y/[n]/a)?", get_type_str(buff.st_mode), filename) ) {
		free(ptr);
		return ERROR;
	}

	ptr->st_mode = buff.st_mode;
	ptr->filename = strdup(filename);
	if (NULL == ptr->filename) {
		log_message(LOG_ERR, "Skipping '%s': %s\n", filename, strerror(errno));
		free(ptr);
		return ERROR;
	}

	ptr->next = FileListHead;
	FileListHead = ptr;

	return OK;
}

int add_dir_to_list(char *dirname)
{
	struct dirent *d;
	DIR *fd;
	char filename[NAME_MAX+PATH_MAX];

	if ( !dirname ) 
		return ERROR;

	if ( !o_recurse ) {
		log_message(LOG_INFO, "'%s' is a directory - skipping\n", dirname);
		return ERROR;
	}

	/* check directory access */
	if ( !o_wipe_slacks && OK != access( dirname, X_OK|R_OK|W_OK ) ) {
		if ( !o_force ) {
			log_message(LOG_ERR, "Could not enter to directory '%s': %s - skipping\n", dirname, strerror(errno));
			return ERROR;
		}
		if ( OK != chmod(dirname, S_IRUSR|S_IWUSR|S_IXUSR ) ) {
			log_message(LOG_ERR, "Could not change permissions for directory '%s': %s - skipping\n", dirname, strerror(errno));
			return ERROR;
		}
	}

	fd = opendir(dirname);
	if ( NULL == fd ) {
		log_message(LOG_ERR, "Could not open directory '%s': %s - skipping\n", dirname, strerror(errno));
		return ERROR;
	}


	while ( NULL != (d = readdir( fd )) ) {
		snprintf(filename, NAME_MAX+PATH_MAX, "%s/%s", dirname, d->d_name);
		if ( 0 == strcmp(d->d_name,".") || 0 == strcmp(d->d_name,"..") )
			continue;
		add_file_to_list(filename);
	}

	closedir(fd);

	return OK;

}

int free_list(wipe_task_t *head)
{
	wipe_task_t *ptr;

	while (NULL != head) {
		ptr  = head;
		head = ptr->next;
		free(ptr->filename);
		free(ptr);
	}
	return OK;
}


int wipe_files_in_list( int pass, int verify )
{
	wipe_task_t *ptr = FileListHead;
	int          rc;

	while ( NULL != ptr ) {
		rc = wipe_file_nas( ptr, pass, verify );
		if ( OK != rc ) {
			ptr->skip = rc;
		}
		ptr = ptr->next;
	}
	return OK;
}

static int do_open_file(wipe_task_t *ctx) 
{
	int fd;
	
	if ( OK != access(ctx->filename, W_OK|R_OK) ) {
		if ( !o_force ) {
			log_message(LOG_ERR, "Access to %s '%s' denied: %s - skipping\n", get_type_str(ctx->st_mode), ctx->filename, strerror(errno));
			return ERROR;
		}
		
		if ( OK != chmod(ctx->filename, S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP|S_IROTH|S_IWOTH) ) {
			log_message(LOG_ERR, "Could not change '%s' permissions: %s - skipping\n", ctx->filename, strerror(errno));
			return ERROR;
		}
	}

#ifdef O_DIRECT
	if (o_direct_io && is_device(ctx->st_mode)) {
		fd = open(ctx->filename, O_RDWR|O_DIRECT);
		if ( ERROR == fd ) {
			log_message(LOG_ERR, "Could not open device '%s' in direct IO mode: %s - skipping\n",  ctx->filename, strerror(errno));
		} else {
			log_message(LOG_INFO, "Device '%s' opened in direct access mode\n", ctx->filename);
			return fd;
		}
	}
#endif
	fd = open(ctx->filename, O_RDWR);
	if ( ERROR == fd ) {
		log_message(LOG_ERR, "Could not open %s '%s': %s - skipping\n", get_type_str(ctx->st_mode), ctx->filename, strerror(errno));
		return ERROR;
	}
	return fd;
}

static int do_open_file_slack(wipe_task_t *ctx) 
{
	int fd;
	
	if ( !S_ISREG(ctx->st_mode) ) {
		log_message(LOG_INFO, "'%s' is not a regular file\n", ctx->filename);
		ctx->skip = 1;
		return OK;
	}

	if (0 == ctx->slack_size) {
		log_message(LOG_INFO, "'%s' does not have a slack\n", ctx->filename);
		ctx->skip = 1;
		return OK;
	}

	if ( OK != access(ctx->filename, W_OK|R_OK) ) {
		if ( !o_force ) {
			log_message(LOG_ERR, "Access to %s '%s' denied: %s - skipping\n", get_type_str(ctx->st_mode), ctx->filename, strerror(errno));
			return ERROR;
		}
		
		if ( OK != chmod(ctx->filename, S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP|S_IROTH|S_IWOTH) ) {
			log_message(LOG_ERR, "Could not change '%s' permissions: %s - skipping\n", ctx->filename, strerror(errno));
			return ERROR;
		}
	}
/*
#ifdef O_SYNC
	fd = open(ctx->filename, O_RDWR|O_SYNC);
#else
	fd = open(ctx->filename, O_RDWR);
#endif
*/
	fd = open(ctx->filename, O_RDWR);
	if ( ERROR == fd ) {
		log_message(LOG_ERR, "Could not open file '%s': %s - skipping\n", ctx->filename, strerror(errno));
		return ERROR;
	}
	
	return fd;
}

static int do_wipe_pass(int fd, wipe_task_t *ctx, int quiet) 
{
	long long int	pos, len, size, start_time;
	int count = 0;

	start_time = get_timestamp();
	
	pos = ctx->start;
	size = ctx->end;
	lseek_f(fd, pos, SEEK_SET);
/*
	log_message(LOG_ERR, "Assigned task start=%lld end=%lld count=%lld\n", pos, size, (size-pos)/o_bufsize);
*/
	while ( pos < size ) {
		len = size - pos < o_bufsize ? size - pos : o_bufsize;
		fill_buff( ctx, len );
#ifdef WIPE_THREADS
		len = bcwipe_pwrite(fd, get_buffer(ctx), len, pos);
#else
		len = bcwipe_write(fd, get_buffer(ctx), len);
#endif
		count++;
		if ( ERROR == len ) {
			if ( ( ENOSPC == errno ) && is_device(ctx->st_mode) ) {
 				ctx->size = pos;
				len = 0;
			} else {
				log_message(LOG_ERR, "Writing to %s '%s' failed at %lld bytes: %s\n", get_type_str(ctx->st_mode), ctx->filename, pos, strerror(errno));
				return errno;
			}
		}

		pos += len;
		ctx->pos = pos;
		
		if (!quiet &&  o_verbose ) {
			print_wiping_progress(size, pos, start_time, ctx->pass);
		}
		
		if (len != o_bufsize) {
			break;
		}
	}
/*
	log_message(LOG_ERR, "Completed task start=%lld end=%lld count=%d\n", ctx->start, ctx->end, count);
*/
	return 0;
}

#ifdef WIPE_THREADS

void * wipe_wrapper(void *param) 
{
	int res;
	thread_task_t *pt = (thread_task_t *)param;
	
	res = do_wipe_pass(pt->fd, &pt->wipe_task, 1);
	pt->wipe_task.flags = res ? -1 : 1;
	return (void *)res;
}

#define WIPE_ITER_LIMIT 100LL

static int prepare_multithread(wipe_task_t *ctx) 
{
	long long int size, len;
	int i;

	if (2 > o_threads || !Threads) {
		return 0;
	}
	
	size = ctx->size + ctx->slack_size;
	len = (long long int)o_bufsize * o_threads * WIPE_ITER_LIMIT;	/* reserve iterations for each process */
	if (len > size) {						/* file is too small */
		return 0;
	}

	/* prepare tasks for multiple threads */
	for (i = 0; i < o_threads; i++) {
		Threads[i].wipe_task = *ctx;
		Threads[i].wipe_task.start   = ((((long long)size/o_bufsize)*i)/o_threads)*o_bufsize;
		Threads[i].wipe_task.pos     = Threads[i].wipe_task.start;
		Threads[i].wipe_task.end     = ((((long long)size/o_bufsize)*(i+1))/o_threads)*o_bufsize;
		if (o_threads-1 == i) {
			Threads[i].wipe_task.end = size;
		}				
		Threads[i].wipe_task.flags   = 0;
		Threads[i].wipe_task.data_context     = DataContext+i;
	}
	return 1;
}

static int monitor_multithread(int verify) 
{
	int i, x, err, percent, pass;
	long long int	total, complete, start_time, cur_time;
	
	start_time = get_timestamp();

	pass = Threads[0].wipe_task.pass;
	total = Threads[0].wipe_task.size + Threads[0].wipe_task.slack_size;
	while (1) {
		complete = 0LL;
		err = 0;
		for (i = 0, x = 0; i < o_threads; i++) {
			complete += Threads[i].wipe_task.pos - Threads[i].wipe_task.start;
			x += Threads[i].wipe_task.flags ? 1 : 0;
			if (Threads[i].wipe_task.flags < 0) {
				err  = -1;
			}
		}
		
		percent = (int)(complete * 100 / total);
		if (verify) {
			fprintf( stdout, "\rverify pass %2d :%10ld/%ld kB (%3d%%)", 
			pass+1, (long int)(complete >> 10), (long int)(total >> 10), percent );
		} else {
			fprintf( stdout, "\rwipe pass %2d/%-2d:%10ld/%ld kB (%3d%%)", 
			pass+1, o_pas_num, (long int)(complete >> 10), (long int)(total >> 10), percent );
		}
		cur_time = get_timestamp();
		if ( cur_time != start_time ) {
			fprintf(stdout,"   Rate: %ld kB/s       ", (long int)((1000LL * complete/(cur_time - start_time)) >> 10));
		} else	{
			fprintf(stdout,"                     ");
		}
		
		if (x == o_threads) {
			break;
		} else {
			usleep(200000);
		}
	}

	return err;
}

#endif

static int wipe_pass(int fd, wipe_task_t *ctx) 
{
	char		str[100];
	int		i, ret;

	print_pass_name(str, sizeof(str), &scheme, ctx->pass);

	ctx->data_context = DataContext;

#ifdef WIPE_THREADS
	if (prepare_multithread(ctx)) {
		log_message(LOG_INFO, "Wiping %s '%s' pass %d/%d [%s] started. %d threads\n", 
			    get_type_str(ctx->st_mode), ctx->filename, ctx->pass+1, o_pas_num, str, o_threads);
		for (i = 0; i < o_threads; i++) {
			Threads[i].fd = fd;
			pthread_create(&(Threads[i].thread), NULL, wipe_wrapper, &(Threads[i]));
		}
		ret = monitor_multithread(0);
	} else 
#endif	
	{
		log_message(LOG_INFO, "Wiping %s '%s' pass %d/%d [%s] started\n", 
			    get_type_str(ctx->st_mode), ctx->filename, ctx->pass+1, o_pas_num, str);
		ctx->start = 0LL;
		ctx->pos = 0LL;
		ctx->end = ctx->size + ctx->slack_size;
		ctx->flags = 0;
		
		ret = do_wipe_pass(fd, ctx, 0);
	}

	if (0 != ret) {
		log_message(LOG_ERR, "Wiping %s '%s' pass %d/%d failed\n", get_type_str(ctx->st_mode), ctx->filename, ctx->pass+1, o_pas_num);
		return ERROR;
	}
	
	fsync(fd);
	if ( o_verbose ) {
		fprintf( stdout, "\n");
	}

	log_message(LOG_INFO, "Wiping %s '%s' pass %d/%d completed\n", get_type_str(ctx->st_mode), ctx->filename, ctx->pass+1, o_pas_num);

	return OK;
}

static int do_verify_pass(int fd, wipe_task_t *ctx, int quiet) 
{
	long long int	pos, len, size, start_time;
	unsigned char   *buf, *ver_buf;
	int x;
	int count = 0;

	start_time = get_timestamp();
	
	pos = ctx->start;
	size = ctx->end;
	lseek_f(fd, pos, SEEK_SET);
/*
	log_message(LOG_ERR, "Assigned task start=%lld end=%lld count=%lld\n", pos, size, (size-pos)/o_bufsize);
*/
	while ( pos < size ) {
		len = size - pos < o_bufsize ? size - pos : o_bufsize;
		fill_buff( ctx, len );
		buf = get_buffer(ctx);
		ver_buf = get_verify_buffer(ctx);
		
#ifdef WIPE_THREADS
		len = bcwipe_pread(fd, ver_buf, len, pos);
#else
		len = bcwipe_read(fd, ver_buf, len);
#endif
		count++;

		if ( ERROR == len )  {
			log_message(LOG_ERR, "Error reading '%s' at %lld bytes : %s\n", ctx->filename, pos, strerror(errno) );
			return errno;
		}
		
		x = verify_buffer( ver_buf, buf, len );
		if ( 0 != x ) {
			log_message(LOG_ERR, "\nVerification of %s '%s' failed at %lld bytes\n"
					     "Expected %02Xh, read %02Xh\n", 
				    get_type_str(ctx->st_mode), ctx->filename, pos + x - 1, ver_buf[x-1], buf[x-1] );
			return -1;
		}
		
		pos += len;
		ctx->pos = pos;
		
		if (!quiet &&  o_verbose ) {
			print_verification_progress(size, pos, start_time, ctx->pass);
		}
		
		if (len != o_bufsize) {
			break;
		}
	}
/*
	log_message(LOG_ERR, "Completed task start=%lld end=%lld count=%d\n", ctx->start, ctx->end, count);
*/
	return 0;
}

#ifdef WIPE_THREADS

void * verify_wrapper(void *param) 
{
	int res;
	thread_task_t *pt = (thread_task_t *)param;
	
	res = do_verify_pass(pt->fd, &pt->wipe_task, 1);
	pt->wipe_task.flags = res ? -1 : 1;
	return (void *)res;
}

#endif

static int verify_pass(int fd, wipe_task_t *ctx) 
{
	int		i, ret;

	ctx->data_context = DataContext;

#ifdef WIPE_THREADS
	if (prepare_multithread(ctx)) {
		log_message(LOG_INFO, "Wiping %s '%s' pass %d verification started. %d threads\n", 
			    get_type_str(ctx->st_mode), ctx->filename, ctx->pass+1, o_threads);
		for (i = 0; i < o_threads; i++) {
			Threads[i].fd = fd;
			pthread_create(&(Threads[i].thread), NULL, verify_wrapper, &(Threads[i]));
		}
		ret = monitor_multithread(1);
	} else 
#endif	
	{
		log_message(LOG_INFO, "Wiping %s '%s' pass %d verification started\n", 
			    get_type_str(ctx->st_mode), ctx->filename, ctx->pass+1);
		ctx->start = 0LL;
		ctx->pos = 0LL;
		ctx->end = ctx->size + ctx->slack_size;
		ctx->flags = 0;
		
		ret = do_verify_pass(fd, ctx, 0);
	}

	fsync(fd);
	if ( o_verbose ) {
		fprintf( stdout, "\n");
	}

	if (0 != ret) {
		log_message(LOG_ERR, "Wiping %s '%s' pass %d verification failed\n", get_type_str(ctx->st_mode), ctx->filename, ctx->pass+1);
		return ERROR;
	}

	log_message(LOG_INFO, "Wiping %s '%s' pass %d verification completed\n", get_type_str(ctx->st_mode), ctx->filename, ctx->pass+1);
	return OK;
	
}

/*
// Verification process requires same random byte sequence
// The function inites all random generators to start from same initial value
// here a time varable is used.
*/

int wipe_file_nas( wipe_task_t *ctx, int pass, int verify )
{
	int fd, is_dev, ret;
	long long int size;
	char *type_str;

	if (o_wipe_slacks)
		return wipe_file_slack_nas( ctx, pass, verify );

	if (ctx->skip)
		return OK;

	if (S_ISDIR(ctx->st_mode))
		return OK;

	is_dev = is_device( ctx->st_mode );
	if ( 0 == ctx->size && !is_dev ) {
		if (0 == pass) {
			log_message(LOG_INFO, "Skipping %s '%s': nothing to do\n", get_type_str(ctx->st_mode), ctx->filename);
		}
		return OK;
	}

	fd = do_open_file(ctx);
	if (ERROR == fd) {
		return ERROR;
	}

	if ( is_dev && 0 == ctx->size ) {
		ctx->size = get_size_of_device(fd);
	}

	size = ctx->size + ctx->slack_size;

	if (verify) {
		pass = ctx->pass; /*  In verification process the last saved settings will be used. */
		verify_pass(fd, ctx);
	} else {
		ctx->prev_seed = ctx->seed;
		ctx->seed = time( NULL );
		ctx->pass = pass;
		wipe_pass(fd, ctx);
	}
	
	if ( !o_dont_delete ) {
		ret = ftruncate( fd, 0 );
	}
	close(fd);

	return OK;

}

int wipe_filenames_in_list()
{
	wipe_task_t *ptr = FileListHead;

	while (ptr) {
		if (!ptr->skip) {
			if (S_ISDIR(ptr->st_mode)) {
				wipe_dirname(ptr->filename);
			} else {
				wipe_filename(ptr->filename, S_ISREG(ptr->st_mode));
			}
		}
		ptr = ptr->next;
	}
	return OK;
}

int wipe_file_slack_nas(wipe_task_t *ctx, int pass, int verify)
{
	char  str[100];
	int   fd, ret;
	struct stat st;
	struct utimbuf time_buf;

	if (ctx->skip)
		return OK;
		
	if (verify)
		return OK;

	if ( ERROR == lstat(ctx->filename, &st) ) {
		log_message(LOG_ERR, "Could not get information on '%s': %s - skipping\n", ctx->filename, strerror(errno));
		return ERROR;
	}

	fd = do_open_file_slack(ctx);
	if (0 == fd) {
		return OK;
	} else if (ERROR == fd) {
		return ERROR;
	}

	print_pass_name(str, sizeof(str), &scheme, pass);
	log_message(LOG_INFO, "Wiping slack of '%s' pass %d/%d [%s] started\n", ctx->filename, pass+1, o_pas_num, str);

	if (ERROR == lseek_f(fd, ctx->size, SEEK_SET)) {
		log_message(LOG_ERR, "Seek to end of file '%s': %s - skipping\n", ctx->filename, strerror(errno));
		ret = ftruncate(fd, ctx->size);
		close(fd);
		return ERROR;
	}

	ctx->prev_seed = ctx->seed;
	ctx->seed = time(NULL);
	ctx->pos = 0LL;
	ctx->pass = pass;
	ctx->data_context = DataContext;
	fill_buff(ctx, ctx->slack_size);
	
	if (ERROR == bcwipe_write(fd, (void *)get_buffer(ctx), ctx->slack_size))	{
		log_message(LOG_ERR, "Error writing to '%s': %s\n", ctx->filename, strerror(errno));
		ret = ftruncate(fd, ctx->size);
		close(fd);
		return ERROR;
	}

/*
#ifndef O_SYNC
	(void)fsync(fd);
#endif
*/
	(void)fsync(fd);
	log_message (LOG_INFO, "Wiping slack of '%s' pass %2d/%d completed\n", ctx->filename, pass+1, o_pas_num);

	if (o_pas_num == pass+1) {
		total_size_of_slacks += ctx->slack_size;
	}
	
	ret = ftruncate(fd, ctx->size);
	close(fd);

	if ( OK != chmod(ctx->filename, st.st_mode) ) {
		log_message(LOG_ERR, "Restore access mask for file '%s': %s\n", ctx->filename, strerror(errno));
		return ERROR;
	}

	time_buf.actime  = st.st_atime; 
	time_buf.modtime = st.st_mtime;
	if ( OK != utime(ctx->filename, &time_buf) ) {
		log_message(LOG_ERR, "Restore access times of file '%s': %s\n", ctx->filename, strerror(errno));
		return ERROR;
	}

	return OK;
}

int wipe_dirname(char *dirname)
{
	struct utimbuf utb;

	if ( o_dont_delete || o_wipe_slacks) 
		return OK;

	if ( !o_dont_wipe_fn ) {
		utb.actime=utb.modtime=0;
		utime(dirname, &utb);         /* set access and modification time to 0 */
	}

	if ( OK != rmdir(dirname) ) {
		log_message(LOG_ERR, "Could not remove directory '%s': %s\n", dirname, strerror(errno));
		return ERROR;
	}

	log_message(LOG_INFO, "Directory '%s' removed\n", dirname);
	return OK;

}


/*  wipe_filename(char *filename, int delete_file_contents) */
/*  wipe filename by renaming */
/*  return value: */
/*  ERROR   on error */
/*  OK      on success */
int wipe_filename(char *filename, int delete_file_contents)
{
	struct utimbuf utb;
	int ret;

	if ( o_dont_delete ) 
		return OK;

	if ( !o_dont_wipe_fn ) {
		if (delete_file_contents) {
			ret = truncate( filename, 0 );         /* set filesize to 0 */
		}
		utb.actime = utb.modtime = 0;
		utime( filename, &utb );         /* set access and modification time to 0 */
	}
	
	if ( OK != bcwipe_unlink(filename, 3) ) {
		log_message(LOG_ERR, "Could not remove file '%s': %s\n", filename, strerror(errno));
		return ERROR;
	}
	log_message(LOG_INFO, "File '%s' removed\n", filename);
	return OK;
}


/*off_t find_size_by_reading(int fd) */
/*return value: */
/*0       on filure */
/*size    on success */
long long int find_size_by_reading(int fd)
{
	off_t limit, pos, lPos, prev, b_pos = 0;
	char buf[64];
	int i;

	for ( limit=0x7f, i=sizeof(limit); --i; )
		limit = (limit << 8) | 0xff;

	pos = prev = limit;
	while ( pos != b_pos && pos <= limit ) {
		/*        fprintf(stdout,"pos=%20ld   b_pos=%12ld   buf=%x\n",(long int)pos,(long int)b_pos,buf[0]&0xff); */
		
		/*
		//    Version 1.7-7 Aug 07 2008
		//    Treats the lseek error as it cannot set file pointer 
		//	beyond device size instead of sending the error. 
		//	( AIX 5.2 reports here 'Invalid argumment' error )
		//
		//if ( pos != lseek_f(fd,pos,SEEK_SET) )
		//{
		//	fprintf(stderr,"lseek error: %s\n",strerror(errno));
		//	return 0;
		//}
		*/
		
		lPos = lseek_f( fd, pos, SEEK_SET );
		
		if ( ( lPos != pos ) || ( 1 != read(fd, buf, 1) ) ) {
			prev = pos;
			pos = (pos+b_pos) >> 1;
		} else	{
			b_pos = pos;
			pos = (pos+prev) >> 1;
		}
	}

	if ( pos >= limit )
		return 0;

	return lseek_f(fd, 0, SEEK_CUR);
}

long long int get_size_of_device(int fd)
{
	long long size=0;
	int i;
	int hist = 0;

#if defined(BLKGETSIZE)
	/* linux */ 
	long l;
	if (!ioctl(fd, BLKGETSIZE, &l)) {
		size = (long long)l*S_BLKSIZE;
	}
	hist = 1;

#elif defined(DIOC_CAPACITY)
	/* hp-ux */
	capacity_type ct;
	if ( !ioctl(fd, DIOC_CAPACITY, &(ct.lba))) {
		size = (long long)ct.lba * DEV_BSIZE;
	}
	hist = 2;

#elif defined(DIOCGMEDIASIZE)
	/* bsd */
	off_t media_size;
	if (-1 == ioctl(fd, DIOCGMEDIASIZE, &media_size)) {
		media_size = 0;
	}
	size = media_size;
	hist = 3;
	
#elif defined(OS_AIX)
	/* aix */
	struct devinfo	devinfo;
	if (-1 != ioctl(fd, IOCINFO, &devinfo)) {
		switch (devinfo.devtype) {
		case DD_DISK:
			if (devinfo.flags & DF_LGDSK) {
				size  = (long long int)devinfo.un.dk64.hi_numblks;
				size  = size << 32;
				size += (long long int)devinfo.un.dk64.lo_numblks;
				size *= (long long int)devinfo.un.dk64.bytpsec;
			} else {
				size = (long long int)devinfo.un.dk.numblks;
				size *= (long long int)devinfo.un.dk.bytpsec;
			}
			break;
		case DD_SCDISK:
			if (devinfo.flags & DF_LGDSK) {
				size  = (long long int)devinfo.un.scdk64.hi_numblks;
				size  = size << 32;
				size += (long long int)devinfo.un.scdk64.lo_numblks;
				size *= (long long int)devinfo.un.scdk64.blksize;
			} else {
				size = (long long int)devinfo.un.scdk.numblks;
				size *= (long long int)devinfo.un.scdk.blksize;
			}
			break;
		
		default:
			size = 0LL;
			break;
		}
	}
#endif
	if ( 0 == size || ERROR == size ) {
		size = lseek_f(fd, 0, SEEK_END);
		hist = 4;
	}

	if ( 0 == size || ERROR == size ) {
		size = find_size_by_reading(fd);
		hist = 5;
	}

	if ( 0 == size || ERROR == size ) {
		for (size = 0x7f, i = sizeof(size); --i;  )
			size = (size << 8) | 0xff;
		hist = 6;
	}

	log_message(LOG_INFO, "Device size %lld bytes (%ld kB), method %d\n", size, (long int)(size/1024), hist);

	return size;
}

int wipe_file_slack( char *filename )
{
	char str[100];
	int fd, ret, pass;
	wipe_task_t info;
	struct stat st;
	uid_t uid;
	struct utimbuf time_buf;

	if ( ERROR == lstat(filename, &st) ) {
		log_message(LOG_ERR, "Could not get information on '%s': %s - skipping\n", filename, strerror(errno));
		return ERROR;
	}

	uid = geteuid();
	if (0 != uid && st.st_uid != uid) {
		log_message(LOG_ERR, "You are not owner of '%s' - skipping\n", filename);
		return OK;
	}

	info.size = st.st_size;
	info.slack_size = st.st_size % st.st_blksize ? st.st_blksize - (st.st_size % st.st_blksize) : 0;
	info.st_mode = st.st_mode;
	info.filename = filename;
	info.seed = 0;
	info.prev_seed = 0;
	info.data_context = DataContext;
	
	fd = do_open_file_slack(&info);
	if (0 == fd) {
		return OK;
	} else if (ERROR == fd) {
		return ERROR;
	}

	for ( pass = 0; pass < o_pas_num; pass++ ) {

		info.pass = pass;
		print_pass_name(str, sizeof(str), &scheme, pass);
		log_message(LOG_INFO, "Wiping slack of '%s' pass %d/%d [%s] started\n", filename, pass+1, o_pas_num, str);
		
		if (ERROR == lseek_f(fd, st.st_size, SEEK_SET)) {
			log_message(LOG_ERR, "Seek failed on file '%s': %s - skipping\n", filename, strerror(errno));
			ret = ftruncate(fd, st.st_size);
			close(fd);
			return ERROR;
		}

		info.prev_seed = info.seed;
		info.seed = time(NULL);
		info.pos = 0;
		info.pass = pass;
		fill_buff(&info, st.st_blksize);

		if (ERROR == bcwipe_write(fd, (void *)get_buffer(&info), info.slack_size)) {
			log_message(LOG_ERR, "Error writing to '%s' slack: %s\n", filename, strerror(errno));
			ret = ftruncate(fd, st.st_size);
			close(fd);
			return ERROR;
		}
		(void)fsync(fd);
		log_message (LOG_INFO, "Wiping slack of '%s' pass %2d/%d completed\n", filename, pass+1, o_pas_num);
	}

	
	ret = ftruncate(fd, st.st_size);

	close(fd);

	total_size_of_slacks += info.slack_size;
	if ( OK != chmod(filename,st.st_mode) ) {
		log_message(LOG_ERR, "Restore access mask for file '%s': %s\n", filename, strerror(errno));
		return ERROR;
	}

	time_buf.actime  = st.st_atime; 
	time_buf.modtime = st.st_mtime;
	if ( OK != utime(filename,&time_buf) ) {
		log_message(LOG_ERR, "Restore access times of file '%s': %s\n", filename, strerror(errno));
		return ERROR;
	}

	log_message(LOG_INFO, "Wiping slack of '%s' completed\n", filename);

	return OK;
}


/* 
//	wipe_file (char *filename)
//		returns value:
//			ERROR on error
//			OK    on success
*/
int wipe_file( char *filename )
{
	int fd, is_dev, ret;
	struct stat st;
	wipe_task_t info;
	int pass;
	
	if (o_wipe_slacks)
		return wipe_file_slack( filename );

	if ( ERROR == lstat( filename, &st ) ) {
		log_message(LOG_ERR, "Stating file %s: %s - skipping\n", filename, strerror(errno) );
		return ERROR;
	}

	is_dev = is_device(st.st_mode);

	if ( is_dev ){
		if ( ERROR == stat( filename, &st ) ) {
			log_message(LOG_ERR, "Stating file %s: %s - skipping\n", filename, strerror(errno) );
			return ERROR;
		}
		
		if ( !S_ISBLK( st.st_mode ) && !S_ISCHR( st.st_mode ) ) {
			log_message(LOG_ERR, "%s: is not a device - skipping\n", filename );
			return ERROR;	
		}
	}

	memset(&info, 0, sizeof(info));
	info.filename = filename;
	info.size = st.st_size;
	info.slack_size = st.st_size % st.st_blksize ? st.st_blksize - (st.st_size % st.st_blksize) : 0;
	info.st_mode = st.st_mode;

	if (o_interactive && !ask_y_n("Wipe %s (y/[n]/a)?", filename) ) 
		return ERROR;

	if ( 0 == st.st_size && !is_dev ) {
		log_message(LOG_INFO, "Skipping %s '%s': nothing to do\n", get_type_str(st.st_mode), filename);
		return OK;
	}

	log_message(LOG_INFO, "Wiping %s '%s'\n", get_type_str(st.st_mode), filename);

	fd = do_open_file(&info);
	if (ERROR == fd) {
		return ERROR;
	}
	
	if ( is_dev ) {
		info.size = get_size_of_device( fd );
		info.slack_size = 0;
	}

	for ( pass = 0; pass < o_pas_num; pass++ ) {
		info.prev_seed = info.seed;
		info.seed = time( NULL );
		info.pass = pass;
		wipe_pass(fd, &info);
		if (o_verify_last_pass && scheme.pass[pass].verify) {
			verify_pass(fd, &info);
		}
	}

	if ( !o_dont_delete )
		ret = ftruncate(fd, 0);

	close(fd);

	return OK;
}

int wipe_file_by_type(char *filename, char *dirname) 
{
	struct stat buff;
	int	result;
	
	if ( OK != lstat(filename, &buff) )	{
		log_message(LOG_ERR, "Cannot stat '%s': %s - skipping\n", filename, strerror(errno));
		return ERROR;
	}

	if ( S_ISDIR(buff.st_mode) ) {
		if (dirname) {
			if (0 == strcmp(dirname, ".") || 0 == strcmp(dirname, ".."))
				return OK;
		} else if (!o_recurse) {
			log_message(LOG_ERR,"'%s' is a directory - skipping\n", filename);
			return OK;
		}
		result = wipe_dir(filename);
	} else if ( S_ISREG(buff.st_mode) ) {
		result = wipe_file( filename );
		if ( OK == result ) {
			result = wipe_filename(filename, 1);
		}
	} else if ( S_ISCHR(buff.st_mode) || S_ISBLK(buff.st_mode) || S_ISLNK(buff.st_mode) )  {
		if ( o_wipe_dev ) {
			result = wipe_file(filename);
		} else {
			result = wipe_filename(filename, 0);
		}
	} else if ( S_ISFIFO(buff.st_mode) || S_ISSOCK(buff.st_mode) ) {
		result = wipe_filename(filename, 0);
	} else {
		log_message(LOG_ERR, "'%s': unsupported file type - skipping\n", filename);
		return ERROR;
	}
	return result;
}

int wipe_dir( char *dirname )
{
	struct dirent *d;
	DIR *fd;
	char fn[NAME_MAX+PATH_MAX];

	if (NULL == dirname) 
		return ERROR;

	if (o_interactive && !ask_y_n("Enter directory %s (y/[n]/a)?", dirname))
		return ERROR;

	/* check directory access */
	if ( !o_wipe_slacks && OK != access(dirname,X_OK|R_OK|W_OK)) {
		if ( !o_force )	{
			log_message(LOG_ERR, "Could not enter directory '%s': %s - skipping\n", dirname, strerror(errno));
			return ERROR;
		}
		if ( OK != chmod(dirname,S_IRUSR|S_IWUSR|S_IXUSR) ) {
			log_message(LOG_ERR, "Could not chmod directory '%s': %s - skipping\n", dirname, strerror(errno));
			return ERROR;
		}
	}

	fd = opendir(dirname);
	if ( NULL == fd ) {
		log_message(LOG_ERR, "Could not open directory '%s': %s - skipping\n", dirname, strerror(errno));
		return ERROR;
	}

	log_message(LOG_INFO, "Entering directory '%s'\n", dirname);

	while ( NULL != (d = readdir(fd)) ) {
		snprintf(fn, NAME_MAX+PATH_MAX, "%s/%s", dirname, d->d_name);
		wipe_file_by_type(fn, d->d_name);
	}

	closedir(fd);

	if ( o_dont_delete )
		return OK;

	if (o_interactive && !ask_y_n("Remove directory '%s' (y/[n]/a)?", dirname) )
		return ERROR;

	if ( OK != rmdir(dirname) ) {
		log_message (LOG_ERR, "Error while removing '%s': %s\n",dirname,strerror(errno));
		return ERROR;
	}
	log_message(LOG_INFO, "Directory '%s' removed\n", dirname);

	return OK;
}



/* -------------- wipe free space routines -------------- */
char *get_mount_point(char *path)
{
	return path;
}

long long int get_free_space(char *path)
{
	int res;
	struct statvfs_f sfs;
	res = statvfs_f( path, &sfs );

	if (res != 0) {
		log_message(LOG_ERR, "statvfs(%s): %s\n",path,strerror(errno));
		return 0;
	}

	return (off_t)sfs.f_bfree * sfs.f_frsize;
}

int can_wipe_all_free_space(char *path)
{
	struct statvfs_f sfs;
	int res;
	
	res = statvfs_f( path, &sfs );
	if (res != 0) {
		log_message(LOG_ERR, "Cannot get free space via statvfs(%s): %s\n", path, strerror(errno));
		return 0;
	}
	return (sfs.f_bfree == sfs.f_bavail || geteuid() == 0);
}

static wipe_task_t *fs_alloc_wipe_info( wipe_task_t **pphead, char *filename, int pass )
{
	wipe_task_t *ptr;
	
	ptr = (wipe_task_t *)malloc( sizeof( wipe_task_t ) );
	if ( !ptr )
		return NULL;
	
	memset(ptr, 0, sizeof(wipe_task_t));
	ptr->filename = strdup(filename);
	if (!ptr->filename) {
		free(ptr);
		return NULL;
	}
	ptr->prev_seed = ptr->seed;
	ptr->seed = time(NULL);
	ptr->pass = pass;
	ptr->next = *pphead;
	*pphead = ptr;

	return ptr;
}

#define MAX_FILE_SIZE   1024*1024*1024

int fs_create_files( wipe_task_t **head, char *path, int pass, long long int *ret_size )
{
	char str[100];
	char tmp[PATH_MAX+NAME_MAX];
	int fd, res, j, write_fail;
	long long int file_size, ss, free_space, x, start_time;
	int cnt, err;
	wipe_task_t *ctx;


	/*
	//	The is a strange report about HPUX 11.23.
	//	We are running it on HPUX 11.23 with the option vIF and what happens is
	//	that a directory is created with a 5 digit random number appended and in
	//	it is created up to 26 1GB files, each one prefixed by a letter a-z.
	//	Once z is reached it stops, removes the files and then starts on the
	//	next pass.
	//
	//	Version 1.7-3
	//	The 'cnt' is a name of the temporary file and extention is random.
	*/
	cnt = 0;
	start_time = get_timestamp();
	write_fail = 0;
	file_size  = 0;
	free_space = get_free_space(path);

	print_pass_name(str, sizeof(str), &scheme, pass);
	log_message(LOG_INFO, "Free space wiping pass %2d/%-2d [%s] started. Total free space %lld kB\n", pass+1, o_pas_num, str, free_space >> 10);

	if ( 0 == free_space ) {
		if (1 != pass) {
			log_message(LOG_ERR, "No free space available on this filesystem\n");
			return ERROR;
		}
		return OK;
	}
	
	while ( TRUE ) {
		ss = 0;

		snprintf( tmp, PATH_MAX+NAME_MAX, "%s/%03x.XXXXXX", path, cnt++ );
		fd = mkstemp( tmp );
		if ( ERROR == fd ) {
			if ( ENOSPC == errno ) {
				res = 0;
				break;
			} 
			log_message(LOG_ERR, "mkstemp(%s): %s\n", tmp, strerror( errno ) );
			goto error_out; 
		}
		ctx = fs_alloc_wipe_info( head, tmp, pass );
		if ( !ctx ) {
			close( fd );
			log_message(LOG_ERR, "Error in allocating memory\n" );
			goto error_out; 
		}

		free_space = get_free_space(path);
		do {
			if (free_space > o_bufsize) {
				j = o_bufsize;
			} else {
				j = 1;
				x = free_space;
				while (x >> j) {
					j++;
				}
				j = 1 << (j-1);
				if (write_fail) {
					j = (j+1) / 2;
					write_fail = 0;
				}
			}

			ctx->pass = pass;
			ctx->pos = ss;
			ctx->data_context = DataContext;
			fill_buff( ctx, j );
			res = bcwipe_write( fd, get_buffer(ctx), j );
			if ( ERROR != res ) {
				file_size += res;
				ss += res;
				if (ret_size) {
					*ret_size = file_size;
				}
			}
			
			free_space = get_free_space(path);

			if ( o_verbose ) {
				print_wiping_progress(free_space+file_size, file_size, start_time, pass);
			}

			if ( ERROR == res || o_bufsize != res) {
				if (ENOSPC == errno) {
				    res = ENOSPC;
				}
				break;
			}
			
			if ( MAX_FILE_SIZE <= ss ) {
				res = 0;
				break;
			}

		} while ( 1 || ERROR != res );

		write_fail = (0 == ss);

		(void)fsync(fd);

		close( fd );
	}
	
	if (OK == res) {
		if (o_verbose) {
			fprintf(stdout, "\n");
		}
		log_message(LOG_INFO, "Free space wiping pass %2d/%-2d completed. Processed %lld kB, remaining %lld kB\n", 
		pass+1, o_pas_num, file_size >> 10, get_free_space(path) >> 10);
		return OK;
	}
	
error_out:
	
	if (o_verbose) {
		fprintf(stdout, "\n");
	}
	log_message(LOG_ERR, "Free space wiping pass %2d/%-2d failed. Processed %lld kB\n", pass+1, o_pas_num, file_size >> 10);

	return ERROR;
}

int fs_verify_files( wipe_task_t *head, long long int size, int pass )
{
	unsigned char *buf, *ver_buf;
	long long int start_time;

	int fd;
	long long int s, ss;
	ssize_t res, x;
	wipe_task_t *ptr;

	log_message(LOG_INFO, "Free space wiping pass %2d verification started\n", pass+1 );
	
	s = 0;
	start_time = get_timestamp();

	for (ptr = head; ptr; ptr = ptr->next ) {

		fd = open( ptr->filename, O_RDONLY );
		if ( ERROR == fd ) {
			log_message(LOG_ERR,"Error in opening file '%s' for verification: %s\n", ptr->filename, strerror(errno) );
			goto error_out;
		}

		ss = 0;
		do {
			res = bcwipe_read( fd, get_verify_buffer(ptr), o_bufsize );
			if ( ERROR == res ) {
				log_message(LOG_ERR, "Error in reading file '%s' for verification: %s\n", ptr->filename, strerror(errno) );
				close( fd );
				goto error_out;
			} 
			
			if (0 == res) {
				break;
			}
			
			ptr->pos = ss;
			fill_buff( ptr, res );
			buf = get_buffer(ptr);
			ver_buf = get_verify_buffer(ptr);
			x = verify_buffer(buf, ver_buf, res);
			if ( 0 != x ) {
				log_message( LOG_ERR, "\nVerification error. File '%s', offset %lld\n"
						      "Expected %02Xh, read %02Xh\n", ptr->filename, s+x-1, buf[x-1], ver_buf[x-1]);
				close( fd );
				goto error_out;
			}
			s  += res;
			ss += res;

			if ( o_verbose ) {
				print_verification_progress(size, s, start_time, pass);
			}
		} while ( res > 0 );

		close( fd );
	}

	if (o_verbose) {
		fprintf(stdout, "\n");
	}
	log_message(LOG_INFO, "Free space wiping pass %2d verified %lld kB\n", pass+1, s >> 10);
	return OK;
error_out:

	if (o_verbose) {
		fprintf(stdout, "\n");
	}
	log_message(LOG_ERR, "Free space wiping pass %2d verification failed\n", pass+1);
	return ERROR;

}

int allocate_free_space( char *path, int pass, int verify )
{
	wipe_task_t *fs_head = NULL;
	long long int size;
	int res;

	res = fs_create_files( &fs_head, path, pass, &size );
	if (OK == res) {
		if ( o_nas_delay ) {
			if ( o_verbose ) {
				fprintf( stdout, "Sleeping %d seconds\n", o_nas_delay );
			}
			sleep(o_nas_delay);
		}

		if ( verify ) {
			res = fs_verify_files( fs_head, size, pass );
		}
	}
	free_list( fs_head );
	return res;
}

int delete_temp_dir(char *dirname, int silent)
{
	struct dirent *d;
	DIR *fd;
	struct stat buff;
	char fn[NAME_MAX+PATH_MAX];
	int locked, deleted, attempt = 3;

	if ( NULL == dirname ) {
		return ERROR;
	}

	fd = opendir(dirname);
	if ( NULL == fd ) {
		if (!silent) {
			log_message(LOG_ERR, "opendir(%s): %s \n",dirname,strerror(errno));
		}
		return ERROR;
	}

	locked = 0;
	deleted = 0;
	while (1) {
		d = readdir(fd);
		if (NULL == d) {
			if (0 == locked) {
				break;
			} else if (0 == deleted) {
				if (attempt) {
					locked = 0;
					deleted = 0;
					rewinddir(fd);
					attempt--;
				} else {
					break;
				}

			} else {
				locked = 0;
				deleted = 0;
				rewinddir(fd);
				continue;
			}
		}

		snprintf(fn, NAME_MAX+PATH_MAX, "%s/%s", dirname, d->d_name);
		if ( OK != lstat(fn,&buff) ) {
			log_message(LOG_ERR,"lstat(%s): %s\n",fn,strerror(errno));
			continue;
		}
		if ( S_ISDIR(buff.st_mode) ) {    /*directory */
			if ( 0 == strcmp(d->d_name,".") || 0 == strcmp(d->d_name,"..") )
				continue;
			delete_temp_dir(fn, silent);
		} else {
			/* unlink a file with retries as a last resort only */
			if ( 0 != bcwipe_unlink(fn, attempt ? 1 : 3 ) ) {
				locked++;
				if (0 == attempt) {
					log_message(LOG_ERR, "unlink(%s): %s\n", fn, strerror(errno));
				}
			} else {
				deleted++;
			}
		}
	}
	closedir(fd);

	if ( OK != rmdir(dirname) ) {
		log_message(LOG_ERR, "rmdir(%s): %s\n", dirname, strerror(errno));
		return ERROR;
	}
	sync();
	return OK;
}

char *make_temp_dir( char *path, char *result, int result_sz )
{
	int fd;
	/*	GCC reports warning 'mktemp is dangerous, better use mkstemp' */
	snprintf( result, result_sz, "%s/bcwipe-wiping_free_space-XXXXXX", path );
	fd = mkstemp( result );
	if ( ERROR == fd )	{
		log_message(LOG_ERR, "Failed to create temporary file via mkstemp(%s): %s\n", result, strerror(errno));
		return NULL;
	}
	close(fd);
	bcwipe_unlink(result, 3);

	if (OK != mkdir(result, 0700)) {
		log_message(LOG_ERR ,"Failed to create a directory via mkdir(%s): %s\n",result,strerror(errno));
		return NULL;
	}
	return result;
}

/*
//	wipe_free_space
//	1. Creates new files and fills them by wiping data for all free space available.
//	All creates file names are stored in list 
//	2. The last pass free space allocation verifies the new files by the list.
//	3. Removes the new directory.
*/
int wipe_free_space(char *path)
{
	int i, res;

	if (o_interactive && !ask_y_n("Wipe free space in %s (y/[n])?",  get_mount_point(path)))
		return OK;

	if (OK != access(path, W_OK|R_OK|X_OK)) {
		log_message(LOG_ERR, "Cannot wipe free space in %s: %s\n", path, strerror(errno));
		return ERROR;
	}

	if (!can_wipe_all_free_space(path) && 
		o_interactive &&
		!ask_y_n("You can not wipe ALL free space on %s.\nContinue (y/[n])?", get_mount_point(path)))
			return OK;
	
	log_message(LOG_INFO, "Wiping free space on %s\n", get_mount_point( path ) );

	for (i = 0; i < o_pas_num; i++) {
	
		if (!make_temp_dir(path, free_space_dir, PATH_MAX)) {
			log_message(LOG_ERR, "Could not create temporary directory for %s\n", get_mount_point(path));
			return ERROR;
		}
		free_space_dir_created = 1;

		res = allocate_free_space( free_space_dir, i, o_verify_last_pass && scheme.pass[i].verify );
		if (OK != res) {
			delete_temp_dir(free_space_dir, 1);
			return res;
		}

		log_message(LOG_INFO, "Deleting temporary files...\n" );

		res = delete_temp_dir(free_space_dir, 0);
		if (OK != res) {
			log_message(LOG_ERR, "Error deleting temporary files under %s\n", get_mount_point(path));
			return res;
		}
	}
	
	log_message(LOG_INFO, "Wiping free space on '%s' completed\n", get_mount_point( path ) );

	return OK;
}

static void exit_handler(void) 
{

	if (free_space_dir_created) {
		delete_temp_dir(free_space_dir, 1);
	}
	if (DataContext) {
		free_data_context(DataContext, o_threads);
	}
	cleanup_scheme(&scheme);
	close_log();
}

static void signal_handler(int sig) 
{
	if (!ask_y_n("\nDo you want to stop wiping (y/[n])?")) {
	    return;
	}
	log_message(LOG_ERR, "Process was interrupted by user\n");
	exit_handler();
	exit(-1);
}

/* -------------- end of wipe free space routines -------------- */


int main(int argc, char* argv[])
{
	int i, result;

	/* turn off buffering*/
	setvbuf(stderr,(char*)NULL,_IONBF,0);
	setvbuf(stdout,(char*)NULL,_IONBF,0);
	
	signal(SIGINT,  signal_handler);
	signal(SIGQUIT, signal_handler);
	signal(SIGABRT, signal_handler);
	signal(SIGTERM, signal_handler);
	atexit(exit_handler);

	result = parseOptions( &argc, &argv );
	if (0 != result) {
		return result;
	}

	log_message(LOG_FILE, "**** BCWipe %s started ****\n", VERSION);
	result = init_scheme(&scheme);
	if (OK != result) {
		return ERROR;
	}

	o_threads = o_threads ? o_threads : 1;
	DataContext = init_data_context(o_threads, o_use_rand ? BCWIPE_ISAAC : BCWIPE_SHA1, o_bufsize);
	if (!DataContext) {
		return -1;
	}
	
	log_message(LOG_INFO, "Wiping scheme: %s, %d pass(es)\n", scheme.name, scheme.num_passes);
	
	
	if (o_wipe_free_space) {
		result = wipe_free_space(argv[0]);
		if (OK == result && o_wipe_slacks) {
			o_recurse = TRUE; /* free space wiping complete, now wipe file slacks        */

		} else {
			goto exit;
		}
	}

	if (o_nas_wiping) {
		result = nas_wiping(argc, argv);
	} else {
		for ( i = argc; i; i-- ) {
			wipe_file_by_type(argv[i-1], NULL);
		}
	}
	if (o_wipe_slacks) {
		if (total_size_of_slacks > 4096) {
			log_message(LOG_INFO, "Wiped %d kB of file slacks\n",(unsigned int)(total_size_of_slacks/1024));
		} else {
			log_message(LOG_INFO, "Wiped %d bytes of file slacks\n",(unsigned int)(total_size_of_slacks));
		}
	}

exit:
	free_data_context(DataContext, o_threads);

	return result;
}

