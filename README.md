# Sports Radar - n8n Cloud

Sports fans check several apps to track their favourite teams. Sports Radar remembers their choices and brings personalised schedules, previews and scheduled-start reminders into Telegram.

This submission contains the six workflow exports used by the n8n Cloud project, database setup for Supabase Postgres, architecture documentation and repeatable checks. Credentials are configured inside n8n and are not supplied in this package.

**Scope:** supported football competitions, NBA teams, and Formula 1 qualifying/race sessions. **Architecture level:** system overview plus workflow-level detail. **Cut line:** schedules and available recent results; no verified lineups, injury reports, betting predictions, live scores or confirmation that play has actually started.

## Start here

- [Architecture diagram](docs/architecture.pdf): workflow boundaries and labelled data flows.
- [Node guide](docs/NODE_GUIDE.md): the nodes and their responsibilities.
- [Verification report](docs/VERIFICATION.md): evidence, export provenance and limitations.
- [Automated check results](docs/check-results.txt): results for the included files.

## Workflows

| File | Purpose | Trigger / input |
| --- | --- | --- |
| [01](workflows/01.json) | Telegram commands/buttons, update deduplication, follows and settings | Telegram Trigger |
| [02](workflows/02.json) | Fetch calendars, filter followed events, validate AI overview, send briefing | Sub-workflow: `context` object |
| [03](workflows/03.json) | Optional daily briefing, reusing 02 | 08:00 Europe/Paris |
| [04](workflows/04.json) | Owner error alert with workflow, node and execution link | Error Trigger |
| [05](workflows/05.json) | Shared calendar scan; queue preview and start jobs | Every six hours / Plan now |
| [05B](workflows/05B.json) | Wait, verify schedule, retrieve recent form and deliver alerts | Sub-workflow: numeric `job_id` |

## Set up a separate n8n Cloud instance

### 1. Prepare Supabase

Create a Supabase project and run these files in its SQL Editor, in order:

1. `sql/01_database_setup.sql`
2. `sql/02_alerts_setup.sql`
3. `sql/03_update_deduplication.sql`

They create the private `sports_radar` schema, tables and functions. Keep this schema out of Supabase's exposed API schemas. n8n connects directly through a Postgres credential; no public application API is required.

### 2. Import the six workflows

In n8n Cloud, import each JSON in `workflows/` into its own workflow. Leave triggers unpublished until credentials and workflow references are configured. These exports include references to the original instance's credentials and child workflows; a new instance requires reselecting those references.

### 3. Create and assign credentials

Create each credential once and select it in every applicable node. Obtain credentials from your own accounts; never commit secret values to the repository.

| Service | Credential / header | Purpose |
| --- | --- | --- |
| Telegram | Telegram API credential with your BotFather token | Receive messages and send replies/alerts |
| Supabase Postgres | Database owner credential, using the project's session-pooler connection details and SSL | User preferences, jobs, update claims and delivery records |
| football-data.org | Header Auth: `X-Auth-Token` | Football teams, schedules and results |
| API-Sports NBA | Header Auth: `x-apisports-key` | Team catalogue and selected-team lookup in 01 |
| BALLDONTLIE | Header Auth: `Authorization`; exact API key, without a `Bearer` prefix | NBA schedules and recent results |
| Groq | Groq API credential | AI overview in 02; exported model: `openai/gpt-oss-20b` |
| Jolpica F1 | No credential | F1 drivers, calendars and results |

Use the same project-owner Postgres credential throughout all six workflows. A provider's free-plan coverage and rate limits may affect available data. Confirm the selected Groq model is available to your account.

In workflow 04, replace the owner notification chat ID with your own private Telegram chat ID. To find it, send a message to your bot and inspect `message.chat.id` in the Telegram Trigger output. Start the bot privately before expecting owner alerts.

### 4. Reconnect child and error workflows

- In 01, **Build and send briefing** must select imported workflow 02.
- In 03, **Send each daily briefing** must also select 02.
- In 05, **Start alert worker** must select imported 05B.
- In the settings of 01, 02, 03, 05 and 05B, select imported 04 as the error workflow.
- Preserve the input mappings: `context` into 02 and `job_id` into 05B.
- Check every workflow's timezone is **Europe/Paris**. An export without an explicit timezone may inherit the instance setting.

Publish callable children and the error workflow before the workflows that use them. Use only one published Telegram Trigger per bot; another trigger using the same token can replace the existing webhook. Use a separate test bot when reproducing the project alongside the original.

### 5. Choose notification settings

Follow a team or driver through Telegram. Upcoming events can be requested immediately with the button or `/events`.

Daily briefings, previews and reminders are independent. Enable only the features you want. Initial alert opt-in defaults to OFF. After opting in, use **Plan now** in 05 to plan eligible upcoming events immediately rather than waiting for its next six-hour scan.

## User commands

| Command / button | Result |
| --- | --- |
| `/start`, Home | Welcome screen and sport choices |
| Sport / league / team or driver buttons | Save a follow |
| My follows, `/myteams` | View saved choices and unfollow controls |
| Upcoming events, `/events` | Request the next seven days now |
| `/daily on`, `/daily off` | Enable or disable the daily digest |
| `/previews on`, `/previews off` | Enable or disable previews about 30 minutes before an event |
| `/reminders on`, `/reminders off` | Enable or disable scheduled-start reminders |
| `/quiet on`, `/quiet off` | Suppress or permit alerts between 23:00 and 07:00 Paris |
| `/alerts` | View alert preferences |
| `/help` | Usage instructions |
| `/demoerror` | Deliberately fail an isolated HTTP request to demonstrate the error path |

## Reliability and AI boundaries

HTTP, database and LLM-chain calls have bounded retries. Telegram sends are not automatically retried after an uncertain acknowledgement because a resend could duplicate a delivered message.

Workflow 02 gives the AI system instructions and a filtered calendar as data. It requests exactly `{ "overview": "..." }`. A Code node checks the response structure, length and text restrictions. Invalid output follows **Use calendar fallback**, so the event list can be sent without an AI introduction. Validation checks structure, not factual truth. Event dates, filtering and statistics come from APIs and deterministic code.

Postgres unique keys protect follows, daily deliveries, alert jobs and recipient deliveries. Workflow 01 claims each Telegram update ID before processing. A repeated update is skipped; two new `/events` messages are separate requests and may each receive a reply. If processing fails after a claim, send a fresh command to retry. This is not a guarantee of exactly-once delivery.

Workers recheck event schedules and current follows, alert opt-in and quiet settings before sending. NBA recent form uses completed games, pagination, provider-owned team IDs and duplicate removal. Older or incomplete history is labelled. Six-hour scans reduce API requests but can miss newly announced or earlier-rescheduled events between scans. F1 follows currently select calendar sessions without verifying each driver's participation.

## Testing

With Node.js installed, run from this folder:

```sh
node tests/check_workflows.cjs
```

These checks inspect the exported graphs, code syntax, routing, AI validation/fallback, sub-workflow mappings, retries and navigation. They do not call the live APIs or confirm future timer deliveries.

For database behaviour, run `tests/database_checks.sql` in the Supabase SQL Editor against a disposable test project after applying the setup scripts. The test uses a transaction and rolls back its test records. It checks duplicate follows, duplicate update claims and independent daily/reminder settings.

Live acceptance checks:

1. Send `/start`; confirm the welcome menu arrives.
2. Follow a team; request My follows in a later execution and confirm persistence.
3. Request Upcoming events; confirm 01 calls 02 and sends a readable schedule.
4. Send `/daily` without an argument and `/nonsense`; confirm useful usage help.
5. Send `/demoerror`; confirm the expected failed execution and workflow 04 owner notification with its execution link.
6. Check `/alerts`; confirm notification choices. Test timed alerts with a suitable upcoming event separately.

## Source snapshot

The workflow graphs match the latest saved Cloud exports downloaded on 22 October 2026, after the approved changes were published. This package preserves those workflow JSON files unchanged. It is not a fresh download of any changes made after those exports. See the verification report for the evidence and limitations.

This folder contains submission files, not Git history. Website upload creates a new commit under the signed-in account and does not reconstruct earlier development history.
