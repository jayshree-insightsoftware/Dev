# Changes Log

Chronological record of significant changes, architectural decisions, and learned lessons. One-liner entries with date prefixes. Don't log every commit -- only inflection points worth recalling later.

Format: `YYYY-MM-DD: brief description of the change and why it matters`

## Entries

2026-05-27: SQL -- sfdc_account_id standardized across all 16 scenario tables to always source from inbound_raw.salesforce.account.ID (previously S2, S4, S5 used c.SALESFORCEID from the licensing table, which is less reliable); account_sfdc_link column added to every MTM_ table; SFDC bridge join via customer.WEBID added to S3, S6, S7 which previously surfaced only a telemetry_account_id; S6 and S7 refactored to CTE pattern for cleaner aggregation; _FIVETRAN_DELETED = FALSE guard added to all account LEFT JOINs.

2026-05-27: Dashboard -- direct "Open in Salesforce" link button added to the SF Account ID slicer field; Salesforce record links added to the S16 table SFDC column, Account View panel, and filter status bar; Account Type dropdown is now populated dynamically from data instead of hardcoded options; bidirectional cross-filtering implemented for Type/Channel/Product Line/CSM dimension slicers so each dropdown shows only values valid given all other active filters.

2026-05-19: Added dashboard.html -- static MTM alert dashboard covering all 16 scenarios with inline data from the 2026-05-19 Snowflake run; shows 17,477 total accounts in alert across Onboarding/Adoption/Retention/Offboarding stages.

2026-05-19: Added sql/create_all_mtm_tables.sql -- single script that creates or replaces all 16 MTM_ tables in consumer_beta.telemetry_overview; this is the canonical SQL for the mart layer.

2026-05-19: Added mtm_scenarios_claude_code.md -- full scenario spec with trigger logic, SQL, output columns, and known telemetry gaps for all 16 MTM scenarios; source of truth for scenario definitions.

2026-05-19: Documented 4 telemetry instrumentation gaps (rule-fire event, save-draft event, subscriber-not-found error, partial join key coverage); these affect S6, S8, S9, and cross-schema joins on WEBID/PLATFORM_LEGACY_ID_C.

2026-05-19: Established project scope -- Reporting Intelligence (Angles Professional, Report Center, Intelligence Layer), source systems dev_telemetry and inbound_raw, output schema consumer_beta.telemetry_overview.
