-- ---------------------------------------------------------------------------
-- 0002 — the intake conversation produces a monitoring prompt.
--
-- The interview is no longer a fixed questionnaire: an LLM interviews the
-- manager until it understands the business, then writes the prompt that the
-- analysis agent will use for THAT org. Storing it here is what makes the
-- onboarding conversation consequential rather than decorative — the words the
-- model writes are the words that later decide whether a message is escalated.
-- ---------------------------------------------------------------------------

ALTER TABLE org_profiles
  ADD COLUMN IF NOT EXISTS generated_prompt text,
  -- Whether the prompt came from the model or the scripted fallback, so it is
  -- obvious later why an org's prompt looks generic.
  ADD COLUMN IF NOT EXISTS prompt_source text,
  ADD COLUMN IF NOT EXISTS prompt_updated_at timestamptz;
