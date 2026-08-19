function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

export const env = {
  port: Number(process.env.PORT ?? 3000),
  logLevel: process.env.LOG_LEVEL ?? 'info',
  isProduction: process.env.NODE_ENV === 'production',
  databaseUrl: required('DATABASE_URL'),
  jwtSecret: required('JWT_SECRET'),
  /** Presented to the `wa` service; never leaves the compose network. */
  internalToken: required('INTERNAL_TOKEN'),
  /** n8n must present this to write AI verdicts back. */
  n8nSecret: process.env.N8N_WEBHOOK_SECRET ?? '',
  waServiceUrl: process.env.WA_SERVICE_URL ?? 'http://wa:3100',
  /**
   * The model that runs the onboarding interview.
   *
   * Called directly from this service rather than through n8n, because the
   * interview is request/response and must work before the box is publicly
   * reachable — n8n can only push results back to a public URL.
   *
   * Any OpenAI-compatible endpoint works: point `LLM_BASE_URL` at Anthropic's
   * compatibility endpoint, or a self-hosted model, and change `LLM_MODEL`.
   * Unset means the app falls back to a scripted interview instead of breaking.
   */
  /**
   * n8n intake-interview webhook. When set, the onboarding conversation is
   * run by the n8n workflow (synchronous request/response) instead of calling
   * the model from here — so the interviewer's prompt and model live in n8n
   * where the operator can edit them. Falls back to the direct LLM below, and
   * then to the scripted interview, so onboarding survives n8n being down.
   */
  n8nIntakeUrl: process.env.N8N_INTAKE_URL ?? '',
  llmApiKey: process.env.LLM_API_KEY ?? process.env.OPENAI_API_KEY ?? '',
  llmBaseUrl: (process.env.LLM_BASE_URL ?? 'https://api.openai.com/v1').replace(
    /\/$/,
    '',
  ),
  llmModel: process.env.LLM_MODEL ?? 'gpt-4.1-mini',
  workerIntervalSeconds: Number(process.env.WORKER_INTERVAL_SECONDS ?? 60),
  fcmServiceAccountFile: process.env.FCM_SERVICE_ACCOUNT_FILE ?? '',
  fcmProjectId: process.env.FCM_PROJECT_ID ?? '',
};
