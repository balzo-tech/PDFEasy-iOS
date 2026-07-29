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

**Configured and live** since 2026-07-29: all three secrets uploaded, every
`[vars]` filled in, deployed. Confirmed from the outside with curl — `/health`
answers, every other route answers `401 app_check_invalid` without a token, and
the per-IP ceiling trips at 30/min with a `429`, which also proves the KV writes
and that the checks run in the order above.

What curl cannot reach is everything behind check 2: that the OpenAI key works,
that Stirling accepts its own, that Apple answers about the subscription, and
that the monthly counters add up. All four need a real App Check token, which
needs a device.

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

- `FIREBASE_PROJECT_NUMBERS` — already filled in: the project *numbers* from the
  Firebase console (Project settings → General), not the project ids. Production
  and staging, comma-separated, because the two builds are two apps to Firebase
  and each mints its own App Check tokens. A worker that knew only production
  would refuse the staging build — which is the build the app is tested with.
- `APPLE_KEY_ID` / `APPLE_ISSUER_ID` — from App Store Connect → Users and Access
  → Integrations → In-App Purchase, where you also generate the `.p8`. Download
  it once; Apple will not show it again.
- `APPLE_BUNDLE_IDS` — read positionally against `FIREBASE_PROJECT_NUMBERS`:
  first with first. The JWT sent to Apple names one app in its `bid` claim, and
  Apple answers 404 about a transaction belonging to any other — so a staging
  subscription asked about under the production bundle id reads as no
  subscription at all. Which app to name comes from the App Check token's
  project, so it is as trustworthy as the attestation. Keep the two lists in the
  same order.
- `STIRLING_BASE_URL` — already filled in with `https://api.stirling.com`,
  Stirling's own hosted API. It runs the same software a self-hosted instance
  does: `/api/v1/info/status` answers `{"version":"2.14.1","status":"UP"}`, and
  the OpenAPI at `/v1/api-docs` contains all seven paths in `upstream.ts` and
  declares `X-API-KEY` as its scheme. Point it at your own instance instead if
  you would rather the documents not leave your infrastructure — there is no
  default in the code on purpose, because a wrong host here would send
  customers' documents somewhere nobody chose.

## What has to happen on the Firebase side

App Check has to be turned on with the **App Attest** provider (Firebase console
→ Build → App Check) in **both** projects — `pdf-expert-270b1` for
`eu.balzo.pdfexpert` and `pdf-expert-staging` for `eu.balzo.pdfexpert.staging` —
with the Team ID `G6RAKRKZPR` registered against each. The two builds are two
apps to Firebase and mint their own tokens; a project that is not registered
mints nothing, and `verifyAppCheck` refuses every request from it.

That registration is the whole of it. In particular:

**Do not turn on enforcement.** The *enforced / monitoring / unenforced* switch
in the console governs Firebase's own backends — Remote Config, Firestore,
Storage — and has no bearing on this worker, which verifies the JWT itself and
always blocks. There is no gradual rollout to be had here: from the first
request the worker either accepts a token or refuses it. Turning enforcement on
for Remote Config would only add a way for the app to lose its configuration,
which is a risk taken for nothing. What monitoring would have given you is in
the Cloudflare logs instead (`[observability]` is enabled in `wrangler.toml`);
a refusal appears there as `401 app_check_invalid`.

**A debug build needs its token registered.** `PdfProAppCheckProviderFactory`
uses App Attest only in release: App Attest needs a Secure Enclave, so the
simulator and the test bundles have none to offer, and a DEBUG build uses
Firebase's debug provider. The app prints the token in a box on launch — from
`AppCheckProviderFactory.swift`, not from Firebase, whose own log line is
emitted by a factory this app does not use. Paste it into App Check → the app →
⋮ → Manage debug tokens, **in the project that build belongs to** (staging
build → staging project). Until then it is refused exactly like a forged token.
The token is a bypass of App Check for whoever holds it: it does not belong in
the repository, in a scheme that is committed, or in a screenshot.

## Tests

    npm test          # 66 cases, no network, no account needed
    npm run typecheck

They cover the limits, the two upstreams and — the part worth having — the order
the checks run in: that a request which fails attestation never reaches Apple or
the quota, and that an unexpected failure inside the worker does not leak to the
caller.

What they cannot cover is a real App Check token or a real Apple answer; both
need credentials this repo does not have. `/health` plus the Cloudflare logs are
how you confirm those two after deploying.
