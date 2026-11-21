import { randomBytes } from 'node:crypto';

import type { Request } from 'express';
import { describe, expect, it } from 'vitest';

import { parseSessionToken } from 'app/services/parseSessionTokenParser.js';

const token = randomBytes(32).toString('hex');

function parse(input: { authorization?: string; cookie?: string }) {
  const req = {
    cookies: input.cookie === undefined ? {} : { sid: input.cookie },
    headers:
      input.authorization === undefined
        ? {}
        : { authorization: input.authorization },
    header(name: string) {
      return name.toLowerCase() === 'authorization'
        ? input.authorization
        : undefined;
    },
  } as unknown as Request;
  return parseSessionToken(req);
}

describe('parseSessionToken', () => {
  it('returns none when no credentials are sent', () => {
    expect(parse({})).toEqual({ kind: 'none' });
  });

  it('returns the cookie token', () => {
    expect(parse({ cookie: token })).toEqual({
      kind: 'token',
      source: 'cookie',
      token,
    });
  });

  it('returns the bearer token', () => {
    expect(parse({ authorization: `Bearer ${token}` })).toEqual({
      kind: 'token',
      source: 'bearer',
      token,
    });
  });

  it('matches the scheme case-insensitively and trims whitespace', () => {
    expect(parse({ authorization: `bearer   ${token}  ` })).toEqual({
      kind: 'token',
      source: 'bearer',
      token,
    });
    expect(parse({ authorization: `BEARER ${token}` })).toEqual({
      kind: 'token',
      source: 'bearer',
      token,
    });
  });

  it('returns conflict when a cookie and a bearer header are both sent', () => {
    expect(parse({ authorization: `Bearer ${token}`, cookie: token })).toEqual({
      kind: 'conflict',
    });
  });

  it('returns none for a bearer header with no value', () => {
    expect(parse({ authorization: 'Bearer' })).toEqual({ kind: 'none' });
  });

  it('returns none for an oversized bearer value', () => {
    expect(parse({ authorization: `Bearer ${'a'.repeat(10_000)}` })).toEqual({
      kind: 'none',
    });
  });

  it('returns none for an uppercase hex bearer value', () => {
    expect(parse({ authorization: `Bearer ${token.toUpperCase()}` })).toEqual({
      kind: 'none',
    });
  });

  it('returns none for a non-hex bearer value of the right length', () => {
    expect(parse({ authorization: `Bearer ${'z'.repeat(64)}` })).toEqual({
      kind: 'none',
    });
  });

  it('ignores a non-bearer Authorization header', () => {
    expect(parse({ authorization: `Basic ${token}` })).toEqual({
      kind: 'none',
    });
  });

  it('uses the cookie when the Authorization header is not bearer', () => {
    expect(parse({ authorization: `Basic ${token}`, cookie: token })).toEqual({
      kind: 'token',
      source: 'cookie',
      token,
    });
  });
});
