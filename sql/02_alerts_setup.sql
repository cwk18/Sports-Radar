-- Sports Radar 05: run in Supabase SQL Editor AFTER database_setup.sql.
-- Re-runnable. Does not change follows, daily settings, or existing functions.
BEGIN;
CREATE TABLE IF NOT EXISTS sports_radar.alert_preferences (
  chat_id text PRIMARY KEY REFERENCES sports_radar.users(chat_id) ON DELETE CASCADE,
  previews_enabled boolean NOT NULL DEFAULT false,
  reminders_enabled boolean NOT NULL DEFAULT false,
  quiet_enabled boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS sports_radar.alert_jobs (
  job_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_id text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('preview','start')),
  due_at timestamptz NOT NULL,
  payload jsonb NOT NULL,
  state text NOT NULL DEFAULT 'queued' CHECK (state IN ('queued','processing','done','failed','cancelled')),
  owner text,
  lease_until timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(event_id,kind)
);
CREATE TABLE IF NOT EXISTS sports_radar.alert_deliveries (
  event_id text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('preview','start')),
  chat_id text NOT NULL REFERENCES sports_radar.users(chat_id) ON DELETE CASCADE,
  state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending','sent','error')),
  created_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  telegram_message_id bigint,
  PRIMARY KEY(event_id,kind,chat_id)
);
CREATE TABLE IF NOT EXISTS sports_radar.alert_api_slots (
  provider text PRIMARY KEY CHECK(provider IN ('football','basketball','f1')),
  next_at timestamptz NOT NULL
);

CREATE OR REPLACE FUNCTION sports_radar.alert_norm(s text) RETURNS text
LANGUAGE sql IMMUTABLE STRICT AS $$
 SELECT regexp_replace(lower(translate(s,'àáâäãåèéêëìíîïòóôöõùúûüñç','aaaaaaeeeeiiiiooooouuuunc')),'[^a-z0-9]','','g')
$$;

CREATE OR REPLACE FUNCTION sports_radar.alert_follows(cid text, e jsonb) RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,sports_radar AS $$
 SELECT EXISTS (
   SELECT 1 FROM sports_radar.follows f
   WHERE f.chat_id=cid AND f.sport=e->>'sport' AND
   (f.sport='f1' OR EXISTS (
     SELECT 1 FROM jsonb_array_elements_text(COALESCE(e->'participants','[]'::jsonb)) p,
       jsonb_array_elements_text(COALESCE(f.aliases,'[]'::jsonb)||jsonb_build_array(f.label)) a
     WHERE sports_radar.alert_norm(p)=sports_radar.alert_norm(a)
   ))
 )
$$;

CREATE OR REPLACE FUNCTION sports_radar.set_alert_preferences(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,sports_radar AS $$
DECLARE cid text:=p->>'chat_id'; cmd text:=p->>'alert_command'; val text:=p->>'alert_value'; a sports_radar.alert_preferences; reply text;
BEGIN
 IF cid IS NULL OR cid !~ '^[0-9]+$' THEN RAISE EXCEPTION 'Private chat ID required'; END IF;
 INSERT INTO sports_radar.users(chat_id) VALUES(cid) ON CONFLICT DO NOTHING;
 INSERT INTO sports_radar.alert_preferences(chat_id) VALUES(cid) ON CONFLICT DO NOTHING;
 IF cmd IN ('previews','reminders','quiet') AND val IN ('on','off') THEN
   UPDATE sports_radar.alert_preferences SET
     previews_enabled=CASE WHEN cmd='previews' THEN val='on' ELSE previews_enabled END,
     reminders_enabled=CASE WHEN cmd='reminders' THEN val='on' ELSE reminders_enabled END,
     quiet_enabled=CASE WHEN cmd='quiet' THEN val='on' ELSE quiet_enabled END,
     updated_at=now() WHERE chat_id=cid;
 END IF;
 SELECT * INTO a FROM sports_radar.alert_preferences WHERE chat_id=cid;
 reply:='Sports Radar alert settings'||E'\n\n'||
   'Previews (30 minutes before): '||CASE WHEN a.previews_enabled THEN 'ON' ELSE 'OFF' END||E'\n'||
   'Scheduled start reminders: '||CASE WHEN a.reminders_enabled THEN 'ON' ELSE 'OFF' END||E'\n'||
   'Quiet hours (23:00–07:00 Paris): '||CASE WHEN a.quiet_enabled THEN 'ON' ELSE 'OFF' END||E'\n\n'||
   '/previews on · /previews off'||E'\n/reminders on · /reminders off\n/quiet on · /quiet off\n/alerts — view these settings';
 RETURN jsonb_build_object('chat_id',cid,'reply',reply);
END $$;

CREATE OR REPLACE FUNCTION sports_radar.plan_alert_jobs(p jsonb) RETURNS SETOF jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,sports_radar AS $$
DECLARE v jsonb; j sports_radar.alert_jobs;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements(p) LOOP
   IF (v->>'due_at')::timestamptz < now()-interval '5 minutes' OR (v->>'due_at')::timestamptz > now()+interval '7 hours' THEN CONTINUE; END IF;
   INSERT INTO sports_radar.alert_jobs(event_id,kind,due_at,payload)
   VALUES(v->>'event_id',v->>'kind',(v->>'due_at')::timestamptz,v)
   ON CONFLICT(event_id,kind) DO UPDATE SET due_at=EXCLUDED.due_at,payload=EXCLUDED.payload,
     state='queued',owner=NULL,lease_until=NULL,updated_at=now()
   WHERE (alert_jobs.state IN ('failed','cancelled'))
      OR (alert_jobs.state='queued' AND alert_jobs.updated_at<now()-interval '5 minutes')
      OR (alert_jobs.state='processing' AND alert_jobs.lease_until<now())
   RETURNING * INTO j;
   IF FOUND THEN RETURN NEXT j.payload||jsonb_build_object('job_id',j.job_id); END IF;
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION sports_radar.take_alert_job(jid bigint, who text) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,sports_radar AS $$
DECLARE j sports_radar.alert_jobs;
BEGIN
 UPDATE sports_radar.alert_jobs SET state='processing',owner=who,
   lease_until=greatest(now(),due_at)+interval '2 hours',updated_at=now()
 WHERE job_id=jid AND state='queued' RETURNING * INTO j;
 IF NOT FOUND THEN RETURN NULL; END IF;
 RETURN j.payload||jsonb_build_object('job_id',j.job_id,'owner',who);
END $$;

CREATE OR REPLACE FUNCTION sports_radar.reserve_alert_api(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,sports_radar AS $$
DECLARE provider_name text:=p->>'sport'; gap interval; slot timestamptz;
BEGIN
 gap:=CASE provider_name WHEN 'basketball' THEN interval '15 seconds' WHEN 'football' THEN interval '7 seconds' ELSE interval '2 seconds' END;
 -- Keep the waiting job lease current after a provider changes the start time.
 UPDATE sports_radar.alert_jobs SET due_at=(p->>'due_at')::timestamptz,payload=p,
   lease_until=greatest(now(),(p->>'due_at')::timestamptz)+interval '2 hours',updated_at=now()
 WHERE job_id=(p->>'job_id')::bigint AND owner=p->>'owner' AND state='processing';
 INSERT INTO sports_radar.alert_api_slots(provider,next_at) VALUES(provider_name,now()) ON CONFLICT DO NOTHING;
 SELECT greatest(next_at,now()) INTO slot FROM sports_radar.alert_api_slots WHERE provider=provider_name FOR UPDATE;
 UPDATE sports_radar.alert_api_slots SET next_at=slot+gap WHERE provider=provider_name;
 RETURN p||jsonb_build_object('api_at',slot);
END $$;

CREATE OR REPLACE FUNCTION sports_radar.claim_alert_recipients(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,sports_radar AS $$
DECLARE a sports_radar.alert_preferences; recipients jsonb:='[]'; cid text; t time; allowed boolean;
BEGIN
 -- Lock the job to prevent competing workers claiming the same delivery.
 PERFORM 1 FROM sports_radar.alert_jobs WHERE job_id=(p->>'job_id')::bigint AND owner=p->>'owner' AND state='processing' FOR UPDATE;
 IF NOT FOUND THEN RETURN p||jsonb_build_object('recipients','[]'::jsonb); END IF;
 IF (p->>'due_at')::timestamptz>now()+interval '2 seconds' OR
    now()-(p->>'due_at')::timestamptz > (CASE WHEN p->>'kind'='preview' THEN interval '5 minutes' ELSE interval '3 minutes' END) THEN
   RETURN p||jsonb_build_object('recipients','[]'::jsonb);
 END IF;
 t:=(now() AT TIME ZONE 'Europe/Paris')::time;
 FOR a IN SELECT * FROM sports_radar.alert_preferences LOOP
   allowed:=CASE WHEN p->>'kind'='preview' THEN a.previews_enabled ELSE a.reminders_enabled END;
   IF NOT allowed OR (a.quiet_enabled AND (t>=time '23:00' OR t<time '07:00')) OR NOT sports_radar.alert_follows(a.chat_id,p) THEN CONTINUE; END IF;
   INSERT INTO sports_radar.alert_deliveries(event_id,kind,chat_id) VALUES(p->>'event_id',p->>'kind',a.chat_id)
   ON CONFLICT DO NOTHING RETURNING chat_id INTO cid;
   IF FOUND THEN recipients:=recipients||jsonb_build_array(jsonb_build_object('chat_id',cid)); END IF;
 END LOOP;
 RETURN p||jsonb_build_object('recipients',recipients);
END $$;

CREATE OR REPLACE FUNCTION sports_radar.finish_alert_delivery(p jsonb) RETURNS boolean
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,sports_radar AS $$
BEGIN
 UPDATE sports_radar.alert_deliveries SET state=CASE WHEN p->>'message_id' IS NOT NULL THEN 'sent' ELSE 'error' END,
   sent_at=CASE WHEN p->>'message_id' IS NOT NULL THEN now() ELSE NULL END,
   telegram_message_id=(p->>'message_id')::bigint
 WHERE event_id=p->>'event_id' AND kind=p->>'kind' AND chat_id=p->>'chat_id' AND state='pending';
 RETURN FOUND;
END $$;

REVOKE ALL ON ALL TABLES IN SCHEMA sports_radar FROM PUBLIC;
REVOKE ALL ON FUNCTION sports_radar.alert_norm(text), sports_radar.alert_follows(text,jsonb),
 sports_radar.set_alert_preferences(jsonb), sports_radar.plan_alert_jobs(jsonb),
 sports_radar.take_alert_job(bigint,text), sports_radar.reserve_alert_api(jsonb),
 sports_radar.claim_alert_recipients(jsonb), sports_radar.finish_alert_delivery(jsonb) FROM PUBLIC;
ALTER TABLE sports_radar.alert_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE sports_radar.alert_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sports_radar.alert_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE sports_radar.alert_api_slots ENABLE ROW LEVEL SECURITY;
COMMIT;
