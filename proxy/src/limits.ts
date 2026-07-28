//
//  limits.ts
//
//  The two ceilings, and why they are here rather than in the app.
//
//  The monthly chat allowance was counted in `ChatUsageTracker`, in the app's
//  own UserDefaults — which means it was counted on the device it was meant to
//  restrain, and reinstalling reset it. Counted against Apple's
//  `originalTransactionId` it survives reinstalls, new devices and a wiped
//  keychain, because it is Apple that issues it.
//
//  The per-IP ceiling is coarse and easy to sidestep with a handful of
//  addresses. It is not the defence — App Check is — it is what keeps a script
//  that has somehow got a valid token from emptying the budget in an afternoon.
//

import { RequestRejected, type Env } from './types'

/// Same month boundary everywhere: UTC. A subscriber travelling across a date
/// line should not get a second allowance.
function currentMonth(now: Date): string {
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`
}

/// Seconds until the start of the next UTC month, so the counter disappears on
/// its own rather than needing a sweep.
function secondsUntilNextMonth(now: Date): number {
  const next = Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)
  return Math.max(60, Math.ceil((next - now.getTime()) / 1000))
}

export interface Usage {
  used: number
  limit: number
}

/**
 * Counts one use against this month's allowance, and refuses when it is spent.
 *
 * KV is eventually consistent, so two requests racing can both read the same
 * count and slip one over the line. That is the right trade here: the ceiling
 * exists to bound a bill, not to be exact to the message, and the alternative
 * (a Durable Object per subscriber) costs latency on every single call.
 */
export async function chargeMonthlyQuota(
  env: Env,
  bucket: string,
  subject: string,
  limit: number,
  now: Date = new Date(),
): Promise<Usage> {
  if (limit <= 0) {
    return { used: 0, limit: 0 }
  }
  const key = `quota:${bucket}:${subject}:${currentMonth(now)}`
  const used = Number((await env.LIMITS.get(key)) ?? '0')
  if (used >= limit) {
    throw new RequestRejected(
      429,
      'monthly_limit_reached',
      `This month's ${bucket} allowance is used up`,
    )
  }
  await env.LIMITS.put(key, String(used + 1), {
    expirationTtl: secondsUntilNextMonth(now),
  })
  return { used: used + 1, limit }
}

/// A minute-wide window per address. Deliberately blunt.
export async function chargeIpRateLimit(
  env: Env,
  ip: string,
  limit: number,
  now: Date = new Date(),
): Promise<void> {
  if (limit <= 0 || !ip) return
  const minute = Math.floor(now.getTime() / 60_000)
  const key = `rl:${ip}:${minute}`
  const used = Number((await env.LIMITS.get(key)) ?? '0')
  if (used >= limit) {
    throw new RequestRejected(429, 'rate_limited', 'Too many requests, slow down')
  }
  await env.LIMITS.put(key, String(used + 1), { expirationTtl: 120 })
}
