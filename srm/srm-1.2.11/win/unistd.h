#ifndef UNISTD__H
#define UNISTD__H

#include <sys/types.h>
#include <sys/stat.h>
#include <io.h>
#include <malloc.h>
#include <direct.h>
#include <process.h>

#pragma warning (disable: 4996 4244)

#define S_IRUSR _S_IREAD
#define S_IWUSR _S_IWRITE

#define snprintf _snprintf

typedef _W64 signed int ssize_t;

/* we define all fake functions for windows compilation here */

_inline int getpid() { return _getpid(); }

#define stat _stat
_inline int lstat(const char *path, struct stat *statbuf) { return _stat(path, statbuf); }

_inline int sync() { return 0; }

_inline int S_ISDIR(int i) { return i&_S_IFDIR; }
_inline int S_ISCHR(int i) { return i&_S_IFCHR; }
_inline int S_ISREG(int i) { return i&_S_IFREG; }

_inline int fsync(int fd) { return _commit(fd); }
_inline int ftruncate(int fd, off_t o) { return _chsize(fd, o); }

#endif
