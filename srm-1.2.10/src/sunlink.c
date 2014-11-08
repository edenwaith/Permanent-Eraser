/* this file is part of srm http://srm.sourceforge.net/
   It is licensed under the MIT/X11 license */

#include "config.h"

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#if defined(__unix__)
#include <sys/ioctl.h>
#endif

#ifdef HAVE_SYS_VFS_H
#include <sys/vfs.h>
#endif

#if defined(HAVE_SYS_PARAM_H) && defined(HAVE_SYS_MOUNT_H)
#include <sys/param.h>
#include <sys/mount.h>
#endif

#if defined(HAVE_LINUX_EXT3_FS_H)
#include <linux/fs.h>
#include <linux/ext3_fs.h>

#define EXT2_IOC_GETFLAGS EXT3_IOC_GETFLAGS
#define EXT2_UNRM_FL EXT3_UNRM_FL
#define EXT2_IMMUTABLE_FL EXT3_IMMUTABLE_FL
#define EXT2_APPEND_FL EXT3_APPEND_FL
#define EXT2_IOC_SETFLAGS EXT3_IOC_SETFLAGS
#define EXT2_SECRM_FL EXT3_SECRM_FL
#define EXT2_IOC_SETFLAGS EXT3_IOC_SETFLAGS
#define EXT2_SUPER_MAGIC EXT3_SUPER_MAGIC

#elif defined(HAVE_LINUX_EXT2_FS_H)
#include <linux/fs.h>
#include <linux/ext2_fs.h>
#endif

#include "srm.h"

static int file = -1;
static off_t file_size;
static unsigned char *buffer;
static unsigned int buffsize;

static void overwrite() {
  off_t i = 0;

  assert(file >= 0);
  assert(buffer);

  if(lseek(file, 0, SEEK_SET) != 0)
    {
      perror("could not seek");
      exit(EXIT_FAILURE);
    }

  if(file_size < (off_t)buffsize)
    write(file, buffer, file_size); /* todo: check */
  else
    {
      while (i < file_size - (off_t)buffsize)
	i += write(file, buffer, buffsize); /* todo: check */
      write(file, buffer, file_size - i); /* todo: check */
    }

#ifdef HAVE_FDATASYNC
  fdatasync(file);
#else

#ifdef F_FULLFSYNC
  fcntl(file, F_FULLFSYNC, 1); /* ignore failure, since it's only a nice-to-have */
#endif

  fsync(file);
#endif	/* HAVE_FDATASYNC */

  if(lseek(file, 0, SEEK_SET) != 0)
    {
      perror("could not seek");
      exit(EXIT_FAILURE);
    }
}

static void overwrite_random(int num_passes)
{
  int i;

  for (i = 0; i < num_passes; i++) {
    randomize_buffer(buffer, buffsize);
    overwrite();
  }
}

static void overwrite_byte(int byte)
{
  assert(buffer);
  memset(buffer, byte, buffsize);
  overwrite();
}

static void overwrite_bytes(int byte1, int byte2, int byte3)
{
  unsigned i;
  assert(buffer);

  memset(buffer, byte1, buffsize);
  for (i = 1; i < buffsize; i += 3) {
    buffer[i] = byte2;
    if(i+1 < buffsize)
      buffer[i+1] = byte3;
  }
  overwrite();
}

static void overwrite_selector(const int sunlink_mode)
{
  if(sunlink_mode & SUNLINK_MODE_DOD)
    {
      overwrite_byte(0xF6);
      overwrite_byte(0x00);
      overwrite_byte(0xFF);
      overwrite_random(1);
      overwrite_byte(0x00);
      overwrite_byte(0xFF);
      overwrite_random(1);
      return;
    }
  if(sunlink_mode & SUNLINK_MODE_DOE)
    {
      overwrite_random(2);
      overwrite_bytes('D', 'o', 'E');
      return;
    }
  if(sunlink_mode & SUNLINK_MODE_OPENBSD)
    {
      overwrite_byte(0xFF);
      overwrite_byte(0x00);
      overwrite_byte(0xFF);
      return;
    }
  if(sunlink_mode & SUNLINK_MODE_SIMPLE)
    {
      overwrite_byte(0x00);
      return;
    }

  /* default case */
  overwrite_random(4);
  overwrite_byte(0x55);
  overwrite_byte(0xAA);
  overwrite_bytes(0x92, 0x49, 0x24);
  overwrite_bytes(0x49, 0x24, 0x92);
  overwrite_bytes(0x24, 0x92, 0x49);
  overwrite_byte(0x00);
  overwrite_byte(0x11);
  overwrite_byte(0x22);
  overwrite_byte(0x33);
  overwrite_byte(0x44);
  overwrite_byte(0x55);
  overwrite_byte(0x66);
  overwrite_byte(0x77);
  overwrite_byte(0x88);
  overwrite_byte(0x99);
  overwrite_byte(0xAA);
  overwrite_byte(0xBB);
  overwrite_byte(0xCC);
  overwrite_byte(0xDD);
  overwrite_byte(0xEE);
  overwrite_byte(0xFF);
  overwrite_bytes(0x92, 0x49, 0x24);
  overwrite_bytes(0x49, 0x24, 0x92);
  overwrite_bytes(0x24, 0x92, 0x49);
  overwrite_bytes(0x6D, 0xB6, 0xDB);
  overwrite_bytes(0xB6, 0xDB, 0x6D);
  overwrite_bytes(0xDB, 0x6D, 0xB6);
  overwrite_random(4);
  overwrite_byte(0x00);		/* if you want to backup your partition or shrink your vmware image having the file zero-ed gives best compression results. */
}

int sunlink(const char *path, const int sunlink_mode) {
  struct stat statbuf;
#ifdef __unix__
  struct flock flock;
#endif

  assert(path);

  if (lstat(path, &statbuf) < 0) 
    return -1;

  file_size = statbuf.st_size;
#ifdef __unix__
  buffsize = statbuf.st_blksize;
#else
  buffsize = 4096;
#endif

  if (!S_ISREG(statbuf.st_mode) || file_size==0)
    return rename_unlink(path);

  if (statbuf.st_nlink > 1) {
    rename_unlink(path);
    errno = EMLINK;
    return -1;
  }

  if ( (buffer = (unsigned char *)alloca(buffsize)) == NULL ) {
    errno = ENOMEM;
    return -1;
  }
  
  if ( (file = open(path, O_WRONLY)) < 0) /* BSD doesn't support O_SYNC */
    return -1;

#ifdef __unix__
  if (fcntl(file, F_WRLCK, &flock) < 0) {
    close(file);
    file=-1;
    return -1;
  }
#endif

#if defined(HAVE_LINUX_EXT2_FS_H) || defined(HAVE_LINUX_EXT3_FS_H)
  {
    struct statfs fs_stats;
    if (fstatfs(file, &fs_stats) < 0 && errno != ENOSYS)
      {
	close(file);
	file=-1;
	return -1;
      }

    if (fs_stats.f_type == EXT2_SUPER_MAGIC ) /* EXT2_SUPER_MAGIC and EXT3_SUPER_MAGIC are the same */
      {
	int flags = 0;

	  if (ioctl(file, EXT2_IOC_GETFLAGS, &flags) < 0)
	    {
	      close(file);
	      file=-1;
	      return -1;
	    }

	  if ( (flags & EXT2_UNRM_FL) ||
	       (flags & EXT2_IMMUTABLE_FL) ||
	       (flags & EXT2_APPEND_FL) )
	    {
	      close(file);
	      file=-1;
	      errno = EPERM;
	      return -1;
	    }

#ifdef HAVE_LINUX_EXT3_FS_H
	  /* if we have the required capabilities we can disable data journaling on ext3 */
	  if(fs_stats.f_type == EXT3_SUPER_MAGIC) /* superflous check again, just to make it clear again */
	    {
	      flags &= ~EXT3_JOURNAL_DATA_FL;
	      ioctl(file, EXT3_IOC_SETFLAGS, flags);
	    }
#endif
	}
  }
#endif /* HAVE_LINUX_EXT2_FS_H */

/* chflags(2) turns out to be a different system call in every BSD
   derivative. The important thing is to make sure we'll be able to
   unlink it after we're through messing around. Unlinking it first
   would remove the need for any of these checks, but would leave the
   user with no way to overwrite the file if the process was
   interupted during the overwriting. So, instead we assume that the
   open() above will fail on immutable and append-only files and try
   and catch only platforms supporting NOUNLINK here.

   OpenBSD - doesn't support nounlink (As of 3.1)
   FreeBSD - supports nounlink (from 4.4 on?)
   Tru64   - unknown
   MacOS X - doesn't support NOUNLINK (as of 10.3.5)
*/

#if defined(HAVE_CHFLAGS) && defined(__FreeBSD__)
  if ((statbuf.st_flags & UF_IMMUTABLE) || 
      (statbuf.st_flags & UF_APPEND) ||
      (statbuf.st_flags & UF_NOUNLINK) || 
      (statbuf.st_flags & SF_IMMUTABLE) ||
      (statbuf.st_flags & SF_APPEND) ||
      (statbuf.st_flags & SF_NOUNLINK)) 
    {
      close(file);
      file=-1;
      errno = EPERM;
      return -1;
    }
#endif /* HAVE_CHFLAGS */

  overwrite_selector(sunlink_mode);

#if defined(HAVE_LINUX_EXT2_FS_H) || defined(HAVE_LINUX_EXT3_FS_H)
  ioctl(file, EXT2_IOC_SETFLAGS, EXT2_SECRM_FL);
#endif

  if (ftruncate(file, 0) < 0) {
    close(file);
    file=-1;
    return -1;
  }

  close(file);
  file=-1;

#ifdef __APPLE__
  /* Also overwrite the file's resource fork, if present. */
  {
    static const char *RSRCFORKSPEC = "/..namedfork/rsrc";
    size_t rsrc_fork_size;
    size_t rsrc_path_size = strlen(path) + strlen(RSRCFORKSPEC) + 1;
    char *rsrc_path = (char *)alloca(rsrc_path_size);
    if (rsrc_path == NULL)
      {
	errno = ENOMEM;
	goto rsrc_fork_failed;
      }

    if (snprintf(rsrc_path, MAXPATHLEN, "%s%s", path, RSRCFORKSPEC ) > MAXPATHLEN - 1)
      {
	errno = ENAMETOOLONG;
	goto rsrc_fork_failed;
      }

    if (lstat(rsrc_path, &statbuf) != 0)
      {
	if (errno == ENOENT || errno == ENOTDIR)
	  rsrc_fork_size = 0;
	else
	  goto rsrc_fork_failed;
      }
    else
      rsrc_fork_size = statbuf.st_size;

    if (rsrc_fork_size > 0)
      {
	file_size = rsrc_fork_size;

	if ((file = open(rsrc_path, O_WRONLY)) < 0)
	  goto rsrc_fork_failed;

	if (fcntl(file, F_WRLCK, &flock) == -1)
	  {
	    close(file);
	    file=-1;
	    goto rsrc_fork_failed;
	  }

	if (options & OPT_V)
	  printf("removing %s\n", rsrc_path);

	overwrite_selector(sunlink_mode);

	ftruncate(file, 0);
	close(file);
	file=-1;
	goto rsrc_fork_done;
      }

  rsrc_fork_failed:
    if (options & OPT_V)
      printf("could not access ressource fork %s: %s\n", rsrc_path, strerror(errno));

  rsrc_fork_done: ;
  }
#endif /* __APPLE__ */
  
  return rename_unlink(path);
}
