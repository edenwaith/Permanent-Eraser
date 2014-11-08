/*******************************************************************
 *
 *  Copyright (c) 1994-2008 Jetico, Inc., Finland
 *  All rights reserved.
 *
 *  File: sha1.c
 *
 *  Description: implementation of SHA-1 Secure Hash Algorithm
 *
 *  Revision:   $Id: sha1.c 223 2009-03-30 05:20:36Z nail $
 *
 *  Created:	24-May-2001
 *
 *******************************************************************/

#include "config.h"
#include <stddef.h>
#include <stdlib.h>
#include <stdlib.h>
#include <string.h>
#include "sha1.h"

/*
 * Originally SHA (Secure Hash Algorithm) description 
 * does not contain Circular Shift Left (on 1 bit) in 
 * W[t] = (W[t-3] ^ W[t-8] ^ W[t-14] ^ W[t-16]) <<< 1
 * 
 * Then, the Circular Shift Left operation appeared in 
 * the SHA description, and algorithm become known as 
 * SHA-1
 *
 */

/* The structure for storing SHA context */

typedef struct SHA1Context_
{    DWORD digest[5];        /* Message digest */
     DWORD countLo, countHi; /* 64-bit byte count */
     DWORD data[16];         /* SHA data buffer */
} SHA1Context;

/* Initial values */

#define A_init  0x67452301
#define B_init  0xefcdab89
#define C_init  0x98badcfe
#define D_init  0x10325476
#define E_init  0xc3d2e1f0

/* Kt constants */
#define K1  0x5a827999   /* For rounds  0-19 */
#define K2  0x6ed9eba1   /* For rounds 20-39 */
#define K3  0x8f1bbcdc   /* For rounds 40-59 */
#define K4  0xca62c1d6   /* For rounds 60-79 */

/* SHA's set of non-linear functions *
 * According to Rich Schroeppel: 
 *    (X & Y) | (~X & Z) == Z ^ (X & (Y ^ Z)) 
 * And obvious enough:
 *    (X & Y) | (X & Z) | (Y & Z) == (X & (Y | Z)) | (Y & Z)
 */

/* For step  0-19: round 0 */
#define f1(X,Y,Z)   ((Z) ^ ((X) & ((Y) ^ (Z))))         
/* For step 20-39: round 1 */
#define f2(X,Y,Z)   ((X) ^ (Y) ^ (Z))                   
/* For step 40-59: round 2 */
#define f3(X,Y,Z)   (((X) & ((Y) | (Z))) | ((Y) & (Z))) 
/* For step 60-79: round 3 */
#define f4(X,Y,Z)   ((X) ^ (Y) ^ (Z))                   

/* According to the SHA-1 description, the main SHA-1 loop uses 
  a, b, c, d, e numbers. Only a and c are changed on each step of 
  the loop. b, d, e are swapped between each other: 
  if F(a,b,c,d,e) = (a <<< 5) + ft(b,c,d) + e + Wt + Kt, then 

  a1 = F(a0,b0,c0,d0,e0)
  b1 = a0
  c1 = b0<<<30
  d1 = c0
  e1 = d0

  Hence, for first 3 steps we get:

  a1 = F(a0,b0,c0,d0,e0)
  a2 = F(a1,b1,c1,d1,e1) = F( F(a0,b0,c0,d0,e0), a0, b0<<<30, c0,      d0)
  a3 = F(a2,b2,c2,d2,e2) = F( F(a1,b1,c1,d1,e1), a1, a0<<<30, b0<<<30, c0)

  From one hand, in each step we need one Temporary local variable to 
  store the result of F(), from the other hand, we need e0 only on the 
  first step. Hence, we can use e0 as this variable. Then, if in 
  each step we will shift left b variable, the next step will look 
  simpler. The first 3 steps will look like:

  1: e0'  = F(a0 , b0, c0,  d0,  e0 ); b0'  = b0  <<< 30
  2: d0'  = F(e0', a0, b0', c0,  d0 ); a0'  = a0  <<< 30
  3: c0'  = F(d0', e0, a0', b0', c0 ); e0'' = e0' <<< 30 

  Hence, the first 3 rounds in SHA loop will look like:

  Round0( A, B, C, D, E) = { E = F(A,B,C,D,E); B = B << 30; }
  Round1( E, A, B, C, D) = { D = F(E,A,B,C,D); A = A << 30; }
  Round2( D, E, A, B, C) = { C = F(D,E,A,B,C); E = E << 30; }

  So, we can make the following #define :
*/

/* mask 0xffffffff is needed if our machine is 64-bits */

#define Round(A, B, C, D, E, f, W, K) (E) = ((ROL(A,5) + f((B),(C),(D)) + (E) + (W) + (K)) & 0xffffffff); (B) = (ROL(B,30))
 
/* Also, we need to calculate W for each from 80 rounds.
   For 1-st 16 rounds W0  ... W15 are just the 16 32-bits words of input 512-bit block.
   For 2-nd 16 rounds W16 ... W31 are calculated from W0  ... W15
   For 3-rd 16 rounds W32 ... W47 are calculated from W16 ... W31
   ... and so on

   Hence, we need only 16 32-bit locals for storing W array, and 
   re-calculate it after each 16 steps
 */

#define RECALCULATE( W )  W[0]  = ROL( (W[13] ^ W[8]  ^ W[2] ^  W[0]),  1 ) & 0xffffffff; W[1]  = ROL( (W[14] ^ W[9]  ^ W[3] ^  W[1]),  1 ) & 0xffffffff; W[2]  = ROL( (W[15] ^ W[10] ^ W[4] ^  W[2]),  1 ) & 0xffffffff; W[3]  = ROL( (W[0]  ^ W[11] ^ W[5] ^  W[3]),  1 ) & 0xffffffff; W[4]  = ROL( (W[1]  ^ W[12] ^ W[6] ^  W[4]),  1 ) & 0xffffffff; W[5]  = ROL( (W[2]  ^ W[13] ^ W[7] ^  W[5]),  1 ) & 0xffffffff; W[6]  = ROL( (W[3]  ^ W[14] ^ W[8] ^  W[6]),  1 ) & 0xffffffff; W[7]  = ROL( (W[4]  ^ W[15] ^ W[9] ^  W[7]),  1 ) & 0xffffffff; W[8]  = ROL( (W[5]  ^ W[0]  ^ W[10] ^ W[8]),  1 ) & 0xffffffff; W[9]  = ROL( (W[6]  ^ W[1]  ^ W[11] ^ W[9]),  1 ) & 0xffffffff; W[10] = ROL( (W[7]  ^ W[2]  ^ W[12] ^ W[10]), 1 ) & 0xffffffff; W[11] = ROL( (W[8]  ^ W[3]  ^ W[13] ^ W[11]), 1 ) & 0xffffffff; W[12] = ROL( (W[9]  ^ W[4]  ^ W[14] ^ W[12]), 1 ) & 0xffffffff; W[13] = ROL( (W[10] ^ W[5]  ^ W[15] ^ W[13]), 1 ) & 0xffffffff; W[14] = ROL( (W[11] ^ W[6]  ^ W[0] ^  W[14]), 1 ) & 0xffffffff; W[15] = ROL( (W[12] ^ W[7]  ^ W[1] ^  W[15]), 1 ) & 0xffffffff


static void SHA_UpdateDigest( DWORD *Digest, DWORD *MessageBlock )
 {
   DWORD a,b,c,d,e, W[16];
   int  i;

   a = Digest[0];
   b = Digest[1];
   c = Digest[2];
   d = Digest[3];
   e = Digest[4];

   for( i = 0; i < 16; i++ ) W[ i ] = MessageBlock[ i ];

   /* 0 - 15 steps */
   /* 1-ST ROUND BEGINS */
   Round( a,b,c,d,e, f1,W[0], K1 );
   Round( e,a,b,c,d, f1,W[1], K1 );
   Round( d,e,a,b,c, f1,W[2], K1 );
   Round( c,d,e,a,b, f1,W[3], K1 ); 
   Round( b,c,d,e,a, f1,W[4], K1 );
   Round( a,b,c,d,e, f1,W[5], K1 );
   Round( e,a,b,c,d, f1,W[6], K1 );
   Round( d,e,a,b,c, f1,W[7], K1 );
   Round( c,d,e,a,b, f1,W[8], K1 ); 
   Round( b,c,d,e,a, f1,W[9], K1 );
   Round( a,b,c,d,e, f1,W[10],K1 );
   Round( e,a,b,c,d, f1,W[11],K1 );
   Round( d,e,a,b,c, f1,W[12],K1 );
   Round( c,d,e,a,b, f1,W[13],K1 ); 
   Round( b,c,d,e,a, f1,W[14],K1 );
   Round( a,b,c,d,e, f1,W[15],K1 );

   RECALCULATE( W );

   /* 16 - 31 steps */
   Round( e,a,b,c,d, f1,W[0], K1 );
   Round( d,e,a,b,c, f1,W[1], K1 );
   Round( c,d,e,a,b, f1,W[2], K1 ); 
   Round( b,c,d,e,a, f1,W[3], K1 );
   /* 2-ND ROUND BEGINS */
   Round( a,b,c,d,e, f2,W[4], K2 );
   Round( e,a,b,c,d, f2,W[5], K2 );
   Round( d,e,a,b,c, f2,W[6], K2 );
   Round( c,d,e,a,b, f2,W[7], K2 ); 
   Round( b,c,d,e,a, f2,W[8], K2 );
   Round( a,b,c,d,e, f2,W[9], K2 );
   Round( e,a,b,c,d, f2,W[10],K2 );
   Round( d,e,a,b,c, f2,W[11],K2 );
   Round( c,d,e,a,b, f2,W[12],K2 ); 
   Round( b,c,d,e,a, f2,W[13],K2 );
   Round( a,b,c,d,e, f2,W[14],K2 );
   Round( e,a,b,c,d, f2,W[15],K2 );

   RECALCULATE( W );

   /* 32 - 47 steps */
   Round( d,e,a,b,c, f2,W[0], K2 );
   Round( c,d,e,a,b, f2,W[1], K2 ); 
   Round( b,c,d,e,a, f2,W[2], K2 );
   Round( a,b,c,d,e, f2,W[3], K2 );
   Round( e,a,b,c,d, f2,W[4], K2 );
   Round( d,e,a,b,c, f2,W[5], K2 );
   Round( c,d,e,a,b, f2,W[6], K2 ); 
   Round( b,c,d,e,a, f2,W[7], K2 );
   /* 3-RD ROUND BEGINS */
   Round( a,b,c,d,e, f3,W[8], K3 );
   Round( e,a,b,c,d, f3,W[9], K3 );
   Round( d,e,a,b,c, f3,W[10],K3 );
   Round( c,d,e,a,b, f3,W[11],K3 ); 
   Round( b,c,d,e,a, f3,W[12],K3 );
   Round( a,b,c,d,e, f3,W[13],K3 );
   Round( e,a,b,c,d, f3,W[14],K3 );
   Round( d,e,a,b,c, f3,W[15],K3 );

   RECALCULATE( W );

   /* 48 - 63 steps */
   Round( c,d,e,a,b, f3,W[0], K3 ); 
   Round( b,c,d,e,a, f3,W[1], K3 );
   Round( a,b,c,d,e, f3,W[2], K3 );
   Round( e,a,b,c,d, f3,W[3], K3 );
   Round( d,e,a,b,c, f3,W[4], K3 );
   Round( c,d,e,a,b, f3,W[5], K3 ); 
   Round( b,c,d,e,a, f3,W[6], K3 );
   Round( a,b,c,d,e, f3,W[7], K3 );
   Round( e,a,b,c,d, f3,W[8], K3 );
   Round( d,e,a,b,c, f3,W[9], K3 );
   Round( c,d,e,a,b, f3,W[10],K3 ); 
   Round( b,c,d,e,a, f3,W[11],K3 );
   /* 4-RD ROUND BEGINS */
   Round( a,b,c,d,e, f4,W[12],K4 );
   Round( e,a,b,c,d, f4,W[13],K4 );
   Round( d,e,a,b,c, f4,W[14],K4 );
   Round( c,d,e,a,b, f4,W[15],K4 ); 

   RECALCULATE( W );

   /* 64 - 79 steps */
   Round( b,c,d,e,a, f4,W[0], K4 );
   Round( a,b,c,d,e, f4,W[1], K4 );
   Round( e,a,b,c,d, f4,W[2], K4 );
   Round( d,e,a,b,c, f4,W[3], K4 );
   Round( c,d,e,a,b, f4,W[4], K4 ); 
   Round( b,c,d,e,a, f4,W[5], K4 );
   Round( a,b,c,d,e, f4,W[6], K4 );
   Round( e,a,b,c,d, f4,W[7], K4 );
   Round( d,e,a,b,c, f4,W[8], K4 );
   Round( c,d,e,a,b, f4,W[9], K4 ); 
   Round( b,c,d,e,a, f4,W[10],K4 );
   Round( a,b,c,d,e, f4,W[11],K4 );
   Round( e,a,b,c,d, f4,W[12],K4 );
   Round( d,e,a,b,c, f4,W[13],K4 );
   Round( c,d,e,a,b, f4,W[14],K4 ); 
   Round( b,c,d,e,a, f4,W[15],K4 );
   /* 4-RD ROUND FINISHED */

   /* Calculate new Message Digest */
   Digest[0] = (Digest[0] + a) & 0xffffffff;
   Digest[1] = (Digest[1] + b) & 0xffffffff;
   Digest[2] = (Digest[2] + c) & 0xffffffff;
   Digest[3] = (Digest[3] + d) & 0xffffffff;
   Digest[4] = (Digest[4] + e) & 0xffffffff;
 }


/************************************************************************
 *
 * Two useful functions: 
 * ReverseDWORD        - worries about Big and Little Endians
 * copyDigestToByteArray - may be, we want to copy digest from Context to 
 *                         independent byte array
 *************************************************************************/

static void copyDigestToByteArray(DWORD *dwInp, byte *bOut )
{ int i, j;

  for(i = 0, j = 0; j < 20; i++, j += 4) /* 20 - is the Digest length in bytes */
   { bOut[j+3] = (byte)( dwInp[i]        & 0xff);
     bOut[j+2] = (byte)((dwInp[i] >> 8)  & 0xff);
     bOut[j+1] = (byte)((dwInp[i] >> 16) & 0xff);
     bOut[j]   = (byte)((dwInp[i] >> 24) & 0xff);
   }
}

/* The function automatically defines if we are Big or Little Endian */
static void ReverseDWORD( DWORD *Data, int Length_DWORD )
{ int i;
  DWORD dwTmp;

  if((*(DWORD *)("ABCD") >> 24) == 'A') return; /* Nothing to do */

  for(i=0; i<Length_DWORD; i++)
  { dwTmp = (Data[i] << 16) | (Data[i] >> 16);
    Data[i] = ((dwTmp & 0xFF00FF00L) >> 8) | ((dwTmp & 0x00FF00FFL) << 8);
  }
}



/**********************************************************************
 * 
 * SHA1Init() initializes a context of the message digest calculations.
 * The memory to store the context is reserved before and the pointer 
 * on the context's memory stored in FSHashAlgorithm element 
 *
 **********************************************************************/

int SHA1Init(void   *context, 
             byte   *key, 
             size_t key_size)
{
  SHA1Context *sha_ctx = (SHA1Context *)context;
  
  sha_ctx->digest[0] = A_init;
  sha_ctx->digest[1] = B_init;
  sha_ctx->digest[2] = C_init;
  sha_ctx->digest[3] = D_init;
  sha_ctx->digest[4] = E_init;

  /* Initialise bit count */
  sha_ctx->countLo = sha_ctx->countHi = 0;

  return SHA1_ERROR_NO;
}


/**********************************************************************
 * 
 * SHA1Process() is called multiple times (if needed) until our message 
 * buffer is not empty
 *
 **********************************************************************/

int SHA1Process(void   *context, 
                byte   *data, 
                size_t length)
{
  DWORD       dwTmp, dataCount, len;
  byte        *bPtr, *msgPtr;
  SHA1Context *sha_ctx = (SHA1Context *)context;


  /* Update byte count */
  /* Check if the overflow occured in the countLo */
  dwTmp = sha_ctx->countLo;

  if ((sha_ctx->countLo = dwTmp + length) < dwTmp)
     (sha_ctx->countHi)++;

  /* If the previous Message was not multiply of 64 bytes,
   * we store remain of the previous Message in SHA_CTX->data[] array.
   * Calculate, how many bytes we currently store in SHA_CTX->data[]
   */
  
  /* calculate in dataCount number of BUSY bytes in sha_ctx->data buffer */
  dataCount = dwTmp & 0x3F; 

  msgPtr = data;
  len = length;

  if(dataCount)
   { bPtr = (byte *)sha_ctx->data + dataCount;

     /* calculate in dataCount number of FREE bytes in sha_ctx->data buffer */
     dataCount = 64 - dataCount;   /* 64 bytes == 512 bites == SHA block size */
     if( length < dataCount )
       { memcpy( bPtr, data, length );
         return SHA1_ERROR_NO;
       }
     
     /* in dataCount - number of free bytes in sha_ctx->data buffer */
     memcpy( bPtr, data, dataCount );
     ReverseDWORD( sha_ctx->data, 16 );
     SHA_UpdateDigest( sha_ctx->digest, sha_ctx->data );
     msgPtr += dataCount;
     len    -= dataCount;
   }

  /* Process data in 64-bytes (512 bites) blocks */
  while( len >= 64 )
   { memcpy( sha_ctx->data, msgPtr, 64 );
     ReverseDWORD( sha_ctx->data, 16 );
     SHA_UpdateDigest( sha_ctx->digest, sha_ctx->data );
     msgPtr += 64;
     len -= 64;
   }

  /* Save remaining bytes of Message. */
  if (len > 0) memcpy( sha_ctx->data, msgPtr, len );

  return SHA1_ERROR_NO;
}



/**********************************************************************
 *
 * SHA1Final(): All message buffer is transformed using SHA1Process().
 * To get the final Message Digest, we have to call SHA1Final()
 *
 **********************************************************************/

int SHA1Final(void *context, byte *digest) /* 'digest' array must be >= 20 bytes */
{
  DWORD       count;
  byte        *dataPtr;
  SHA1Context *sha_ctx = (SHA1Context *)context;

  /* Calculate number of BUSY bytes in sha_ctx->data buffer */
  count = sha_ctx->countLo & 0x3F;

  /* Set the first char of padding to 0x80.  This is safe since there is
     always at least one byte free */
  dataPtr = (byte *)sha_ctx->data + count;
  *dataPtr++ = 0x80;

  /* Calculate number of FREE bytes in sha_ctx->data buffer */
  count = 63 - count; /* sha_ctx->data is 64 bytes, but we already used one byte for 0x80 */

  /*   If count is more than 8, it means that we have the place for 
   * 2 DWORDS to place the length of message. 
   *    If no, we have to pad the current 64-byte block by 0, re-calculate 
   * digest, then fill the first 56 bytes in sha_ctx->data by 0, place 
   * the length of Message to the last 8 bytes and calculate final Digest
   */
  if( count < 8 )
   { memset( dataPtr, 0, count );
     ReverseDWORD( sha_ctx->data, 16 );
     SHA_UpdateDigest( sha_ctx->digest, sha_ctx->data );
     /* prepare to calculate final digest, where the length will be written in last 8 bytes */
     memset( sha_ctx->data, 0, 56 ); 
   }
  else if (count > 8) memset(dataPtr, 0, count - 8);

  sha_ctx->data[14] = (((sha_ctx->countHi) << 3) &0xffffffff) | (((sha_ctx->countLo) >> 29) & 0x7);
  sha_ctx->data[15] = ((sha_ctx->countLo) << 3) & 0xffffffff;

  ReverseDWORD( sha_ctx->data, 14 ); /* Do not reverse last 8 bytes */
  SHA_UpdateDigest( sha_ctx->digest, sha_ctx->data );

  copyDigestToByteArray( sha_ctx->digest, digest );
 
  return SHA1_ERROR_NO;
}



/**********************************************************************
 *
 *   SHA1Update() - the size of byte array "data" must be 
 *  equal to the block size of SHA1 algorithm, i.e. 512 bits = 64 bytes
 *
 **********************************************************************/

int SHA1Update(void *context, byte *data)
{ 
  SHA1Context *sha_ctx;

  sha_ctx = (SHA1Context *)context;

   /* 16 * sizeof(DWORD) == 64 bytes */
  memcpy( sha_ctx->data, data, 16 ); 
  
  ReverseDWORD( sha_ctx->data, 16 );

  SHA_UpdateDigest( sha_ctx->digest, sha_ctx->data );

  return SHA1_ERROR_NO;
}


/**********************************************************************
 *
 *   SHA1Allocate() - allocates memory needed for SHA1Context structure
 *
 **********************************************************************/

int SHA1Allocate(void **context)
{
  *context = malloc(sizeof(SHA1Context));
  if (*context) 
  { return SHA1_ERROR_NO;
  }
  return SHA1_ERROR_INTERNAL_ERROR;
}


/**********************************************************************
 * 
 * SHA1Free() - Frees resources allocated in SHA1Allocate
 *
 **********************************************************************/

int SHA1Free(void **context)
{
  free(*context);
  *context = 0;
  return 0;
}

/**********************************************************************
 * 
 * SHA1MakeDigest() - Helpful function if the whole message is in the 
 * memory and we have to create digest for it.
 *
 **********************************************************************/

int SHA1MakeDigest( byte *message, int messageLength, byte *digest )
{
    SHA1Context *context;
  
    if ( SHA1Allocate((void **)(&context)) != SHA1_ERROR_NO )
        return SHA1_ERROR_INTERNAL_ERROR;


    if ( SHA1Init(context, 0, 0) != SHA1_ERROR_NO)
    {   SHA1Free((void **)(&context));
        return SHA1_ERROR_INTERNAL_ERROR;
    }

    if ( SHA1Process(context, message, messageLength) != SHA1_ERROR_NO )
    {   SHA1Free((void **)(&context));
        return SHA1_ERROR_INTERNAL_ERROR;
    }

    if ( SHA1Final(context, digest) != SHA1_ERROR_NO )
    {   SHA1Free((void **)(&context));
        return SHA1_ERROR_INTERNAL_ERROR;
    }

    SHA1Free((void **)(&context));
    return SHA1_ERROR_NO;
}
char sha1_c[]="$Id: sha1.c 223 2009-03-30 05:20:36Z nail $";
