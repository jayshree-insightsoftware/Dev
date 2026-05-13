# Project Conventions

This file is read automatically by Claude Code on session start. Its contents should also be copy/pasted into the Claude project instructions on claude.ai so the web interface uses the same rules.

## What this project is

This is a warehouse-first analytics project. Raw data lives in a SQL warehouse. AI-assisted exploration validates business concepts against the raw data. Validated concepts inform the design of a semantic mart layer in SQL. A thin application reads marts as a contract and renders them. Business logic lives in SQL, not in application code.

Update this section in each new project with specifics: the warehouse account and schema, the source systems, the eventual dashboard purpose, the stakeholders.

## Branch strategy

The repo uses a dev/main branching model. Active development happens on `dev` to keep CI/CD from firing unnecessarily.

The `dev` branch is for all active work. Pushes to dev trigger tests only, never deploys. You, me, and Claude Code all commit and push to dev.

The `main` branch is production-only and protected. It only receives merges from `dev` via pull request. Every push to main triggers the full deploy pipeline plus an automatic data refresh.

When I say "deploy to prod", merge dev into main and push. The deploy workflow runs first, then auto-triggers the data refresh workflow so fresh data follows fresh code.

Always commit to dev unless I explicitly say otherwise. Never push directly to main.

## File-based project memory

You and Claude Code should maintain `.md` files at the repo root and in `exploration/` to keep track of state across sessions. These supplement (don't replace) the in-conversation context.

CLAUDE.md (this file) contains the methodology, conventions, and active gotchas. Refresh it when significant changes happen.

TODO.md tracks pending work. When I describe a multi-step task or you identify follow-up work, add it to TODO.md with status markers (`[ ]` pending, `[x]` complete, `[~]` in progress). Mark items complete as you finish them. Keep this honest -- if something gets deferred or scope-changed, update the entry.

CHANGES.md maintains a chronological log of significant changes (architectural shifts, new modules, deprecated approaches). One-liner entries with date prefixes. Don't log every commit -- only inflection points worth recalling later.

DATA_INVENTORY.md is the map of the warehouse: tables in scope, what each appears to represent, the grain, last-updated patterns. Build this in Phase 1 and refresh it when new sources come into scope.

Each concept being explored gets a file in `exploration/concepts/`. Each raw table being studied gets a file in `exploration/inventory/`. Each mart proposal gets a file in `exploration/proposals/`. Use the `_TEMPLATE.md` and `_TEMPLATE.sql` files in those folders as starting points.

At the start of a session, read CLAUDE.md, TODO.md, and DATA_INVENTORY.md before doing significant work. At the end of substantial work, update the relevant .md files. When the user describes a new multi-step plan, write it to TODO.md before executing so we have a checkpoint to return to.

When investigating a bug or working through architectural decisions, append a brief note to CHANGES.md so future sessions understand the reasoning, not just the code.

## The four phases

Phase 1 is discovery and inventory. Output: DATA_INVENTORY.md and per-table notes in `exploration/inventory/`.

Phase 2 is concept-by-concept exploration. Output: validated SQL and rationale per concept in `exploration/concepts/`.

Phase 3 is mart design. Output: proposed mart SQL and rationale in `exploration/proposals/`. Approved proposals graduate to `warehouse/marts/`.

Phase 4 is app development. Output: thin app reading from marts as a contract.

Refer to `docs/EXPLORATION_PLAYBOOK.md` for the detailed workflow within each phase.

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

## Authorized data scope

List the warehouse schemas, databases, and tables that AI assistants are authorized to query during exploration. Default to read-only and scope tightly. Update this section as scope expands.

## Brand and styling

insightsoftware brand colors when relevant:
Primary: Brand Green #31AB46, Brand Blue #007AC9
Secondary: Orange #C7532F, Gold #DFAC2D, Eggplant #372248, Cerulean #00B9FF, Purple #46217C, Fuchsia #C5267E
Neutrals: Emerald Green #008556, Cloud Blue #ECFAFF, Dark Navy #1E2556, Cool Black #00000E, Slate #2E2E2E

The corporate navy #1E2556 must never change in any theme.

Use Poppins for all UI typography.
