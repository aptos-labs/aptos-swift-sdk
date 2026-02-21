// TweetNaCl - a compact, verified cryptographic library.
// Public domain. Daniel J. Bernstein, Tanja Lange, et al.
// https://tweetnacl.cr.yp.to/
//
// Only the Ed25519 signing functions are exposed here.

#ifndef TWEETNACL_H
#define TWEETNACL_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Ed25519 keypair from seed.
// pk: 32-byte public key (output)
// sk: 64-byte secret key (output) = seed || pk
// seed: 32-byte seed (input)
// Returns 0 on success.
int crypto_sign_ed25519_seed_keypair(unsigned char *pk, unsigned char *sk,
                                     const unsigned char *seed);

// Ed25519 detached signature.
// sig: 64-byte signature (output)
// m: message bytes (input)
// mlen: message length
// sk: 64-byte secret key (seed || pk)
// Returns 0 on success.
int crypto_sign_ed25519_detached(unsigned char *sig,
                                 const unsigned char *m, unsigned long long mlen,
                                 const unsigned char *sk);

#ifdef __cplusplus
}
#endif

#endif // TWEETNACL_H
