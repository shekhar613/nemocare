import { Router } from 'express';
import admin from 'firebase-admin';
import { config } from '../config.js';

const router = Router();

router.get('/', (_req, res) => {
  res.json({
    ok: true,
    service: 'nemocare-backend',
    nvidiaConfigured: Boolean(config.nvidia.apiKey),
    tavilyConfigured: Boolean(config.tavily.apiKey),
    tavilyEnabled: Boolean(config.tavily.enabled),
    firebaseConfigured: admin.apps.length > 0,
    requireAuth: config.requireAuth,
    grounding: config.tavily.enabled ? 'medical_kb+tavily' : 'medical_kb_only',
  });
});

export default router;
