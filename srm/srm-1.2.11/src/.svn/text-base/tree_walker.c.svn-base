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
#include "impl.h"

static int prompt_user(const char *string)
{
  char inbuf[8];
  if(!string) return 0;

  printf("%s", string); fflush(stdout);
  fgets(inbuf, 4, stdin);
  return strncmp(inbuf, "y", 1) == 0;
}

static int check_perms(const char *path)
{
  int fd=-1;
  struct stat statbuf;

  if(!path) return -1;

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

static int prompt_file(const char *path, const int options)
{
  int fd=-1, return_value=1;
  size_t bufsize;
  char *buf=0;
  struct stat statbuf;

  if(!path) return -1;

  bufsize = strlen(path) + 80;

  if (options & SRM_OPT_F)
    {
      if (options & SRM_OPT_V)
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
      if (options & SRM_OPT_I)
	{
	  snprintf(buf, bufsize, "Remove %s? ", path);
	  return_value = prompt_user(buf);
	}
    }

  if ((options & SRM_OPT_V) && return_value)
    printf("removing %s\n", path);

  if(fd >= 0)
    close(fd); /* close if open succeeded, or silently fail */

  return return_value;
}

int process_file(char *path, const int flag, const int options)
{
  if(!path) return -1;

  while (path[strlen(path) - 1] == SRM_DIRSEP)
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
    if (options & SRM_OPT_R)
      {
	if ( prompt_file(path, options) && (rename_unlink(path) < 0) )
	  errorp("unable to remove %s", path);
      }
    else
      error("%s is a directory", path);
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
    if ( !(options & SRM_OPT_F) )
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
    if ( prompt_file(path, options) && (sunlink(path, options) < 0) ) {
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

#ifdef HAVE_FTS_OPEN

int tree_walker(char **trees, const int options)
{
  FTSENT *current_file=0;
  FTS *stream=0;
  int i = 0, opt = FTS_PHYSICAL | FTS_NOCHDIR;

  if(!trees) return -1;

  /* remove trailing slashes free trees */
  while (trees[i] != NULL) {
    while (trees[i][strlen(trees[i]) - 1] == SRM_DIRSEP)
      trees[i][strlen(trees[i]) -1] = '\0';
    i++;
  }

  if(options & SRM_OPT_X)
    opt |= FTS_XDEV;

  if ( (stream = fts_open(trees, opt, NULL)) == NULL )
    errorp("fts_open() returned NULL");
  else {
    while ( (current_file = fts_read(stream)) != NULL) {
      process_file(current_file->fts_path, current_file->fts_info, options);
      if ( !(options & SRM_OPT_R) )
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

static int options;

static int ftw_process_path(const char *opath, const struct stat *statbuf, int flag, struct FTW *dummy)
{
  size_t path_size;
  char *path;

  if(!opath) return -1;

  path_size = strlen(opath) + 1;
  path = (char *)alloca(path_size);

  if (path == NULL) {
    errno = ENOMEM;
    return -1;
  }
  strncpy(path, opath, path_size);

  switch (flag) {
  case FTW_F:
    process_file(path, FTS_F, options);
    break;
  case FTW_SL:
    process_file(path, FTS_SL, options);
    break;
  case FTW_SLN:
    process_file(path, FTS_SLNONE, options);
    break;
  case FTW_D:
    process_file(path, FTS_D, options);
    break;
  case FTW_DP:
    process_file(path, FTS_DP, options);
    break;
  case FTW_DNR:
    process_file(path, FTS_DNR, options);
    break;
  case FTW_NS:
    process_file(path, FTS_NS, options);
    break;
  default:
    error("unknown nftw flag: %i", flag);
  }

  if (options & SRM_OPT_R)
    return 0;
  return 1;
}

int tree_walker(char **trees, const int options_)
{
  int i = 0;
  int opt = 0;

  if(!trees) return -1;
  options = options_;

  if(options & SRM_OPT_X)
    opt |= FTW_MOUNT;
  if(options & SRM_OPT_R)
    opt |= FTW_DEPTH|FTW_PHYS;

  while (trees[i] != NULL)
    {
      /* remove trailing slashes */
      while (trees[i][strlen(trees[i]) - 1] == SRM_DIRSEP)
	trees[i][strlen(trees[i]) -1] = '\0';

      nftw(trees[i], ftw_process_path, 10, opt);
      ++i;
    }
  return 0;
}

#elif defined(_WIN32)
/* code is in win/tree_walker.cpp */

#else
#error No tree traversal function found
#endif
