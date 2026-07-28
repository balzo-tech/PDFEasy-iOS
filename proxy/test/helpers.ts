import type { Env } from '../src/types'

export interface TestEnv extends Env {
  __store: Map<string, string>
  __ttls: Map<string, number>
}

/// A KV stand-in: a Map, plus the TTLs it was asked for so the tests can assert
/// that a counter is set to disappear when the month does.
export function makeEnv(overrides: Partial<Env> = {}): TestEnv {
  const store = new Map<string, string>()
  const ttls = new Map<string, number>()
  const kv = {
    async get(key: string) {
      return store.has(key) ? store.get(key)! : null
    },
    async put(key: string, value: string, options?: { expirationTtl?: number }) {
      store.set(key, value)
      if (options?.expirationTtl) ttls.set(key, options.expirationTtl)
    },
    async delete(key: string) {
      store.delete(key)
      ttls.delete(key)
    },
  }
  return {
    OPENAI_API_KEY: 'sk-test',
    STIRLING_API_KEY: 'stirling-test',
    APPLE_PRIVATE_KEY: '',
    FIREBASE_PROJECT_NUMBER: '1234567890',
    APPLE_KEY_ID: 'KEYID',
    APPLE_ISSUER_ID: 'ISSUER',
    APPLE_BUNDLE_IDS: 'eu.balzo.pdfexpert,eu.balzo.pdfexpert.staging',
    STIRLING_BASE_URL: 'https://stirling.example',
    CHAT_MONTHLY_LIMIT: '20',
    STIRLING_MONTHLY_LIMIT: '50',
    IP_RATE_LIMIT: '30',
    LIMITS: kv as unknown as KVNamespace,
    ...overrides,
    __store: store,
    __ttls: ttls,
  }
}
