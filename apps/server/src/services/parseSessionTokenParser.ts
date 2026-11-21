import type { Request } from 'express';

import {
  SESSION_COOKIE_NAME,
  SESSION_TOKEN_PATTERN,
} from 'app/constants/sessionConstants.js';

type ParsedSessionToken =
  | { kind: 'conflict' }
  | { kind: 'none' }
  | { kind: 'token'; source: 'bearer' | 'cookie'; token: string };

const BEARER_SCHEME = 'bearer';

function readAuthorizationHeader(req: Request): string | undefined {
  const value = req.headers?.authorization;
  return typeof value === 'string' ? value : undefined;
}

/**
 * Reads the session token from the request. A session cookie and a bearer
 * Authorization header together are a conflict. A bearer value must be 64
 * lowercase hex characters. Non-bearer Authorization schemes are ignored.
 */
function parseSessionToken(req: Request): ParsedSessionToken {
  const cookie = req.cookies?.[SESSION_COOKIE_NAME] as unknown;
  const cookieToken = typeof cookie === 'string' && cookie ? cookie : undefined;

  const header = readAuthorizationHeader(req)?.trim() ?? '';
  const scheme = header.slice(0, BEARER_SCHEME.length).toLowerCase();
  const rest = header.slice(BEARER_SCHEME.length);
  // The scheme must end at the header end or at whitespace ("Bearerx" is not bearer).
  const isBearer =
    scheme === BEARER_SCHEME && (rest === '' || /^\s/.test(rest));

  if (isBearer) {
    if (cookieToken) return { kind: 'conflict' };
    const bearerToken = rest.trim();
    if (SESSION_TOKEN_PATTERN.test(bearerToken)) {
      return { kind: 'token', source: 'bearer', token: bearerToken };
    }
    return { kind: 'none' };
  }

  if (cookieToken)
    return { kind: 'token', source: 'cookie', token: cookieToken };
  return { kind: 'none' };
}

export { parseSessionToken };
export type { ParsedSessionToken };
