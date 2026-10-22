BEGIN;
SELECT sports_radar.command('{"chat_id":"123456789","action":"follow","sport":"football","team_key":"61","label":"Chelsea FC","aliases":["chelsea"]}'::jsonb);
SELECT sports_radar.command('{"chat_id":"123456789","action":"follow","sport":"football","team_key":"61","label":"Chelsea FC","aliases":["chelsea"]}'::jsonb);
DO $$ BEGIN
 IF (SELECT count(*) FROM sports_radar.follows WHERE chat_id='123456789' AND sport='football' AND team_key='61')<>1 THEN RAISE EXCEPTION 'Duplicate follow'; END IF;
END $$;
INSERT INTO sports_radar.processed_updates(update_id,chat_id) VALUES(9223372036854000000,'123456789') ON CONFLICT DO NOTHING;
INSERT INTO sports_radar.processed_updates(update_id,chat_id) VALUES(9223372036854000000,'123456789') ON CONFLICT DO NOTHING;
DO $$ BEGIN
 IF (SELECT count(*) FROM sports_radar.processed_updates WHERE update_id=9223372036854000000)<>1 THEN RAISE EXCEPTION 'Duplicate update'; END IF;
END $$;
SELECT sports_radar.set_alert_preferences('{"chat_id":"123456789","alert_command":"reminders","alert_value":"on"}'::jsonb);
SELECT sports_radar.command('{"chat_id":"123456789","action":"daily","daily":false}'::jsonb);
DO $$ BEGIN
 IF (SELECT daily_enabled FROM sports_radar.users WHERE chat_id='123456789') THEN RAISE EXCEPTION 'Daily off failed'; END IF;
 IF NOT (SELECT reminders_enabled FROM sports_radar.alert_preferences WHERE chat_id='123456789') THEN RAISE EXCEPTION 'Daily off affected reminder preference'; END IF;
END $$;
SELECT 'PASS: duplicate follows, update replay protection and independent alert settings' AS result;
ROLLBACK;
