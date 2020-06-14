/* this file is part of srm http://srm.sourceforge.net/
   It is licensed under the MIT/X11 license */

#ifndef IMPL__H
#define IMPL__H

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
#define SRM_DIRSEP '/'
#elif defined(_WIN32)
#define SRM_DIRSEP '\\'
#else
#error no SRM_DIRSEP definition for your platform (yet)!
#endif

#ifdef __cplusplus
extern "C" {
#endif

extern char *program_name;
void error(char *msg, ...);
void errorp(char *msg, ...);
int process_file(char *path, const int flag, const int options);
int tree_walker(char ** trees, const int options);
void init_random(const unsigned int seed);
unsigned char random_char(void);
int randomize_buffer(unsigned char *buffer, int length);

#ifdef __cplusplus
}
#endif

#endif
