# pdfpro-proxy

The Cloudflare Worker that holds the API keys PDF Pro used to carry in its
bundle.

## Why it exists

The OpenAI key was compiled into the app, XOR-obfuscated against a pad that
changes every build. That stops `strings` on the binary and nothing else: the app
has to undo the obfuscation to use the key, so a debugger attached to the process
reads it in cleartext. Whoever reads it spends it, and the invoice arrives at
Balzo.

Moving the key here is only half the job. An endpoint that forwards for anybody
is the same key with a URL in front of it. So each request has to earn its way
to an upstream, in this order — cheapest check first:

| # | Check | Refuses with |
|---|-------|--------------|
| 1 | Requests per minute from this IP | `429 rate_limited` |
| 2 | Firebase App Check token (App Attest underneath) | `401 app_check_invalid` |
| 3 | Apple says the subscription is active | `402 subscription_expired` |
| 4 | This month's allowance for this subscriber | `429 monthly_limit_reached` |

Check 3 is also the first time the paywall is enforced anywhere but the UI: the
app's own `isPremium` was a check in front of a screen, and an HTTP client
skipped it. Check 4 replaces `ChatUsageTracker`, which counted the monthly
allowance in the app's own UserDefaults — on the device it was meant to
restrain, and reset by reinstalling. Counted here against Apple's
`originalTransactionId`, it survives reinstalls and new devices.

## Routes

    POST /v1/chat                    → api.openai.com/v1/chat/completions
    POST /v1/stirling/{operation}    → {STIRLING_BASE_URL}/{mapped path}
    GET  /health                     → {"ok":true}, checks nothing

Both need `X-App-Check` and `X-Original-Transaction-Id`.

The chat route only forwards a body naming an allowed model, and caps
`max_tokens`; the Stirling route takes an operation *name* and maps it to a path
itself, because a caller that could choose the path could reach any endpoint on
the Stirling host.

## Where it is

    https://pdfpro-proxy.giuseppe-c9b.workers.dev

Deployed on the **Balzo** Cloudflare account (`account_id` is in `wrangler.toml`;
the token can see three accounts and a deploy has to say which). The KV namespace
`pdfpro-proxy-LIMITS` is already created and bound.

Deployed and answering, but **not yet configured**: with no secrets and no
`FIREBASE_PROJECT_NUMBER` it refuses everything, which is the correct state for a
proxy nobody has given keys to. `/health` answers `{"ok":true}`; every other
route answers 401 until App Check is set up.

## Setting it up

    npm install
    npx wrangler secret put OPENAI_API_KEY
    npx wrangler secret put STIRLING_API_KEY
    npx wrangler secret put APPLE_PRIVATE_KEY      # the whole .p8, BEGIN/END included
    npx wrangler deploy                            # after filling in [vars]

The KV namespace step is done:

    [[kv_namespaces]]
    binding = "LIMITS"
    id = "77d0eede826e41459f52126bfeaa64b5"

Then fill in `[vars]` in `wrangler.toml`:

- `FIREBASE_PROJECT_NUMBER` — the project *number* from the Firebase console
  (Project settings → General), not the project id.
- `APPLE_KEY_ID` / `APPLE_ISSUER_ID` — from App Store Connect → Users and Access
  → Integrations → In-App Purchase, where you also generate the `.p8`. Download
  it once; Apple will not show it again.
- `STIRLING_BASE_URL` — where your Stirling-PDF instance actually answers. No
  default on purpose: a wrong host here would send customers' documents
  somewhere nobody chose.

## What has to happen on the Firebase side

App Check has to be turned on for the iOS app with the **App Attest** provider
(Firebase console → Build → App Check), and the app's Team ID and bundle id
registered there. Until that is done, `verifyAppCheck` refuses every request —
which is the correct failure: an unconfigured proxy is an open key.

While rolling out, App Check has a *monitoring* mode in the Firebase console
that reports how many requests would have been refused without blocking them.
Worth a day or two there before enforcing.

## Tests

    npm test          # 34 cases, no network, no account needed
    npm run typecheck

They cover the limits, the two upstreams and — the part worth having — the order
the checks run in: that a request which fails attestation never reaches Apple or
the quota, and that an unexpected failure inside the worker does not leak to the
caller.

What they cannot cover is a real App Check token or a real Apple answer; both
need credentials this repo does not have. `/health` plus the Cloudflare logs are
how you confirm those two after deploying.
