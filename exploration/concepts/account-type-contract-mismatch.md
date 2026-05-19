# Account type vs contract status mismatch

Status: validated
Profiled: 2026-05-18
Tables: ACCOUNT, CONTRACT

## Business question

Are there accounts labeled as Former Customer or Expired Entitlements that still have active contracts?

## Finding

709 accounts are labeled "Former Customer" (615) or "Customer (Expired Entitlements)" (94) on the Account record but have CONTRACT_STATUS_C = 'Active' on at least one linked contract. These accounts carry $1.34M in active Net ARR across 768 contracts.

Important: the standard STATUS field on the Contract table should not be used for this check. It stays "Activated" permanently and does not update when contracts expire. The custom CONTRACT_STATUS_C field (Active/Expired/Cancelled/Inactive) is the correct field.

## Top affected accounts

| Account ID | Account name | Type | Net ARR |
|-----------|-------------|------|---------|
| 0014U000030aDbyQAE | Eviden France SAS | Former Customer | $250,737 |
| 0012S00002MOOTXQA5 | AxiCorp Financial Services | Former Customer | $104,828 |
| 0012S00002Up3zEQAR | Meal Ticket | Former Customer | $66,550 |
| 0014U00002cvifuQAA | Buruj Cooperative Insurance | Former Customer | $61,584 |
| 0014U00002md8yQQAQ | Lowe's Companies, Inc | Expired Entitlements | $55,460 |

## SQL

```sql
SELECT
  a.ID as account_id,
  a.NAME as account_name,
  a.TYPE as account_type,
  c.ID as contract_id,
  c.CONTRACT_STATUS_C as contract_status,
  c.START_DATE,
  c.END_DATE,
  ROUND(c.NET_ARR_C, 0) as net_arr
FROM INBOUND_RAW.SALESFORCE.CONTRACT c
JOIN INBOUND_RAW.SALESFORCE.ACCOUNT a ON c.ACCOUNT_ID = a.ID
WHERE c.IS_DELETED = FALSE AND a.IS_DELETED = FALSE
  AND c.CONTRACT_STATUS_C = 'Active'
  AND a.TYPE IN ('Former Customer', 'Customer (Expired Entitlements)')
ORDER BY c.NET_ARR_C DESC NULLS LAST;
```

## Validation reference

Snowflake is the trusted source. Originally this analysis used the standard STATUS field which showed 5,250 accounts and $52.1M -- those numbers were incorrect. After switching to the correct CONTRACT_STATUS_C field, the accurate numbers are 709 accounts and $1.34M.

## Recommended action

Update Account Type to "Customer" for these 709 accounts. A full export with Salesforce IDs is available in the Former_Customer_Active_Contracts CSV/Excel deliverable.
