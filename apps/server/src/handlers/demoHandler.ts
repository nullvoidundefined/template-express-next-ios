import type { Request, Response } from 'express';

import { HTTP } from 'app/constants/httpConstants.js';
import { createDemoCard } from 'app/services/demoCardService.js';

function createDemoHandlers() {
  function createCard(req: Request, res: Response): void {
    const { kind } = req.body as { kind: 'message' | 'prompt' };
    const card = createDemoCard(kind);
    res.status(HTTP.STATUS.CREATED).json({ card });
  }

  return { createCard };
}

type DemoHandlers = ReturnType<typeof createDemoHandlers>;

export { createDemoHandlers };
export type { DemoHandlers };
