import { assertTavilyConfigured, config } from '../config.js';

/**
 * Thin Tavily search client (same contract as Flutter TavilyClient).
 */
export async function tavilySearch(query, { maxResults = 5 } = {}) {
  const trimmed = String(query || '').trim();
  if (!trimmed) return [];
  assertTavilyConfigured();

  const response = await fetch(config.tavily.baseUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      api_key: config.tavily.apiKey,
      query: trimmed,
      max_results: maxResults,
      search_depth: 'basic',
      include_answer: false,
    }),
  });

  if (!response.ok) {
    throw new Error(`Tavily request failed (${response.status})`);
  }

  const data = await response.json();
  const results = Array.isArray(data.results) ? data.results : [];
  return results.map((r) => ({
    title: r.title || '',
    url: r.url || '',
    content: r.content || r.snippet || '',
  }));
}

export function formatSourcesForPrompt(sources) {
  if (!sources?.length) return '(no web sources)';
  return sources
    .map((s, i) => {
      const snippet = String(s.content || '').slice(0, 400);
      return `${i + 1}. ${s.title || 'Untitled'}\n   URL: ${s.url || ''}\n   ${snippet}`;
    })
    .join('\n');
}
