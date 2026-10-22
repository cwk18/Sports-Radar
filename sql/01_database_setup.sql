-- Sports Radar: run once in the Supabase SQL Editor.
-- Re-running keeps existing preferences and delivery records.
CREATE SCHEMA IF NOT EXISTS sports_radar;
REVOKE ALL ON SCHEMA sports_radar FROM PUBLIC;

CREATE TABLE IF NOT EXISTS sports_radar.users (
 chat_id text PRIMARY KEY CHECK (chat_id ~ '^[0-9]+$'),
 daily_enabled boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS sports_radar.follows (
 chat_id text NOT NULL REFERENCES sports_radar.users(chat_id) ON DELETE CASCADE,
 sport text NOT NULL CHECK(sport IN ('football','basketball','f1')),
 team_key text NOT NULL, label text NOT NULL, aliases jsonb NOT NULL DEFAULT '[]',
 PRIMARY KEY(chat_id,sport,team_key)
);
CREATE TABLE IF NOT EXISTS sports_radar.deliveries (
 chat_id text NOT NULL REFERENCES sports_radar.users(chat_id) ON DELETE CASCADE,
 local_date date NOT NULL, status text NOT NULL CHECK(status IN ('pending','sent')),
 created_at timestamptz NOT NULL DEFAULT now(), sent_at timestamptz,
 PRIMARY KEY(chat_id,local_date)
);

-- This function processes a validated command and returns that user's preferences.
CREATE OR REPLACE FUNCTION sports_radar.command(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, sports_radar AS $$
DECLARE
 cid text := p->>'chat_id'; a text := p->>'action';
 pref jsonb; daily boolean; reply text := coalesce(p->>'reply','');
BEGIN
 INSERT INTO sports_radar.users(chat_id) VALUES(cid) ON CONFLICT DO NOTHING;
 IF a='follow' THEN
  INSERT INTO sports_radar.follows(chat_id,sport,team_key,label,aliases)
  VALUES(cid,p->>'sport',p->>'team_key',p->>'label',p->'aliases')
  ON CONFLICT(chat_id,sport,team_key) DO UPDATE SET label=EXCLUDED.label,aliases=EXCLUDED.aliases;
 ELSIF a='unfollow' THEN
  DELETE FROM sports_radar.follows WHERE chat_id=cid AND sport=p->>'sport' AND team_key=p->>'team_key';
 ELSIF a='daily' THEN
  UPDATE sports_radar.users SET daily_enabled=(p->>'daily')::boolean WHERE chat_id=cid;
 END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('sport',f.sport,'team_key',f.team_key,'label',f.label,'aliases',f.aliases) ORDER BY f.sport,f.label),'[]'::jsonb)
 INTO pref FROM sports_radar.follows f WHERE f.chat_id=cid;
 SELECT daily_enabled INTO daily FROM sports_radar.users WHERE chat_id=cid;
 IF a='myteams' THEN
  SELECT coalesce(string_agg(f.label || ' (' || f.sport || ')', E'\n' ORDER BY f.sport,f.label),'No preferences yet. Use /follow football Chelsea, /follow basketball Lakers or /follow f1.')
  INTO reply FROM sports_radar.follows f WHERE f.chat_id=cid;
  reply := reply || E'\n\nDaily digest: ' || CASE WHEN daily THEN 'on' ELSE 'off' END;
 END IF;
 RETURN jsonb_build_object('chat_id',cid,'mode','manual','prefs',pref,'reply',reply,'do_briefing',a='events');
END $$;
REVOKE ALL ON ALL TABLES IN SCHEMA sports_radar FROM PUBLIC;
REVOKE ALL ON FUNCTION sports_radar.command(jsonb) FROM PUBLIC;
-- Connect n8n as the database owner using the Supabase session pooler.
-- This private schema is not a public client API; do not add it to exposed schemas.
