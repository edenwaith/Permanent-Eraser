/* this file is part of srm http://srm.sourceforge.net/
   It is licensed under the MIT/X11 license */

#include "config.h"

#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "srm.h"
#include "impl.h"

#if defined(__unix__)
#include <dirent.h>
/* ripped from http://www.opensource.apple.com/darwinsource/Current/srm-6/srm/src/rename_unlink.c */
static int empty_directory(const char *path)
{
  DIR *dp;
  struct dirent *de;

  if(!path) return -1;

  dp = opendir(path);
  if (dp == NULL)
    return -1;

  while ((de = readdir(dp)) != NULL)
    {
      if (
#ifdef __APPLE__
	  de->d_namlen < 3 &&
#endif
	  (!strcmp(de->d_name, ".") || !strcmp(de->d_name, "..")))
	continue;

      closedir(dp);
      return -1;
    }
  closedir(dp);
  return 0;
}
#endif

int rename_unlink(const char *path) {
  char *new_name, *p;
  struct stat statbuf;
  size_t new_name_size;
  int i = 0;

  if(!path)
    {
      errno = EINVAL;
      return -1;
    }

  /* does path exist? */
  if (lstat(path, &statbuf) < 0)
    return -1;

#if defined(__unix__)
  /* is path is a directory it should be empty */
  if (S_ISDIR(statbuf.st_mode) && (empty_directory(path) < 0))
    {
      /* Directory isn't empty (e.g. because it contains an immutable file). Attempting to remove it will fail, so avoid renaming it. */
      errno = ENOTEMPTY;
      return -1;
    }
#endif

  /* construct the new random name */
  new_name_size = strlen(path) + 15;

  if ( (new_name = (char *)alloca(new_name_size)) == NULL ) {
    errno = ENOMEM;
    return -1;
  }

  strncpy(new_name, path, new_name_size);

  if ( (p = strrchr(new_name, SRM_DIRSEP)) != NULL ) {
    p++;
    *p = '\0';
  } else {
    p = new_name;
  }

  do {
    i = 0;

    while (i < 14) {
      unsigned char c = random_char();
      if (isalnum((int) c)) {
	p[i] = c;
	i++;
      }
    }
    p[i] = '\0';
  } while (lstat(new_name, &statbuf) == 0);

  /* rename */
  if (rename(path, new_name) < 0)
    return -1;

  sync();

  /* check the new name */
  if (lstat(new_name, &statbuf) < 0) {
    /* Bad mojo, we just renamed to new_name and now the path is invalid.
       Die ungracefully and exit before anything worse happens. */
    perror("Fatal error in rename_unlink()");
    exit(EXIT_FAILURE);
  }

  /* remove */
  if (S_ISDIR(statbuf.st_mode))
    return rmdir(new_name);

  return unlink(new_name);
}
