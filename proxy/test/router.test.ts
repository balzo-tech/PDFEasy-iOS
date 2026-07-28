import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { RequestRejected } from '../src/types'
import { makeEnv } from './helpers'

// The two checks that need the network are stubbed: what is under test here is
// the order they run in and what happens when one says no.
const verifyAppCheck = vi.fn<(token: string | null, project: string) => Promise<unknown>>()
const verifyEntitlement = vi.fn<(id: string | null, env: unknown) => Promise<unknown>>()
const forwardChat = vi.fn(async (_request: Request, _env: unknown) =>
  new Response('chat', { status: 200 }),
)
const forwardStirling = vi.fn(async (_request: Request, _operation: string, _env: unknown) =>
  new Response('doc', { status: 200 }),
)

vi.mock('../src/appcheck', () => ({ verifyAppCheck }))
vi.mock('../src/entitlement', () => ({ verifyEntitlement }))
vi.mock('../src/upstream', () => ({ forwardChat, forwardStirling }))

const { default: worker } = await import('../src/index')

function post(path: string, headers: Record<string, string> = {}): Request {
  return new Request(`https://proxy.example${path}`, {
    method: 'POST',
    body: '{}',
    headers: { 'cf-connecting-ip': '9.9.9.9', ...headers },
  })
}

const goodHeaders = { 'x-app-check': 'token', 'x-original-transaction-id': '1000000000000001' }

beforeEach(() => {
  verifyAppCheck.mockResolvedValue({ appId: 'app' })
  verifyEntitlement.mockResolvedValue({ originalTransactionId: '1000000000000001' })
})

afterEach(() => {
  vi.clearAllMocks()
})

describe('routing', () => {
  it('answers health without asking anything of the caller', async () => {
    const response = await worker.fetch(new Request('https://proxy.example/health'), makeEnv())
    expect(response.status).toBe(200)
    expect(verifyAppCheck).not.toHaveBeenCalled()
  })

  it('refuses anything but POST on the real routes', async () => {
    const response = await worker.fetch(new Request('https://proxy.example/v1/chat'), makeEnv())
    expect(response.status).toBe(405)
  })

  it('has nothing at an unknown path', async () => {
    const response = await worker.fetch(post('/v1/anything'), makeEnv())
    expect(response.status).toBe(404)
  })

  it('forwards a chat once every check has passed', async () => {
    const response = await worker.fetch(post('/v1/chat', goodHeaders), makeEnv())
    expect(response.status).toBe(200)
    expect(forwardChat).toHaveBeenCalledOnce()
  })

  it('passes the operation name through to Stirling', async () => {
    await worker.fetch(post('/v1/stirling/repair', goodHeaders), makeEnv())
    expect(forwardStirling.mock.calls[0][1]).toBe('repair')
  })
})

describe('what has to be true before anything is spent', () => {
  it('stops at App Check, without asking Apple or touching the quota', async () => {
    verifyAppCheck.mockRejectedValue(new Error('nope'))
    const env = makeEnv()
    const response = await worker.fetch(post('/v1/chat', goodHeaders), env)
    expect(response.status).toBe(401)
    expect(verifyEntitlement).not.toHaveBeenCalled()
    expect(forwardChat).not.toHaveBeenCalled()
    expect(env.__store.size).toBe(1) // the rate-limit counter, nothing else
  })

  it('stops when the subscription has lapsed, before the upstream', async () => {
    verifyEntitlement.mockRejectedValue(
      new RequestRejected(402, 'subscription_expired', 'not active'),
    )
    const response = await worker.fetch(post('/v1/chat', goodHeaders), makeEnv())
    expect(response.status).toBe(402)
    expect(await response.json()).toMatchObject({ error: { code: 'subscription_expired' } })
    expect(forwardChat).not.toHaveBeenCalled()
  })

  it('stops once the month is spent, and says which limit was hit', async () => {
    const env = makeEnv({ CHAT_MONTHLY_LIMIT: '1' })
    await worker.fetch(post('/v1/chat', goodHeaders), env)
    const second = await worker.fetch(post('/v1/chat', goodHeaders), env)
    expect(second.status).toBe(429)
    expect(await second.json()).toMatchObject({ error: { code: 'monthly_limit_reached' } })
    expect(forwardChat).toHaveBeenCalledOnce()
  })

  it('counts chat and stirling separately, so one cannot starve the other', async () => {
    const env = makeEnv({ CHAT_MONTHLY_LIMIT: '1', STIRLING_MONTHLY_LIMIT: '1' })
    await worker.fetch(post('/v1/chat', goodHeaders), env)
    const stirling = await worker.fetch(post('/v1/stirling/repair', goodHeaders), env)
    expect(stirling.status).toBe(200)
  })

  it('turns the address away before it costs a lookup', async () => {
    const env = makeEnv({ IP_RATE_LIMIT: '1' })
    await worker.fetch(post('/v1/chat', goodHeaders), env)
    vi.clearAllMocks()
    verifyAppCheck.mockResolvedValue({ appId: 'app' })
    const second = await worker.fetch(post('/v1/chat', goodHeaders), env)
    expect(second.status).toBe(429)
    expect(verifyAppCheck).not.toHaveBeenCalled()
  })

  it('does not leak an unexpected failure to the caller', async () => {
    verifyEntitlement.mockRejectedValue(new Error('kv exploded'))
    const response = await worker.fetch(post('/v1/chat', goodHeaders), makeEnv())
    expect(response.status).toBe(500)
    expect(await response.text()).not.toContain('kv exploded')
  })
})
