import { randomBytes } from 'node:crypto';

import request from 'supertest';
import { beforeEach, describe, expect, it } from 'vitest';

import { createApp } from 'app/app.js';
import { query, withTransaction } from 'app/database/databasePool.js';

const { app: testApp } = createApp({ query, withTransaction });

const DB_AVAILABLE = !!process.env.DATABASE_URL;

const CSRF_HEADER = 'X-Requested-With';
const CSRF_VALUE = 'XMLHttpRequest';
const TRANSPORT_HEADER = 'X-Session-Transport';
const TRANSPORT_VALUE = 'token';
const CARDS_PATH = '/v1/demo/cards';

/**
 * Demo cards endpoint against the real app and a real database, with a bearer
 * session. Skips when DATABASE_URL is not set. Tests that assert a rejection
 * the middleware could produce on a missing route (413, 403) are paired with a
 * request that must return 201, so they fail until the route exists.
 */
describe.skipIf(!DB_AVAILABLE)('demo cards integration', () => {
  let sessionToken: string;

  function agent() {
    return request(testApp);
  }

  function postCards(body: unknown) {
    return agent()
      .post(CARDS_PATH)
      .set(CSRF_HEADER, CSRF_VALUE)
      .set('Authorization', `Bearer ${sessionToken}`)
      .send(body as object);
  }

  beforeEach(async () => {
    const res = await agent()
      .post('/v1/auth/register')
      .set(CSRF_HEADER, CSRF_VALUE)
      .set(TRANSPORT_HEADER, TRANSPORT_VALUE)
      .send({
        email: `demo-${randomBytes(8).toString('hex')}@example.com`,
        password: randomBytes(12).toString('hex'),
      });
    expect(res.status).toBe(201);
    sessionToken = res.body.sessionToken as string;
  });

  it.each(['message', 'prompt'] as const)(
    'returns 201 and a %s card for a valid session',
    async (kind) => {
      const res = await postCards({ kind });

      expect(res.status).toBe(201);
      expect(res.body.card.kind).toBe(kind);
      expect(typeof res.body.card.id).toBe('string');
    },
  );

  it('returns 401 AUTH_REQUIRED without a session, while a session succeeds', async () => {
    const ok = await postCards({ kind: 'message' });
    expect(ok.status).toBe(201);

    const res = await agent()
      .post(CARDS_PATH)
      .set(CSRF_HEADER, CSRF_VALUE)
      .send({ kind: 'message' });

    expect(res.status).toBe(401);
    expect(res.body.code).toBe('AUTH_REQUIRED');
  });

  it.each([
    ['unknown kind', { kind: 'other' }],
    ['missing kind', {}],
    ['extra key', { extra: 1, kind: 'message' }],
    ['operator object as kind', { kind: { $ne: 1 } }],
  ])('returns 400 INPUT_VALIDATION_ERROR for %s', async (_name, body) => {
    const res = await postCards(body);

    expect(res.status).toBe(400);
    expect(res.body.code).toBe('INPUT_VALIDATION_ERROR');
  });

  it('returns 413 for a body over 10 kb, while a normal body succeeds', async () => {
    const ok = await postCards({ kind: 'message' });
    expect(ok.status).toBe(201);

    const res = await postCards({
      kind: 'message',
      pad: 'x'.repeat(11 * 1024),
    });

    expect(res.status).toBe(413);
  });

  it('returns 403 without X-Requested-With, while a request with it succeeds', async () => {
    const ok = await postCards({ kind: 'message' });
    expect(ok.status).toBe(201);

    const res = await agent()
      .post(CARDS_PATH)
      .set('Authorization', `Bearer ${sessionToken}`)
      .send({ kind: 'message' });

    expect(res.status).toBe(403);
  });

  it('gives two calls without an Idempotency-Key different card ids', async () => {
    const first = await postCards({ kind: 'message' });
    const second = await postCards({ kind: 'message' });

    expect(first.status).toBe(201);
    expect(second.status).toBe(201);
    expect(first.body.card.id).not.toBe(second.body.card.id);
  });
});
