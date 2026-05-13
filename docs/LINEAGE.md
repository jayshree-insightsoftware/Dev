# Data Lineage

Source-to-mart paths. For each mart in the warehouse, document which raw and staging tables feed into it.

Used when a mart shows wrong numbers and you need to trace upstream to find the source of the issue.

## Format

For each mart, capture the dependency chain:

```
mart_name
  ↑ staging.cleaned_orders, staging.cleaned_customers
      ↑ raw.salesforce.opportunities, raw.salesforce.accounts
```

Plus a one-paragraph description of what transformations happen at each layer.

## Entries

### (Example: marts/account_monthly_arr)

Dependencies:
```
account_monthly_arr
  ↑ staging.normalized_account_arr_history
      ↑ raw.salesforce.account_arr_facts, raw.warehouse.account_dim
```

Transformations:

The raw `account_arr_facts` table contains daily ARR snapshots from Salesforce. The staging model `normalized_account_arr_history` aggregates these to month-end snapshots, joins to the account dimension for territory and product family, and filters out test accounts (Customer_Type IN ('Test', 'Internal')).

The mart `account_monthly_arr` further aggregates to one row per (account, year-month), computes starting/ending ARR for the period, and joins to the date dimension for fiscal period mapping.

Refresh: Raw refreshes hourly. Staging rebuilds every 4 hours. Mart rebuilds every 4 hours. Snapshot to app every 4 hours after mart rebuild completes.

---

(Add entries as marts are designed and built)
