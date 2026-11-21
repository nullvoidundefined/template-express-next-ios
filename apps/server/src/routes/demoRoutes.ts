import express from 'express';
import type { Router } from 'express';

import type { DemoHandlers } from 'app/handlers/demoHandler.js';
import { requireAuth } from 'app/middleware/requireAuthMiddleware.js';
import { validate } from 'app/middleware/validateMiddleware.js';
import { createDemoCardSchema } from 'app/schemas/demoSchema.js';

function createDemoRouter(handlers: DemoHandlers): Router {
  const demoRouter = express.Router();

  demoRouter.use(requireAuth);
  demoRouter.post(
    '/cards',
    validate(createDemoCardSchema),
    handlers.createCard,
  );

  return demoRouter;
}

export { createDemoRouter };
