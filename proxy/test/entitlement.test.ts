import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { exportPKCS8, generateKeyPair } from 'jose'
import { resetAppleTokenForTests, verifyEntitlement } from '../src/entitlement'
import { RequestRejected } from '../src/types'
import { makeEnv } from './helpers'

// A real ES256 key, generated here rather than checked in: the code signs a JWT
// with it before it can ask Apple anything, and a fake string would fail at
// `importPKCS8` for a reason that has nothing to do with what these tests are
// about. Nothing verifies the signature — `fetch` is stubbed.
const { privateKey } = await generateKeyPair('ES256', { extractable: true })
const APPLE_PRIVATE_KEY = await exportPKCS8(privateKey)

const ACTIVE = { data: [{ lastTransactions: [{ status: 1 }] }] }
const EXPIRED = { data: [{ lastTransactions: [{ status: 2 }] }] }

const TRANSACTION = '2000000123456789'

/// Answers keyed by host, so a test says what production and the sandbox each
/// replied without caring about the order they were called in.
function stubApple(answers: { production: Response; sandbox: Response }) {
  const fetchMock = vi.fn(async (input: RequestInfo | URL) => {
    const url = String(input)
    return url.includes('sandbox') ? answers.sandbox : answers.production
  })
  vi.stubGlobal('fetch', fetchMock)
  return fetchMock
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status })
}

beforeEach(() => {
  resetAppleTokenForTests()
})

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('what the app presents as a subscription', () => {
  it('refuses an id that is not one, without spending a call on Apple', async () => {
    // What a StoreKit configuration file in the scheme produces: purchases are
    // simulated on the device, and `Transaction.originalID` counts from zero.
    // Apple has never heard of it, so there is nothing to ask about.
    const fetchMock = stubApple({ production: json(ACTIVE), sandbox: json(ACTIVE) })
    await expect(
      verifyEntitlement('0', makeEnv({ APPLE_PRIVATE_KEY })),
    ).rejects.toMatchObject({ status: 402, code: 'no_subscription' })
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('refuses a missing header the same way', async () => {
    await expect(
      verifyEntitlement(null, makeEnv({ APPLE_PRIVATE_KEY })),
    ).rejects.toBeInstanceOf(RequestRejected)
  })
})

describe('asking Apple, across its two hosts', () => {
  it('falls through to the sandbox when production has no such transaction', async () => {
    stubApple({ production: json({}, 404), sandbox: json(ACTIVE) })
    await expect(
      verifyEntitlement(TRANSACTION, makeEnv({ APPLE_PRIVATE_KEY })),
    ).resolves.toMatchObject({ originalTransactionId: TRANSACTION })
  })

  it('falls through even when production fails outright', async () => {
    // Measured, not imagined: asked about a sandbox transaction, production
    // answers 500 `5000001` — and a device test is exactly this case.
    stubApple({
      production: json({ errorCode: 5000001 }, 500),
      sandbox: json(ACTIVE),
    })
    await expect(
      verifyEntitlement(TRANSACTION, makeEnv({ APPLE_PRIVATE_KEY })),
    ).resolves.toMatchObject({ originalTransactionId: TRANSACTION })
  })

  it('reports the store unreachable only when neither host could answer', async () => {
    stubApple({ production: json({}, 500), sandbox: json({}, 503) })
    await expect(
      verifyEntitlement(TRANSACTION, makeEnv({ APPLE_PRIVATE_KEY })),
    ).rejects.toMatchObject({ status: 502, code: 'store_unreachable' })
  })

  it('is not a subscriber when both hosts say there is no such transaction', async () => {
    stubApple({ production: json({}, 404), sandbox: json({}, 404) })
    await expect(
      verifyEntitlement(TRANSACTION, makeEnv({ APPLE_PRIVATE_KEY })),
    ).rejects.toMatchObject({ status: 402, code: 'subscription_expired' })
  })

  it('turns an expired subscription away', async () => {
    stubApple({ production: json(EXPIRED), sandbox: json(ACTIVE) })
    await expect(
      verifyEntitlement(TRANSACTION, makeEnv({ APPLE_PRIVATE_KEY })),
    ).rejects.toMatchObject({ status: 402, code: 'subscription_expired' })
  })
})

describe('caching', () => {
  it('asks Apple once and remembers the answer', async () => {
    const fetchMock = stubApple({ production: json(ACTIVE), sandbox: json(ACTIVE) })
    const env = makeEnv({ APPLE_PRIVATE_KEY })
    await verifyEntitlement(TRANSACTION, env)
    await verifyEntitlement(TRANSACTION, env)
    expect(fetchMock).toHaveBeenCalledOnce()
    expect(env.__ttls.get(`ent:${TRANSACTION}`)).toBe(15 * 60)
  })

  it('remembers a no as well, so a lapsed subscriber is not a call each time', async () => {
    const fetchMock = stubApple({ production: json(EXPIRED), sandbox: json(EXPIRED) })
    const env = makeEnv({ APPLE_PRIVATE_KEY })
    await expect(verifyEntitlement(TRANSACTION, env)).rejects.toBeInstanceOf(RequestRejected)
    await expect(verifyEntitlement(TRANSACTION, env)).rejects.toBeInstanceOf(RequestRejected)
    expect(fetchMock).toHaveBeenCalledOnce()
  })

  it('does not cache a store that was merely unreachable', async () => {
    const fetchMock = stubApple({ production: json({}, 500), sandbox: json({}, 500) })
    const env = makeEnv({ APPLE_PRIVATE_KEY })
    await expect(verifyEntitlement(TRANSACTION, env)).rejects.toMatchObject({ status: 502 })
    await expect(verifyEntitlement(TRANSACTION, env)).rejects.toMatchObject({ status: 502 })
    expect(fetchMock).toHaveBeenCalledTimes(4)
  })
})
