import { describe, expect, it } from 'vitest';

import { createDemoCard } from 'app/services/demoCardService.js';

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

describe('createDemoCard', () => {
  it.each([
    { kind: 'message', title: 'Message' },
    { kind: 'prompt', title: 'Prompt' },
  ] as const)('builds a $kind card', ({ kind, title }) => {
    const card = createDemoCard(kind);

    expect(card.kind).toBe(kind);
    expect(card.title).toBe(title);
    expect(card.body.length).toBeGreaterThanOrEqual(1);
    expect(card.body.length).toBeLessThanOrEqual(140);
    expect(card.id).toMatch(UUID_PATTERN);
    expect(Number.isNaN(Date.parse(card.createdAt))).toBe(false);
    expect(new Date(card.createdAt).toISOString()).toBe(card.createdAt);
  });

  it('gives each call a different id', () => {
    expect(createDemoCard('message').id).not.toBe(createDemoCard('message').id);
  });
});
