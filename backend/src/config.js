import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.resolve(__dirname, '../.env') });

function required(name, fallback = '') {
  const value = process.env[name] ?? fallback;
  return typeof value === 'string' ? value.trim() : '';
}

export const config = {
  port: Number(process.env.PORT || 8080),
  nvidia: {
    apiKey: required('NVIDIA_API_KEY'),
    baseUrl: required(
      'NVIDIA_BASE_URL',
      'https://integrate.api.nvidia.com/v1',
    ).replace(/\/$/, ''),
    model: required(
      'NVIDIA_MODEL',
      'nvidia/nemotron-3.5-lightning-30b-a3b',
    ),
  },
  tavily: {
    apiKey: required('TAVILY_API_KEY'),
    baseUrl: required('TAVILY_BASE_URL', 'https://api.tavily.com/search'),
    // Off by default — insights ground on insights_knowledge_base.json / MEDICAL_KB.
    enabled: String(process.env.USE_TAVILY || 'false').toLowerCase() === 'true',
  },
  firebase: {
    credentialsPath: required(
      'GOOGLE_APPLICATION_CREDENTIALS',
      './serviceAccountKey.json',
    ),
    serviceAccountJson: required('FIREBASE_SERVICE_ACCOUNT_JSON'),
    usersCollection: required('USERS_COLLECTION', 'USERS'),
    medicalKbCollection: required('MEDICAL_KB_COLLECTION', 'MEDICAL_KB'),
    medicalKbCombosCollection: required(
      'MEDICAL_KB_COMBOS_COLLECTION',
      'MEDICAL_KB_COMBOS',
    ),
  },
  requireAuth: String(process.env.REQUIRE_AUTH || 'false').toLowerCase() === 'true',
  corsOrigin: required('CORS_ORIGIN', '*'),
  medicalKbPath: path.resolve(
    __dirname,
    '../data/insights_knowledge_base.json',
  ),
};

export function assertNvidiaConfigured() {
  if (!config.nvidia.apiKey) {
    throw new Error('NVIDIA_API_KEY is missing. Copy .env.example → .env');
  }
}

export function assertTavilyConfigured() {
  if (!config.tavily.apiKey) {
    throw new Error('TAVILY_API_KEY is missing. Copy .env.example → .env');
  }
}
