# Schema Contract

The contract between the warehouse mart layer and the application. Every mart that the app reads is documented here.

Update this file whenever a mart is added, modified, or deprecated. Treat it as you would API documentation: changes are versioned and breaking changes are flagged.

## Mart catalog

For each mart, document:

### `mart_name`

Purpose: One sentence describing what business question(s) this mart answers.

Grain: One row per what? (account-month, opportunity, account-product-month, etc.)

Refresh cadence: How often does this mart get rebuilt? (e.g., every 4 hours via snapshot.yml)

Source dependencies: Which staging or raw tables does this mart depend on? (See LINEAGE.md for full path.)

Validation reference: Pointer to the validation query and the known-good number it should return.

Columns:

| Column | Type | Description | Nullable | Notes |
|--------|------|-------------|----------|-------|
| (column) | (type) | (what it means) | (Y/N) | (caveats) |

Sample row:

(Include 1-2 sample rows formatted as a code block so consumers can see the shape concretely.)

Known caveats: Anything weird about this mart that consumers need to know. Special filters applied? Certain account types excluded? Forecast periods handled differently from actuals?

---

(Repeat the block above for each mart)
