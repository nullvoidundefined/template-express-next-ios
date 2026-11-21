import type { Request, Response } from 'express';
import { describe, expect, it } from 'vitest';

import { createDemoHandlers } from 'app/handlers/demoHandler.js';

interface FakeResponse {
  body: unknown;
  statusCode: number;
}

function runCreateCard(body: unknown): FakeResponse {
  const result: FakeResponse = { body: undefined, statusCode: 200 };
  const res = {
    json(payload: unknown) {
      result.body = payload;
      return res;
    },
    status(code: number) {
      result.statusCode = code;
      return res;
    },
  };
  createDemoHandlers().createCard(
    { body } as unknown as Request,
    res as unknown as Response,
  );
  return result;
}

describe('demo handlers', () => {
  describe('createCard', () => {
    it.each(['message', 'prompt'] as const)(
      'responds 201 with a %s card wrapped in card',
      (kind) => {
        const { body, statusCode } = runCreateCard({ kind });
        const { card } = body as { card: { id: string; kind: string } };

        expect(statusCode).toBe(201);
        expect(card.kind).toBe(kind);
        expect(typeof card.id).toBe('string');
      },
    );

    it('gives two requests different card ids', () => {
      const first = runCreateCard({ kind: 'message' }).body as {
        card: { id: string };
      };
      const second = runCreateCard({ kind: 'message' }).body as {
        card: { id: string };
      };

      expect(first.card.id).not.toBe(second.card.id);
    });
  });
});
