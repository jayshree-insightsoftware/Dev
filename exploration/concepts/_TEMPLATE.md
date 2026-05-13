# Concept: (Name)

Copy this template to `exploration/concepts/<descriptive_name>.md` when starting a new concept exploration.

## Business question

State the question this concept answers in plain language. Be specific about scope and period. Examples:
- "What was Gross Retention for Q1 2026, expressed as a percentage of arr_cohort?"
- "How many distinct active customers did we have at month-end April 2026, where 'active' means..."

Vague questions produce vague answers. Tighten the question until it has exactly one correct numerical answer.

## Validation reference

Where will we cross-check the answer? A PBI report, a finance team number, a known historical value, a spreadsheet someone trusts. Be specific:
- "PBI Retention Analysis v3 dashboard, Q1 2026 filter applied, shows 87.3%"
- "Finance team confirmed April 2026 active count = 2,847 in monthly review deck"

Without a validation reference, the concept cannot be considered validated. The reference establishes ground truth.

## Validated SQL

The final SQL that produces the right number. Include the exact result it returns and the period it covers.

```sql
-- (Paste the validated SQL here)
```

Result: (the number this query produces)
Period: (exact period the query covered)
Matched reference: yes / no with explanation

## Edge cases discovered

The categories of records or conditions that required special handling. These are gold -- they generalize to other concepts.

Examples:
- Test accounts (Customer_Type = 'Test') must be excluded
- The forecast period uses a different cancel categorization than actuals
- Accounts with both Standard and Enterprise contracts double-count if not deduped
- (etc.)

## Dependencies

Which raw tables does this concept touch? Which staging or mart tables (if any)?

## Open questions

Anything that came up during exploration but wasn't resolved. Park here so it doesn't get lost.

## Status

- [ ] SQL drafted
- [ ] Number matches validation reference
- [ ] Edge cases documented
- [ ] Ready to inform mart design
