/*******************************************************************
 *
 *  Copyright (c) 1994-2008 Jetico, Inc., Finland
 *  All rights reserved.
 *
 *  File:        sha1random.h
 *
 *  Description: declaration of random generator based on SHA-1 
 *               Secure Hash Algorithm 
 *
 *  Revision:   $Id: sha1random.h 193 2008-02-04 03:47:57Z pav $
 *
 *  Created:	24-May-2001
 *
 *******************************************************************/

#ifndef __SHA1RANDOM_H__
#define __SHA1RANDOM_H__

#include <stddef.h>
#include "sha1.h"

/**************************************************************************************\
 * Function:  SHA1RandomAllocate
 *  void **sRandom    pointer to internal structure of random generator;
 *
 * Return value:
 *  If successfull return NO_ERROR.
\**************************************************************************************/
int SHA1RandomAllocate(void **sRandom);

/**************************************************************************************\
 * Function:  SHA1RandomFree
 *  void **sRandom    pointer to internal structure of random generator;
 *
 * Return value:
 *  If successfull return NO_ERROR.
\**************************************************************************************/
int SHA1RandomFree(void **sRandom);


/*************************************************************************************\
*
* Function:  SHA1RandomInitialize
*   void *sRandom   - pointer to internal structure of random generator;
*
\*************************************************************************************/
int SHA1RandomInitialize( void *sRandom );


/*************************************************************************************\
*
* Function:  SHA1RandomUpdate
*   void *sRandom           - pointer to internal structure of random generator;
*   byte   *seedBuffer      - pointer to initialisation buffer;
*   size_t  seedBufferSize  - size of the initialization buffer;
*
* Description:
*  Use this function to initialize current random state by seedBuffer.
*  The seedBufferSize does not limited. State will always padded by SHA1 digest
*  algorithm.
*
\*************************************************************************************/
int SHA1RandomRandomize(void *sRandom,
                         byte *seedBuffer, size_t seedBufferSize);


/*************************************************************************************\
*
* Function: SHA1RandomGenerateBytes (
*   void *sRandom       - pointer to internal structure of random generator;
*   byte *buffer        - pointer to buffer for new generated random data
*   size_t bufferSize   - size in bytes of required random data
*
* Description:
*  sRandom structure must be initialized by SHA1RandomInit.
*  SHA1RandomGenerate function can by called numerous times.
\*************************************************************************************/
int SHA1RandomGetRandomBytes(
    void *sRandom,
    byte *buffer ,
    size_t bufferSize);


/*************************************************************************************\
*
* Function: SHA1RandomFinal (
*   void *sRandom       - pointer to void structure;
*
* Description:
*  secure zeroizes sRandom structure and deallocate it.
\*************************************************************************************/
int SHA1RandomFinalize(void *sRandom);

/*-------------------------------------------------------------
SHA1RandomGenerate high level generation function...
    return NO_ERROR (0) if successful
-------------------------------------------------------------*/
extern int SHA1RandomGenerate(byte *byteBuffer, size_t byteBufferSize, byte *seedBuffer, size_t seedBufferSize );

#endif /* __SHA1RANDOM_H__ */
