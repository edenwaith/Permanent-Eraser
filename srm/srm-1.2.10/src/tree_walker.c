/* this file is part of srm http://srm.sourceforge.net/
   It is licensed under the MIT/X11 license */

#include "config.h"

#if defined(__linux__) && 1
/* Three kludges for the price of one; glibc's fts package doesn't
   support LFS, so fall back to nftw. Do it here, before the headers
   define _BSD_SOURCE and set the prefer BSD behavior, preventing us
   from including XPG behavior with nftw later on. Check for linux and
   not glibc for the same reason. Can't include features.h without
   prefering bsd.

   Once glibc has a working fts, remove nftw completely along with
   this hack.
 */

#undef HAVE_FTS_OPEN
#define _GNU_SOURCE
#endif

#if defined(__linux__) && defined(HAVE_FTS_OPEN)
/* the fts function does not like 64bit-on-32bit, but we don't need it here anyway. */
#ifdef _FILE_OFFSET_BITS
#undef _FILE_OFFSET_BITS
#define LARGE_FILES_ARE_ENABLED 1
#endif
#ifdef _LARGE_FILES
#undef _LARGE_FILES
#define LARGE_FILES_ARE_ENABLED 1
#endif
#endif // 0

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#if HAVE_FTS_OPEN
#include <fts.h>
#endif

#include "srm.h"

static int prompt_user(const char *string)
{
  char inbuf[8];
  assert(string);

  printf("%s", string); fflush(stdout);
  fgets(inbuf, 4, stdin);
  return strncmp(inbuf, "y", 1) == 0;
}

static int check_perms(const char *path)
{
  int fd=-1;
  struct stat statbuf;

  assert(path);

  if( (stat(path, &statbuf) < 0) && (lstat(path, &statbuf) < 0) )
    return 0;

  if ( S_ISREG(statbuf.st_mode) && ((fd = open(path, O_WRONLY)) < 0) && (errno == EACCES) )
    {
      if ( chmod(path, S_IRUSR | S_IWUSR) < 0 )
	{
	  errorp("Unable to reset %s to writable (probably not owner) ... skipping", path);
	  return 0;
	}
    }

  if(fd>=0)
    close(fd);
  return 1;
}

static int prompt_file(const char *path)
{
  int fd=-1, return_value=1;
  size_t bufsize;
  char *buf=0;
  struct stat statbuf;

  assert(path);

  bufsize = strlen(path) + 80;

  if (options & OPT_F) {
    if (options & OPT_V)
      printf("removing %s\n", path);
    return check_perms(path);
  }

  if( (stat(path, &statbuf) < 0) && (lstat(path, &statbuf) < 0) )
    {
      errorp("could not stat %s", path);
      return 0;
    }

  if ( (buf = (char *)alloca(bufsize)) == NULL )
    {
      errorp("Out of memory at line %d in prompt_file()", __LINE__);
      return 0;
    }

  if ( S_ISREG(statbuf.st_mode) && ((fd = open(path, O_WRONLY)) < 0) && (errno == EACCES) )
    {
      /* Not a symlink, not writable */
      snprintf(buf, bufsize, "Remove write protected file %s? ", path);
      if ( (return_value = prompt_user(buf)) == 1 ) 
	return_value = check_perms(path);
    }
  else
    {
      /* Writable file or symlink */
      if (options & OPT_I) {
	snprintf(buf, bufsize, "Remove %s? ", path);
	return_value = prompt_user(buf);
      }
    }

  if ((options & OPT_V) && return_value) 
    printf("removing %s\n", path);

  if(fd >= 0)
    close(fd); /* close if open succeeded, or silently fail */

  return return_value;
}

static int process_file(char *path, int flag)
{
  assert(path);

  while (path[strlen(path) - 1] == DIRSEP) 
    path[strlen(path)- 1] = '\0';

  switch (flag) {
#ifdef FTS_D
  case FTS_D:
    /*error("%s as FTS_D", path);*/
    break;
#endif

#ifdef FTS_DC
  case FTS_DC:
    error("cyclic directory entry %s", path);
    break;
#endif

#ifdef FTS_DNR
  case FTS_DNR:
#endif
    error("%s: permission denied", path);
    break;

#ifdef FTS_DOT
  case FTS_DOT: break;
#endif

#ifdef FTS_DP
  case FTS_DP:
    if (options & OPT_R) {
      if ( prompt_file(path) && (rename_unlink(path) < 0) )
	errorp("unable to remove %s", path);
    } else {
      error("%s is a directory", path);
    }
    break;
#endif

#ifdef FTS_ERR
  case FTS_ERR:
    error("fts error on %s", path);
    break;
#endif

#ifdef FTS_NS
  case FTS_NS:
#endif
#ifdef FTS_NSOK
  case FTS_NSOK:
#endif
    /* if we have 32bit system and file is >2GiB the fts functions can not stat them, so we just ignore the fts error. */
#ifndef LARGE_FILES_ARE_ENABLED
    /* Ignore nonexistant files with -f */
    if ( !(options & OPT_F) )
      {
	error("unable to stat %s", path);
	break;
      }
#endif
    /* no break here */

#ifdef FTS_DEFAULT
  case FTS_DEFAULT:
#endif
#ifdef FTS_F
  case FTS_F:
#endif
#ifdef FTS_SL
  case FTS_SL:
#endif
#ifdef FTS_SLNONE
  case FTS_SLNONE:
#endif
    if ( prompt_file(path) && (sunlink(path, options) < 0) ) {
      if (errno == EMLINK) 
	error("%s has multiple links, this one has been removed but not "
	      "overwritten", path);
      else
	errorp("unable to remove %s", path);
    }
    break;

  default:
    error("unknown fts flag: %i", flag);
  }
  return 0;
}

#if HAVE_FTS_OPEN

int tree_walker(char **trees) {
  FTSENT *current_file=0;
  FTS *stream=0;
  int i = 0;

  assert(trees);

  while (trees[i] != NULL) {
    while (trees[i][strlen(trees[i]) - 1] == DIRSEP)
      trees[i][strlen(trees[i]) -1] = '\0';
    i++;
  }

  if ( (stream = fts_open(trees, FTS_PHYSICAL | FTS_NOCHDIR, NULL)) == NULL )
    errorp("fts_open() returned NULL");
  else {
    while ( (current_file = fts_read(stream)) != NULL) {
      process_file(current_file->fts_path, current_file->fts_info);
      if ( !(options & OPT_R) )
	fts_set(stream, current_file, FTS_SKIP);
    }
    fts_close(stream);
  }
  return 0;
}

#elif HAVE_NFTW

#if defined(__digital__) && defined(__unix__)
/* Shut up tru64's cc(1) */
#define _XOPEN_SOURCE_EXTENDED
#endif

#define _GNU_SOURCE
#include <ftw.h>

static int ftw_process_path(const char *opath, const struct stat *statbuf, int flag, struct FTW *dummy)
{
  size_t path_size;
  char *path;

  assert(opath);

  path_size = strlen(opath) + 1;
  path = (char *)alloca(path_size);

  if (path == NULL) {
    errno = ENOMEM;
    return -1;
  }
  strncpy(path, opath, path_size);

  switch (flag) {
  case FTW_F:
    process_file(path, FTS_F);
    break;
  case FTW_SL:
    process_file(path, FTS_SL);
    break;
  case FTW_SLN:
    process_file(path, FTS_SLNONE);
    break;
  case FTW_D:
    process_file(path, FTS_D);
    break;
  case FTW_DP:
    process_file(path, FTS_DP);
    break;
  case FTW_DNR:
    process_file(path, FTS_DNR);
    break;
  case FTW_NS:
    process_file(path, FTS_NS);
    break;
  default:
    error("unknown nftw flag: %i", flag);
  }

  if (options & OPT_R)
    return 0;
  return 1;
}

int tree_walker(char **trees) {
  int i = 0;
  assert(trees);

  while (trees[i] != NULL) { 
    while (trees[i][strlen(trees[i]) - 1] == DIRSEP)
      trees[i][strlen(trees[i]) -1] = '\0';
    if (options & OPT_R)
      nftw(trees[i], ftw_process_path, 10, FTW_DEPTH|FTW_PHYS);
    else
      nftw(trees[i], ftw_process_path, 10, 0);
    i++;
  }
  return 0;
}

#elif defined(_WIN32)
/* code is in win/tree_walker.cpp */

#else
#error No tree traversal function found
#endif
