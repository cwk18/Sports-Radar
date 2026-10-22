# Node-by-node explanation

This inventory explains the nodes in the release exports.

## 01 Sports Radar - Telegram commands

| Node | Responsibility |
| --- | --- |
| Telegram message | Receive private-message and callback updates from the bot. |
| Understand command | Transform or validate incoming data using the code shown in this node. |
| Button click? | Choose true or false according to the displayed condition. |
| Acknowledge button | Acknowledges each button once, before API calls. An expired callback must not block processing. |
| Route request | Each update takes exactly one route. The named parser reference preserves context after Telegram acknowledgment. |
| Choose football league | Send or acknowledge a Telegram interaction. |
| Get league teams | Call the configured provider URL with bounded retry settings. |
| Get NBA teams | Call the configured provider URL with bounded retry settings. |
| Get F1 Drivers | Call the configured provider URL with bounded retry settings. |
| Get selected football team | Call the configured provider URL with bounded retry settings. |
| Get selected NBA team | Call the configured provider URL with bounded retry settings. |
| Get selected F1 driver | Call the configured provider URL with bounded retry settings. |
| Load my follows | Run the shown parameterised SQL against private project state. |
| Save command and load preferences | Run the shown parameterised SQL against private project state. |
| Prepare football teams | Transform or validate incoming data using the code shown in this node. |
| 20 teams? | Choose true or false according to the displayed condition. |
| Send 20-team menu | Send or acknowledge a Telegram interaction. |
| Send 18-team menu | Send or acknowledge a Telegram interaction. |
| Prepare NBA teams | Transform or validate incoming data using the code shown in this node. |
| Send NBA team menu | Send or acknowledge a Telegram interaction. |
| Prepare F1 drivers | Transform or validate incoming data using the code shown in this node. |
| Send F1 driver menu | Send or acknowledge a Telegram interaction. |
| Prepare football follow | Transform or validate incoming data using the code shown in this node. |
| Prepare NBA follow | Transform or validate incoming data using the code shown in this node. |
| Prepare F1 follow | Transform or validate incoming data using the code shown in this node. |
| Save follow | Run the shown parameterised SQL against private project state. |
| Confirm follow | Shared confirmation after saving or removing a follow. Escapes database labels for Telegram HTML. |
| Format my follows | Transform or validate incoming data using the code shown in this node. |
| Send my follows | Five native button fields shared by My follows and the Unfollow selector. The formatter supplies labels and callbacks. |
| Read saved context | Transform or validate incoming data using the code shown in this node. |
| Build and send briefing | Call the selected child using the explicitly mapped inputs. |
| Reply to command | Send or acknowledge a Telegram interaction. |
| Remove follow | Deletes only the selected follow belonging to this private chat. Returns a confirmation even for an old/already removed button. |
| Save daily settings | Run the shown parameterised SQL against private project state. |
| Alert settings? | Choose true or false according to the displayed condition. |
| Save alert settings | Run the shown parameterised SQL against private project state. |
| Read alert settings | Transform or validate incoming data using the code shown in this node. |
| Confirm alert settings | Send or acknowledge a Telegram interaction. |
| Claim Telegram update | An update ID is claimed once before any side effects. A fresh user command has a new ID and is processed normally. Failed commands can be sent again as a fresh message. |
| Demo failure? | Choose true or false according to the displayed condition. |
| Demonstrate controlled API failure | Deliberate demonstration only: /demoerror routes here. Normal sports requests are unaffected. The HTTP 404 must trigger workflow 04. |

## 02 Sports Radar - Build and send briefing

| Node | Responsibility |
| --- | --- |
| Mark daily delivery sent | Select your Sports Radar Supabase Postgres credential. |
| Send sports briefing | Select the same Telegram bot credential everywhere. |
| Format Telegram message | Transform or validate incoming data using the code shown in this node. |
| Groq Chat Model | Select Groq credential and an available text model from its dropdown. |
| Write short overview | Generate the constrained overview using the system prompt and supplied calendar JSON. |
| Events found? | Choose true or false according to the displayed condition. |
| Prepare briefing | Transform or validate incoming data using the code shown in this node. |
| Read next-year F1 calendar | Transform or validate incoming data using the code shown in this node. |
| Get next-year F1 calendar | Public F1 calendar; no API key required. |
| Next year needed? | Choose true or false according to the displayed condition. |
| Read F1 calendar | Transform or validate incoming data using the code shown in this node. |
| Get F1 calendar | Public F1 calendar; no API key required. |
| F1 needed? | Choose true or false according to the displayed condition. |
| Read NBA calendar | Transform or validate incoming data using the code shown in this node. |
| Get NBA calendar | Select your BALLDONTLIE Header Auth credential before publishing. Header name: Authorization. Value: your exact BALLDONTLIE API key, with no Bearer prefix. Fetches the date window in pages of 100; additional pages are spaced 13 seconds apart. |
| NBA needed? | Choose true or false according to the displayed condition. |
| Read football calendar | Transform or validate incoming data using the code shown in this node. |
| Get football calendar | Header Auth: name X-Auth-Token; value your football-data.org key. |
| Football needed? | Choose true or false according to the displayed condition. |
| Read briefing context | Transform or validate incoming data using the code shown in this node. |
| Prevent repeat daily sends | Select your Sports Radar Supabase Postgres credential. |
| Set seven-day window | Transform or validate incoming data using the code shown in this node. |
| Briefing requested | Declare the child workflow input contract. |
| Validate AI overview | Transform or validate incoming data using the code shown in this node. |
| AI overview valid? | Choose true or false according to the displayed condition. |
| Use calendar fallback | Transform or validate incoming data using the code shown in this node. |

## 03 Sports Radar - Daily digest

| Node | Responsibility |
| --- | --- |
| Every morning at 8 | Start on the displayed Europe/Paris schedule. |
| Load subscribed users | Select your Sports Radar Supabase Postgres credential. |
| Send each daily briefing | REQUIRED: select 02 Sports Radar - Build and send briefing from your workflow list. |

## 04 Sports Radar - Error alert

| Node | Responsibility |
| --- | --- |
| Workflow failed | Receive an unhandled failure payload from linked workflows. |
| Prepare owner alert | Transform or validate incoming data using the code shown in this node. |
| Notify project owner | Select the same Telegram bot credential everywhere. |

## 05 Sports Radar - Previews and start reminders

| Node | Responsibility |
| --- | --- |
| Every six hours | Start on the displayed Europe/Paris schedule. |
| Plan now | Start an on-demand test or planning run. |
| Load alert audience | Run the shown parameterised SQL against private project state. |
| Prepare alert window | Transform or validate incoming data using the code shown in this node. |
| Football needed? | Choose true or false according to the displayed condition. |
| Get football calendar | Use the same Football API credential as workflow 02. |
| Read football calendar | Transform or validate incoming data using the code shown in this node. |
| NBA needed? | Choose true or false according to the displayed condition. |
| Get NBA calendar | Select BALLDONTLIE NBA Header Auth: Authorization = exact API key, no Bearer. |
| Read NBA calendar | Transform or validate incoming data using the code shown in this node. |
| F1 needed? | Choose true or false according to the displayed condition. |
| Get F1 calendar | Public Jolpica endpoint; no key. |
| Read F1 calendar | Transform or validate incoming data using the code shown in this node. |
| Next year needed? | Choose true or false according to the displayed condition. |
| Get next-year F1 calendar | Public Jolpica endpoint; no key. |
| Read next-year F1 calendar | Transform or validate incoming data using the code shown in this node. |
| Build alert jobs | Transform or validate incoming data using the code shown in this node. |
| Queue new alerts | Run the shown parameterised SQL against private project state. |
| Unpack jobs | Transform or validate incoming data using the code shown in this node. |
| For each job | Process the supplied items in controlled batches. |
| Report calendar warnings | Transform or validate incoming data using the code shown in this node. |
| Start alert worker | REQUIRED: select imported 05B Sports Radar - Alert worker. Keep Wait for Sub-Workflow Completion OFF. Loop Over Items supplies one job per invocation. |

## 05B Sports Radar - Alert worker

| Node | Responsibility |
| --- | --- |
| Alert requested | Declare the child workflow input contract. |
| Take alert job | Run the shown parameterised SQL against private project state. |
| Open alert job | Transform or validate incoming data using the code shown in this node. |
| Wait until schedule check | Persist this execution until the configured time. |
| Reserve provider slot | Run the shown parameterised SQL against private project state. |
| Unpack API slot | Transform or validate incoming data using the code shown in this node. |
| Wait for provider slot | Persist this execution until the configured time. |
| Choose provider | Route the parsed request to the matching command/sport branch. |
| Request football data | Use the same Football API credential as workflow 02. |
| Request NBA data | Select BALLDONTLIE NBA Header Auth: Authorization = exact API key, no Bearer. |
| Request F1 data | Public Jolpica endpoint; no key. |
| Read provider response | Transform or validate incoming data using the code shown in this node. |
| Next action | Route the parsed request to the matching command/sport branch. |
| Render alert message | Transform or validate incoming data using the code shown in this node. |
| Wait until alert time | Persist this execution until the configured time. |
| Claim current recipients | Run the shown parameterised SQL against private project state. |
| Unpack recipients | Transform or validate incoming data using the code shown in this node. |
| Has recipients? | Choose true or false according to the displayed condition. |
| Expand recipients | Transform or validate incoming data using the code shown in this node. |
| For each recipient | Process the supplied items in controlled batches. |
| Space Telegram sends | Persist this execution until the configured time. |
| Send event alert | Send or acknowledge a Telegram interaction. |
| Record delivery | Run the shown parameterised SQL against private project state. |
| Finish alert job | Run the shown parameterised SQL against private project state. |
| Report delivery issues | Transform or validate incoming data using the code shown in this node. |
| Stop unsafe alert | Run the shown parameterised SQL against private project state. |
| Report provider issues | Transform or validate incoming data using the code shown in this node. |
| Test delivery | Start an on-demand test or planning run. |
| Test settings | Transform or validate incoming data using the code shown in this node. |
| Send test only | Send or acknowledge a Telegram interaction. |
