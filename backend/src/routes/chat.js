import { Router } from 'express';
import {
  assertEmailMatchesAuth,
  optionalFirebaseAuth,
} from '../middleware/auth.js';
import { answerQuestion } from '../services/chatPipeline.js';

const router = Router();

/**
 * POST /chat/ask
 *
 * Body:
 * {
 *   "email": "user@mail.com",
 *   "question": "Why is my MCV low?",
 *   "history": [{ "role": "user"|"assistant", "content": "..." }]
 * }
 */
router.post(
  '/ask',
  optionalFirebaseAuth,
  assertEmailMatchesAuth,
  async (req, res) => {
    try {
      const email = String(req.body?.email || '').trim().toLowerCase();
      const question = String(req.body?.question || '').trim();
      if (!email) {
        return res.status(400).json({ error: 'email is required' });
      }
      if (!question) {
        return res.status(400).json({ error: 'question is required' });
      }

      const history = Array.isArray(req.body?.history) ? req.body.history : [];
      const comparisonContext =
        req.body?.comparisonContext &&
        typeof req.body.comparisonContext === 'object'
          ? req.body.comparisonContext
          : null;
      const result = await answerQuestion({
        email,
        question,
        history,
        comparisonContext,
      });

      return res.json({
        ok: true,
        email,
        ...result,
      });
    } catch (err) {
      console.error('POST /chat/ask', err);
      return res.status(500).json({
        error: err.message || 'Chat ask failed',
      });
    }
  },
);

export default router;
