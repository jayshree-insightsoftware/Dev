# Changes Log

Chronological record of significant changes, architectural decisions, and learned lessons. One-liner entries with date prefixes. Don't log every commit -- only inflection points worth recalling later.

Format: `YYYY-MM-DD: brief description of the change and why it matters`

## Entries

2026-05-19: Added dashboard.html -- static MTM alert dashboard covering all 16 scenarios with inline data from the 2026-05-19 Snowflake run; shows 17,477 total accounts in alert across Onboarding/Adoption/Retention/Offboarding stages.

2026-05-19: Added sql/create_all_mtm_tables.sql -- single script that creates or replaces all 16 MTM_ tables in consumer_beta.telemetry_overview; this is the canonical SQL for the mart layer.

2026-05-19: Added mtm_scenarios_claude_code.md -- full scenario spec with trigger logic, SQL, output columns, and known telemetry gaps for all 16 MTM scenarios; source of truth for scenario definitions.

2026-05-19: Documented 4 telemetry instrumentation gaps (rule-fire event, save-draft event, subscriber-not-found error, partial join key coverage); these affect S6, S8, S9, and cross-schema joins on WEBID/PLATFORM_LEGACY_ID_C.

2026-05-19: Established project scope -- Reporting Intelligence (Angles Professional, Report Center, Intelligence Layer), source systems dev_telemetry and inbound_raw, output schema consumer_beta.telemetry_overview.
