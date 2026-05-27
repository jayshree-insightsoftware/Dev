# Project Conventions

This file is read automatically by Claude Code on session start. Its contents should also be copy/pasted into the Claude project instructions on claude.ai so the web interface uses the same rules.

## What this project is

This is a warehouse-first analytics project. Raw data lives in a SQL warehouse. AI-assisted exploration validates business concepts against the raw data. Validated concepts inform the design of a semantic mart layer in SQL. A thin application reads marts as a contract and renders them. Business logic lives in SQL, not in application code.

**Product:** Reporting Intelligence -- Angles Professional, Report Center, and Intelligence Layer.

**Purpose:** Build triggered alert scripts and a live dashboard for 16 "Moments That Matter" (MTM) CS scenarios across the customer lifecycle (Onboarding, Adoption, Retention, Offboarding). Each scenario identifies accounts matching a behavioral trigger condition, ready to push to Totango or surface to CSMs.

**Warehouse:** Snowflake. Source databases are `dev_telemetry` (product telemetry and licensing) and `inbound_raw` (Salesforce CRM). MTM output tables land in `consumer_beta.telemetry_overview` with the prefix `MTM_`.

**Dashboard:** `dashboard.html` at repo root -- static HTML that reads inline data from the last Snowflake run. Data dated 2026-05-19. Features direct Salesforce record links (account ID filter button, S16 table, Account View panel), bidirectional cross-filtering for all dimension slicers, and dynamically populated dropdowns.

**Stakeholders:** CSM Lead, CSMs, AEs, RevOps, CS Leadership, Product, Product Marketing, IT/Provisioning, Legal/Compliance.

## Branch strategy

The repo uses a dev/main branching model. Active development happens on `dev` to keep CI/CD from firing unnecessarily.

The `dev` branch is for all active work. Pushes to dev trigger tests only, never deploys. You, me, and Claude Code all commit and push to dev.

The `main` branch is production-only and protected. It only receives merges from `dev` via pull request. Every push to main triggers the full deploy pipeline plus an automatic data refresh.

When I say "deploy to prod", merge dev into main and push. The deploy workflow runs first, then auto-triggers the data refresh workflow so fresh data follows fresh code.

Always commit to dev unless I explicitly say otherwise. Never push directly to main.

## File-based project memory

You and Claude Code should maintain `.md` files at the repo root and in `exploration/` to keep track of state across sessions. These supplement (don't replace) the in-conversation context.

CLAUDE.md (this file) contains the methodology, conventions, and accumulated project knowledge. Refresh it when significant changes happen. The session-end workflow in `docs/SESSION_WORKFLOW.md` describes how to keep this file up to date without manual rewriting every time.

TODO.md tracks pending work. When I describe a multi-step task or you identify follow-up work, add it to TODO.md with status markers (`[ ]` pending, `[x]` complete, `[~]` in progress). Mark items complete as you finish them. Keep this honest -- if something gets deferred or scope-changed, update the entry.

CHANGES.md maintains a chronological log of significant changes (architectural shifts, new modules, deprecated approaches). One-liner entries with date prefixes. Don't log every commit -- only inflection points worth recalling later.

DATA_INVENTORY.md is the map of the warehouse: tables in scope, what each appears to represent, the grain, last-updated patterns. Build this in Phase 1 and refresh it when new sources come into scope.

Each concept being explored gets a file in `exploration/concepts/`. Each raw table being studied gets a file in `exploration/inventory/`. Each mart proposal gets a file in `exploration/proposals/`. Use the `_TEMPLATE.md` and `_TEMPLATE.sql` files in those folders as starting points.

At the start of a session, follow the session-start procedure in `docs/SESSION_WORKFLOW.md`. At the end of substantial work, follow the session-end procedure in the same file to update the relevant .md files.

## Core definitions

This section captures business definitions that have been agreed and validated during exploration. Once a definition lands here it should not be relitigated without explicit instruction. This prevents Claude from re-deriving agreed concepts from scratch at the start of each session.

Format: bold term, one-sentence definition, source of truth field or table in parentheses if applicable.

**License validated**: A license key has been used to authenticate and launch the product at least once, evidenced by a non-NULL `LASTVALIDATEDDATE` in `awssql_spslicensing_dbo.customerlicensekeys`. Keys with NULL `LASTVALIDATEDDATE` were provisioned but the product was never launched.

**Active user (30-day)**: A licensed user (`ASSIGNEDUSER`) with at least one row in `dailylicenseusage` where `LASTVALIDATEDDATE` falls within the last 30 days from the reference date.

**Report Center (RC)**: The primary reporting module of Angles Professional. Telemetry lives in `WM_TRACKEDEVENTS_ANGLEPROF_REPORTCENTER`. First activation milestone is reaching the upload page (`RC | User on Reports Upload Page`).

**Intelligence Layer (IL)**: The rule-based alerting module within Angles Professional -- the key premium differentiator. Telemetry lives in `WM_TRACKEDEVENTS_ANGLESPROF_INTELLAYER`. Value realization proxy is viewing the Results tab (`INTEL | Click Results tab Button`).

**MTM stage (Onboarding)**: Scenarios S1-S4, covering the period from contract signature through first meaningful product use.

**MTM stage (Adoption)**: Scenarios S5-S9, covering feature breadth, schedule creation, Intelligence Layer entry, and first rule saved.

**MTM stage (Retention)**: Scenarios S10-S14, covering seat utilization, dormancy, IL engagement health, and pre-renewal scoring.

**MTM stage (Offboarding)**: Scenarios S15-S16, covering lapsed-maintenance detection and closed-lost churn audit.

## Current headline numbers

Quick sanity-check values that should approximately match across sessions. If Claude produces a number wildly different from what's here, something broke -- stop and investigate rather than proceeding.

As of 2026-05-19 dashboard run (source: `dashboard.html` and `consumer_beta.telemetry_overview.MTM_*` tables):

| Scenario | Name | Count | Stage |
|----------|------|-------|-------|
| S1 | CSM Assignment & Sales Handoff | 0 | Onboarding |
| S2 | License Key Assigned, Never Used | 5,861 | Onboarding |
| S3 | Double-Homepage Confusion (ISW to RC) | 104 | Onboarding |
| S4 | First Report Upload Stall | 5,844 | Onboarding |
| S5 | Feature Discovery Gap (30-day mark) | 5,303 | Adoption |
| S6 | Schedule Creation Drop-Off | 22 | Adoption |
| S7 | Intelligence Layer Never Entered | 44 | Adoption |
| S8 | Rule Creation Funnel Failure | 6 | Adoption |
| S9 | First Rule Fired -- Value Realized | 0 | Adoption |
| S10 | License Seat Utilization Drop | 13 | Retention |
| S11 | Dormant Licensed Seats -- Renewal Risk | 82 | Retention |
| S12 | Login-Without-IL Health Check | 70 | Retention |
| S13 | IL Engagement Drop | 0 | Retention |
| S14 | Pre-Renewal Health Scorecard | 22 | Retention |
| S15 | Lapsed Maintenance -- Still Using | 0 | Offboarding |
| S16 | Cancellation -- IL Adoption Audit | 106 | Offboarding |
| **Total** | **All scenarios** | **17,477** | -- |

Note: `DAILYLICENSEUSAGE` data was current to 2026-03-19 at time of last run -- ~2 months stale. Refresh before presenting retention/offboarding numbers to stakeholders.

## Known data quality issues

Document here any data quality problems discovered during exploration that would corrupt dashboard numbers if ignored. Format each as a one-liner with the count affected and the recommended handling. Review this section before presenting any numbers to stakeholders.

- Stale licensing data: `DAILYLICENSEUSAGE` was current to 2026-03-19 at the 2026-05-19 run -- approximately 2 months of lag. Parameterise `REF_DATE` in S10 and related scripts to MAX(LASTVALIDATEDDATE) rather than CURRENT_DATE. Retention/offboarding numbers will undercount recent activity until refreshed.
- Partial join key coverage (affects S2, S3, S4, S14): `customer.WEBID` and `account.PLATFORM_LEGACY_ID_C` joins to telemetry `ACCOUNT_ID` (format `platform:{ID}`) are incomplete -- not all licensing customers match a telemetry account. Each script must include a coverage-check that prints `{X} of {N} accounts matched via join key ({pct}% coverage)`.
- Rule-fire event not instrumented (affects S9): No telemetry event exists for when an Intelligence Layer rule fires or when a notification is opened. Results tab view (`INTEL | Click Results tab Button`) is the best available proxy. S9 count of 0 may be a gap artifact, not a true zero.
- No schedule save-draft event (affects S6): Mid-flow abandonment on the schedule creation page is invisible -- only page entry and completion are captured. S6 abandonment rate of 92% is directionally correct but understates true abandonment.
- Subscriber-not-found error not instrumented (affects S8): When a rule creator adds a subscriber email that is not in the system, there is no error event. This is believed to be the leading cause of Rule Creation Funnel Failure (S8) but cannot be confirmed from current telemetry.

## Authorized data scope

List the warehouse schemas, databases, and tables that AI assistants are authorized to query during exploration. Default to read-only and scope tightly. Update this section as scope expands.

Equally important: list tables that might LOOK relevant but are explicitly out of scope, and why. Negative scope (what not to touch) is as important as positive scope in a large warehouse with hundreds of tables. A table that "seems like it should answer this question but is wrong" will be reached for every session unless explicitly fenced off.

In scope (read-only):

- `dev_telemetry.product_telemetry.WM_WHOLOGGEDINYESTERDAY_ANGLESPROF` -- daily login records per account
- `dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLEPROF_REPORTCENTER` -- Report Center WalkMe events
- `dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLESPROF_INTELLAYER` -- Intelligence Layer WalkMe events
- `dev_telemetry.awssql_spslicensing_dbo.customer` -- licensing customer master (join key to SFDC via SALESFORCEID)
- `dev_telemetry.awssql_spslicensing_dbo.customerlicensekeys` -- individual license key records with LASTVALIDATEDDATE
- `dev_telemetry.awssql_spslicensing_dbo.dailylicenseusage` -- daily per-user usage records
- `inbound_raw.salesforce.account` -- SFDC account master (includes PLATFORM_LEGACY_ID_C for telemetry join, CUSTOMER_SUCCESS_ASSOCIATE_C, NEXT_RENEWAL_DATE_C, OPEN_RENEWABLE_AMOUNT_C)
- `inbound_raw.salesforce.contract` -- contract records with STATUS and CUSTOMER_SIGNED_DATE
- `inbound_raw.salesforce.opportunity` -- opportunity records with STAGE_NAME and WIN_LOSS_REASON_C
- `inbound_raw.salesforce.onboarding_c` -- onboarding object with STAGE_C and STATUS_C
- `consumer_beta.telemetry_overview.MTM_*` -- output tables written by `sql/create_all_mtm_tables.sql`; read by the dashboard

Key join paths:
- Licensing to SFDC: `awssql_spslicensing_dbo.customer.SALESFORCEID = salesforce.account.ID`
- Licensing to telemetry: `CONCAT('platform:', customer.WEBID)` matches `product_telemetry.ACCOUNT_ID`
- SFDC to telemetry: `CONCAT('platform:', account.PLATFORM_LEGACY_ID_C)` matches `product_telemetry.ACCOUNT_ID`
- Telemetry to SFDC (bridge): telemetry `ACCOUNT_ID` → `CONCAT('platform:', customer.WEBID)` → `customer.SALESFORCEID` → `salesforce.account.ID`; used for scenarios that originate from telemetry tables (S3, S6, S7, S12, S13)

All MTM_ output tables include `sfdc_account_id` (sourced from `salesforce.account.ID`) and `account_sfdc_link` (a pre-built Salesforce URL). Both are NULL when no matching SF record exists.

Explicitly out of scope:

- Any Snowflake schemas outside `dev_telemetry`, `inbound_raw`, and `consumer_beta.telemetry_overview` -- scope is limited to Angles Professional CS telemetry and the CRM records that support it.
- `inbound_raw.salesforce.task` and `inbound_raw.salesforce.event` -- CS activity log tables that look relevant but have not been validated against MTM scenarios; do not query until explicitly added to scope.

## The four phases

Phase 1 is discovery and inventory. Output: DATA_INVENTORY.md and per-table notes in `exploration/inventory/`.

Phase 2 is concept-by-concept exploration. Output: validated SQL and rationale per concept in `exploration/concepts/`.

Phase 3 is mart design. Output: proposed mart SQL and rationale in `exploration/proposals/`. Approved proposals graduate to `warehouse/marts/`.

Phase 4 is app development. Output: thin app reading from marts as a contract.

Refer to `docs/EXPLORATION_PLAYBOOK.md` for the detailed workflow within each phase. Refer to `docs/SESSION_WORKFLOW.md` for the mechanics of running individual sessions.

## Working style preferences

When I describe a multi-step task, write the plan to TODO.md first, then execute step by step. Confirm I'm aligned before kicking off major architectural changes.

Don't ping-pong on stylistic disagreements. If I push back on a fix two or three times, stop and ask Claude Code to handle it with direct data access -- you're working from in-conversation context, Claude Code can query the actual database.

When debugging, prefer one diagnostic query over speculation. Ask me to run a SQL query against the warehouse rather than guessing at the cause.

If a fix doesn't work, don't escalate complexity. Step back, look at the actual error message, and address the root cause. Complexity is usually a sign you're treating the wrong layer.

When introducing new dependencies or env vars, document them in the relevant .md files and remind me to update Azure App Service and GitHub Actions secrets where needed.

Don't push code that hasn't been tested locally. If I'm in the middle of a long-running operation, pause pushes until it completes.

## Exploration phase principles

The unit of progress during exploration is "concept understood and documented", not "code committed". A successful 90-minute session might produce 50 lines of SQL and one markdown file. That's fine.

Set up exploration questions to be small and targeted. "Find the table that represents customer renewals and tell me what its grain is" is good. "Explore this database and build me a dashboard" produces garbage.

Every concept must be validated against a known reference before it's considered understood. The reference can be a PBI report, a finance team number, a spreadsheet, or another trusted source. Without validation, the concept is a hypothesis, not a finding.

Edge cases discovered during exploration are gold. Capture them in the concept doc. "Oh, we need to exclude test accounts" is the kind of thing that takes 10 minutes to discover and saves 10 hours when it bites you later.

Build an independent validation rather than trusting vendor-provided confidence scores. When a source system or third-party data provider gives you a "trust" or "confidence" field, treat it as one input among many, not as the answer. Most projects discover at some point that vendor confidence and actual usability are not the same thing.

## Mart design principles

A mart is the contract between the warehouse and the app. The app reads marts. The app does not read raw or staging. The app does not write SQL that aggregates data -- aggregations belong in marts.

Each mart corresponds to a business concept and has a documented grain (one row per what?). Columns are named for what they mean to a business user, not what they happened to be called in the source.

Every mart has a validation query in `warehouse/marts/validations/` that produces a known-good number against a known-good period. When mart numbers look wrong, run the validation to determine whether the bug is upstream (in raw/staging) or downstream (in the app).

Anything a finance team would argue about (definitions, formulas, scope) lives in SQL. Anything a designer would argue about (formatting, colors, layout) lives in the app. This is the line between business logic and presentation logic.

## App principles

The app is thin. It filters, orders, and paginates pre-aggregated mart data. It does not compute business logic.

Every mart's row shape should be expressible as a TypeScript type (or equivalent schema). Queries are typed. If a mart's columns change, the type breaks at compile time.

Period logic uses a date dimension table from the warehouse, not JavaScript date arithmetic. Timezone bugs from `new Date()` and `setDate()` are a recurring failure mode and the warehouse-side date_dim eliminates them.

Reuse the patterns documented in `docs/DEPLOYMENT.md` for production architecture. The hybrid blob storage pattern (warehouse → blob → app cache) avoids many classes of problems and should be the default unless there's a strong reason otherwise.

## Writing and code rules

Never use em dashes in any writing or comments. Use two hyphens or restructure the sentence.

No bullet points in prose responses. Use flowing sentences. Reserve lists for genuinely enumerated content (file paths, env vars, ordered steps), not for organizing ideas that should be prose.

Tests must pass before every commit. Once the app exists, the test command goes here.

Commit messages should be descriptive and reference what changed and why, not just what file was touched. Multi-line commit messages are encouraged when the change has nontrivial reasoning.

SQL scripts that are promoted from exploration conversations into the repo need a standard header block. See `docs/SESSION_WORKFLOW.md` for the SQL promotion workflow and header template.

## Brand and styling

insightsoftware brand colors when relevant:
Primary: Brand Green #31AB46, Brand Blue #007AC9
Secondary: Orange #C7532F, Gold #DFAC2D, Eggplant #372248, Cerulean #00B9FF, Purple #46217C, Fuchsia #C5267E
Neutrals: Emerald Green #008556, Cloud Blue #ECFAFF, Dark Navy #1E2556, Cool Black #00000E, Slate #2E2E2E

The corporate navy #1E2556 must never change in any theme.

Use Poppins for all UI typography.
