# Verification - Cloud submission

## Export provenance

The six workflow JSON files were copied unchanged from the saved release. Their node graphs and connections were compared with the latest matching n8n Cloud downloads available on this computer on 22 October 2026; all six match. File hashes are recorded in `workflow-sha256.json`.

The source record reports that all six corrected Cloud graphs were published before these exports were downloaded. This packaging step did not access or change the live instance. Later live edits, if any, are not captured by this snapshot.

## Recorded live checks

On 22 October 2026 at approximately 15:48 Europe/Paris, the user tested `/start`, `/events` and `/demoerror` and confirmed all three expected responses arrived. The recorded executions were successful runs #342 and #343, and intentional failure #345 for the error-path demonstration. The deliberate failure is expected and triggers the owner alert.

## Checks for this package

Run `node tests/check_workflows.cjs` to reproduce the workflow checks. The attached `check-results.txt` records the packaging-time results. These cover graph consistency, JavaScript syntax, routing, usage help, invalid AI output, calendar fallback, input mappings, retries and navigation.

The timezone check accepts an omitted export setting because n8n may inherit the instance setting. Confirm Europe/Paris in the Cloud settings; an omitted value is not proof of the live timezone.

The supplied database test is available for a separate Supabase test project. It was not executed against the live production database during this packaging step.

## Limitations

- Future timed alerts were not newly tested end to end during packaging. Waiting executions may retain the version with which they started.
- External API availability, quotas and schedule correctness are not established by static checks.
- AI schema validation does not establish factual accuracy.
- Telegram delivery can be uncertain if acknowledgement is lost; sends are not automatically retried in that situation.
- Credential secrets are not included. Imported credential and child-workflow references must be configured in a new Cloud instance.
- This package does not supply or claim a multi-day Git commit history.

## Export detail

For the included Wait node version 1.1, omitted `unit` defaults to seconds. `amount: 1` therefore means a one-second spacing delay. The check accounts for the node version rather than assuming the older default.
