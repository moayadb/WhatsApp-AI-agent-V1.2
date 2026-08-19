-- ---------------------------------------------------------------------------
-- 0001_init — Multi-Channel AI Analyzer
--
-- Shape of the world: an ORG (Faisal's brokerage) owns AGENTS (his ten sales
-- staff) and CHANNELS (the WhatsApp numbers actually linked via Baileys). Every
-- CONVERSATION belongs to one channel and one contact, which is what finally
-- makes an alert attributable to a named agent — the thing the Firestore
-- version could never do.
-- ---------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS citext;     -- case-insensitive email

-- --------------------------------------------------------------------- types
CREATE TYPE user_role      AS ENUM ('owner', 'manager', 'viewer');
CREATE TYPE channel_status AS ENUM ('new', 'pairing', 'connected', 'syncing',
                                    'disconnected', 'logged_out', 'error');
CREATE TYPE link_method    AS ENUM ('pairing_code', 'qr');
CREATE TYPE msg_direction  AS ENUM ('in', 'out');
CREATE TYPE alert_type     AS ENUM ('sla_breach', 'cold_lead',
                                    'unauthorized_promise', 'off_channel',
                                    'escalation', 'other');
CREATE TYPE severity       AS ENUM ('urgent', 'high', 'medium', 'low');
CREATE TYPE alert_status   AS ENUM ('new', 'done', 'ignored');

-- ---------------------------------------------------------------------- orgs
CREATE TABLE orgs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  locale      text NOT NULL DEFAULT 'ar',
  timezone    text NOT NULL DEFAULT 'Asia/Dubai',
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- --------------------------------------------------------------------- users
-- Self-service signup, unlike the old hand-made allowlist accounts. The first
-- user of an org is its owner and creates the org in the same transaction.
CREATE TABLE users (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id               uuid NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  full_name            text NOT NULL,
  email                citext NOT NULL UNIQUE,
  phone_e164           text NOT NULL,
  password_hash        text NOT NULL,
  role                 user_role NOT NULL DEFAULT 'owner',
  -- Journey step 1 requires agreeing to the terms; store WHEN, not a boolean,
  -- because the timestamp is the part that is worth anything in a dispute.
  terms_accepted_at    timestamptz,
  privacy_accepted_at  timestamptz,
  last_login_at        timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX users_org_idx ON users (org_id);

-- ------------------------------------------------------------- org profiling
-- Output of journey step 2, the intake conversation. Kept separate from
-- settings: this is what Faisal SAID, settings are what the system DOES.
CREATE TABLE org_profiles (
  org_id         uuid PRIMARY KEY REFERENCES orgs(id) ON DELETE CASCADE,
  business_type  text,
  team_size      integer,
  focus_areas    jsonb NOT NULL DEFAULT '[]'::jsonb,
  pains          jsonb NOT NULL DEFAULT '[]'::jsonb,
  transcript     jsonb NOT NULL DEFAULT '[]'::jsonb,
  completed_at   timestamptz,
  updated_at     timestamptz NOT NULL DEFAULT now()
);

-- Detector thresholds. Seeded from the intake answers, editable afterwards.
CREATE TABLE org_settings (
  org_id                        uuid PRIMARY KEY REFERENCES orgs(id) ON DELETE CASCADE,
  first_response_minutes        integer NOT NULL DEFAULT 15,
  vip_first_response_minutes    integer NOT NULL DEFAULT 5,
  cold_lead_hours               integer NOT NULL DEFAULT 48,
  -- Local hours in the org timezone during which push is suppressed.
  quiet_hours_start             smallint,
  quiet_hours_end               smallint,
  detect_unauthorized_promise   boolean NOT NULL DEFAULT true,
  detect_off_channel            boolean NOT NULL DEFAULT true,
  -- Push only at/above this severity — the "notify me only when I'm needed" dial.
  min_push_severity             severity NOT NULL DEFAULT 'high',
  updated_at                    timestamptz NOT NULL DEFAULT now()
);

-- -------------------------------------------------------------------- agents
CREATE TABLE agents (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      uuid NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  name        text NOT NULL,
  email       citext,
  active      boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX agents_org_idx ON agents (org_id) WHERE active;

-- ------------------------------------------------------------------ channels
-- One row per linked WhatsApp number. `agent_id` NULL means the number belongs
-- to the manager himself, which journey step 3 explicitly allows.
CREATE TABLE channels (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id               uuid NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  agent_id             uuid REFERENCES agents(id) ON DELETE SET NULL,
  label                text,
  phone_e164           text,          -- typed by the user for pairing-code linking
  wa_jid               text,          -- learned from WhatsApp once connected
  status               channel_status NOT NULL DEFAULT 'new',
  link_method          link_method,
  -- Transient linking state. Both are cleared the moment the session opens.
  pairing_code         text,
  qr                   text,
  pairing_expires_at   timestamptz,
  last_connected_at    timestamptz,
  last_disconnected_at timestamptz,
  last_error           text,
  -- Consent record: monitoring an employee's WhatsApp needs one, and
  -- retrofitting it later is expensive.
  consent_name         text,
  consent_at           timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (org_id, phone_e164)
);
CREATE INDEX channels_org_idx ON channels (org_id);

-- Baileys credential store, replacing useMultiFileAuthState. Keeping it in
-- Postgres is what lets a container restart resume every session instead of
-- asking ten agents to re-link.
CREATE TABLE wa_auth_state (
  channel_id  uuid NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  key         text NOT NULL,
  value       jsonb NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (channel_id, key)
);

-- ------------------------------------------------------------------ contacts
CREATE TABLE contacts (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id        uuid NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  wa_jid        text NOT NULL,
  phone_e164    text,
  display_name  text,
  is_vip        boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (org_id, wa_jid)
);

-- ------------------------------------------------------------- conversations
-- `awaiting_reply_since` is the whole response-time product in one column: set
-- when a customer message arrives with nothing pending, cleared when the agent
-- replies. The worker only has to look for rows where it is old.
CREATE TABLE conversations (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id               uuid NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  channel_id           uuid NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  contact_id           uuid NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  agent_id             uuid REFERENCES agents(id) ON DELETE SET NULL,
  last_message_at      timestamptz,
  last_inbound_at      timestamptz,
  last_outbound_at     timestamptz,
  awaiting_reply_since timestamptz,
  first_response_ms    bigint,
  sla_alerted_at       timestamptz,
  cold_alerted_at      timestamptz,
  message_count        integer NOT NULL DEFAULT 0,
  created_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (channel_id, contact_id)
);
-- The worker's hot path: unanswered threads, oldest first.
CREATE INDEX conversations_awaiting_idx
  ON conversations (awaiting_reply_since)
  WHERE awaiting_reply_since IS NOT NULL;
CREATE INDEX conversations_org_activity_idx
  ON conversations (org_id, last_message_at DESC);

-- ------------------------------------------------------------------ messages
CREATE TABLE messages (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id           uuid NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  conversation_id  uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  wa_message_id    text,
  direction        msg_direction NOT NULL,
  body             text,
  media_type       text,
  transcript       text,          -- voice notes, filled in by n8n
  sent_at          timestamptz NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (conversation_id, wa_message_id)
);
CREATE INDEX messages_conversation_idx
  ON messages (conversation_id, sent_at DESC);

-- -------------------------------------------------------------------- alerts
-- `dedupe_key` is what stops one slow agent from generating the same breach
-- alert every sweep. Unique per org, so the writer can upsert blindly.
CREATE TABLE alerts (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id              uuid NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
  conversation_id     uuid REFERENCES conversations(id) ON DELETE SET NULL,
  channel_id          uuid REFERENCES channels(id) ON DELETE SET NULL,
  agent_id            uuid REFERENCES agents(id) ON DELETE SET NULL,
  contact_id          uuid REFERENCES contacts(id) ON DELETE SET NULL,
  type                alert_type NOT NULL,
  severity            severity NOT NULL DEFAULT 'medium',
  title               text NOT NULL,
  insight             text,
  recommended_action  text,
  evidence            jsonb NOT NULL DEFAULT '[]'::jsonb,
  event_at            timestamptz NOT NULL,
  status              alert_status NOT NULL DEFAULT 'new',
  completed_at        timestamptz,
  completed_by        uuid REFERENCES users(id) ON DELETE SET NULL,
  handling_ms         bigint,
  dedupe_key          text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (org_id, dedupe_key)
);
CREATE INDEX alerts_feed_idx ON alerts (org_id, status, event_at DESC);
CREATE INDEX alerts_agent_idx ON alerts (org_id, agent_id, event_at DESC);

-- ------------------------------------------------------------------- devices
CREATE TABLE devices (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token       text NOT NULL UNIQUE,
  platform    text NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX devices_user_idx ON devices (user_id);
