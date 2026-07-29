//
//  entitlement.ts
//
//  Whether the caller is actually a subscriber.
//
//  The chat and the Stirling tools sit behind the paywall, and until now that
//  was enforced in the app alone — an `isPremium` check in front of a screen.
//  Anyone able to make an HTTP request skipped it. Here it is checked against
//  Apple before a request costs anything.
//
//  The app sends the `originalTransactionId` of its subscription. We do not
//  trust it on its own: we ask Apple's App Store Server API what that
//  subscription's status is, with a JWT signed by the .p8 issued in App Store
//  Connect. Answers are cached briefly — a subscription does not change state
//  minute to minute, and every uncached call is latency on someone's chat.
//

import { SignJWT, importPKCS8 } from 'jose'
import { RequestRejected, type Env } from './types'

const PRODUCTION_HOST = 'https://api.storekit.itunes.apple.com'
const SANDBOX_HOST = 'https://api.storekit-sandbox.itunes.apple.com'

/// Statuses Apple reports for an auto-renewable subscription. 1 is active and 5
/// does not exist; 3 (billing retry) and 4 (grace period) still entitle the
/// customer, and cutting them off over a card that needs updating is how you
/// turn a payment problem into a refund request.
const ENTITLING_STATUSES = new Set([1, 3, 4])

const CACHE_SECONDS = 15 * 60

export interface Subscriber {
  /// Apple's stable id for the subscription, and the key everything downstream
  /// counts against: it survives reinstalls, which `installId` does not.
  originalTransactionId: string
}

export async function verifyEntitlement(
  originalTransactionId: string | null,
  env: Env,
): Promise<Subscriber> {
  if (!originalTransactionId || !/^[0-9]{6,20}$/.test(originalTransactionId)) {
    throw new RequestRejected(402, 'no_subscription', 'No subscription was presented')
  }
  const cacheKey = `ent:${originalTransactionId}`
  const cached = await env.LIMITS.get(cacheKey)
  if (cached === 'active') {
    return { originalTransactionId }
  }
  if (cached === 'inactive') {
    throw new RequestRejected(402, 'subscription_expired', 'This subscription is not active')
  }

  const active = await askApple(originalTransactionId, env)
  await env.LIMITS.put(cacheKey, active ? 'active' : 'inactive', {
    expirationTtl: CACHE_SECONDS,
  })
  if (!active) {
    throw new RequestRejected(402, 'subscription_expired', 'This subscription is not active')
  }
  return { originalTransactionId }
}

/// Production first, then sandbox: a TestFlight or Xcode build's transactions
/// only exist in the sandbox, and Apple answers 404 for them in production.
///
/// "Answers 404" was too kind a description of production. Asked about a
/// transaction it does not have, it has also been seen returning 500
/// (`5000001`, "an unknown error occurred") and 401. Treating those as fatal
/// meant a sandbox subscriber got a 502 and the sandbox was never asked — which
/// is every device test, and every TestFlight build. So any answer production
/// cannot make sense of moves on to the sandbox, and only a failure at *both*
/// hosts is reported as the store being unreachable.
async function askApple(originalTransactionId: string, env: Env): Promise<boolean> {
  let unreachable: number | null = null
  for (const host of [PRODUCTION_HOST, SANDBOX_HOST]) {
    const response = await fetch(
      `${host}/inApps/v1/subscriptions/${originalTransactionId}`,
      { headers: { Authorization: `Bearer ${await appleToken(env)}` } },
    )
    if (response.status === 404) continue
    if (!response.ok) {
      unreachable = response.status
      continue
    }
    const body = (await response.json()) as AppleStatusResponse
    return statusIsEntitling(body)
  }
  if (unreachable !== null) {
    // Nobody answered, and at least one host failed for a reason that is not
    // "no such subscription". Saying "not a subscriber" here would take the
    // paywall down on an Apple outage.
    throw new RequestRejected(
      502,
      'store_unreachable',
      `App Store Server API answered ${unreachable}`,
    )
  }
  return false
}

interface AppleStatusResponse {
  data?: Array<{ lastTransactions?: Array<{ status?: number }> }>
}

function statusIsEntitling(body: AppleStatusResponse): boolean {
  for (const group of body.data ?? []) {
    for (const transaction of group.lastTransactions ?? []) {
      if (typeof transaction.status === 'number' && ENTITLING_STATUSES.has(transaction.status)) {
        return true
      }
    }
  }
  return false
}

/// Apple's API wants a short-lived ES256 JWT signed with the .p8. Rebuilt per
/// isolate rather than per request; an hour is well inside the 60 minutes Apple
/// allows.
let tokenCache: { value: string; expiresAt: number } | null = null

async function appleToken(env: Env): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (tokenCache && tokenCache.expiresAt - 60 > now) {
    return tokenCache.value
  }
  if (!env.APPLE_PRIVATE_KEY || !env.APPLE_KEY_ID || !env.APPLE_ISSUER_ID) {
    throw new RequestRejected(500, 'not_configured', 'App Store Server API credentials are not set')
  }
  const key = await importPKCS8(env.APPLE_PRIVATE_KEY, 'ES256')
  const expiresAt = now + 30 * 60
  const value = await new SignJWT({ bid: env.APPLE_BUNDLE_IDS.split(',')[0].trim() })
    .setProtectedHeader({ alg: 'ES256', kid: env.APPLE_KEY_ID, typ: 'JWT' })
    .setIssuer(env.APPLE_ISSUER_ID)
    .setAudience('appstoreconnect-v1')
    .setIssuedAt(now)
    .setExpirationTime(expiresAt)
    .sign(key)
  tokenCache = { value, expiresAt }
  return value
}

/// Test seam.
export function resetAppleTokenForTests() {
  tokenCache = null
}
