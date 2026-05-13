# Table: (full_qualified_name)

Copy this template to `exploration/inventory/<table_name>.md` when documenting a raw table during Phase 1.

## Hypothesis

One paragraph: what does this table appear to represent based on a sample of rows?

## Grain

One row per what? (Examples: one row per customer, one row per customer per month-end, one row per order line, one row per opportunity-stage-transition.)

If the grain is unclear, document the ambiguity and what would clarify it.

## Row count

Approximate count at the time of inventory. Date of count.

## Date range

Earliest record date and latest record date. If multiple date columns exist (created_date, updated_date, transaction_date), document each.

## Refresh pattern

How often does this table appear to update? Daily ETL? Real-time? On-demand? What's typical lag from source system to here?

## Likely keys

Columns that appear to function as primary or foreign keys based on uniqueness and naming.

| Column | Distinct count | Looks like | Notes |
|--------|---------------|------------|-------|
| account_id | (count) | foreign key to account dim | |

## Columns of interest

Not every column needs documentation, but flag the ones that matter for likely use cases:

| Column | Type | Sample values | Notes |
|--------|------|---------------|-------|

## Sample rows

5-10 sample rows as a code block. Use real data unless privacy concerns require anonymization.

## Apparent relationships

Other tables this one seems related to. Examples: "Each row has account_id which joins to ACCOUNT.id" or "Looks like a child of ORDERS via order_id".

## Caveats and quirks

Anything odd worth flagging. Test data mixed with real data? Soft-deleted records? Misleading column names? Deprecated columns still populated?

## Status

- [ ] Sampled and hypothesis drafted
- [ ] Hypothesis validated with stakeholder (or marked as best-guess)
- [ ] Relationships mapped
