import { env } from './env';
import { logger } from './logger';

/**
 * Minimal client for any OpenAI-compatible chat API.
 *
 * Written against the wire format rather than a vendor SDK so switching to
 * Claude, or to a self-hosted model, is a base-URL and model-name change in
 * `.env` — no code and no new dependency.
 *
 * This runs server-side and only ever makes outbound calls, which is why the
 * intake conversation works on a laptop while the n8n analysis path does not:
 * n8n has to call back in, and nothing can reach a machine on someone's desk.
 */

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export class LlmUnavailable extends Error {}

export function llmConfigured(): boolean {
  return env.llmApiKey.length > 0;
}

/**
 * One chat completion, parsed as JSON.
 *
 * `response_format: json_object` is requested but not trusted — some providers
 * ignore it, so the response is also scanned for a JSON body before parsing.
 */
export async function chatJson<T>(messages: ChatMessage[]): Promise<T> {
  if (!llmConfigured()) throw new LlmUnavailable('no LLM API key configured');

  const response = await fetch(`${env.llmBaseUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${env.llmApiKey}`,
    },
    body: JSON.stringify({
      model: env.llmModel,
      messages,
      temperature: 0.4,
      response_format: { type: 'json_object' },
    }),
    signal: AbortSignal.timeout(45_000),
  });

  if (!response.ok) {
    const detail = await response.text().catch(() => '');
    logger.warn(
      { status: response.status, detail: detail.slice(0, 300) },
      'LLM call failed',
    );
    throw new LlmUnavailable(`LLM returned ${response.status}`);
  }

  const body = (await response.json()) as {
    choices?: { message?: { content?: string } }[];
  };
  const content = body.choices?.[0]?.message?.content;
  if (!content) throw new LlmUnavailable('LLM returned no content');

  return parseJson<T>(content);
}

/** Tolerate a model that wraps its JSON in prose or a fenced code block. */
function parseJson<T>(raw: string): T {
  try {
    return JSON.parse(raw) as T;
  } catch {
    const start = raw.indexOf('{');
    const end = raw.lastIndexOf('}');
    if (start !== -1 && end > start) {
      return JSON.parse(raw.slice(start, end + 1)) as T;
    }
    throw new LlmUnavailable('LLM response was not JSON');
  }
}
