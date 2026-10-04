import cors from 'cors';
import express from 'express';
import { config } from './config.js';
import { initFirebase } from './services/firestore.js';
import chatRouter from './routes/chat.js';
import healthRouter from './routes/health.js';
import insightsRouter from './routes/insights.js';

const firebaseReady = Boolean(initFirebase());

const app = express();

const corsOrigin =
  config.corsOrigin === '*'
    ? true
    : config.corsOrigin.split(',').map((s) => s.trim());

app.use(
  cors({
    origin: corsOrigin,
  }),
);
app.use(express.json({ limit: '2mb' }));

app.get('/', (_req, res) => {
  res.json({
    service: 'nemocare-backend',
    docs: {
      health: 'GET /health',
      refresh: 'POST /insights/refresh',
      cached: 'GET /insights/:email',
      kb: 'GET /insights/kb/all',
      chat: 'POST /chat/ask',
    },
  });
});

app.use('/health', healthRouter);
app.use('/insights', insightsRouter);
app.use('/chat', chatRouter);

app.use((err, _req, res, _next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: err.message || 'Internal server error' });
});

app.listen(config.port, () => {
  console.log(`Nemo Care API listening on http://localhost:${config.port}`);
  console.log(`  NVIDIA: ${config.nvidia.apiKey ? 'configured' : 'MISSING'}`);
  console.log(
    `  Grounding: ${config.tavily.enabled ? 'medical_kb + Tavily' : 'medical_kb only'}`,
  );
  console.log(
    `  Tavily: ${config.tavily.enabled ? (config.tavily.apiKey ? 'enabled' : 'ENABLED BUT KEY MISSING') : 'disabled'}`,
  );
  console.log(`  Firebase: ${firebaseReady ? 'configured' : 'MISSING'}`);
  console.log(`  Auth required: ${config.requireAuth}`);
});
