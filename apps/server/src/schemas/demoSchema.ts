import { z } from 'zod';

export const createDemoCardSchema = z
  .object({ kind: z.enum(['message', 'prompt']) })
  .strict();

export type CreateDemoCardInput = z.infer<typeof createDemoCardSchema>;
