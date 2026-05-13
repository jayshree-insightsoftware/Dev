# isw-enterprisedata-exploration-template

A starter repository for building data exploration and dashboard projects at insightsoftware using a warehouse-first methodology with AI-assisted exploration.

## What this template is for

You're starting a new project where the input is raw data in a warehouse and the eventual output is a dashboard or analytical app. Before writing any app code, you need to understand the data, validate the business concepts, and design a clean semantic layer that the app can read as a contract.

This template scaffolds that workflow. It provides the folder structure, file templates, methodology docs, and AI assistant conventions to do it well.

## The methodology in one paragraph

Raw data lives in the warehouse. You explore it with Claude (web interface or Claude Code) using MCP to query the warehouse directly. Validated business concepts get documented in `exploration/concepts/`. Patterns across concepts inform mart designs proposed in `exploration/proposals/`. Approved marts graduate into `warehouse/marts/` as the formal semantic layer. The dashboard app reads marts as a contract and contains essentially no business logic. When business rules change, you change SQL, not application code.

## How to use this template

Clone or copy this repo as the starting point for a new project. Rename the top-level folder to your project name. Update the relevant project metadata. Then:

Read `CLAUDE.md` to understand the conventions. This is also what Claude Code reads automatically on session start.

Copy `CLAUDE.md` contents into your Claude project instructions on claude.ai so the web interface uses the same rules.

Set up warehouse access via MCP. See `docs/MCP_SETUP.md` for step-by-step instructions for Snowflake and other warehouses.

Run the project kickoff intake before starting any exploration. See `docs/PROJECT_KICKOFF.md` for the structured intake questions Claude should ask before doing real work. The kickoff populates CLAUDE.md and DATA_INVENTORY.md with project-specific context.

Run individual sessions following `docs/SESSION_WORKFLOW.md`. Every session starts with the orientation prompt and ends with the update prompt. This keeps the file-based project memory accurate across sessions.

Begin Phase 1 exploration following `docs/EXPLORATION_PLAYBOOK.md`.

## The four phases of a project

Phase 1 is discovery and inventory. Get a map of the territory by cataloging tables, sampling rows, and writing hypothesis descriptions. Output goes into `DATA_INVENTORY.md` and `exploration/inventory/`.

Phase 2 is concept-by-concept exploration. Pick a business concept, write SQL against raw, validate the number against a known reference, document the finding. Output goes into `exploration/concepts/`.

Phase 3 is mart design. When patterns emerge across multiple concepts, propose marts that serve them. Proposals live in `exploration/proposals/` until approved, then graduate to `warehouse/marts/`.

Phase 4 is app development. The mart layer is now a stable contract. Build a thin app that reads marts and renders them. Reuse the deployment patterns documented in `docs/DEPLOYMENT.md`.

## What this template does NOT do

It does not contain working code. It is scaffolding only. The app folders are empty stubs. You add your stack of choice when you reach Phase 4.

It does not enforce a specific warehouse. The methodology assumes Snowflake but adapts to any SQL warehouse with read-only access available via MCP.

It does not assume a specific frontend framework. The thin-app principle applies regardless of whether you use React, Vue, Svelte, or anything else.

## Maintenance

When you complete a project using this template and discover patterns worth promoting, update the template itself. The template improves with each project that uses it.
