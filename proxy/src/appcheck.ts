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
//  Two Firebase projects mint tokens for this worker, production and staging,
//  because the two builds are two apps to Firebase. Which is why the project
//  number is a list: the staging build is how the app gets tested against a real
//  proxy, and a worker that only knew production would refuse every one of those
//  tests at the door.
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
  /// The project number that minted it — production or staging.
  projectNumber: string
}

/// A comma-separated var, in the order it was written. Empty entries are
/// dropped so a trailing comma is not read as a project that verifies nothing —
/// or, in `APPLE_BUNDLE_IDS`, as an app with no name.
export function parseList(raw: string): string[] {
  return raw
    .split(',')
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0)
}

/**
 * The bundle id of the app that belongs to `projectNumber`.
 *
 * `FIREBASE_PROJECT_NUMBERS` and `APPLE_BUNDLE_IDS` are parallel lists —
 * production first, then staging — so the position in one gives the entry in
 * the other. Which app it is matters beyond bookkeeping: the JWT sent to the
 * App Store Server API carries a `bid` claim, and Apple answers 404 for a
 * transaction that belongs to a different app. Asking about a staging
 * subscription under the production bundle id gets "no such transaction" for a
 * subscription that is perfectly active.
 */
export function bundleIdForProject(
  projectNumbers: string,
  bundleIds: string,
  projectNumber: string,
): string | null {
  const index = parseList(projectNumbers).indexOf(projectNumber)
  if (index < 0) return null
  return parseList(bundleIds)[index] ?? null
}

/**
 * Which of `numbers` a token names, or null if it names none of them.
 *
 * `jwtVerify` is given both lists and checks them independently, so on its own
 * it would accept a token that claims one project as its issuer and another as
 * its audience. No such token exists — Firebase mints both claims from the same
 * project — and both projects here are ours, so nothing is gained by forging
 * one. It is checked anyway because it costs a string comparison, and because
 * "the token belongs to one project" is the thing this function is supposed to
 * be able to say.
 */
export function matchingProject(
  numbers: string[],
  issuer: unknown,
  audience: unknown,
): string | null {
  const audiences = Array.isArray(audience) ? audience : [audience]
  const match = numbers.find(
    (number) =>
      issuer === `https://firebaseappcheck.googleapis.com/${number}` &&
      audiences.includes(`projects/${number}`),
  )
  return match ?? null
}

/**
 * Verifies an App Check token and returns its claims.
 *
 * Throws on anything that is not a valid, unexpired token issued by Firebase for
 * one of the configured projects — there is no soft failure here on purpose: a
 * caller that cannot attest gets nothing.
 */
export async function verifyAppCheck(
  token: string | null,
  projectNumbers: string,
): Promise<AppCheckClaims> {
  if (!token) {
    throw new Error('missing App Check token')
  }
  const numbers = parseList(projectNumbers)
  if (numbers.length === 0) {
    // An unconfigured worker refuses everything rather than verifying against
    // the empty string, which no token can name and every token would fail
    // against for the wrong reason.
    throw new Error('no Firebase project number configured')
  }
  const { payload } = await jwtVerify(token, keySet(), {
    issuer: numbers.map((number) => `https://firebaseappcheck.googleapis.com/${number}`),
    audience: numbers.map((number) => `projects/${number}`),
    algorithms: ['RS256'],
  })
  const projectNumber = matchingProject(numbers, payload.iss, payload.aud)
  if (!projectNumber) {
    throw new Error('App Check token names two different projects')
  }
  if (typeof payload.sub !== 'string' || payload.sub.length === 0) {
    throw new Error('App Check token carries no app id')
  }
  return { appId: payload.sub, projectNumber }
}
