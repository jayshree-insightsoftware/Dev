# Project Kickoff

When a user arrives with a freshly-cloned copy of this template and a new project in mind, do NOT immediately start exploring data. The first session should be structured intake. The goal is to fill in the "What this project is" section of CLAUDE.md and the connection details in DATA_INVENTORY.md so all future sessions have proper context.

If you (Claude) are reading this at the start of a fresh project session, run the intake before doing anything else. If the user is impatient and wants to jump straight to data, gently push back -- 20 minutes of intake saves hours of misaligned exploration.

## Intake questions to ask the user

Work through these conversationally. Don't fire them as a checklist. Adapt the order based on what the user offers up first. The goal is structured context, not interrogation.

### About the project itself

What's the business purpose of this project? What question are we ultimately trying to answer or what decision are we trying to support?

Who are the stakeholders? Who will use the eventual dashboard or app? Whose definitions matter when business rules are ambiguous?

Is there an existing system or report that does some of this today? PowerBI report, spreadsheet, slide deck? If so, that's our primary validation reference for Phase 2.

What does "done" look like for Phase 1? Is the deliverable a dashboard, an analytical app, a one-time analysis, or something else?

What's the timeline? This affects whether to aim for a small validated MVP fast or to do thorough exploration.

### About the data

What warehouse are we connecting to? (Snowflake, BigQuery, Redshift, etc.)

What's the account or host? Database? Schema? Be specific -- "Salesforce data" is not specific enough; "FINANCE.CUSTOMERS in the CORP_DATA warehouse" is.

Is the data already curated by a data team, or is this raw landing data? This affects whether we lean more on staging or jump straight to mart design.

How is the data refreshed and how often? Daily ETL? Real-time streaming? Manual loads?

Who owns the data? If we discover quality issues or need to expand scope, who do we talk to?

Are there tables that look obviously relevant but you know we should NOT use? Common reasons: deprecated, contains test data mixed in, behind a different team's contract, etc.

### About access

Has the Snowflake MCP (or equivalent) connector been set up for this project in claude.ai? See `docs/MCP_SETUP.md` for the steps if not.

Has Claude Code been configured to use the same MCP connection?

What's the access mode? Read-only is required for exploration. If write access exists for any reason, flag it clearly so we don't accidentally mutate data.

### About validation

For the first concept we'll explore in Phase 2, what's a known-good number we can validate against? Without this we can't tell when SQL is correct.

If there's no existing report or trusted reference, that's fine -- but we need to identify a stakeholder who can confirm "yes, that number is right" so we have ground truth.

### About working style

Has the user worked with this template before, or is this their first project using it? First-time users benefit from more methodology context. Repeat users may want to move faster.

Does the user prefer to drive the queries themselves (paste results back into chat) or have Claude Code execute via MCP directly?

What's the user's typical session length? This affects how much to chunk work.

## What to do with the answers

After intake, do the following before any exploration:

1. Update CLAUDE.md "What this project is" section with the project specifics (purpose, stakeholders, eventual deliverable, source systems, validation references).

2. Update DATA_INVENTORY.md connection details section with the warehouse account, schema, and authorized scope.

3. Add a CHANGES.md entry: `YYYY-MM-DD: Project kickoff completed. Initial scope: [brief summary]`.

4. Populate the initial TODO.md with Phase 1 items based on what the user described.

5. Commit these to dev so the project memory starts off correctly populated.

Then -- and only then -- proceed to Phase 1 exploration.

## When intake reveals problems

If during intake you discover blockers, name them clearly and don't proceed:

If the warehouse access isn't set up yet, stop and direct the user to `docs/MCP_SETUP.md`. Don't try to work around it.

If there's no validation reference for any concept and no stakeholder available to confirm numbers, raise the risk explicitly. Exploration without validation produces hypotheses, not findings. The project might still proceed, but the user should understand what they're giving up.

If the requested scope is ambiguous (multiple warehouses, unclear which schemas, "we want to explore the whole data lake"), push back. Scope tightly to begin with. Expanding scope later is easy; recovering from unscoped exploration is hard.

If the timeline is unrealistic for the scope, say so. A real dashboard that displays validated numbers takes weeks at minimum, not days. Setting expectations early prevents disappointment later.
