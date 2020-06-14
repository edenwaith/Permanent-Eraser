/*******************************************************************
 *
 *  Copyright (c) 1994-2008 Jetico, Inc., Finland
 *  All rights reserved.
 *
 *  File:         sha1random.c
 *
 *  Description:  implementation of random generator based on SHA-1 
 *                Secure Hash Algorithm 
 *
 *  Revision:     $Id: sha1random.c 223 2009-03-30 05:20:36Z nail $
 *
 *  Created:	  24-May-2001
 *
 *******************************************************************/

#include "config.h"
#include "sha1random.h"
#include "sha1.h"
#include <stdlib.h>
#include <memory.h>

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

typedef struct _SHA1RandomData SHA1RandomData;

struct _SHA1RandomData
{
    void *SHACtx;       /* SHA1 hash generator used */
    byte *state;        /* Current state buffer */
    size_t stateLength; /* Usually equals to SHA1_DIGEST_SIZE */
    byte *pool;     /* Buffer for random data generated from state by SHACtx*/
    size_t poolLength;  /* Usually equals to SHA1_DIGEST_SIZE */

    size_t residue;     /* Quantity of unused bytes */
};

static void SHA1RandomReGenerate(void *sRandom);

enum { NO_ERROR = 0, MALLOC_ERROR };

int SHA1RandomAllocate(void **sRandom)
{
    void **SHA_ctx;
    SHA1RandomData *sha1Data;
    int result;

    /* Allocate memory for the rng's structure. */
    sha1Data = (SHA1RandomData *) malloc(sizeof (SHA1RandomData));
    if ( sha1Data == NULL )
        return MALLOC_ERROR;

    /* Allocate memory for the rng's pool of random bytes. */
    sha1Data->pool = (byte *)malloc(SHA1_DIGEST_SIZE);
    if (sha1Data->pool == NULL ) {
        free(sha1Data);
        return MALLOC_ERROR;
    }
    sha1Data->poolLength = SHA1_DIGEST_SIZE;

    /* Allocate memory for rng's state in rng specific data. */
    sha1Data->state = (byte *)malloc(SHA1_DIGEST_SIZE);
    if (sha1Data->state == NULL ) {
        free(sha1Data->pool);
        free(sha1Data);
        return MALLOC_ERROR;
    }
    sha1Data->stateLength=SHA1_DIGEST_SIZE;

    /* Allocate the rng's hash algorithm context. */
    SHA_ctx=&(sha1Data->SHACtx);
    if ((result=SHA1Allocate(SHA_ctx))!=NO_ERROR) {
        free(sha1Data->state);
        free(sha1Data->pool);
        free(sha1Data);
        return result;
    }

    *sRandom = sha1Data;

    return NO_ERROR;
}

int SHA1RandomInitialize( void *sRandom )
{
    SHA1RandomData *sha1Data = (SHA1RandomData *)sRandom;

    memset(sha1Data->pool, 0, sha1Data->poolLength);
    memset(sha1Data->state, 0, sha1Data->stateLength);
    sha1Data->residue=0;

    return NO_ERROR;
}

int SHA1RandomFinalize(void *sRandom)
{
    SHA1RandomData *sha1Data = (SHA1RandomData *)sRandom;

    memset(sha1Data->pool, 0, sha1Data->poolLength);
    memset(sha1Data->state, 0, sha1Data->stateLength);
    sha1Data->residue=0;

    return NO_ERROR;
}

int SHA1RandomFree(void **sRandom)
{
    SHA1RandomData *sha1Data = (SHA1RandomData *)(*sRandom);

    SHA1Free(&(sha1Data->SHACtx));
    free(sha1Data->state);
    free(sha1Data->pool);
    free(sha1Data);

    return NO_ERROR;
}

/**
 * Randomizes the random number pool using SHA1 hashing algorithm.
 * The function can by called many times.
 * Digest of seed data will accumulated in sha1Data->state.
 */
int SHA1RandomRandomize(void *sRandom, byte *seed, size_t seedLength)
{
    size_t x,i;

    SHA1RandomData *sha1Data = (SHA1RandomData *)sRandom;

    void *SHA_ctx = sha1Data->SHACtx;

    SHA1Init(SHA_ctx, 0, 0); 
    SHA1Process(SHA_ctx, seed, seedLength);
    SHA1Final(SHA_ctx,  sha1Data->pool);

    /* add digest to state */
    for (i = sha1Data->stateLength, x = 0; i-- ; )
    {   x += sha1Data->state[i] + sha1Data->pool[i];
        sha1Data->state[i] = (byte)x;
        x >>= 8;
    }

    memset(sha1Data->pool, 0, sha1Data->poolLength);
    sha1Data->residue = 0;

    return NO_ERROR;
}

int SHA1RandomGetRandomBytes(void *sRandom, byte *buffer, size_t bufferSize)
{
    SHA1RandomData *sha1Data = (SHA1RandomData *)sRandom;

    while (bufferSize > sha1Data->residue)
    {
        memcpy(
            buffer ,
            &(sha1Data->pool[sha1Data->poolLength - sha1Data->residue]),
            sha1Data->residue );

        bufferSize -= sha1Data->residue;
        buffer += sha1Data->residue;

        SHA1RandomReGenerate(sRandom);
    }
    
    memcpy(
        buffer,
        &(sha1Data->pool[sha1Data->poolLength - sha1Data->residue]),
        bufferSize);

    sha1Data->residue -= bufferSize;

    return NO_ERROR;
}


static void SHA1RandomReGenerate(void *sRandom)
{
    SHA1RandomData *sha1Data = (SHA1RandomData *)sRandom;
    void *SHA_ctx=sha1Data->SHACtx;
    int i;

    /* Generate new data */
    SHA1Init(SHA_ctx, 0, 0); 
    SHA1Process(SHA_ctx, sha1Data->state, sha1Data->stateLength);

    /* FinalDigest array must be >= 20 bytes */
    SHA1Final(SHA_ctx, sha1Data->pool);

    /* Increment current state */
    for (i = sha1Data->stateLength ; i-- ; )
        if (sha1Data->state[i]++)
            break;

    sha1Data->residue = sha1Data->poolLength;
}

/*************************************************************************************\
*   Function : SHA1RandomGenerate
*       High level function.
*       Allocate and initialize SHA1 random generator;
*       Set seed by seedBuffer;
*       Generate random sequence of bytes to buffer;
*       Free SHA1 random generator.
*   Params:
*       byte    *byteBuffer ,   - destination buffer for random generation.
*       size_t  byteBufferSize, - size of destnation buffer in bytes.
*       byte    *seedBuffer ,   - seed byte stream to initaialize prime random generator.
*       size_t  seedBufferSize  - size of seedBuffer in bytes.
*  Return value :
*       Return NO_ERROR if successful.
\*************************************************************************************/

int  SHA1RandomGenerate ( byte *byteBuffer ,size_t byteBufferSize ,byte *seedBuffer ,size_t seedBufferSize )
{
    void *sRandom;
    int result; 

    result = SHA1RandomAllocate( &sRandom );
    if ( result != NO_ERROR )
        return result;

    result = SHA1RandomInitialize( sRandom );

    if ( result == NO_ERROR )
        result = SHA1RandomRandomize( sRandom, seedBuffer, seedBufferSize );

    if ( result == NO_ERROR )
        result = SHA1RandomGetRandomBytes( sRandom, byteBuffer, byteBufferSize );
    
    if ( result == NO_ERROR )
        result = SHA1RandomFinalize( sRandom );

    SHA1RandomFree( &sRandom );

    return result;
}

char sha1random_c[]="$Id: sha1random.c 223 2009-03-30 05:20:36Z nail $";
