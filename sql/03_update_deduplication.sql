-- Additive migration. Existing follows, preferences and alert jobs are preserved.
CREATE TABLE IF NOT EXISTS sports_radar.processed_updates (
  update_id bigint PRIMARY KEY,
  chat_id text NOT NULL CHECK (chat_id ~ '^[0-9]+$'),
  received_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON sports_radar.processed_updates FROM PUBLIC;
ALTER TABLE sports_radar.processed_updates ENABLE ROW LEVEL SECURITY;
-- Direct owner/Postgres access only. Do not expose sports_radar via the public API.
