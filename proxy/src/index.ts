//
//  index.ts
//
//  PDF Pro's proxy.
//
//  The app used to carry the OpenAI key in its bundle, XOR-obfuscated. The
//  obfuscation raises the bar and nothing more: the app has to undo it to use
//  the key, so a debugger on the device reads it. Whoever reads it spends it,
//  and the bill arrives here. The key now lives in this Worker and the app
//  never sees one.
//
//  Moving the key is only half of it. An open endpoint is the same key with a
//  URL in front, so every request has to earn its way to an upstream:
//
//    1. a ceiling per IP, against scripted traffic
//    2. App Check, proving this is the real app on a real device
//    3. Apple, asked whether the subscription is actually active
//    4. this month's allowance, counted where the device cannot reach it
//
//  In that order, cheapest first: the checks that cost a network call happen
//  only for callers that have already passed the ones that do not.
//

import { verifyAppCheck } from './appcheck'
import { verifyEntitlement } from './entitlement'
import { chargeIpRateLimit, chargeMonthlyQuota } from './limits'
import { RequestRejected, type Env } from './types'
import { forwardChat, forwardStirling } from './upstream'

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return await route(request, env)
    } catch (error) {
      if (error instanceof RequestRejected) {
        return error.toResponse()
      }
      console.error('unhandled', error)
      return Response.json(
        { error: { code: 'internal', message: 'Something went wrong' } },
        { status: 500 },
      )
    }
  },
}

async function route(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url)

  if (request.method === 'GET' && url.pathname === '/health') {
    return Response.json({ ok: true })
  }
  if (request.method !== 'POST') {
    throw new RequestRejected(405, 'method_not_allowed', 'Only POST is accepted')
  }

  const chat = url.pathname === '/v1/chat'
  const stirling = url.pathname.startsWith('/v1/stirling/')
  if (!chat && !stirling) {
    throw new RequestRejected(404, 'not_found', 'No such route')
  }

  await chargeIpRateLimit(
    env,
    request.headers.get('cf-connecting-ip') ?? '',
    Number(env.IP_RATE_LIMIT ?? '0'),
  )

  // App Check throws plain errors; they become a 401 here rather than leaking
  // as a 500, and the message stays vague on purpose — a caller that failed
  // attestation does not get told which part it failed.
  try {
    await verifyAppCheck(request.headers.get('x-app-check'), env.FIREBASE_PROJECT_NUMBER)
  } catch (error) {
    if (error instanceof RequestRejected) throw error
    throw new RequestRejected(401, 'app_check_invalid', 'App Check token rejected')
  }

  const subscriber = await verifyEntitlement(
    request.headers.get('x-original-transaction-id'),
    env,
  )

  if (chat) {
    await chargeMonthlyQuota(
      env,
      'chat',
      subscriber.originalTransactionId,
      Number(env.CHAT_MONTHLY_LIMIT ?? '0'),
    )
    return forwardChat(request, env)
  }

  const operation = url.pathname.slice('/v1/stirling/'.length)
  await chargeMonthlyQuota(
    env,
    'stirling',
    subscriber.originalTransactionId,
    Number(env.STIRLING_MONTHLY_LIMIT ?? '0'),
  )
  return forwardStirling(request, operation, env)
}
