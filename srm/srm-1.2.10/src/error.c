/* this file is part of srm http://srm.sourceforge.net/
   It is licensed under the MIT/X11 license */

#include "config.h"

#include <stdarg.h>
#include <stdio.h>
#include <unistd.h>

#include "srm.h"

void error(char *msg, ...) {
  va_list ap;
  char buff[100];

  va_start(ap, msg);
  vsnprintf(buff, 100, msg, ap);
  fprintf(stderr, "%s: %s\n", program_name, buff);
  va_end(ap);
 }

void errorp(char *msg, ...) {
  va_list ap;
  char buff[100], buff2[120];
  
  va_start(ap, msg);
  vsnprintf(buff, 100, msg, ap);
  snprintf(buff2, 120, "%s: %s", program_name, buff);
  perror(buff2);
  va_end(ap);
}
