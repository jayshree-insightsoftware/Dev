# Data Inventory

The map of the warehouse. Built during Phase 1. Updated whenever new sources come into scope.

## Connection details

Warehouse type: (e.g., Snowflake)
Account / host: (e.g., xp97223-edw)
Authorized schemas: (e.g., CONSUMER.FINANCE)
MCP server URL: (the MCP endpoint AI assistants use to query)
Access mode: read-only (this should be the default; flag any exceptions)

## Source systems

Where does the data in scope originate? Salesforce, NetSuite, internal applications, third-party feeds, etc. Capture enough context that someone unfamiliar with the warehouse can orient themselves.

## In-scope tables

For each table the project will reference, capture:

| Table | Appears to represent | Grain (one row per...) | Approx row count | Last updated | Notes |
|-------|---------------------|------------------------|------------------|--------------|-------|
| (table_name) | (one-line hypothesis) | (account, account-month, etc.) | (rough) | (timestamp pattern) | (anything odd) |

Detailed notes on each table live in `exploration/inventory/<table_name>.md`. This summary table is just the index.

## Tables explicitly out of scope

If certain schemas or tables are explicitly NOT to be queried during exploration, document them here with the reason.

## Refresh patterns

Document how often each source updates and what the typical lag is. This matters for understanding when "stale" data is actually a problem versus expected.

## Known data quirks

Catch-all for things that don't fit elsewhere but future you should know: deprecated columns that are still populated, columns with misleading names, tables that look related but aren't, etc.
