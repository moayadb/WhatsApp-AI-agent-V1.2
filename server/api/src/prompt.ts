import { one, pool } from './db';
import { topicsForPrompt } from './intake';
import { logger } from './logger';

/**
 * The only place in the API that writes `org_profiles.generated_prompt`.
 *
 * Contract 6 makes this an invariant: every write to the prompt regenerates
 * the topics. The reason is that the manager can no longer see the prompt —
 * the labels are his entire view of it, so labels that describe a prompt two
 * versions old are not a cosmetic bug, they are the product lying about what
 * it is watching.
 *
 * Keeping the write in one function is what makes the invariant hold. A route
 * that reached for `UPDATE org_profiles SET generated_prompt` directly would
 * be able to skip it, and nothing would fail loudly when it did.
 */

export type PromptSource = 'llm' | 'script' | 'manual';

export interface SavePromptInput {
  orgId: string;
  /** The complete new prompt. */
  prompt: string;
  source: PromptSource;
  /**
   * Topics the same turn already produced. An interview or refine turn returns
   * them alongside the prompt, so there is nothing to regenerate; anything else
   * leaves this empty and the workflow is asked to describe the prompt.
   */
  topics?: string[];
  /** Language for generated labels. Defaults to the org's own locale. */
  locale?: string;
  /** Set only by the turn that finishes onboarding. */
  completeOnboarding?: boolean;
}

/**
 * Write a prompt and the topics that describe it.
 *
 * Returns the topics now in force — which, when generation failed, are the
 * previous ones. Blanking them would leave the manager looking at a Settings
 * screen that says nothing is being watched while the analysis agent carries
 * on watching.
 */
export async function savePrompt(
  input: SavePromptInput,
): Promise<{ topics: string[] }> {
  let topics = input.topics ?? [];

  if (topics.length === 0) {
    const locale =
      input.locale ??
      (
        await one<{ locale: string }>('SELECT locale FROM orgs WHERE id = $1', [
          input.orgId,
        ])
      )?.locale ??
      'ar';
    topics = await topicsForPrompt(input.prompt, locale);
    if (topics.length === 0) {
      logger.warn(
        { orgId: input.orgId },
        'topics generation produced nothing; previous labels kept',
      );
    }
  }

  const row = await one<{ prompt_topics: string[] }>(
    `UPDATE org_profiles SET
       generated_prompt = $2,
       prompt_source = $3,
       -- An empty array means generation failed. NULLIF turns it back into
       -- "no change" so a failed call can never empty the screen.
       prompt_topics = COALESCE(NULLIF($4::jsonb, '[]'::jsonb), prompt_topics),
       prompt_updated_at = now(),
       completed_at = CASE WHEN $5 THEN now() ELSE completed_at END,
       updated_at = now()
     WHERE org_id = $1
     RETURNING prompt_topics`,
    [
      input.orgId,
      input.prompt,
      input.source,
      JSON.stringify(topics),
      input.completeOnboarding === true,
    ],
  );

  return { topics: row?.prompt_topics ?? [] };
}

/**
 * Regenerate topics for every org whose prompt has none.
 *
 * Idempotent: an org that already has labels is skipped, so a re-run after a
 * partial failure only picks up what is still missing. Deliberately serial —
 * each org costs one model call, and there is no deadline here worth spending
 * rate limit on.
 */
export async function backfillTopics(): Promise<{
  scanned: number;
  filled: number;
  failed: number;
}> {
  const { rows } = await pool.query<{
    org_id: string;
    generated_prompt: string;
    locale: string;
  }>(
    `SELECT p.org_id, p.generated_prompt, o.locale
       FROM org_profiles p
       JOIN orgs o ON o.id = p.org_id
      WHERE p.generated_prompt IS NOT NULL
        AND (p.prompt_topics IS NULL OR jsonb_array_length(p.prompt_topics) = 0)
      ORDER BY p.updated_at ASC`,
  );

  let filled = 0;
  let failed = 0;

  for (const row of rows) {
    const topics = await topicsForPrompt(row.generated_prompt, row.locale);
    if (topics.length === 0) {
      failed++;
      logger.warn({ orgId: row.org_id }, 'backfill: no topics produced');
      continue;
    }
    await pool.query(
      `UPDATE org_profiles SET prompt_topics = $2::jsonb, updated_at = now()
        WHERE org_id = $1`,
      [row.org_id, JSON.stringify(topics)],
    );
    filled++;
    logger.info({ orgId: row.org_id, topics }, 'backfill: topics written');
  }

  return { scanned: rows.length, filled, failed };
}
