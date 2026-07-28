export interface Env {
  // Secrets
  OPENAI_API_KEY: string
  STIRLING_API_KEY: string
  APPLE_PRIVATE_KEY: string
  // Vars
  FIREBASE_PROJECT_NUMBER: string
  APPLE_KEY_ID: string
  APPLE_ISSUER_ID: string
  APPLE_BUNDLE_IDS: string
  STIRLING_BASE_URL: string
  CHAT_MONTHLY_LIMIT: string
  STIRLING_MONTHLY_LIMIT: string
  IP_RATE_LIMIT: string
  // Bindings
  LIMITS: KVNamespace
}

/// Anything that stops a request before it reaches an upstream. Carries the
/// status the app should see and a code it can branch on — the app has to tell
/// "your subscription lapsed" apart from "you have used this month's messages".
export class RequestRejected extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message)
  }

  toResponse(): Response {
    return Response.json(
      { error: { code: this.code, message: this.message } },
      { status: this.status },
    )
  }
}
