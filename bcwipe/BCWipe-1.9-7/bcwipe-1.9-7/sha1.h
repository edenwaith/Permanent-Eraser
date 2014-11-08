/*******************************************************************
 *
 *  Copyright (c) 1994-2008 Jetico, Inc., Finland
 *  All rights reserved.
 *
 *  File:        sha1.h
 *
 *  Description: declaration of SHA-1 Secure Hash Algorithm 
 *               external procedures
 *
 *  Revision:   $Id: sha1.h 193 2008-02-04 03:47:57Z pav $
 *
 *  Created:	24-May-2001
 *
 *******************************************************************/

/*
 *  SHA1 message-digest algorithm.
 */

#ifndef __SHA1_H__
#define __SHA1_H__

#define SHA1_DIGEST_SIZE        20

#define SHA1_ERROR_NO           0x0
#define SHA1_ERROR_INTERNAL_ERROR   0x1


typedef unsigned char byte;
typedef unsigned int  DWORD;

int SHA1Init(void   *context, 
             byte   *key, 
             size_t key_size);

int SHA1Process(void   *context, 
                byte   *data, 
                size_t length);

int SHA1Update(void *context, byte *data);

int SHA1Final(void *context, 
              byte *digest);

int SHA1Allocate(void **context);

int SHA1Free(void **context);

int SHA1MakeDigest( byte *message, int messageLength, byte *digest );


/* 
 * On the Intel processors Circular Shift Left operation 
 * (Rotation Left) may be done as one command for processor
 */

/* #define __INTEL_PLATFORM */

#ifdef __INTEL_PLATFORM
#  define ROL(X, n) _asm rol X, n
#else
#  define ROL( X, n )   ( ( ( X ) << n ) | ( ( X ) >> ( 32 - n ) ) )
#endif


#endif /* __SHA1_H__ */
