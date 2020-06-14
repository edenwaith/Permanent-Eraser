/* this file is part of srm http://srm.sourceforge.net/
   It is licensed under the MIT/X11 license */

#include "config.h"

#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "srm.h"

static int urand_file = -1;

void init_random(const unsigned int seed) {
  struct stat statbuf;

#ifdef HAVE_LRAND48
  srand48(seed);
#else
  srand(seed);
#endif

  if (lstat("/dev/urandom", &statbuf) == 0 && S_ISCHR(statbuf.st_mode))
    urand_file = open("/dev/urandom", O_RDONLY);
}

unsigned char random_char(void) {
  if (urand_file >= 0) {
    unsigned char c;
    if(read(urand_file, &c, 1) > 0)
      return c;
  }
#ifdef HAVE_LRAND48
  return lrand48() & 0xFF;
#else
  return rand() & 0xFF;
#endif
}

#ifdef _MSC_VER
// I don't know why, but Microsoft does not like our readn() function below
#define readn read
#else
/**
   reads from a file descriptor into a buffer. The function finishes
   when either count bytes have been read, the file descriptor reached
   the end-of-file or the file descriptor changed to an error state.

   ripped from Advanced Programming in the Unix Environment by Richard Stevens

   @param fd file descriptor
   @param buf pointer to a buffer
   @param count number of bytes to read into buf

   @return upon success the number of bytes read which may be less than count when end-of-file reached, upon error the negative return code from write() (see the errno variable for details)
 */
static ssize_t readn(int fd, void *buf, const size_t count)
{
  /*lint --e{1924}*/

  if(fd<0 || !buf) return -1;

  char *ptr=(char*)buf;
  size_t nleft=count;
  while(nleft > 0)
    {
      ssize_t nread;
      if( (nread=read(fd, ptr, nleft)) < 0)
	return nread;
      else if (nread == 0)
	break;			/* EOF */
      /*lint -e{737} ignore loss of sign*/
      nleft -= nread;
      ptr   += nread;
    }
  /*lint -e{713} ignore loss of precision*/
  return count - nleft;
}
#endif

int randomize_buffer(unsigned char *buffer, int length) {
  int i;

  if (urand_file >= 0) {
    return readn(urand_file, buffer, length);
  }

  for (i = 0; i < length; i++)
    buffer[i] = random_char();

  return length;
}
