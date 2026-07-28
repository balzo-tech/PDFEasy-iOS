import { afterEach, describe, expect, it, vi } from 'vitest'
import { forwardChat, forwardStirling } from '../src/upstream'
import { makeEnv } from './helpers'

function chatRequest(body: unknown): Request {
  return new Request('https://proxy.example/v1/chat', {
    method: 'POST',
    body: JSON.stringify(body),
    headers: { 'content-type': 'application/json' },
  })
}

function stubFetch(response = new Response('{}', { status: 200 })) {
  const spy = vi.fn(async (_input: RequestInfo | URL, _init?: RequestInit) => response)
  vi.stubGlobal('fetch', spy)
  return spy
}

/// What the upstream was called with, in the shape the assertions want.
function callArgs(spy: ReturnType<typeof stubFetch>): [string, RequestInit] {
  const [input, init] = spy.mock.calls[0]
  return [String(input), (init ?? {}) as RequestInit]
}

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('chat forwarding', () => {
  it('sends the key the app no longer has', async () => {
    const fetchSpy = stubFetch()
    await forwardChat(chatRequest({ model: 'gpt-4o-mini', messages: [{ role: 'user' }] }), makeEnv())
    const [url, init] = callArgs(fetchSpy)
    expect(url).toBe('https://api.openai.com/v1/chat/completions')
    expect((init.headers as Record<string, string>).Authorization).toBe('Bearer sk-test')
  })

  it('refuses a model that is not on the list', async () => {
    stubFetch()
    await expect(
      forwardChat(chatRequest({ model: 'gpt-4-turbo', messages: [{ role: 'user' }] }), makeEnv()),
    ).rejects.toMatchObject({ status: 400, code: 'model_not_allowed' })
  })

  it('refuses a request with no model at all', async () => {
    stubFetch()
    await expect(
      forwardChat(chatRequest({ messages: [{ role: 'user' }] }), makeEnv()),
    ).rejects.toMatchObject({ code: 'model_not_allowed' })
  })

  it('caps the token budget the caller asks for', async () => {
    const fetchSpy = stubFetch()
    await forwardChat(
      chatRequest({ model: 'gpt-4o-mini', messages: [{ role: 'user' }], max_tokens: 999_999 }),
      makeEnv(),
    )
    const [, init] = callArgs(fetchSpy)
    expect(JSON.parse(init.body as string).max_tokens).toBe(4096)
  })

  it('drops a streaming request rather than half-supporting it', async () => {
    const fetchSpy = stubFetch()
    await forwardChat(
      chatRequest({ model: 'gpt-4o-mini', messages: [{ role: 'user' }], stream: true }),
      makeEnv(),
    )
    const [, init] = callArgs(fetchSpy)
    expect(JSON.parse(init.body as string).stream).toBeUndefined()
  })

  it('refuses an empty conversation', async () => {
    stubFetch()
    await expect(
      forwardChat(chatRequest({ model: 'gpt-4o-mini', messages: [] }), makeEnv()),
    ).rejects.toMatchObject({ status: 400 })
  })

  it('says so when the key is missing rather than calling OpenAI without one', async () => {
    stubFetch()
    await expect(
      forwardChat(
        chatRequest({ model: 'gpt-4o-mini', messages: [{ role: 'user' }] }),
        makeEnv({ OPENAI_API_KEY: '' }),
      ),
    ).rejects.toMatchObject({ status: 500, code: 'not_configured' })
  })

  it('passes the upstream status back unchanged', async () => {
    stubFetch(new Response('{"error":{}}', { status: 429 }))
    const response = await forwardChat(
      chatRequest({ model: 'gpt-4o-mini', messages: [{ role: 'user' }] }),
      makeEnv(),
    )
    expect(response.status).toBe(429)
  })
})

describe('stirling forwarding', () => {
  function upload(): Request {
    return new Request('https://proxy.example/v1/stirling/repair', {
      method: 'POST',
      body: 'pretend-multipart',
      headers: { 'content-type': 'multipart/form-data; boundary=abc' },
    })
  }

  it('maps the operation name to the service path and adds the key', async () => {
    const fetchSpy = stubFetch()
    await forwardStirling(upload(), 'repair', makeEnv())
    const [url, init] = callArgs(fetchSpy)
    expect(url).toBe('https://stirling.example/api/v1/misc/repair')
    expect((init.headers as Record<string, string>)['X-API-KEY']).toBe('stirling-test')
  })

  it('keeps the multipart boundary, without which the upload is unreadable', async () => {
    const fetchSpy = stubFetch()
    await forwardStirling(upload(), 'repair', makeEnv())
    const [, init] = callArgs(fetchSpy)
    expect((init.headers as Record<string, string>)['Content-Type']).toContain('boundary=abc')
  })

  it('refuses an operation it does not know, rather than forwarding a path', async () => {
    stubFetch()
    await expect(
      forwardStirling(upload(), '../../admin/settings', makeEnv()),
    ).rejects.toMatchObject({ status: 404, code: 'unknown_operation' })
  })

  it('refuses when nobody has said where Stirling lives', async () => {
    stubFetch()
    await expect(
      forwardStirling(upload(), 'repair', makeEnv({ STIRLING_BASE_URL: '' })),
    ).rejects.toMatchObject({ code: 'not_configured' })
  })

  it('tolerates a base url with a trailing slash', async () => {
    const fetchSpy = stubFetch()
    await forwardStirling(upload(), 'repair', makeEnv({ STIRLING_BASE_URL: 'https://s.example/' }))
    const [url] = callArgs(fetchSpy)
    expect(url).toBe('https://s.example/api/v1/misc/repair')
  })

  it('keeps the filename hint the app derives the extension from', async () => {
    stubFetch(
      new Response('ok', {
        status: 200,
        headers: { 'content-disposition': 'attachment; filename="out.docx"' },
      }),
    )
    const response = await forwardStirling(upload(), 'pdfToWord', makeEnv())
    expect(response.headers.get('content-disposition')).toContain('out.docx')
  })
})
