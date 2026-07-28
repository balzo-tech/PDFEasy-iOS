import { describe, expect, it } from 'vitest'
import { chargeIpRateLimit, chargeMonthlyQuota } from '../src/limits'
import { RequestRejected } from '../src/types'
import { makeEnv } from './helpers'

describe('monthly quota', () => {
  it('counts each use and refuses once the allowance is spent', async () => {
    const env = makeEnv()
    for (let i = 1; i <= 3; i += 1) {
      const usage = await chargeMonthlyQuota(env, 'chat', 'tx-1', 3)
      expect(usage.used).toBe(i)
    }
    await expect(chargeMonthlyQuota(env, 'chat', 'tx-1', 3)).rejects.toMatchObject({
      status: 429,
      code: 'monthly_limit_reached',
    })
  })

  it('counts each subscriber separately', async () => {
    const env = makeEnv()
    await chargeMonthlyQuota(env, 'chat', 'tx-1', 1)
    const other = await chargeMonthlyQuota(env, 'chat', 'tx-2', 1)
    expect(other.used).toBe(1)
  })

  it('counts chat and stirling against their own allowances', async () => {
    const env = makeEnv()
    await chargeMonthlyQuota(env, 'chat', 'tx-1', 1)
    const stirling = await chargeMonthlyQuota(env, 'stirling', 'tx-1', 1)
    expect(stirling.used).toBe(1)
  })

  it('starts over on the first of the month', async () => {
    const env = makeEnv()
    const january = new Date('2026-01-31T23:00:00Z')
    const february = new Date('2026-02-01T01:00:00Z')
    await chargeMonthlyQuota(env, 'chat', 'tx-1', 1, january)
    await expect(chargeMonthlyQuota(env, 'chat', 'tx-1', 1, january)).rejects.toBeInstanceOf(
      RequestRejected,
    )
    const fresh = await chargeMonthlyQuota(env, 'chat', 'tx-1', 1, february)
    expect(fresh.used).toBe(1)
  })

  it('expires the counter when the month ends, not 30 days later', async () => {
    const env = makeEnv()
    const lastDay = new Date('2026-03-31T22:00:00Z')
    await chargeMonthlyQuota(env, 'chat', 'tx-1', 5, lastDay)
    const ttl = env.__ttls.get('quota:chat:tx-1:2026-03')
    expect(ttl).toBeDefined()
    expect(ttl!).toBeLessThanOrEqual(2 * 60 * 60)
  })

  it('is a no-op when no ceiling is configured', async () => {
    const env = makeEnv()
    const usage = await chargeMonthlyQuota(env, 'chat', 'tx-1', 0)
    expect(usage).toEqual({ used: 0, limit: 0 })
    expect(env.__store.size).toBe(0)
  })
})

describe('ip rate limit', () => {
  it('refuses once the minute is full', async () => {
    const env = makeEnv()
    const now = new Date('2026-05-05T10:00:30Z')
    await chargeIpRateLimit(env, '1.2.3.4', 2, now)
    await chargeIpRateLimit(env, '1.2.3.4', 2, now)
    await expect(chargeIpRateLimit(env, '1.2.3.4', 2, now)).rejects.toMatchObject({
      status: 429,
      code: 'rate_limited',
    })
  })

  it('opens a new window on the next minute', async () => {
    const env = makeEnv()
    await chargeIpRateLimit(env, '1.2.3.4', 1, new Date('2026-05-05T10:00:30Z'))
    await expect(
      chargeIpRateLimit(env, '1.2.3.4', 1, new Date('2026-05-05T10:01:05Z')),
    ).resolves.toBeUndefined()
  })

  it('does nothing without an address to count', async () => {
    const env = makeEnv()
    await chargeIpRateLimit(env, '', 1)
    expect(env.__store.size).toBe(0)
  })
})
