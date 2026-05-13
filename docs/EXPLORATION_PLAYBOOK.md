# Exploration Playbook

How to run productive exploration sessions with Claude (web interface and Claude Code) against raw warehouse data via MCP.

## Setup before any exploration

Connect Claude to the warehouse via MCP. For Snowflake, that means installing the Snowflake MCP server and configuring it with read-only credentials scoped to the schemas listed in DATA_INVENTORY.md.

Confirm the connection works by asking Claude to run a trivial query like `SELECT current_database(), current_schema()`. If that returns expected values, the channel is open.

For Claude Code, the MCP configuration goes in the project's settings. For claude.ai web, the MCP connection is configured per project. Both should be configured before starting.

## Phase 1: Discovery and inventory

The goal of Phase 1 is to produce DATA_INVENTORY.md and per-table notes in `exploration/inventory/`. You should be able to read these in 15 minutes and understand what's in the warehouse.

Start with a table inventory. Ask Claude to list all tables in the in-scope schemas, with row counts, column counts, and last-updated patterns where available. Capture the output in DATA_INVENTORY.md.

For each table, ask Claude to sample 20 rows and write a hypothesis paragraph: what does this table appear to represent, what's the grain, what columns look like keys, what columns look derived. Save to `exploration/inventory/<table_name>.md` using `_TEMPLATE.md` as the starting structure.

Resist the urge to start querying business logic in Phase 1. The goal is the map, not the journey. You'll get to the destinations in Phase 2.

Phase 1 typically takes 2-5 sessions depending on how many tables are in scope.

## Phase 2: Concept-by-concept exploration

This is the heart of the project. Pick one business concept at a time. A concept is a specific question with a specific number as the answer: "what was Gross Retention for Q1 2026", "how many active customers did we have at month-end April 2026", "what was the total ARR walked from new logos in 2025".

For each concept:

Open a new file at `exploration/concepts/<concept_name>.md` using `_TEMPLATE.md`. Fill in the business question and the validation reference (where you'll cross-check the answer).

Ask Claude to propose SQL that answers the question. The first attempt is usually wrong. Run it, look at the result, iterate.

The iteration loop: Claude proposes SQL, you run it, the number doesn't match the validation reference, you and Claude diagnose why. Common diagnoses: wrong filter, wrong join condition, wrong aggregation level, edge cases not handled (test accounts, internal records, etc.).

When the number matches the validation reference, the concept is validated. Capture the final SQL in the concept doc along with:
- The validation reference and the exact number it produces
- The edge cases discovered during iteration (these are gold)
- Any caveats about scope or applicability

A successful concept session produces 50-100 lines of SQL and one markdown file. Sessions are typically 60-90 minutes. Resist the urge to chain concepts in one session -- the focus drops sharply after the first.

## Phase 3: Mart design

Once you have 5-10 validated concepts, patterns will be visible. Common joins, common filters, common groupings. Time to propose marts.

A mart is a curated table or view that the app reads. Each mart serves multiple related concepts efficiently. Mart design is about finding the right granularity: too fine and the app re-aggregates everything; too coarse and you can't answer related questions.

For each mart proposal, create `exploration/proposals/<mart_name>.md` and `<mart_name>.sql`. The markdown answers: which concepts does this mart serve, what's the grain, what does refreshing it cost, why is this a separate mart instead of a column in another. The SQL is the actual proposed mart definition.

Review proposals carefully. Push back on proposals that try to do too much. A mart that serves 8 concepts but is incomprehensible is worse than three marts that each serve 3 concepts cleanly.

When a proposal is approved, the mart graduates to `warehouse/marts/<mart_name>.sql` and gets a validation query in `warehouse/marts/validations/<mart_name>.sql`. The validation runs every refresh and produces a known number for a known period.

## Phase 4: App development

The mart layer is now a contract. App development is a separate workflow with its own conventions (see the eventual `app/` README). The key principle: the app reads marts. It does not contain business logic. When a number changes, you change SQL.

## Working effectively across phases

You will be tempted to skip ahead. Don't. The phases exist because skipping leads to rework. Building an app on a mart layer that wasn't validated leads to bugs that require teardown and redesign. Designing marts on concepts that weren't validated leads to marts that don't answer the right questions. Exploring concepts without an inventory leads to wasted queries against the wrong tables.

That said, Phase 1 and Phase 2 are often interleaved in practice. Discovering a concept requires touching tables, and touching tables fills in the inventory. Just make sure DATA_INVENTORY.md and the concept docs stay in sync.

## When numbers don't match

This is the most common failure mode and worth its own section. You ran the SQL Claude proposed, the number is wrong, and you don't know why. The debugging hierarchy:

First, check the SQL against the business question. Is the filter right? Is the aggregation level right? Is the join doing what you expect? AI assistants make subtle errors here often.

Second, check the validation reference. Is the reference itself definitely correct? Is it for exactly the same scope and period? "Q1 2026" might mean fiscal vs. calendar; "active customers" might exclude certain types in one source and not another.

Third, check the raw data. Run isolation queries: how many rows in the source table for this period? What's the distinct count of accounts? Are there obvious outliers or duplicates? Sometimes the raw data has issues that no SQL will paper over.

Fourth, ask Claude to enumerate edge cases. "What could cause this number to be lower/higher than expected?" Often the answer is in there -- a category of records that's being included or excluded inappropriately.

The discipline is: do not declare a concept validated when the number is "close enough". A $200K discrepancy on a $6.5M number looks small but usually indicates a real categorization or scoping difference that will compound across other concepts.

## Documentation hygiene

Update DATA_INVENTORY.md as you learn things in Phase 2 and 3. The inventory built in Phase 1 is the first draft, not the final word.

Add notes to BUSINESS_LOGIC.md for any non-obvious rationale. Why does this calculation exclude internal accounts? Why is this filter applied at the join rather than the where? Future you will not remember.

When a session produces meaningful artifacts, commit them to dev with a descriptive message. The commit log of the exploration phase is itself documentation.
