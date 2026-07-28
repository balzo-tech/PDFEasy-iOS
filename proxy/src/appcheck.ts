//
//  appcheck.ts
//
//  Proof that the caller is the real app on a real device.
//
//  Firebase App Check wraps Apple's App Attest: the app asks Firebase for a
//  token, Firebase only issues one after Apple has vouched for the binary and
//  the device, and what arrives here is a short-lived RS256 JWT. Verifying it is
//  the whole reason a key can live in this Worker instead of in the bundle —
//  without it the key is not extractable but the endpoint is, and the bill is
//  the same.
//

import { createRemoteJWKSet, jwtVerify } from 'jose'

const JWKS_URL = new URL('https://firebaseappcheck.googleapis.com/v1/jwks')

/// Built once per isolate. `jose` caches the keys and refetches them when it
/// meets a `kid` it does not know, which is what key rotation looks like.
let jwks: ReturnType<typeof createRemoteJWKSet> | null = null

function keySet() {
  if (!jwks) {
    jwks = createRemoteJWKSet(JWKS_URL, { cacheMaxAge: 24 * 60 * 60 * 1000 })
  }
  return jwks
}

export interface AppCheckClaims {
  /// The Firebase app id the token was minted for.
  appId: string
}

/**
 * Verifies an App Check token and returns its claims.
 *
 * Throws on anything that is not a valid, unexpired token issued by Firebase
 * for this project — there is no soft failure here on purpose: a caller that
 * cannot attest gets nothing.
 */
export async function verifyAppCheck(
  token: string | null,
  projectNumber: string,
): Promise<AppCheckClaims> {
  if (!token) {
    throw new Error('missing App Check token')
  }
  const { payload } = await jwtVerify(token, keySet(), {
    issuer: `https://firebaseappcheck.googleapis.com/${projectNumber}`,
    audience: `projects/${projectNumber}`,
    algorithms: ['RS256'],
  })
  if (typeof payload.sub !== 'string' || payload.sub.length === 0) {
    throw new Error('App Check token carries no app id')
  }
  return { appId: payload.sub }
}
