/* this file is part of srm http://srm.sourceforge.net/
   It is licensed under the MIT/X11 license */

#ifndef SRM__H
#define SRM__H

#define OPT_F (1 << 0)
#define OPT_I (1 << 1)
#define OPT_R (1 << 2)
#define OPT_V (1 << 3)

#define SUNLINK_MODE_SIMPLE (1 << 4)
#define SUNLINK_MODE_OPENBSD (1 << 5)
#define SUNLINK_MODE_DOD (1 << 6)
#define SUNLINK_MODE_DOE (1 << 7)

#ifndef FTS_F
#define FTS_F 11111
#endif
#ifndef FTS_SL
#define FTS_SL 22222
#endif
#ifndef FTS_SLNONE
#define FTS_SLNONE 22223
#endif
#ifndef FTS_D
#define FTS_D 33333
#endif
#ifndef FTS_DP
#define FTS_DP 44444
#endif
#ifndef FTS_DNR
#define FTS_DNR 55555
#endif
#ifndef FTS_NS
#define FTS_NS 66666
#endif

#if defined(__unix__) || defined(__APPLE__)
#define DIRSEP '/'
#elif defined(_WIN32)
#define DIRSEP '\\'
#else
#error no DIRSEP definition
#endif

#ifdef __cplusplus
extern "C" {
#endif

extern int options;
extern char *program_name;

void error(char *msg, ...);
void errorp(char *msg, ...);
int rename_unlink(const char*path);
int tree_walker(char ** trees);
int sunlink(const char * path, const int sunlink_mode);
void init_random(const unsigned int seed);
unsigned char random_char(void);
int randomize_buffer(unsigned char *buffer, int length);

#ifdef __cplusplus
}
#endif

#endif
