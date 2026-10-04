import { ChatOpenAI } from '@langchain/openai';
import { assertNvidiaConfigured, config } from '../config.js';

/**
 * LangChain ChatOpenAI pointed at NVIDIA Integrate (OpenAI-compatible).
 */
export function createNvidiaChat({ temperature = 0.2, maxTokens = 500 } = {}) {
  assertNvidiaConfigured();
  return new ChatOpenAI({
    apiKey: config.nvidia.apiKey,
    model: config.nvidia.model,
    temperature,
    maxTokens,
    configuration: {
      baseURL: config.nvidia.baseUrl,
    },
    modelKwargs: {
      top_p: 0.9,
      chat_template_kwargs: { enable_thinking: false },
      reasoning_budget: 0,
    },
  });
}

export function stripCodeFences(content) {
  let text = String(content || '').trim();
  if (text.startsWith('```')) {
    text = text.replace(/^```(?:json)?\s*/i, '');
    text = text.replace(/\s*```$/, '');
  }
  return text.trim();
}

export function parseJsonContent(content) {
  const cleaned = stripCodeFences(content);
  try {
    const parsed = JSON.parse(cleaned);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new Error('NVIDIA returned non-object JSON');
    }
    return parsed;
  } catch (_) {
    // Lightning / reasoning models sometimes wrap JSON in prose.
    const start = cleaned.indexOf('{');
    const end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      const sliced = cleaned.slice(start, end + 1);
      const parsed = JSON.parse(sliced);
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
        throw new Error('NVIDIA returned non-object JSON');
      }
      return parsed;
    }
    throw new Error('NVIDIA returned invalid JSON');
  }
}

function extractTextContent(response) {
  if (typeof response.content === 'string') return response.content;
  if (Array.isArray(response.content)) {
    return response.content.map((p) => p.text || '').join('');
  }
  return String(response.content ?? '');
}

/**
 * Invoke chat and parse JSON object from the model response.
 */
export async function chatJson({ system, user, maxTokens = 500 }) {
  const llm = createNvidiaChat({ maxTokens });
  const response = await llm.invoke([
    { role: 'system', content: system },
    { role: 'user', content: user },
  ]);
  return parseJsonContent(extractTextContent(response));
}

/**
 * Invoke chat and return plain text (for home Q&A).
 */
export async function chatText({
  system,
  messages,
  maxTokens = 220,
  temperature = 0.2,
}) {
  const llm = createNvidiaChat({ maxTokens, temperature });
  const response = await llm.invoke([
    { role: 'system', content: system },
    ...messages,
  ]);
  let text = extractTextContent(response).trim();
  // Strip common reasoning preambles from Lightning-style models.
  if (text.includes('Here\'s a thinking process') || text.includes('thinking process')) {
    const parts = text.split(/\n{2,}/);
    text = parts[parts.length - 1].trim();
  }
  return text;
}
