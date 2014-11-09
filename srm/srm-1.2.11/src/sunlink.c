/* this file is part of srm http://srm.sourceforge.net/
   It is licensed under the MIT/X11 license */

#include "config.h"

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
#include <stdint.h>
#endif

#ifdef HAVE_SYS_VFS_H
#include <sys/vfs.h>
#endif

#if defined(__APPLE__)
#include <sys/disk.h>
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
#ifndef EXT2_SUPER_MAGIC
#define EXT2_SUPER_MAGIC EXT3_SUPER_MAGIC
#endif

#elif defined(HAVE_LINUX_EXT2_FS_H)
#include <linux/fs.h>
#include <linux/ext2_fs.h>
#endif

#include "srm.h"
#include "impl.h"

#ifndef O_SYNC
#define O_SYNC 0
#endif

#define NO_UNLINK 0

#define KiB 1024
#define MiB (KiB*KiB)
#define GiB (KiB*KiB*KiB)

struct srm_target
{
  int fd;
  const char* file_name;
  off_t file_size;
  unsigned char *buffer;
  unsigned buffer_size;
  int options;
};

static volatile int SIGINT_received = 0;
#if defined(__unix__)
#include <signal.h>
#if defined(__linux__) && !defined(__USE_GNU)
typedef __sighandler_t sighandler_t;
#endif
#if defined(__FreeBSD__) || defined(__OpenBSD__)
typedef sig_t sighandler_t;
#endif

static void sigint_handler(int signo)
{
  SIGINT_received = signo;
}
int sunlink_impl(const char *path, const int options);

int sunlink(const char *path, const int options)
{
#ifdef SIGUSR2
  sighandler_t usr2=signal(SIGUSR2, sigint_handler);
#endif
#ifdef SIGINFO
  sighandler_t info=signal(SIGINFO, sigint_handler);
#endif
#ifdef SIGPIPE
  sighandler_t pipe=signal(SIGPIPE, SIG_IGN);
#endif

  int ret=sunlink_impl(path, options);

#ifdef SIGPIPE
  signal(SIGPIPE, pipe);
#endif
#ifdef SIGINFO
  signal(SIGINFO, info);
#endif
#ifdef SIGUSR2
  signal(SIGUSR2, usr2);
#endif
  return ret;
}

#else /* __unix__ */
#define sunlink_impl sunlink
#endif

/**
   writes a buffer to a file descriptor. Ensures that the complete
   buffer is written.

   ripped from Advanced Programming in the Unix Environment by Richard Stevens

   @param fd file descriptor
   @param buf pointer to a buffer
   @param count size of buf in bytes

   @return upon success the number of bytes written, upon error the negative return code from write() (see the errno variable for details)
*/
static ssize_t writen(const int fd, const void* buf, const size_t count)
{
  const char *ptr=(const char*)buf;
  size_t nleft=count;

  if(fd<0 || !buf) return -1;

  while(nleft > 0)
    {
      ssize_t nwritten;
      if( (nwritten=write(fd, ptr, nleft)) < 0)
	return nwritten;
      nleft -= nwritten;
      ptr   += nwritten;
    }

  return count;
}

static void flush(int fd)
{
  /* force buffered writes to be flushed to disk */
#if defined F_FULLFSYNC
  /* F_FULLFSYNC is equivalent to fsync plus device flush to media */
  if (fcntl(fd, F_FULLFSYNC, NULL) != 0) {
    /* we're not on a fs that supports this; fall back to plain fsync */
    fsync(fd);
  }
#elif HAVE_FDATASYNC
  fdatasync(fd);
#else
  fsync(fd);
#endif
}

static int overwrite(struct srm_target *srm, const int pass)
{
  off_t i = 0;
  ssize_t w;

  if(!srm) return -1;
  if(!srm->buffer) return -1;
  if(srm->buffer_size < 1) return -1;

  if(lseek(srm->fd, 0, SEEK_SET) != 0)
    {
      perror("could not seek");
      return -1;
    }

  if(srm->file_size < (off_t)(srm->buffer_size))
    {
      w=writen(srm->fd, srm->buffer, srm->file_size);
      if(w != srm->file_size)
	return -1;
    }
  else
    {
      while (i < srm->file_size - (off_t)srm->buffer_size)
	{
	  w=writen(srm->fd, srm->buffer, srm->buffer_size);
	  if(w != (ssize_t)(srm->buffer_size))
	    return -1;
	  i += w;

	  if((srm->options & SRM_OPT_V) > 1 || SIGINT_received)
	    {
	      if(srm->file_size < MiB)
		printf("\rpass %i %uKiB/%uKiB   ", pass, (unsigned)(i/KiB), (unsigned)(srm->file_size/KiB));
	      else if(srm->file_size < GiB)
		printf("\rpass %i %uMiB/%uMiB   ", pass, (unsigned)(i/MiB), (unsigned)(srm->file_size/MiB));
	      else
		printf("\rpass %i %uGiB/%uGiB   ", pass, (unsigned)(i/GiB), (unsigned)(srm->file_size/GiB));

	      if(SIGINT_received)
		{
		  if(srm->file_name)
		    printf("%s\n", srm->file_name);
		  else
		    putchar('\n');
		  SIGINT_received=0;
		}
	      fflush(stdout);
	    }
	}
      w=writen(srm->fd, srm->buffer, srm->file_size - i);
      if(w != srm->file_size-i)
	return -1;
    }

  if((srm->options & SRM_OPT_V) > 1)
    {
      printf("\rpass %i sync                        ", pass);
      fflush(stdout);
    }

  flush(srm->fd);

  if(lseek(srm->fd, 0, SEEK_SET) != 0)
    {
      perror("could not seek");
      return -1;
    }

  return 0;
}

static int overwrite_random(struct srm_target *srm, const int pass, const int num_passes)
{
  int i;

  if(!srm) return -1;
  if(!srm->buffer) return -1;
  if(srm->buffer_size < 1) return -1;

  for (i = 0; i < num_passes; i++)
    {
      randomize_buffer(srm->buffer, srm->buffer_size);
      if(overwrite(srm, pass+i) < 0)
	return -1;
    }

  return 0;
}

static int overwrite_byte(struct srm_target *srm, const int pass, const int byte)
{
  if(!srm) return -1;
  if(!srm->buffer) return -1;
  if(srm->buffer_size < 1) return -1;
  memset(srm->buffer, byte, srm->buffer_size);
  return overwrite(srm, pass);
}

static int overwrite_bytes(struct srm_target *srm, const int pass, const unsigned char byte1, const unsigned char byte2, const unsigned char byte3)
{
  unsigned i;
  if(!srm) return -1;
  if(!srm->buffer) return -1;
  if(srm->buffer_size < 1) return -1;

  memset(srm->buffer, byte1, srm->buffer_size);
  for (i = 1; i < srm->buffer_size; i += 3) {
    srm->buffer[i] = byte2;
    if(i+1 < srm->buffer_size)
      srm->buffer[i+1] = byte3;
  }
  return overwrite(srm, pass);
}

static int overwrite_selector(struct srm_target *srm)
{
  if(!srm) return -1;

#if defined(F_NOCACHE)
  /* before performing file I/O, set F_NOCACHE to prevent caching */
  (void)fcntl(srm->fd, F_NOCACHE, 1);
#endif

  if( (srm->buffer = (unsigned char *)alloca(srm->buffer_size)) == NULL )
    {
      errno = ENOMEM;
      return -1;
    }

  if(srm->options & SRM_MODE_DOD)
    {
      if((srm->options&SRM_OPT_V) == SRM_OPT_V)
	printf("US DoD mode\n");
      if(overwrite_byte(srm, 1, 0xF6) < 0) return -1;
      if(overwrite_byte(srm, 2, 0x00) < 0) return -1;
      if(overwrite_byte(srm, 3, 0xFF) < 0) return -1;
      if(overwrite_random(srm, 4, 1) < 0) return -1;
      if(overwrite_byte(srm, 5, 0x00) < 0) return -1;
      if(overwrite_byte(srm, 6, 0xFF) < 0) return -1;
      if(overwrite_random(srm, 7, 1) < 0) return -1;
    }
  else if(srm->options & SRM_MODE_DOE)
    {
      if((srm->options&SRM_OPT_V) == SRM_OPT_V)
	printf("US DoE mode\n");
      if(overwrite_random(srm, 1, 2) < 0) return -1;
      if(overwrite_bytes(srm, 3, 'D', 'o', 'E') < 0) return -1;
    }
  else if(srm->options & SRM_MODE_OPENBSD)
    {
      if((srm->options&SRM_OPT_V) == SRM_OPT_V)
	printf("OpenBSD mode\n");
      if(overwrite_byte(srm, 1, 0xFF) < 0) return -1;
      if(overwrite_byte(srm, 2, 0x00) < 0) return -1;
      if(overwrite_byte(srm, 3, 0xFF) < 0) return -1;
    }
  else if(srm->options & SRM_MODE_SIMPLE)
    {
      if((srm->options&SRM_OPT_V) == SRM_OPT_V)
	printf("Simple mode\n");
      if(overwrite_byte(srm, 1, 0x00) < 0) return -1;
    }
  else
    {
      if((srm->options&SRM_OPT_V) == SRM_OPT_V)
	printf("Full mode\n");
      if(overwrite_random(srm, 1, 4) < 0) return -1;
      if(overwrite_byte(srm, 5, 0x55) < 0) return -1;
      if(overwrite_byte(srm, 6, 0xAA) < 0) return -1;
      if(overwrite_bytes(srm, 7, 0x92, 0x49, 0x24) < 0) return -1;
      if(overwrite_bytes(srm, 8, 0x49, 0x24, 0x92) < 0) return -1;
      if(overwrite_bytes(srm, 9, 0x24, 0x92, 0x49) < 0) return -1;
      if(overwrite_byte(srm, 10, 0x00) < 0) return -1;
      if(overwrite_byte(srm, 11, 0x11) < 0) return -1;
      if(overwrite_byte(srm, 12, 0x22) < 0) return -1;
      if(overwrite_byte(srm, 13, 0x33) < 0) return -1;
      if(overwrite_byte(srm, 14, 0x44) < 0) return -1;
      if(overwrite_byte(srm, 15, 0x55) < 0) return -1;
      if(overwrite_byte(srm, 16, 0x66) < 0) return -1;
      if(overwrite_byte(srm, 17, 0x77) < 0) return -1;
      if(overwrite_byte(srm, 18, 0x88) < 0) return -1;
      if(overwrite_byte(srm, 19, 0x99) < 0) return -1;
      if(overwrite_byte(srm, 20, 0xAA) < 0) return -1;
      if(overwrite_byte(srm, 21, 0xBB) < 0) return -1;
      if(overwrite_byte(srm, 22, 0xCC) < 0) return -1;
      if(overwrite_byte(srm, 23, 0xDD) < 0) return -1;
      if(overwrite_byte(srm, 24, 0xEE) < 0) return -1;
      if(overwrite_byte(srm, 25, 0xFF) < 0) return -1;
      if(overwrite_bytes(srm, 26, 0x92, 0x49, 0x24) < 0) return -1;
      if(overwrite_bytes(srm, 27, 0x49, 0x24, 0x92) < 0) return -1;
      if(overwrite_bytes(srm, 28, 0x24, 0x92, 0x49) < 0) return -1;
      if(overwrite_bytes(srm, 29, 0x6D, 0xB6, 0xDB) < 0) return -1;
      if(overwrite_bytes(srm, 30, 0xB6, 0xDB, 0x6D) < 0) return -1;
      if(overwrite_bytes(srm, 31, 0xDB, 0x6D, 0xB6) < 0) return -1;
      if(overwrite_random(srm, 32, 4) < 0) return -1;
      /* if you want to backup your partition or shrink your vmware image having the file zero-ed gives best compression results. */
      if(overwrite_byte(srm, 36, 0x00) < 0) return -1;
    }

  if((srm->options & SRM_OPT_V) > 1)
    printf("\n");

  return 0;
}

int sunlink_impl(const char *path, const int options)
{
  struct srm_target srm;
  struct stat statbuf;
#ifdef __unix__
  struct flock flock;
#endif

  /* check function arguments */
  if(!path) return -1;

  srm.file_name = path;
  srm.options = options;

  /* check if path exists */
  if (lstat(path, &statbuf) < 0)
    return -1;

  srm.file_size = statbuf.st_size;
#ifdef _MSC_VER
  srm.buffer_size = 4096;
#else
  srm.buffer_size = statbuf.st_blksize;
#endif
  if(srm.buffer_size < 16)
    srm.buffer_size = 512;
  if((srm.options & SRM_OPT_V) == SRM_OPT_V)
    printf("buffer_size=%u\n", srm.buffer_size);

#ifdef __linux__
  if(S_ISBLK(statbuf.st_mode))
    {
      int secsize=512;
      long blocks=0;
      uint64_t u=0, u_;

      if( (srm.fd = open(srm.file_name, O_WRONLY)) < 0)
	return -1;

      if(ioctl(srm.fd, BLKSSZGET, &secsize) < 0)
	{
	  perror("could not ioctl(BLKSSZGET)");
	  return 1;
	}
      if((options&SRM_OPT_V) == SRM_OPT_V)
	printf("sector size %i bytes\n", secsize);

      if(ioctl(srm.fd, BLKGETSIZE, &blocks) < 0)
	{
	  perror("could not ioctl(BLKGETSIZE)");
	  return 1;
	}
      if((options&SRM_OPT_V) == SRM_OPT_V)
	printf("BLKGETSIZE %i blocks\n", (int)blocks);

      if(ioctl(srm.fd, BLKGETSIZE64, &u) < 0)
	{
	  perror("could not ioctl(BLKGETSIZE64)");
	  return 1;
	}
      if((options&SRM_OPT_V) == SRM_OPT_V)
	printf("BLKGETSIZE64 %llu bytes\n", (unsigned long long)u);

      u_=((uint64_t)blocks)*secsize;
      if(u_ != u)
	printf("!Warning! sectorsize*blocks:%llu != bytes:%llu\n", u_, u);

      srm.file_size = u;
      srm.buffer_size = secsize;

      if(srm.file_size == 0)
	{
	  close(srm.fd);
	  if (srm.options & SRM_OPT_V)
	    fprintf(stderr, "could not determine block device %s filesize\n", srm.file_name);
	  errno = EIO;
	  return -1;
	}

      if((options&SRM_OPT_V) > 1)
	printf("block device %s size: %llu bytes\n", srm.file_name, (unsigned long long)u);

      if(overwrite_selector(&srm) < 0)
	{
	  int e=errno;
	  if (srm.options & SRM_OPT_V)
	    fprintf(stderr, "could not overwrite device %s: %s\n", srm.file_name, strerror(errno));
	  close(srm.fd);
	  errno=e;
	  return -1;
	}
      close(srm.fd);
      return 0;
    }
#endif

  if (!S_ISREG(statbuf.st_mode) || srm.file_size==0)
    return rename_unlink(srm.file_name);

  if (statbuf.st_nlink > 1) {
    rename_unlink(srm.file_name);
    errno = EMLINK;
    return -1;
  }

  if ( (srm.fd = open(srm.file_name, O_WRONLY|O_SYNC)) < 0)
    return -1;

#ifdef __unix__
  if (fcntl(srm.fd, F_WRLCK, &flock) < 0) {
    int e=errno;
    close(srm.fd);
    errno=e;
    return -1;
  }
#endif

#if defined(HAVE_SYS_VFS_H) || (defined(HAVE_SYS_PARAM_H) && defined(HAVE_SYS_MOUNT_H))
  {
    struct statfs fs_stats;
    if (fstatfs(srm.fd, &fs_stats) < 0 && errno != ENOSYS)
      {
	int e=errno;
	close(srm.fd);
	errno=e;
	return -1;
      }

#if defined(__linux__)
    srm.buffer_size = fs_stats.f_bsize;
#elif defined(__FreeBSD__) || defined(__APPLE__)
    srm.buffer_size = fs_stats.f_iosize;
#else
#error Please define your platform.
#endif
    if((srm.options & SRM_OPT_V) == SRM_OPT_V)
      printf("buffer_size=%u\n", srm.buffer_size);

#if defined(HAVE_LINUX_EXT2_FS_H) || defined(HAVE_LINUX_EXT3_FS_H)
    if (fs_stats.f_type == EXT2_SUPER_MAGIC ) /* EXT2_SUPER_MAGIC and EXT3_SUPER_MAGIC are the same */
      {
	int flags = 0;

	  if (ioctl(srm.fd, EXT2_IOC_GETFLAGS, &flags) < 0)
	    {
	      int e=errno;
	      close(srm.fd);
	      errno=e;
	      return -1;
	    }

	  if ( (flags & EXT2_UNRM_FL) ||
	       (flags & EXT2_IMMUTABLE_FL) ||
	       (flags & EXT2_APPEND_FL) )
	    {
	      close(srm.fd);
	      errno = EPERM;
	      return -1;
	    }

#ifdef HAVE_LINUX_EXT3_FS_H
	  /* if we have the required capabilities we can disable data journaling on ext3 */
	  if(fs_stats.f_type == EXT3_SUPER_MAGIC) /* superflous check again, just to make it clear again */
	    {
	      flags &= ~EXT3_JOURNAL_DATA_FL;
	      ioctl(srm.fd, EXT3_IOC_SETFLAGS, flags);
	    }
#endif
	}
#endif /* HAVE_LINUX_EXT2_FS_H */
  }
#endif /* HAVE_SYS_VFS_H */

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
      close(srm.fd);
      errno = EPERM;
      return -1;
    }
#endif /* HAVE_CHFLAGS */

  if(overwrite_selector(&srm) < 0)
    {
      int e=errno;
      if (srm.options & SRM_OPT_V)
	fprintf(stderr, "could not overwrite file %s: %s\n", srm.file_name, strerror(errno));
      close(srm.fd);
      errno=e;
      return -1;
    }

#if defined(HAVE_LINUX_EXT2_FS_H) || defined(HAVE_LINUX_EXT3_FS_H)
  ioctl(srm.fd, EXT2_IOC_SETFLAGS, EXT2_SECRM_FL);
#endif

#if !NO_UNLINK
  if (ftruncate(srm.fd, 0) < 0) {
    int e=errno;
    close(srm.fd);
    errno=e;
    return -1;
  }
#endif

  close(srm.fd);
  srm.fd = -1;

#ifdef __APPLE__
  /* Also overwrite the file's resource fork, if present. */
  {
#define RSRCFORKSPEC "/..namedfork/rsrc"
    struct srm_target rsrc;
    rsrc.buffer = srm.buffer;
    rsrc.buffer_size = srm.buffer_size;
    rsrc.file_name = (char *)alloca(strlen(srm.file_name) + sizeof(RSRCFORKSPEC) + 1);
    if (rsrc.file_name == NULL)
      {
	errno = ENOMEM;
	goto rsrc_fork_failed;
      }

    if (snprintf((char*)rsrc.file_name, MAXPATHLEN, RSRCFORKSPEC "%s", srm.file_name) > MAXPATHLEN - 1)
      {
	errno = ENAMETOOLONG;
	goto rsrc_fork_failed;
      }

    if (lstat(rsrc.file_name, &statbuf) != 0)
      {
	if (errno == ENOENT || errno == ENOTDIR)
	  rsrc.file_size = 0;
	else
	  goto rsrc_fork_failed;
      }
    else
      rsrc.file_size = statbuf.st_size;

    if (rsrc.file_size > 0)
      {
	if ((rsrc.fd = open(rsrc.file_name, O_WRONLY|O_SYNC)) < 0)
	  goto rsrc_fork_failed;

	if (fcntl(rsrc.fd, F_WRLCK, &flock) == -1)
	  {
	    close(rsrc.fd);
	    goto rsrc_fork_failed;
	  }

	if (rsrc.options & SRM_OPT_V)
	  printf("removing %s\n", rsrc.file_name);

	if(overwrite_selector(&rsrc) < 0)
	  {
	    if (rsrc.options & SRM_OPT_V)
	      fprintf(stderr, "could not overwrite ressource fork %s: %s\n", rsrc.file_name, strerror(errno));
	  }

	ftruncate(rsrc.fd, 0);
	close(rsrc.fd);
	goto rsrc_fork_done;
      }

  rsrc_fork_failed:
    if (rsrc.options & SRM_OPT_V)
      fprintf(stderr, "could not access ressource fork %s: %s\n", srm.file_name, strerror(errno));

  rsrc_fork_done: ;
  }
#endif /* __APPLE__ */

#if NO_UNLINK
  return 0;
#else
  return rename_unlink(srm.file_name);
#endif
}
