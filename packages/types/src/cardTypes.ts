// Shared domain types for demo cards.

export type CardKind = 'message' | 'prompt';

export type Card = {
  body: string;
  createdAt: string;
  id: string;
  kind: CardKind;
  title: string;
};


