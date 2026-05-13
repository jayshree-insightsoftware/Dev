# Staging Layer

Staging models normalize raw data shapes without applying business logic. The contract for staging models:

One staging model per source table (or per logical group of raw records).

Consistent column naming. If raw has `acct_id`, `account_id`, and `accountid` across different sources, staging uses one name (e.g., `account_id`).

Consistent types. Strings that should be timestamps get cast. Numerics stored as text get cast. Date columns get normalized to date type (not timestamp) where appropriate.

Basic filtering of test or junk records that no downstream consumer would want. Mark this filtering with comments explaining what's being excluded and why.

Deduplication where the source has duplicates that aren't meaningful.

What does NOT belong in staging:
- Business definitions (those go in marts)
- Joins that combine multiple source tables (those go in marts)
- Aggregations (those go in marts)
- Anything stakeholders might argue about (those go in marts)

If you find yourself adding "interesting" logic to a staging model, it's probably a mart.

## Files

Each staging model is a single SQL file named after the source: `stg_<source>__<table>.sql` (e.g., `stg_salesforce__opportunities.sql`).

## Refresh

Staging models typically refresh more frequently than marts but less frequently than raw. Tune based on actual downstream needs.
