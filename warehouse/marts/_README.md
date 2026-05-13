# Mart Layer

Marts are the contract between the warehouse and the application. The app reads marts. The app does not read raw or staging. The app does not write SQL that aggregates data -- aggregations belong here.

Each mart corresponds to a business concept and has a documented grain. Columns are named for what they mean to a business user, not what they happened to be called in the source.

Every mart documented in this folder must also have:
- An entry in `docs/SCHEMA.md` with full column documentation
- A lineage entry in `docs/LINEAGE.md`
- A validation query in `validations/<mart_name>.sql`
- Rationale captured in `docs/BUSINESS_LOGIC.md` if any calculation is non-obvious

Marts graduate from `exploration/proposals/` after approval. No mart should appear here without going through the proposal process first.

## Naming

`<concept>_<grain>` -- e.g., `arr_by_account_month`, `pipeline_by_opportunity`, `retention_by_account_quarter`. The grain in the name removes ambiguity.

## Refresh

The snapshot pipeline runs all marts in dependency order. If you add a mart that depends on another mart, document the dependency in `docs/LINEAGE.md` and ensure the pipeline orders correctly.

## Versioning

Treat marts as a versioned API. If you make a breaking change (renaming a column, changing the grain), publish the new version under a new name (`arr_by_account_month_v2`) and keep the old one until the app migrates. Don't surprise downstream consumers.
