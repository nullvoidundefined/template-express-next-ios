import { randomBytes } from 'node:crypto';

import express from 'express';
import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

import { requestLogger } from 'app/middleware/requestLoggerMiddleware.js';

// Real pino writing to an in-memory sink, so tests can read what the
// serializers actually emit.
const logLines = vi.hoisted(() => [] as string[]);

vi.mock('app/services/loggerService.js', async () => {
  const { default: pino } = await import('pino');
  return {
    logger: pino(
      { level: 'info' },
      {
        write(line: string) {
          logLines.push(line);
        },
      },
    ),
  };
});

const app = express();
app.use(requestLogger);
app.get('/test', (_req, res) => res.json({ ok: true }));

describe('requestLogger', () => {
  it('generates a request ID when none is provided', async () => {
    const res = await request(app).get('/test');
    expect(res.status).toBe(200);
    expect(res.headers['x-request-id']).toBeDefined();
    expect(res.headers['x-request-id']).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
    );
  });

  it('echoes back a provided x-request-id header', async () => {
    const customId = 'my-custom-request-id-123';
    const res = await request(app).get('/test').set('x-request-id', customId);
    expect(res.headers['x-request-id']).toBe(customId);
  });

  it('truncates request IDs longer than 64 characters', async () => {
    const longId = 'a'.repeat(100);
    const res = await request(app).get('/test').set('x-request-id', longId);
    expect(res.headers['x-request-id']).toBe('a'.repeat(64));
  });

  it('generates unique IDs across requests', async () => {
    const res1 = await request(app).get('/test');
    const res2 = await request(app).get('/test');
    expect(res1.headers['x-request-id']).not.toBe(res2.headers['x-request-id']);
  });

  it('never logs the session token from the Authorization or Cookie headers', async () => {
    const token = randomBytes(32).toString('hex');
    logLines.length = 0;

    const res = await request(app)
      .get('/test')
      .set('Authorization', `Bearer ${token}`)
      .set('Cookie', `sid=${token}`);

    expect(res.status).toBe(200);
    const output = logLines.join('\n');
    // Guard against a vacuous pass: the request must actually have been logged.
    expect(output).toContain('/test');
    expect(output).not.toContain(token);
  });
});
