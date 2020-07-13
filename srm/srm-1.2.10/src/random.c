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

  if (lstat("/dev/urandom", &statbuf) == 0 && S_ISCHR(statbuf.st_mode)) {
    urand_file = open("/dev/urandom", O_RDONLY);
  } else {
    srand(seed);
  }
}

unsigned char random_char(void) {
  if (urand_file >= 0) {
    unsigned char c;
    read(urand_file, &c, 1);
    return c;
  }
  return rand()&0xFF;
}

int randomize_buffer(unsigned char *buffer, int length) {
  int i;

  if (urand_file >= 0) {
    return read(urand_file, buffer, length);
  }

  for (i = 0; i < length; i++)
    buffer[i] = rand();

  return length;
}
