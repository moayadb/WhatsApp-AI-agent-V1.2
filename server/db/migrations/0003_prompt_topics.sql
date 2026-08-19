-- ---------------------------------------------------------------------------
-- 0003 — what the manager sees instead of the prompt.
--
-- `generated_prompt` is the analysis agent's instructions: long, structured,
-- and written for a model rather than for a person. Showing it to the manager
-- made the product look like a configuration file. He now sees `prompt_topics`
-- — three to six short labels naming what is being watched — and changes them
-- by asking in conversation, not by editing text.
--
-- The prompt itself stays exactly where it was: still generated, still stored,
-- still the thing the AI runs on. Only the display surface changed.
-- ---------------------------------------------------------------------------

ALTER TABLE org_profiles
  ADD COLUMN IF NOT EXISTS prompt_topics jsonb NOT NULL DEFAULT '[]'::jsonb;
