import { randomBytes, randomUUID } from 'node:crypto';

import request from 'supertest';
import { describe, expect, it } from 'vitest';

import { createApp } from 'app/app.js';
import { SESSION_TOKEN_PATTERN } from 'app/constants/sessionConstants.js';
import { query, withTransaction } from 'app/database/databasePool.js';

const { app: testApp } = createApp({ query, withTransaction });

const DB_AVAILABLE = !!process.env.DATABASE_URL;

const CSRF_HEADER = 'X-Requested-With';
const CSRF_VALUE = 'XMLHttpRequest';
const TRANSPORT_HEADER = 'X-Session-Transport';
const TRANSPORT_VALUE = 'token';

/**
 * Bearer-token session transport for native clients, against the real app and
 * a real database. Skips when DATABASE_URL is not set.
 */
describe.skipIf(!DB_AVAILABLE)('bearer auth integration', () => {
  function agent() {
    return request(testApp);
  }

  function newCredentials() {
    return {
      email: `bearer-${randomUUID()}@example.com`,
      password: randomBytes(12).toString('hex'),
    };
  }

  async function registerWithToken(
    credentials: ReturnType<typeof newCredentials>,
  ) {
    return agent()
      .post('/v1/auth/register')
      .set(CSRF_HEADER, CSRF_VALUE)
      .set(TRANSPORT_HEADER, TRANSPORT_VALUE)
      .send(credentials);
  }

  describe('token transport on register and login', () => {
    it('register with the transport header returns sessionToken, no cookie, no-store', async () => {
      const res = await registerWithToken(newCredentials());

      expect(res.status).toBe(201);
      expect(res.body.sessionToken).toMatch(SESSION_TOKEN_PATTERN);
      expect(res.headers['set-cookie']).toBeUndefined();
      expect(res.headers['cache-control']).toBe('no-store');
    });

    it('login with the transport header returns sessionToken, no cookie, no-store', async () => {
      const credentials = newCredentials();
      await registerWithToken(credentials);

      const res = await agent()
        .post('/v1/auth/login')
        .set(CSRF_HEADER, CSRF_VALUE)
        .set(TRANSPORT_HEADER, TRANSPORT_VALUE)
        .send(credentials);

      expect(res.status).toBe(200);
      expect(res.body.sessionToken).toMatch(SESSION_TOKEN_PATTERN);
      expect(res.body.user.email).toBe(credentials.email);
      expect(res.headers['set-cookie']).toBeUndefined();
      expect(res.headers['cache-control']).toBe('no-store');
    });
  });

  // Characterization: describes today's behavior and may pass before the change.
  describe('cookie transport is unchanged without the header', () => {
    it('register returns only user and sets a cookie', async () => {
      const res = await agent()
        .post('/v1/auth/register')
        .set(CSRF_HEADER, CSRF_VALUE)
        .send(newCredentials());

      expect(res.status).toBe(201);
      expect(Object.keys(res.body)).toEqual(['user']);
      expect(res.headers['set-cookie']).toBeDefined();
    });

    it('login returns only user and sets a cookie', async () => {
      const credentials = newCredentials();
      await agent()
        .post('/v1/auth/register')
        .set(CSRF_HEADER, CSRF_VALUE)
        .send(credentials);

      const res = await agent()
        .post('/v1/auth/login')
        .set(CSRF_HEADER, CSRF_VALUE)
        .send(credentials);

      expect(res.status).toBe(200);
      expect(Object.keys(res.body)).toEqual(['user']);
      expect(res.headers['set-cookie']).toBeDefined();
    });
  });

  describe('GET /v1/auth/me with a bearer token', () => {
    it('authenticates a valid token', async () => {
      const credentials = newCredentials();
      const { body } = await registerWithToken(credentials);

      const res = await agent()
        .get('/v1/auth/me')
        .set('Authorization', `Bearer ${body.sessionToken}`);

      expect(res.status).toBe(200);
      expect(res.body.user.email).toBe(credentials.email);
    });

    it('rejects an unknown token with 401 AUTH_REQUIRED', async () => {
      const res = await agent()
        .get('/v1/auth/me')
        .set('Authorization', `Bearer ${randomBytes(32).toString('hex')}`);

      expect(res.status).toBe(401);
      expect(res.body.code).toBe('AUTH_REQUIRED');
    });

    it('rejects a token whose session is expired', async () => {
      const credentials = newCredentials();
      const { body } = await registerWithToken(credentials);
      const live = await agent()
        .get('/v1/auth/me')
        .set('Authorization', `Bearer ${body.sessionToken}`);
      expect(live.status).toBe(200);
      await query(
        `UPDATE sessions SET expires_at = NOW() - INTERVAL '1 hour'
         WHERE user_id = (SELECT id FROM users WHERE email = $1)`,
        [credentials.email],
      );

      const res = await agent()
        .get('/v1/auth/me')
        .set('Authorization', `Bearer ${body.sessionToken}`);

      expect(res.status).toBe(401);
    });

    it('rejects a request carrying both a valid cookie and a valid bearer token', async () => {
      const credentials = newCredentials();
      const cookieRes = await agent()
        .post('/v1/auth/register')
        .set(CSRF_HEADER, CSRF_VALUE)
        .send(credentials);
      const cookie =
        ((cookieRes.headers['set-cookie'] ?? []) as string[])[0] ?? '';
      const bearerRes = await agent()
        .post('/v1/auth/login')
        .set(CSRF_HEADER, CSRF_VALUE)
        .set(TRANSPORT_HEADER, TRANSPORT_VALUE)
        .send(credentials);

      const res = await agent()
        .get('/v1/auth/me')
        .set('Cookie', cookie)
        .set('Authorization', `Bearer ${bearerRes.body.sessionToken}`);

      expect(res.status).toBe(400);
      expect(res.body.code).toBe('AUTH_AMBIGUOUS_CREDENTIALS');
    });
  });

  describe('POST /v1/auth/logout with a bearer token', () => {
    it('deletes the session so the token then gives 401', async () => {
      const { body } = await registerWithToken(newCredentials());
      const auth = `Bearer ${body.sessionToken}`;
      const live = await agent().get('/v1/auth/me').set('Authorization', auth);
      expect(live.status).toBe(200);

      const logout = await agent()
        .post('/v1/auth/logout')
        .set('Authorization', auth)
        .set(CSRF_HEADER, CSRF_VALUE);
      expect(logout.status).toBe(204);

      const me = await agent().get('/v1/auth/me').set('Authorization', auth);
      expect(me.status).toBe(401);
    });

    it('without X-Requested-With gives 403 CSRF_HEADER_MISSING and keeps the session', async () => {
      const { body } = await registerWithToken(newCredentials());
      const auth = `Bearer ${body.sessionToken}`;

      const logout = await agent()
        .post('/v1/auth/logout')
        .set('Authorization', auth);
      expect(logout.status).toBe(403);
      expect(logout.body.code).toBe('CSRF_HEADER_MISSING');

      const me = await agent().get('/v1/auth/me').set('Authorization', auth);
      expect(me.status).toBe(200);
    });
  });

  describe('PATCH /v1/auth/me password change', () => {
    it('with bearer and the transport header rotates the token', async () => {
      const credentials = newCredentials();
      const { body } = await registerWithToken(credentials);
      const oldAuth = `Bearer ${body.sessionToken}`;

      const res = await agent()
        .patch('/v1/auth/me')
        .set('Authorization', oldAuth)
        .set(CSRF_HEADER, CSRF_VALUE)
        .set(TRANSPORT_HEADER, TRANSPORT_VALUE)
        .send({
          currentPassword: credentials.password,
          newPassword: randomBytes(12).toString('hex'),
        });

      expect(res.status).toBe(200);
      expect(res.body.sessionToken).toMatch(SESSION_TOKEN_PATTERN);
      expect(res.body.sessionToken).not.toBe(body.sessionToken);
      expect(res.headers['set-cookie']).toBeUndefined();

      const oldMe = await agent()
        .get('/v1/auth/me')
        .set('Authorization', oldAuth);
      expect(oldMe.status).toBe(401);

      const newMe = await agent()
        .get('/v1/auth/me')
        .set('Authorization', `Bearer ${res.body.sessionToken}`);
      expect(newMe.status).toBe(200);
    });

    it('on a cookie session revokes the same user bearer session', async () => {
      const credentials = newCredentials();
      const cookieRes = await agent()
        .post('/v1/auth/register')
        .set(CSRF_HEADER, CSRF_VALUE)
        .send(credentials);
      const cookie =
        ((cookieRes.headers['set-cookie'] ?? []) as string[])[0] ?? '';
      const bearerRes = await agent()
        .post('/v1/auth/login')
        .set(CSRF_HEADER, CSRF_VALUE)
        .set(TRANSPORT_HEADER, TRANSPORT_VALUE)
        .send(credentials);
      const bearerAuth = `Bearer ${bearerRes.body.sessionToken}`;
      const before = await agent()
        .get('/v1/auth/me')
        .set('Authorization', bearerAuth);
      expect(before.status).toBe(200);

      const change = await agent()
        .patch('/v1/auth/me')
        .set('Cookie', cookie)
        .set(CSRF_HEADER, CSRF_VALUE)
        .send({
          currentPassword: credentials.password,
          newPassword: randomBytes(12).toString('hex'),
        });
      expect(change.status).toBe(200);

      const after = await agent()
        .get('/v1/auth/me')
        .set('Authorization', bearerAuth);
      expect(after.status).toBe(401);
    });
  });
});
