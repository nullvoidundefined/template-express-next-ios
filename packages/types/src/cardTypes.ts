// Shared domain types for demo cards.

type CardKind = 'message' | 'prompt';

type Card = {
  body: string;
  createdAt: string;
  id: string;
  kind: CardKind;
  title: string;
};

export type { Card, CardKind };
