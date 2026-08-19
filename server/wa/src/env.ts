function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

export const env = {
  port: Number(process.env.PORT ?? 3100),
  logLevel: process.env.LOG_LEVEL ?? 'info',
  databaseUrl: required('DATABASE_URL'),
  /** Shared with `api`. Every route here refuses a caller without it. */
  internalToken: required('INTERNAL_TOKEN'),
  /** Where each analysed message is POSTed. Empty disables AI analysis. */
  n8nAnalyzeUrl: process.env.N8N_ANALYZE_URL ?? '',
  n8nSecret: process.env.N8N_WEBHOOK_SECRET ?? '',
  /**
   * The API service, for delivering AI verdicts. The n8n call is synchronous
   * request/response, so this service receives the verdict and hands it to the
   * API's hook itself — n8n never needs to reach the app, which is what lets
   * the whole loop run from a machine with no public address.
   */
  apiUrl: (process.env.API_URL ?? 'http://127.0.0.1:3000').replace(/\/$/, ''),
};
