// Ed25519 signing implementation based on TweetNaCl.
// Original TweetNaCl: Daniel J. Bernstein, Tanja Lange, et al.
// Public domain. https://tweetnacl.cr.yp.to/
//
// This file contains the Ed25519 deterministic signing primitives.
// Includes embedded SHA-512, field arithmetic in GF(2^255-19),
// and Ed25519 group operations.

#include "tweetnacl.h"
#include <string.h>
#include <stdlib.h>

typedef long long i64;
typedef i64 gf[16];

static const gf
  gf0 = {0},
  gf1 = {1},
  D = {0x78a3, 0x1359, 0x4dca, 0x75eb, 0xd8ab, 0x4141, 0x0a4d, 0x0070,
       0xe898, 0x7779, 0x4079, 0x8cc7, 0xfe73, 0x2b6f, 0x6cee, 0x5203},
  D2 = {0xf159, 0x26b2, 0x9b94, 0xebd6, 0xb156, 0x8283, 0x149a, 0x00e0,
        0xd130, 0xeef3, 0x80f2, 0x198e, 0xfce7, 0x56df, 0xd9dc, 0x2406},
  X = {0xd51a, 0x8f25, 0x2d60, 0xc956, 0xa7b2, 0x9525, 0xc760, 0x692c,
       0xdc5c, 0xfdd6, 0xe231, 0xc0a4, 0x53fe, 0xcd6e, 0x36d3, 0x2169},
  Y = {0x6658, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666,
       0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666};

// ----- SHA-512 -----

static unsigned long long dl64(const unsigned char *x) {
  unsigned long long u = 0;
  for (int i = 0; i < 8; i++) u = (u << 8) | x[i];
  return u;
}

static void ts64(unsigned char *x, unsigned long long u) {
  for (int i = 7; i >= 0; i--) { x[i] = (unsigned char)(u & 0xff); u >>= 8; }
}

static const unsigned long long K512[80] = {
  0x428a2f98d728ae22ULL, 0x7137449123ef65cdULL, 0xb5c0fbcfec4d3b2fULL, 0xe9b5dba58189dbbcULL,
  0x3956c25bf348b538ULL, 0x59f111f1b605d019ULL, 0x923f82a4af194f9bULL, 0xab1c5ed5da6d8118ULL,
  0xd807aa98a3030242ULL, 0x12835b0145706fbeULL, 0x243185be4ee4b28cULL, 0x550c7dc3d5ffb4e2ULL,
  0x72be5d74f27b896fULL, 0x80deb1fe3b1696b1ULL, 0x9bdc06a725c71235ULL, 0xc19bf174cf692694ULL,
  0xe49b69c19ef14ad2ULL, 0xefbe4786384f25e3ULL, 0x0fc19dc68b8cd5b5ULL, 0x240ca1cc77ac9c65ULL,
  0x2de92c6f592b0275ULL, 0x4a7484aa6ea6e483ULL, 0x5cb0a9dcbd41fbd4ULL, 0x76f988da831153b5ULL,
  0x983e5152ee66dfabULL, 0xa831c66d2db43210ULL, 0xb00327c898fb213fULL, 0xbf597fc7beef0ee4ULL,
  0xc6e00bf33da88fc2ULL, 0xd5a79147930aa725ULL, 0x06ca6351e003826fULL, 0x142929670a0e6e70ULL,
  0x27b70a8546d22ffcULL, 0x2e1b21385c26c926ULL, 0x4d2c6dfc5ac42aedULL, 0x53380d139d95b3dfULL,
  0x650a73548baf63deULL, 0x766a0abb3c77b2a8ULL, 0x81c2c92e47edaee6ULL, 0x92722c851482353bULL,
  0xa2bfe8a14cf10364ULL, 0xa81a664bbc423001ULL, 0xc24b8b70d0f89791ULL, 0xc76c51a30654be30ULL,
  0xd192e819d6ef5218ULL, 0xd69906245565a910ULL, 0xf40e35855771202aULL, 0x106aa07032bbd1b8ULL,
  0x19a4c116b8d2d0c8ULL, 0x1e376c085141ab53ULL, 0x2748774cdf8eeb99ULL, 0x34b0bcb5e19b48a8ULL,
  0x391c0cb3c5c95a63ULL, 0x4ed8aa4ae3418acbULL, 0x5b9cca4f7763e373ULL, 0x682e6ff3d6b2b8a3ULL,
  0x748f82ee5defb2fcULL, 0x78a5636f43172f60ULL, 0x84c87814a1f0ab72ULL, 0x8cc702081a6439ecULL,
  0x90befffa23631e28ULL, 0xa4506cebde82bde9ULL, 0xbef9a3f7b2c67915ULL, 0xc67178f2e372532bULL,
  0xca273eceea26619cULL, 0xd186b8c721c0c207ULL, 0xeada7dd6cde0eb1eULL, 0xf57d4f7fee6ed178ULL,
  0x06f067aa72176fbaULL, 0x0a637dc5a2c898a6ULL, 0x113f9804bef90daeULL, 0x1b710b35131c471bULL,
  0x28db77f523047d84ULL, 0x32caab7b40c72493ULL, 0x3c9ebe0a15c9bebcULL, 0x431d67c49c100d4cULL,
  0x4cc5d4becb3e42b6ULL, 0x597f299cfc657e2aULL, 0x5fcb6fab3ad6faecULL, 0x6c44198c4a475817ULL
};

#define RR(x,c) (((x) >> (c)) | ((x) << (64 - (c))))
#define Ch(x,y,z) (((x) & (y)) ^ (~(x) & (z)))
#define Maj(x,y,z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define Sigma0(x) (RR(x,28) ^ RR(x,34) ^ RR(x,39))
#define Sigma1(x) (RR(x,14) ^ RR(x,18) ^ RR(x,41))
#define sigma0(x) (RR(x,1) ^ RR(x,8) ^ ((x) >> 7))
#define sigma1(x) (RR(x,19) ^ RR(x,61) ^ ((x) >> 6))

static int crypto_hashblocks(unsigned char *x, const unsigned char *m, unsigned long long n) {
  unsigned long long z[8], b[8], a[8], w[16];
  int i, j;
  for (i = 0; i < 8; i++) z[i] = a[i] = dl64(x + 8*i);
  while (n >= 128) {
    for (i = 0; i < 16; i++) w[i] = dl64(m + 8*i);
    for (i = 0; i < 80; i++) {
      for (j = 0; j < 8; j++) b[j] = a[j];
      unsigned long long t = a[7] + Sigma1(a[4]) + Ch(a[4],a[5],a[6]) + K512[i] + w[i%16];
      b[7] = t + Sigma0(a[0]) + Maj(a[0],a[1],a[2]);
      b[3] += t;
      for (j = 0; j < 8; j++) a[(j+1)%8] = b[j];
      if (i%16 == 15) {
        for (j = 0; j < 16; j++)
          w[j] += w[(j+9)%16] + sigma0(w[(j+1)%16]) + sigma1(w[(j+14)%16]);
      }
    }
    for (i = 0; i < 8; i++) { a[i] += z[i]; z[i] = a[i]; }
    m += 128;
    n -= 128;
  }
  for (i = 0; i < 8; i++) ts64(x + 8*i, z[i]);
  return (int)n;
}

static const unsigned char sha512_iv[64] = {
  0x6a,0x09,0xe6,0x67,0xf3,0xbc,0xc9,0x08,
  0xbb,0x67,0xae,0x85,0x84,0xca,0xa7,0x3b,
  0x3c,0x6e,0xf3,0x72,0xfe,0x94,0xf8,0x2b,
  0xa5,0x4f,0xf5,0x3a,0x5f,0x1d,0x36,0xf1,
  0x51,0x0e,0x52,0x7f,0xad,0xe6,0x82,0xd1,
  0x9b,0x05,0x68,0x8c,0x2b,0x3e,0x6c,0x1f,
  0x1f,0x83,0xd9,0xab,0xfb,0x41,0xbd,0x6b,
  0x5b,0xe0,0xcd,0x19,0x13,0x7e,0x21,0x79
};

static int crypto_hash_sha512(unsigned char *out, const unsigned char *m, unsigned long long n) {
  unsigned char h[64], x[256];
  unsigned long long b = n;
  int i;
  memcpy(h, sha512_iv, 64);
  crypto_hashblocks(h, m, n);
  m += n;
  n &= 127;
  m -= n;
  memset(x, 0, 256);
  for (i = 0; i < (int)n; i++) x[i] = m[i];
  x[n] = 128;
  n = 256 - 128 * (n < 112);
  x[n-9] = (unsigned char)(b >> 61);
  ts64(x+n-8, b << 3);
  crypto_hashblocks(h, x, n);
  memcpy(out, h, 64);
  return 0;
}

// ----- GF(2^255-19) field arithmetic -----

static void set25519(gf r, const gf a) {
  int i;
  for (i = 0; i < 16; i++) r[i] = a[i];
}

static void car25519(gf o) {
  int i;
  i64 c;
  for (i = 0; i < 16; i++) {
    o[i] += (1LL << 16);
    c = o[i] >> 16;
    o[(i+1) * (i < 15)] += c - 1 + 37 * (c - 1) * (i == 15);
    o[i] -= c << 16;
  }
}

static void sel25519(gf p, gf q, int b) {
  i64 t, c = ~(b - 1);
  int i;
  for (i = 0; i < 16; i++) {
    t = c & (p[i] ^ q[i]);
    p[i] ^= t;
    q[i] ^= t;
  }
}

static void pack25519(unsigned char *o, const gf n) {
  int i, j, b;
  gf m, t;
  set25519(t, n);
  car25519(t);
  car25519(t);
  car25519(t);
  for (j = 0; j < 2; j++) {
    m[0] = t[0] - 0xffed;
    for (i = 1; i < 15; i++) {
      m[i] = t[i] - 0xffff - ((m[i-1] >> 16) & 1);
      m[i-1] &= 0xffff;
    }
    m[15] = t[15] - 0x7fff - ((m[14] >> 16) & 1);
    b = (int)((m[15] >> 16) & 1);
    m[14] &= 0xffff;
    sel25519(t, m, 1 - b);
  }
  for (i = 0; i < 16; i++) {
    o[2*i] = (unsigned char)(t[i] & 0xff);
    o[2*i+1] = (unsigned char)(t[i] >> 8);
  }
}

// Forward declare par25519
static unsigned char par25519(const gf a);

static void unpack25519(gf o, const unsigned char *n) {
  int i;
  for (i = 0; i < 16; i++) o[i] = n[2*i] + ((i64)n[2*i+1] << 8);
  o[15] &= 0x7fff;
}

static void A_gf(gf o, const gf a, const gf b) {
  int i;
  for (i = 0; i < 16; i++) o[i] = a[i] + b[i];
}

static void Z_gf(gf o, const gf a, const gf b) {
  int i;
  for (i = 0; i < 16; i++) o[i] = a[i] - b[i];
}

static void M_gf(gf o, const gf a, const gf b) {
  i64 t[31];
  int i, j;
  for (i = 0; i < 31; i++) t[i] = 0;
  for (i = 0; i < 16; i++)
    for (j = 0; j < 16; j++)
      t[i+j] += a[i] * b[j];
  for (i = 0; i < 15; i++) t[i] += 38 * t[i+16];
  for (i = 0; i < 16; i++) o[i] = t[i];
  car25519(o);
  car25519(o);
}

static void S_gf(gf o, const gf a) {
  M_gf(o, a, a);
}

static void inv25519(gf o, const gf a) {
  gf c;
  int i;
  set25519(c, a);
  for (i = 253; i >= 0; i--) {
    S_gf(c, c);
    if (i != 2 && i != 4) M_gf(c, c, a);
  }
  set25519(o, c);
}

static unsigned char par25519(const gf a) {
  unsigned char d[32];
  pack25519(d, a);
  return d[0] & 1;
}

// ----- Extended coordinates group operations -----
// p[0]=X, p[1]=Y, p[2]=Z, p[3]=T where T=XY/Z

static void pack_point(unsigned char *r, gf p[4]) {
  gf tx, ty, zi;
  inv25519(zi, p[2]);
  M_gf(tx, p[0], zi);
  M_gf(ty, p[1], zi);
  pack25519(r, ty);
  r[31] ^= (unsigned char)(par25519(tx) << 7);
}

static void cswap_point(gf p[4], gf q[4], unsigned char b) {
  int i;
  for (i = 0; i < 4; i++)
    sel25519(p[i], q[i], b);
}

static void add_points(gf p[4], gf q[4]) {
  gf a, b, c, d, t, e, f, g, h;
  Z_gf(a, p[1], p[0]);
  Z_gf(t, q[1], q[0]);
  M_gf(a, a, t);
  A_gf(b, p[0], p[1]);
  A_gf(t, q[0], q[1]);
  M_gf(b, b, t);
  M_gf(c, p[3], q[3]);
  M_gf(c, c, D2);
  M_gf(d, p[2], q[2]);
  A_gf(d, d, d);
  Z_gf(e, b, a);
  Z_gf(f, d, c);
  A_gf(g, d, c);
  A_gf(h, b, a);
  M_gf(p[0], e, f);
  M_gf(p[1], h, g);
  M_gf(p[2], g, f);
  M_gf(p[3], e, h);
}

static void scalarmult(gf p[4], gf q[4], const unsigned char *s) {
  int i;
  set25519(p[0], gf0);
  set25519(p[1], gf1);
  set25519(p[2], gf1);
  set25519(p[3], gf0);
  for (i = 255; i >= 0; --i) {
    unsigned char b = (s[i/8] >> (i & 7)) & 1;
    cswap_point(p, q, b);
    add_points(q, p);
    add_points(p, p);
    cswap_point(p, q, b);
  }
}

static void scalarbase(gf p[4], const unsigned char *s) {
  gf q[4];
  set25519(q[0], X);
  set25519(q[1], Y);
  set25519(q[2], gf1);
  M_gf(q[3], X, Y);
  scalarmult(p, q, s);
}

// ----- Scalar arithmetic mod l -----

static const i64 L[32] = {
  0xed, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58,
  0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9, 0xde, 0x14,
  0,    0,    0,    0,    0,    0,    0,    0,
  0,    0,    0,    0,    0,    0,    0,    0x10
};

static void modL(unsigned char *r, i64 x[64]) {
  i64 carry;
  int i, j;
  for (i = 63; i >= 32; --i) {
    carry = 0;
    for (j = i - 32; j < i - 12; j++) {
      x[j] += carry - 16 * x[i] * L[j - (i - 32)];
      carry = (x[j] + 128) >> 8;
      x[j] -= carry << 8;
    }
    x[j] += carry;
    x[i] = 0;
  }
  carry = 0;
  for (j = 0; j < 32; j++) {
    x[j] += carry - (x[31] >> 4) * L[j];
    carry = x[j] >> 8;
    x[j] &= 255;
  }
  for (j = 0; j < 32; j++) x[j] -= carry * L[j];
  for (i = 0; i < 32; i++) {
    x[i+1] += x[i] >> 8;
    r[i] = (unsigned char)(x[i] & 255);
  }
}

static void reduce(unsigned char *r) {
  i64 x[64];
  int i;
  for (i = 0; i < 64; i++) x[i] = (unsigned long long)r[i];
  for (i = 0; i < 64; i++) r[i] = 0;
  modL(r, x);
}

// ----- Ed25519 API -----

int crypto_sign_ed25519_seed_keypair(unsigned char *pk, unsigned char *sk,
                                     const unsigned char *seed) {
  unsigned char d[64];
  gf p[4];
  int i;

  crypto_hash_sha512(d, seed, 32);
  d[0] &= 248;
  d[31] &= 127;
  d[31] |= 64;

  scalarbase(p, d);
  pack_point(pk, p);

  for (i = 0; i < 32; i++) sk[i] = seed[i];
  for (i = 0; i < 32; i++) sk[32+i] = pk[i];

  return 0;
}

int crypto_sign_ed25519_detached(unsigned char *sig,
                                 const unsigned char *m, unsigned long long mlen,
                                 const unsigned char *sk) {
  unsigned char d[64], h[64], r[64];
  i64 x[64];
  gf p[4];
  int i;
  unsigned long long j;

  crypto_hash_sha512(d, sk, 32);
  d[0] &= 248;
  d[31] &= 127;
  d[31] |= 64;

  // Compute nonce: r = SHA-512(prefix || message)
  // where prefix = d[32..64] (the second half of SHA-512(seed))
  {
    unsigned long long hlen = 32 + mlen;
    unsigned char *hbuf = (unsigned char *)malloc(hlen);
    if (!hbuf) return -1;
    memcpy(hbuf, d + 32, 32);       // prefix
    memcpy(hbuf + 32, m, mlen);     // message
    crypto_hash_sha512(r, hbuf, hlen);
    free(hbuf);
  }
  reduce(r);

  // R = r * B
  scalarbase(p, r);
  pack_point(sig, p);  // sig[0..32] = R

  // Compute S: k = SHA-512(R || pk || message)
  {
    unsigned long long hlen = 64 + mlen;
    unsigned char *hbuf = (unsigned char *)malloc(hlen);
    if (!hbuf) return -1;
    memcpy(hbuf, sig, 32);          // R
    memcpy(hbuf + 32, sk + 32, 32); // public key
    memcpy(hbuf + 64, m, mlen);     // message
    crypto_hash_sha512(h, hbuf, hlen);
    free(hbuf);
  }
  reduce(h);

  // S = (r + h*a) mod l
  for (i = 0; i < 64; i++) x[i] = 0;
  for (i = 0; i < 32; i++) x[i] = (unsigned long long)r[i];
  for (i = 0; i < 32; i++)
    for (j = 0; j < 32; j++)
      x[i+j] += (i64)h[i] * (i64)d[j];
  modL(sig + 32, x);  // sig[32..64] = S

  return 0;
}
