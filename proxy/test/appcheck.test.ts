//
//  appcheck.test.ts
//
//  The parts of App Check verification that do not need a real Firebase key.
//
//  `verifyAppCheck` itself is not exercised here: it fetches Firebase's JWKS and
//  checks an RS256 signature, and faking that would test `jose` rather than this
//  worker. What is worth testing is the part written here — which projects a
//  token is allowed to come from, and the refusal to take a token that names two
//  of them.
//

import { describe, expect, it } from 'vitest'
import { bundleIdForProject, matchingProject, parseList, verifyAppCheck } from '../src/appcheck'

const PRODUCTION = '950539290225'
const STAGING = '971070997447'
const NUMBERS = `${PRODUCTION},${STAGING}`
const BUNDLE_IDS = 'eu.balzo.pdfexpert,eu.balzo.pdfexpert.staging'

const issuerOf = (number: string) => `https://firebaseappcheck.googleapis.com/${number}`

describe('parseList', () => {
  it('reads a single project', () => {
    expect(parseList(PRODUCTION)).toEqual([PRODUCTION])
  })

  it('reads a list, and tolerates the spacing a human leaves', () => {
    expect(parseList(` ${PRODUCTION} , ${STAGING} `)).toEqual([PRODUCTION, STAGING])
  })

  it('drops empty entries rather than keeping a project that matches nothing', () => {
    expect(parseList(`${PRODUCTION},,`)).toEqual([PRODUCTION])
  })

  it('reads an unset var as no projects at all', () => {
    expect(parseList('')).toEqual([])
    expect(parseList('  ,  ')).toEqual([])
  })
})

describe('bundleIdForProject', () => {
  it('gives the production app for the production project', () => {
    expect(bundleIdForProject(NUMBERS, BUNDLE_IDS, PRODUCTION)).toBe('eu.balzo.pdfexpert')
  })

  it('gives the staging app for the staging project — the whole point', () => {
    expect(bundleIdForProject(NUMBERS, BUNDLE_IDS, STAGING)).toBe('eu.balzo.pdfexpert.staging')
  })

  it('has nothing to say about a project that is not configured', () => {
    expect(bundleIdForProject(NUMBERS, BUNDLE_IDS, '1111111111')).toBeNull()
  })

  it('refuses to guess when the two lists are not the same length', () => {
    // Rather than falling back to the first bundle id, which is the bug this
    // function exists to fix.
    expect(bundleIdForProject(NUMBERS, 'eu.balzo.pdfexpert', STAGING)).toBeNull()
  })
})

describe('matchingProject', () => {
  const numbers = [PRODUCTION, STAGING]

  it('accepts a production token', () => {
    expect(matchingProject(numbers, issuerOf(PRODUCTION), `projects/${PRODUCTION}`)).toBe(PRODUCTION)
  })

  it('accepts a staging token — the reason the list exists', () => {
    expect(matchingProject(numbers, issuerOf(STAGING), `projects/${STAGING}`)).toBe(STAGING)
  })

  it('accepts the array audience Firebase actually sends', () => {
    const audience = [`projects/${PRODUCTION}`, 'projects/pdf-expert-270b1']
    expect(matchingProject(numbers, issuerOf(PRODUCTION), audience)).toBe(PRODUCTION)
  })

  it('refuses a project that is not configured', () => {
    expect(matchingProject(numbers, issuerOf('1111111111'), 'projects/1111111111')).toBeNull()
  })

  it('refuses a token that names one project as issuer and another as audience', () => {
    expect(matchingProject(numbers, issuerOf(PRODUCTION), `projects/${STAGING}`)).toBeNull()
  })

  it('refuses a token with no issuer or audience at all', () => {
    expect(matchingProject(numbers, undefined, undefined)).toBeNull()
  })

  it('matches nothing when no project is configured', () => {
    expect(matchingProject([], issuerOf(PRODUCTION), `projects/${PRODUCTION}`)).toBeNull()
  })
})

describe('verifyAppCheck', () => {
  it('refuses a missing token before touching the network', async () => {
    await expect(verifyAppCheck(null, PRODUCTION)).rejects.toThrow(/missing App Check token/)
  })

  it('refuses everything when the worker has no project configured', async () => {
    await expect(verifyAppCheck('a.b.c', '')).rejects.toThrow(/no Firebase project number/)
  })
})
