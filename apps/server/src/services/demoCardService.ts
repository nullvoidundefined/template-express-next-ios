import crypto from 'node:crypto';

import type { Card, CardKind } from '@repo/types';

const MESSAGE_BODY_OPTIONS = [
  'Welcome to your demo feed. This is a sample message card.',
  'Every great project starts with a single card in the stream.',
  'This message card shows how your feed will look in production.',
];

const PROMPT_BODY_OPTIONS = [
  'What would you build first if you had unlimited compute?',
  'Describe the feature that would make your users happiest today.',
  'If your app could do one new thing tomorrow, what should it be?',
];

function createDemoCard(kind: CardKind): Card {
  const options =
    kind === 'message' ? MESSAGE_BODY_OPTIONS : PROMPT_BODY_OPTIONS;
  const body = options[Math.floor(Math.random() * options.length)]!;

  return {
    body,
    createdAt: new Date().toISOString(),
    id: crypto.randomUUID(),
    kind,
    title: kind === 'message' ? 'Message' : 'Prompt',
  };
}

export { createDemoCard };
