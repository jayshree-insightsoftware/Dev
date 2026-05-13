# Session Workflow

The mechanics of running individual exploration sessions productively. This is about HOW to work within a session. The four-phase methodology in CLAUDE.md is about WHAT the work is.

## Session start

Every session begins the same way regardless of phase. Don't skip this -- 5 minutes of orientation prevents 30 minutes of re-deriving things that were already settled.

Standard session start prompt to fire at Claude:

> "Read CLAUDE.md, TODO.md, CHANGES.md (last 10 entries), and DATA_INVENTORY.md. Then summarize the current project state in 3-5 sentences. Call out any TODO items marked `[~]` in progress. Flag any items in the Known data quality issues section that are relevant to today's planned work. Then ask what to work on."

The point is to get Claude oriented before it starts producing SQL. If Claude jumps straight to the work without orientation, it will frequently re-derive concepts already in Core definitions, or query tables already documented as out of scope, or miss a known data quality landmine.

When Claude returns with its summary, verify it. If the summary is wrong, fix the .md files before continuing -- they're the persistent memory and they need to be correct.

## Session end

Every productive session needs to leave a trace. Without it, the next session restarts from zero.

Standard session end prompt to fire at Claude:

> "We've wrapped up today's exploration. Please read the current CLAUDE.md and generate a fully updated version that incorporates everything we decided and discovered in this session. Specifically: update the Core definitions section with any agreed definitions, add any new gotchas to the Known data quality issues section, update the Current headline numbers if any tile values were validated. Also refresh TODO.md and CHANGES.md with one-liner entries for what we did and what's now pending. Show me what changed before I commit."

Claude should produce a diff or a clearly marked "what changed" section so you can review before committing. Don't accept a blanket "I updated everything" -- you need to see the specific edits.

After review and commit, also paste the updated CLAUDE.md contents into the claude.ai project instructions panel. The repo CLAUDE.md is what Claude Code reads automatically; the project instructions panel is what claude.ai reads. Both need to stay in sync.

## SQL promotion workflow

During exploration, SQL evolves quickly. The query you ran in turn 14 is probably better than the one in turn 7. The validated version that finally matched the reference number is the one that should be saved.

When SQL is ready to promote from the conversation into the repo:

It must have produced a number that matches a validation reference. Unvalidated SQL stays in the conversation history; it does not graduate.

It must have a clear home. Concept SQL goes in `exploration/concepts/<concept_name>.md` (embedded in the markdown). Mart proposal SQL goes in `exploration/proposals/<mart_name>.sql`. Validation SQL goes in `warehouse/marts/validations/<mart_name>.sql`. Don't drop loose SQL files at random paths.

It must have the standard header block. Copy/paste this at the top of every SQL script committed to the repo:

```sql
-- Project: [project name]
-- Concept: [what business concept this represents]
-- Grain: [one row per what]
-- Source tables: [list]
-- Known edge cases: [list anything that would break a naive reader]
-- Validation: [what reference number this was checked against and when]
-- Last updated: [date]
```

The header is non-negotiable. Future you (or future Claude) will read scripts in this repo without the conversation context, and the header is the only thing that makes them readable.

Standard prompt to ask Claude to do the promotion for you:

> "The SQL we landed on in this session is ready to promote. Please add the standard header block, format it cleanly, and write it to the appropriate location in the repo. Show me the final file before committing."

## Mockup workflow

Before designing marts (Phase 3), build an interactive mockup of the eventual dashboard. The mockup surfaces definition questions and shape decisions that are easier to address against a visual than against an empty SQL file.

When to build a mockup: after Phase 2 has validated enough concepts (typically 5-8) that the dashboard shape is becoming clear. Not before -- you'll mock up the wrong thing.

Where to build it: in claude.ai web interface using the visualizer tool. Claude Code cannot render interactive visuals. This is one of the few workflow steps that is web-only.

How to use it: ask Claude to build an interactive React mockup that simulates the dashboard with fabricated but reasonable data. The mockup is throwaway -- it doesn't connect to real data, doesn't get committed to the repo, doesn't need to be elegant code.

What to look for during the mockup review: definitional gaps. The mockup will need numbers for tiles, rows for tables, slices for charts. As you imagine real data flowing in, you'll discover that "active customer" wasn't fully defined, that "channel" has overlapping categories, that the time period selector needs prior-period comparison logic that wasn't planned for. Capture these as they come up -- they're free design feedback.

Once the mockup feels right, convert it to a written spec. Standard prompt:

> "Convert this mockup into a written spec. For each component, list: what data it needs, what filtering it accepts, what aggregation it expects (sum, count, average, etc.), and what the expected row/value count is at typical scale. Save this to docs/DASHBOARD_SPEC.md. This will inform mart design in Phase 3."

The spec then drives mart proposals. If the spec says "the customer table needs to show one row per customer with current ARR, count of products, and last interaction date", that's a mart with three columns and a known grain.

## Hand-off between Claude.ai and Claude Code

These two surfaces serve different purposes:

claude.ai is good for thinking, exploration conversations, mockups, and discussing definitions. It cannot directly modify files or run code (beyond MCP queries).

Claude Code is good for actually changing files in the repo, running tests, executing complex SQL via MCP, and committing work. It cannot build visual mockups.

A common pattern: use claude.ai to validate a concept and agree on the SQL. Then use Claude Code to add the standard header, write the file to disk, and commit it.

When you want Claude Code to pick up where claude.ai left off, share the relevant context -- usually a paste of the conversation summary plus the SQL. Both surfaces read CLAUDE.md so the methodology is shared automatically.

## When the session goes sideways

Some sessions feel productive but produce nothing usable. This is usually one of two failure modes:

The first is unscoped exploration. You started with a vague question and Claude generated 15 queries that each almost answered a different question. Recovery: stop, write a tightly-scoped question in TODO.md, restart the session against that.

The second is unresolved disagreement. Claude proposed an approach, you pushed back, it proposed another, you pushed back, and now you're three rounds deep with no resolution. Recovery: stop and ask Claude Code to run a diagnostic query against the actual data. Often the disagreement is grounded in different assumptions about what the data looks like, and one query settles it.

Either way: don't let a sideways session end without a session-end summary. Even "we explored X and concluded the approach was wrong, deferring to next session" is valuable to capture. Sessions that fail silently waste their lessons.
