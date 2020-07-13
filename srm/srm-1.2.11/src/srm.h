/* this file is part of srm http://srm.sourceforge.net/
   It is licensed under the MIT/X11 license */

#ifndef SRM__H
#define SRM__H

/** the lower three bits of the option argument to sunlink() set the verbosity level. */
#define SRM_OPT_V 7
/** force unlink */
#define SRM_OPT_F (1 << 3)
/** interactive unlink, ask before handling a file */
#define SRM_OPT_I (1 << 4)
/** recursive */
#define SRM_OPT_R (1 << 5)
/** do not cross file system boundaries */
#define SRM_OPT_X (1 << 6)
/** simple overwrite mode */
#define SRM_MODE_SIMPLE (1 << 16)
/** OpenBSD overwrite mode */
#define SRM_MODE_OPENBSD (1 << 17)
/** US DoD overwrite mode */
#define SRM_MODE_DOD (1 << 18)
/** US DoE overwrite mode */
#define SRM_MODE_DOE (1 << 19)

#ifdef __cplusplus
extern "C" {
#endif

/** unlink a file/directory in a secure way.

    Before the file/directory is unlinked it's name is renamed to a
    random filename, so that the original name can not be
    reconstructed with special tools. This function does not overwrite
    the file contents before unlinking! Use sunlink() for that
    purpose.

    This function sets errno.

    @param path (absolute) path to file/directory
    @return 0 upon success, negative upon error
*/
int rename_unlink(const char *path);

/** unlink a file/directory in a secure way.

    This function will overwrite the file contents before unlinking
    the file. This prevents special tools from reconstructing the
    unlinked file.

    This function sets errno.

    @param path (absolute) path to file/directory
    @param options a combination of SRM_* flags

    @return 0 upon success, negative upon error
*/
int sunlink(const char *path, const int options);

#ifdef __cplusplus
}
#endif

#endif
