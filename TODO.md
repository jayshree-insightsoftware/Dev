# TODO

Tracks pending work for this project. Keep this honest -- update entries when scope changes or work is deferred.

Status markers: `[ ]` pending, `[~]` in progress, `[x]` complete

## Phase 1: Discovery and inventory

[x] Identify source databases and schemas (dev_telemetry, inbound_raw)
[x] Map key tables and join paths (see CLAUDE.md Authorized data scope)
[x] Populate DATA_INVENTORY.md with table list and grain descriptions
[x] Validate join coverage gap (WEBID / PLATFORM_LEGACY_ID_C partial match -- documented as known issue)

## Phase 2: Concept exploration

[x] Define all 16 MTM scenarios with trigger conditions, SQL, and output columns (mtm_scenarios_claude_code.md)
[x] Validate scenario SQL against Snowflake -- counts confirmed in dashboard.html (2026-05-19)
[x] Document telemetry instrumentation gaps for S6, S8, S9 (subscriber not found, save-draft, rule-fire)
[x] Document stale DAILYLICENSEUSAGE data (current to 2026-03-19; note in known issues)

## Phase 3: Mart design

[x] Create all 16 MTM tables in consumer_beta.telemetry_overview via sql/create_all_mtm_tables.sql
[x] Standardize sfdc_account_id to source from salesforce.account.ID and add account_sfdc_link column to all tables (2026-05-27)
[ ] Write validation queries for each MTM_ table in warehouse/marts/validations/
[ ] Confirm MTM_ table row counts match dashboard.html snapshot -- re-run script if DAILYLICENSEUSAGE has been refreshed
[ ] Add account_type and product_lines columns to SELECT lists for S3, S6, S7, S8, S9, S12, S13 -- S3/S6/S7 now have the SFDC bridge join in place so only the column additions remain; S8/S9/S12/S13 still lack the SFDC join

## Phase 4: App development

[ ] Decide whether dashboard.html becomes a served app or stays as a static export -- document decision in CHANGES.md
[ ] If served app: replace inline data in dashboard.html with live reads from MTM_ mart tables
[ ] Add CSM-name lookup to replace raw CUSTOMER_SUCCESS_ASSOCIATE_C (Salesforce User ID) with display names
[ ] Wire up Account Slicer dropdowns with live account data from MTM_ tables
[ ] Add CSV export button per scenario card

## Open questions and parked items

- S9 count is 0 (accounts that saved a rule but never viewed results). This may be a telemetry coverage gap rather than a true zero -- confirm once rule-fire instrumentation is added. Priority request to product: add `INTEL | Rule Fired` and `INTEL | Notification Opened` events.
- S13 count is 0 (IL engagement drop). Investigate whether the HAVING clause logic is correct or whether date arithmetic is filtering everything out.
- S15 count is 0 (lapsed maintenance, still using). Confirm ONMAINTENANCE field values in licensing -- may need to check for 0/1 rather than TRUE/FALSE depending on Snowflake connector.
- Coverage check function: each script that joins via WEBID or PLATFORM_LEGACY_ID_C should print coverage pct -- not yet implemented in Python scripts.
- Python scripts: mtm_scenarios_claude_code.md has the SQL and template structure; standalone .py files have not yet been generated.
