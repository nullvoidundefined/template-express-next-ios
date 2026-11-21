import type { CardKind } from '@repo/types';
import { z } from 'zod';

const CARD_KINDS = ['message', 'prompt'] as const satisfies readonly CardKind[];

// Compile-time tie: fails the build if CardKind gains a member CARD_KINDS lacks.
type CardKindsCovered = CardKind extends (typeof CARD_KINDS)[number]
  ? true
  : never;
const cardKindsCovered: CardKindsCovered = true;
void cardKindsCovered;

const createDemoCardSchema = z.object({ kind: z.enum(CARD_KINDS) }).strict();

type CreateDemoCardInput = z.infer<typeof createDemoCardSchema>;

export { createDemoCardSchema };
export type { CreateDemoCardInput };
