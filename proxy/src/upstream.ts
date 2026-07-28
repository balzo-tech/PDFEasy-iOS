//
//  upstream.ts
//
//  The two hops the keys are needed for, and the shape of what may be asked.
//
//  A proxy that forwards whatever it is handed is a key with extra steps: give
//  it a body naming an expensive model and a huge token budget and it will pay
//  for it. So both routes are narrow — a fixed path, a checked model, a capped
//  size — and everything else is refused before a byte leaves.
//

import { RequestRejected, type Env } from './types'

/// Models the app is allowed to ask for. Adding one here is a deliberate act
/// with a price attached; the app naming its own would not be.
const ALLOWED_MODELS = new Set(['gpt-4o-mini', 'gpt-4o', 'gpt-4.1-mini'])

const MAX_COMPLETION_TOKENS = 4096
const MAX_CHAT_BODY_BYTES = 512 * 1024

/// Stirling operations, mapped to the paths the service exposes. The app sends
/// the name, never a path: a caller that could choose the path could reach any
/// endpoint on the Stirling host.
const STIRLING_PATHS: Record<string, string> = {
  pdfToWord: '/api/v1/convert/pdf/word',
  pdfToPresentation: '/api/v1/convert/pdf/presentation',
  pdfToCsv: '/api/v1/convert/pdf/csv',
  pdfToPdfa: '/api/v1/convert/pdf/pdfa',
  repair: '/api/v1/misc/repair',
  sanitize: '/api/v1/security/sanitize-pdf',
  fileToPdf: '/api/v1/convert/file/pdf',
}

const MAX_UPLOAD_BYTES = 32 * 1024 * 1024

export async function forwardChat(request: Request, env: Env): Promise<Response> {
  if (!env.OPENAI_API_KEY) {
    throw new RequestRejected(500, 'not_configured', 'OPENAI_API_KEY is not set')
  }
  const raw = await request.text()
  if (raw.length > MAX_CHAT_BODY_BYTES) {
    throw new RequestRejected(413, 'body_too_large', 'Chat request is too large')
  }
  let body: Record<string, unknown>
  try {
    body = JSON.parse(raw)
  } catch {
    throw new RequestRejected(400, 'bad_request', 'Chat request is not JSON')
  }

  const model = typeof body.model === 'string' ? body.model : ''
  if (!ALLOWED_MODELS.has(model)) {
    throw new RequestRejected(400, 'model_not_allowed', `Model ${model || '(none)'} is not allowed`)
  }
  if (!Array.isArray(body.messages) || body.messages.length === 0) {
    throw new RequestRejected(400, 'bad_request', 'Chat request has no messages')
  }
  const requested = typeof body.max_tokens === 'number' ? body.max_tokens : MAX_COMPLETION_TOKENS
  body.max_tokens = Math.min(Math.max(1, requested), MAX_COMPLETION_TOKENS)
  // Streaming would need the response piped back rather than read; the app does
  // not ask for it, so it is refused rather than half-supported.
  delete body.stream

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  })
  return passThrough(response)
}

export async function forwardStirling(
  request: Request,
  operation: string,
  env: Env,
): Promise<Response> {
  const path = STIRLING_PATHS[operation]
  if (!path) {
    throw new RequestRejected(404, 'unknown_operation', `No such operation: ${operation}`)
  }
  if (!env.STIRLING_BASE_URL) {
    throw new RequestRejected(500, 'not_configured', 'STIRLING_BASE_URL is not set')
  }
  if (!env.STIRLING_API_KEY) {
    throw new RequestRejected(500, 'not_configured', 'STIRLING_API_KEY is not set')
  }
  const declared = Number(request.headers.get('content-length') ?? '0')
  if (declared > MAX_UPLOAD_BYTES) {
    throw new RequestRejected(413, 'body_too_large', 'Document is too large')
  }

  const base = env.STIRLING_BASE_URL.replace(/\/+$/, '')
  const response = await fetch(`${base}${path}`, {
    method: 'POST',
    headers: {
      'X-API-KEY': env.STIRLING_API_KEY,
      // The multipart boundary is in the original header and must survive.
      'Content-Type': request.headers.get('content-type') ?? 'multipart/form-data',
    },
    body: request.body,
  })
  return passThrough(response)
}

/// Copies the upstream answer back, minus the hop-by-hop headers a Worker must
/// not repeat, and keeps the filename hint the app derives extensions from.
function passThrough(response: Response): Response {
  const headers = new Headers()
  for (const name of ['content-type', 'content-disposition', 'content-length']) {
    const value = response.headers.get(name)
    if (value) headers.set(name, value)
  }
  return new Response(response.body, { status: response.status, headers })
}

export const testing = { ALLOWED_MODELS, STIRLING_PATHS, MAX_COMPLETION_TOKENS }
