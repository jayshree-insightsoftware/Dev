# MCP Setup

How to connect Claude (both the claude.ai web interface and Claude Code) to a warehouse via MCP. Required before any exploration begins.

This document focuses on Snowflake since that's the most common case for insightsoftware projects, but the general approach applies to other warehouses with MCP servers (BigQuery, Postgres, etc.).

## What MCP is doing for you

MCP (Model Context Protocol) is the bridge that lets Claude query the warehouse directly during a conversation, instead of you having to paste query results back and forth manually. When configured correctly:

You describe what you want to know. Claude generates SQL. Claude executes it via MCP. The result comes back inline. You discuss the result and iterate.

Without MCP, the same conversation requires you to copy SQL out, run it in a separate tool, copy the result back, and paste it as text. This works but adds ~30 seconds of friction to every iteration, which adds up fast over a 90-minute session.

MCP access should always be read-only during exploration. Writing to the warehouse from a chat is not what this is for.

## Snowflake MCP setup (claude.ai web interface)

1. In claude.ai, open your project settings.

2. Find the "Connectors" or "MCP servers" section in the project configuration.

3. Add a new connector. For Snowflake, you'll provide:
   - Account identifier (the part of your Snowflake URL like `xp97223-edw`)
   - Username
   - Authentication method (password, key pair, or OAuth -- key pair is recommended for service accounts)
   - Warehouse name (the compute warehouse, e.g., `ANALYTICS_WH`)
   - Database and schema scope (default to the specific schema you're authorized to read)
   - Role (use a role that has READ-ONLY access to the relevant schemas)

4. Save the connector. claude.ai will test the connection.

5. Verify it works: in a fresh conversation in this project, ask Claude to run `SELECT current_database(), current_schema(), current_user(), current_role()`. The result should match what you configured.

If the connection test fails, the most common causes are: wrong account identifier format, role doesn't have USAGE on the warehouse, or network policies on the Snowflake account blocking the MCP IP.

## Snowflake MCP setup (Claude Code)

Claude Code reads MCP server configuration from a config file. The location varies by installation but is typically `~/.config/claude-code/mcp.json` or similar.

Add a server entry pointing to a Snowflake MCP server binary or container. Anthropic and the community publish reference implementations -- check the current Claude Code documentation for the recommended package.

The config entry will include the same connection parameters as the web setup: account, user, auth, warehouse, database, schema, role.

Once configured, restart Claude Code. In the next session, ask it to run the same `SELECT current_database()...` verification query to confirm the connection is live.

## Scoping access correctly

The role you give to MCP should be as narrow as possible. Recommended practice:

Create a dedicated role for AI exploration, e.g., `AI_EXPLORATION_RO`.

Grant USAGE on the warehouse, database, and schemas in scope.

Grant SELECT on the specific tables and views in scope -- not on the whole schema if you can avoid it. This forces an explicit decision when scope needs to expand.

Do NOT grant INSERT, UPDATE, DELETE, MERGE, or any DDL privileges. Read-only must mean read-only.

Set query timeouts and resource limits on the role so a runaway exploration query can't consume the warehouse.

If your warehouse has row-level security or column masking, verify it's applied to the AI role too. PII protection should be enforced at the warehouse layer, not relied on Claude to respect.

## Verifying it actually works

After setup, run these verification queries in a fresh conversation:

```sql
-- Confirm identity and scope
SELECT current_database(), current_schema(), current_role(), current_warehouse();

-- Confirm read access to expected tables
SELECT count(*) FROM (your_first_in_scope_table) LIMIT 1;

-- Confirm WRITE access is denied (this should error)
CREATE TABLE test_write_blocked (id int);
```

If the third query succeeds, your role has more privileges than it should. Fix that before doing anything else.

## Common failure modes

"Cannot connect to Snowflake account" -- check the account identifier format. Snowflake account IDs have several valid formats and they're not interchangeable. The MCP server expects a specific one (often the legacy format like `xp97223-edw` rather than the newer `xp97223.us-east-1`).

"Role does not have USAGE on warehouse" -- the role exists but lacks compute access. Grant USAGE explicitly. `GRANT USAGE ON WAREHOUSE analytics_wh TO ROLE ai_exploration_ro;`

"Connection succeeds but tables not found" -- usually a schema/database context issue. Verify the default schema in the connector matches where the tables actually live, or qualify queries with full `database.schema.table` paths.

"Queries timeout after 30 seconds" -- some MCP servers have aggressive default timeouts. Increase to 5 minutes for exploration use. Anything longer than that during exploration usually means a query is doing too much and should be scoped tighter.

"Claude is making things up about the data" -- almost always means MCP isn't actually connected and Claude is generating plausible-sounding but fabricated results. Run the verification query immediately if you suspect this.

## When MCP isn't available

Some environments won't allow MCP -- corporate security policies, lack of suitable warehouse driver, etc. In that case, exploration still works but the user has to be the query executor:

Claude proposes SQL in the conversation. The user copy/pastes it into Snowsight (or whatever tool the user has access to). The user pastes results back into the conversation. Claude reads results and iterates.

This works fine for exploration; it just adds friction. The four-phase methodology, the templates, and the session workflow all still apply. The only thing missing is the auto-execute step.

If working without MCP, note it explicitly in CLAUDE.md so future sessions know not to expect direct query execution.
