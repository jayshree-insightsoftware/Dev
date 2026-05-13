# Mart Proposal: (name)

Copy this template (and `_TEMPLATE.sql`) to `exploration/proposals/<mart_name>.md` and `<mart_name>.sql` when proposing a new mart.

## Concepts served

Which validated concepts from `exploration/concepts/` does this mart support? List by file name.

A mart that serves only one concept is suspicious -- maybe the concept is too narrow, or maybe this should be a column in an existing mart instead. Aim for 3+ concepts per mart.

## Grain

One row per what? Be precise. The grain determines what questions the mart can answer without re-aggregation.

## Columns

| Column | Type | Source | Purpose |
|--------|------|--------|---------|

Each column has a clear purpose. If you can't articulate why a column exists, it shouldn't be in the mart.

## Dependencies

Which raw and staging tables does this mart read from? Document the join logic.

## Refresh cost

Roughly how long does this mart take to rebuild? How does that affect the overall snapshot pipeline?

If the mart is expensive (10+ minutes), is that justified by how often it's read? Could it be materialized incrementally?

## Why a separate mart

Why does this need to be a new mart rather than a column added to an existing one? Justify the separation.

## Alternatives considered

Other shapes this mart could take. What other granularities did you consider, and why is the proposed one better?

## Open questions

Any unresolved design questions that need stakeholder input before approval.

## Status

- [ ] Proposal drafted
- [ ] Sample query result reviewed against expectations
- [ ] Approved by (stakeholder)
- [ ] Ready to graduate to `warehouse/marts/`
