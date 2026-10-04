import { Router } from 'express';
import {
  assertEmailMatchesAuth,
  optionalFirebaseAuth,
} from '../middleware/auth.js';
import { retrieveForFinding, loadMedicalKb } from '../services/medicalKb.js';
import { refreshIfFindingsChanged } from '../services/insightsPipeline.js';
import { fetchUserDoc } from '../services/firestore.js';
import { config } from '../config.js';

const router = Router();

/**
 * POST /insights/refresh
 *
 * Body:
 * {
 *   "email": "user@mail.com",
 *   "force": false,
 *   "persist": true,
 *   "userDoc": { ... }   // optional — otherwise loaded from Firestore
 * }
 */
router.post(
  '/refresh',
  optionalFirebaseAuth,
  assertEmailMatchesAuth,
  async (req, res) => {
    try {
      const email = String(req.body?.email || '').trim().toLowerCase();
      if (!email) {
        return res.status(400).json({ error: 'email is required' });
      }

      const force = Boolean(req.body?.force);
      const persist = req.body?.persist !== false;
      const userDoc =
        req.body?.userDoc && typeof req.body.userDoc === 'object'
          ? req.body.userDoc
          : undefined;

      const bundle = await refreshIfFindingsChanged({
        email,
        userDoc,
        force,
        persist,
      });

      return res.json({
        ok: true,
        email,
        ...bundle,
      });
    } catch (err) {
      console.error('POST /insights/refresh', err);
      return res.status(500).json({
        error: err.message || 'Insights refresh failed',
      });
    }
  },
);

/** Inspect medical KB (static paths before /:email). */
router.get('/kb/all', async (_req, res) => {
  try {
    const kb = await loadMedicalKb();
    const keys = Object.keys(kb.byFindingKey || {});
    return res.json({
      ok: true,
      keys,
      count: keys.length,
      comboCount: Array.isArray(kb.combos) ? kb.combos.length : 0,
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.get('/kb/lookup/:findingKey', async (req, res) => {
  try {
    const chunks = await retrieveForFinding(req.params.findingKey);
    return res.json({ ok: true, findingKey: req.params.findingKey, chunks });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

/**
 * GET /insights/:email
 * Read cached insights bundle from Firestore (no generation).
 */
router.get('/:email', optionalFirebaseAuth, async (req, res) => {
  try {
    const email = String(req.params.email || '').trim().toLowerCase();
    if (config.requireAuth && req.user?.email && req.user.email !== email) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    const doc = await fetchUserDoc(email);
    if (!doc) {
      return res.status(404).json({ error: 'User not found' });
    }
    const insights = doc.insights || { fingerprint: '', cards: [] };
    return res.json({
      ok: true,
      email,
      insights,
      insights_meta: doc.insights_meta || null,
    });
  } catch (err) {
    console.error('GET /insights/:email', err);
    return res
      .status(500)
      .json({ error: err.message || 'Failed to load insights' });
  }
});

export default router;
