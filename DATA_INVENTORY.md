# Data Inventory

The map of the warehouse. Built during Phase 1. Updated whenever new sources come into scope.

## Connection details

Warehouse type: Snowflake
Account / host: [your_account].snowflakecomputing.com
Authorized output schema: consumer_beta.telemetry_overview
Access mode: read-only on source schemas; write permitted to consumer_beta.telemetry_overview for MTM_ tables
Environment variables: SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PASSWORD, SNOWFLAKE_WAREHOUSE, SNOWFLAKE_ROLE

## Source systems

Two source databases are in scope:

`dev_telemetry` pulls from two origins: WalkMe behavioral event tracking (product_telemetry schema) and the Angles Professional licensing system (awssql_spslicensing_dbo schema, sourced from an AWS SQL Server via Fivetran). Both are read-only during exploration.

`inbound_raw` is Salesforce CRM data landed via Fivetran. The salesforce schema contains the account, contract, opportunity, and onboarding objects relevant to CS workflows.

## In-scope tables

| Table | Appears to represent | Grain (one row per...) | Notes |
|-------|---------------------|------------------------|-------|
| `dev_telemetry.product_telemetry.WM_WHOLOGGEDINYESTERDAY_ANGLESPROF` | Daily login records for Angles Professional users | account + date | ACCOUNT_ID format: `platform:{WEBID}` or `platform:{PLATFORM_LEGACY_ID_C}` |
| `dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLEPROF_REPORTCENTER` | WalkMe-tracked behavioral events within Report Center | event occurrence (account + event name + time) | Key events: `RC | User On Home Page`, `RC | User on Reports Upload Page`, `RC | User on Create Schedules Page`, `RC | Create Report Schedule Clicked`, `RC | Lineos Clicked`, `RC | View all Clicked (Reports)` |
| `dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLESPROF_INTELLAYER` | WalkMe-tracked behavioral events within Intelligence Layer | event occurrence (account + event name + time) | Key events: `INTEL | User on Intelligence Layer Home Page`, `INTEL | Click Create Rule Button`, `INTEL | Subscribers Added to Rule`, `INTEL | Button to Save Rule Clicked`, `INTEL | Click Results tab Button`, `INTEL | Edit Rule Button`, `INTEL | Delete Rule Button` |
| `dev_telemetry.awssql_spslicensing_dbo.customer` | Licensing customer master | customer | Key columns: CUSTOMERID, CUSTOMERNAME, SALESFORCEID (join to SFDC), WEBID (join to telemetry), ONMAINTENANCE |
| `dev_telemetry.awssql_spslicensing_dbo.customerlicensekeys` | Individual license key records | license key | Key columns: CUSTOMERID, ASSIGNEDUSER, CUSTOMEREMAIL, DATEASSIGNED, LASTVALIDATEDDATE (NULL = never launched), REGISTERED, DEACTIVATED; filter on `_FIVETRAN_DELETED = FALSE` |
| `dev_telemetry.awssql_spslicensing_dbo.dailylicenseusage` | Daily per-user product usage records | customer + assigned user + date | LASTVALIDATEDDATE is the usage date; data current to 2026-03-19 as of last run -- parameterise REF_DATE to MAX(LASTVALIDATEDDATE) not CURRENT_DATE |
| `inbound_raw.salesforce.account` | Salesforce account master | account | Key columns: ID, NAME, TYPE, ACTIVE_PRODUCT_LINES_C, CUSTOMER_SUCCESS_ASSOCIATE_C, PLATFORM_LEGACY_ID_C (join to telemetry), NEXT_RENEWAL_DATE_C, OPEN_RENEWABLE_AMOUNT_C, CUSTOMER_HEALTH_GRADE_C, TOTANGO_TOTANGO_ACCOUNT_HEALTH_C, AT_RISK_C, OPEN_SUPPORT_CASES_C; filter on `_FIVETRAN_DELETED = FALSE` |
| `inbound_raw.salesforce.contract` | Salesforce contract records | contract | Key columns: ACCOUNT_ID, STATUS ('Activated'), CUSTOMER_SIGNED_DATE; filter on `_FIVETRAN_DELETED = FALSE` |
| `inbound_raw.salesforce.opportunity` | Salesforce opportunity records | opportunity | Key columns: ACCOUNT_ID, STAGE_NAME ('Closed Lost'), CLOSE_DATE, WIN_LOSS_REASON_C, WIN_LOSS_SUB_REASON_C, PRODUCT_LINE_C; filter on `_FIVETRAN_DELETED = FALSE` |
| `inbound_raw.salesforce.onboarding_c` | Salesforce onboarding custom object | onboarding record | Key columns: ACCOUNT_C (join to account.ID), STAGE_C, STATUS_C |
| `consumer_beta.telemetry_overview.MTM_S1_CSM_ASSIGNMENT_HANDOFF` | MTM output: accounts with no CSM assigned >1 day after contract activation | account | Written by sql/create_all_mtm_tables.sql |
| `consumer_beta.telemetry_overview.MTM_S2_LICENSE_KEY_NEVER_USED` | MTM output: license keys registered but never validated after 48+ hours | license key | 5,861 rows as of 2026-05-19 |
| `consumer_beta.telemetry_overview.MTM_S3_DOUBLE_HOMEPAGE_CONFUSION` | MTM output: accounts with logins but no RC homepage event | account | 104 rows as of 2026-05-19 |
| `consumer_beta.telemetry_overview.MTM_S4_FIRST_REPORT_UPLOAD_STALL` | MTM output: accounts 3+ days past first use with no upload page reached | account | 5,844 rows as of 2026-05-19 |
| `consumer_beta.telemetry_overview.MTM_S5_FEATURE_DISCOVERY_GAP` | MTM output: 30+ active days, zero secondary RC feature events | account | 5,303 rows as of 2026-05-19 |
| `consumer_beta.telemetry_overview.MTM_S6_SCHEDULE_CREATION_DROPOFF` | MTM output: visited schedule page, never completed, 5+ days | account | 22 rows as of 2026-05-19 |
| `consumer_beta.telemetry_overview.MTM_S7_IL_NEVER_ENTERED` | MTM output: RC active 7+ days, zero IL events ever | account | 44 rows as of 2026-05-19 |
| `consumer_beta.telemetry_overview.MTM_S8_RULE_CREATION_FUNNEL_FAILURE` | MTM output: visited IL homepage, never saved a rule | account | 6 rows as of 2026-05-19 |
| `consumer_beta.telemetry_overview.MTM_S9_FIRST_RULE_FIRED_VALUE_REALIZED` | MTM output: rule saved but Results tab not viewed in 7+ days | account | 0 rows as of 2026-05-19 (possible instrumentation gap -- see known issues) |
| `consumer_beta.telemetry_overview.MTM_S10_LICENSE_SEAT_UTILIZATION_DROP` | MTM output: active users <50% of prior 30d for 5+ seat accounts | account | 13 rows as of 2026-05-19 |
| `consumer_beta.telemetry_overview.MTM_S11_DORMANT_SEATS_RENEWAL_RISK` | MTM output: >30% dormant seats, renewal within 120 days | account | 82 rows as of 2026-05-19 |
| `consumer_beta.telemetry_overview.MTM_S12_LOGIN_WITHOUT_IL_HEALTH_CHECK` | MTM output: active logins 14d, zero IL events same window | account | 70 rows as of 2026-05-19 |
| `consumer_beta.telemetry_overview.MTM_S13_IL_ENGAGEMENT_DROP` | MTM output: no new rules 60+ days OR results not viewed 14+ days | account | 0 rows as of 2026-05-19 (HAVING logic may need review -- see open questions) |
| `consumer_beta.telemetry_overview.MTM_S14_PRE_RENEWAL_HEALTH_SCORECARD` | MTM output: renewal within 120 days, 5-signal health scorecard | account | 22 rows as of 2026-05-19 |
| `consumer_beta.telemetry_overview.MTM_S15_LAPSED_MAINTENANCE_STILL_USING` | MTM output: ONMAINTENANCE=FALSE but license validating daily | account | 0 rows as of 2026-05-19 (ONMAINTENANCE field type may need checking -- see open questions) |
| `consumer_beta.telemetry_overview.MTM_S16_CANCELLATION_IL_ADOPTION_AUDIT` | MTM output: Closed Lost opportunities with IL/RC/license state at churn | opportunity | 106 rows as of 2026-05-19 |

## Tables explicitly out of scope

- `inbound_raw.salesforce.task` and `inbound_raw.salesforce.event` -- CS activity log tables that look relevant to MTM scenarios but have not been validated; excluded until explicitly added.
- Any Snowflake schemas outside `dev_telemetry`, `inbound_raw`, and `consumer_beta.telemetry_overview`.

## Refresh patterns

`dev_telemetry` and `inbound_raw` are loaded via Fivetran. Exact refresh cadence not confirmed. `DAILYLICENSEUSAGE` was current to 2026-03-19 during the 2026-05-19 run -- approximately 2 months of lag at that point. Check MAX(LASTVALIDATEDDATE) before running S10/S11 to determine actual data currency.

The MTM_ output tables in `consumer_beta.telemetry_overview` are refreshed by re-running `sql/create_all_mtm_tables.sql`. There is no scheduled refresh -- this is a manual or CI-triggered run.

## Known data quirks

- Telemetry ACCOUNT_ID is a formatted string -- `platform:{WEBID}` or `platform:{PLATFORM_LEGACY_ID_C}` -- not a raw numeric ID. String-concatenate when joining.
- `_FIVETRAN_DELETED` columns exist on Fivetran-sourced tables. Always filter `_FIVETRAN_DELETED = FALSE` to exclude soft-deleted rows.
- `SESSION_ID` exists in Intelligence Layer events (used by S8/S13) but does not appear in Report Center events -- do not attempt SESSION_ID-based deduplication in RC telemetry tables.
- `TRY_TO_DATE(EVENT_TIME)` is required when casting EVENT_TIME in telemetry tables because the raw field is VARCHAR and some rows contain non-date values.
- `CUSTOMER_SUCCESS_ASSOCIATE_C` in the SFDC account table stores a Salesforce User ID (18-char), not a display name. A separate User lookup is needed for human-readable CSM names in the dashboard.
