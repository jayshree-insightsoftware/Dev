# Business Logic Rationale

The "why" behind every non-obvious calculation in the mart layer. Code shows what, not why. This file captures the why.

When you find yourself writing a comment in SQL that starts with "this excludes X because..." or "this uses Y not Z because...", the longer-form version of that explanation goes here. The SQL comment can be brief and point to this file.

## Format

Each entry is a short section with:
- The calculation or rule
- The rationale (why it's done this way)
- The source of the decision (who decided, when, what stakeholder owns it)
- Related concepts (links to concept docs or other rules)

## Entries

### (Example: Retention Cohort Definition)

Rule: The denominator for retention metrics uses `arr_cohort`, not `atr_cohort`.

Rationale: ARR Cohort represents the recurring revenue base that was eligible for renewal during the period. ATR Cohort includes additional in-period activity that inflates the denominator and produces artificially high retention rates. Finance team has defined ARR Cohort as the official denominator.

Source: Finance team standard, documented in PBI report `Retention Analysis v3`. Confirmed during exploration session 2025-XX-XX.

Related: `exploration/concepts/retention.md`, mart `marts/retention_by_account_month.sql`.

---

(Add entries as decisions are made during exploration and mart design)
