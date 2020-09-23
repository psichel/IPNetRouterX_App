/*
 * Author     :  Paul Kocher
 * E-mail     :  pck@netcom.com
 * Date       :  1997
 * Description:  C implementation of the Blowfish algorithm.
 */

#define BLOWFISH_MAX_KEY_BYTES 56          /* 448 bits */


typedef struct
{
  unsigned long   P[16 + 2];
  unsigned long   S[4][256];
} nmCypher_ctx;


void nmCypher_init( nmCypher_ctx *ctx, const char *key, int keyLen);
void nmCypher_encrypt( nmCypher_ctx *ctx, unsigned long *xl, unsigned long *xr);
