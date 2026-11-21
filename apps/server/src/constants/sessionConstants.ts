/** Cookie name for the session id. */
export const SESSION_COOKIE_NAME = 'sid';

/** Single source of truth for session lifetime (cookie maxAge and DB expires_at). */
export const SESSION_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

/** Pattern a session token must match: 64 lowercase hex characters. */
export const SESSION_TOKEN_PATTERN = /^[a-f0-9]{64}$/;

/** Request header a native client sends to receive the session token in the body. */
export const SESSION_TRANSPORT_HEADER = 'X-Session-Transport';

/** Value of the transport header that opts in to the bearer token transport. */
export const SESSION_TRANSPORT_TOKEN = 'token';
