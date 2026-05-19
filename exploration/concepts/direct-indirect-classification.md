# Direct vs Indirect channel classification

Status: validated
Profiled: 2026-05-18
Tables: ACCOUNT, CONTRACT

## Business question

How are accounts classified as Direct vs Indirect, and does the Account Channel field match the actual billing relationship on Contracts?

## Finding

The Account.CHANNEL_C field and the Contract.BILL_TO_ACCOUNT_C field tell different stories for 9,283 accounts covering 35,349 contracts and $75.5M in ARR.

When Bill To Account equals the Contract Account, the customer pays directly (Direct). When they differ, a third party (partner or distributor) is paying on the customer's behalf (Indirect).

## Numbers

As reported (Account Channel field):
- Direct: $699M ARR (31,469 activated contracts)
- Indirect: $261M ARR (36,220 activated contracts)

Corrected (Contract Bill To logic):
- Direct: $737M ARR (32,578 contracts)
- Indirect: $222M ARR (35,111 contracts)

Revenue shift: $75.5M total. Indirect is overstated by approximately $38M because 1,771 Indirect accounts are actually billing themselves directly.

Mismatch breakdown:
- 5,133 Direct accounts billed through a partner or distributor (19,092 contracts, $18.9M)
- 4,150 Indirect accounts billing themselves directly (16,257 contracts, $56.7M)

## Validation reference

Snowflake is the trusted source per project kickoff. Numbers derived from INBOUND_RAW.SALESFORCE.ACCOUNT joined with INBOUND_RAW.SALESFORCE.CONTRACT where IS_DELETED = FALSE and STATUS = 'Activated'. The CONTRACT_STATUS_C field was used where applicable to confirm active status.

## SQL

```sql
-- Revenue split: as reported vs corrected
SELECT
  'As reported (Account Channel)' as view_type,
  a.CHANNEL_C as classification,
  COUNT(*) as contracts,
  ROUND(SUM(c.NET_ARR_C), 0) as net_arr
FROM INBOUND_RAW.SALESFORCE.CONTRACT c
JOIN INBOUND_RAW.SALESFORCE.ACCOUNT a ON c.ACCOUNT_ID = a.ID
WHERE c.IS_DELETED = FALSE AND a.IS_DELETED = FALSE AND c.STATUS = 'Activated'
GROUP BY a.CHANNEL_C
UNION ALL
SELECT
  'Corrected (Bill To logic)',
  CASE WHEN c.BILL_TO_ACCOUNT_C = c.ACCOUNT_ID OR c.BILL_TO_ACCOUNT_C IS NULL THEN 'Direct' ELSE 'Indirect' END,
  COUNT(*),
  ROUND(SUM(c.NET_ARR_C), 0)
FROM INBOUND_RAW.SALESFORCE.CONTRACT c
JOIN INBOUND_RAW.SALESFORCE.ACCOUNT a ON c.ACCOUNT_ID = a.ID
WHERE c.IS_DELETED = FALSE AND a.IS_DELETED = FALSE AND c.STATUS = 'Activated'
GROUP BY CASE WHEN c.BILL_TO_ACCOUNT_C = c.ACCOUNT_ID OR c.BILL_TO_ACCOUNT_C IS NULL THEN 'Direct' ELSE 'Indirect' END
ORDER BY view_type, classification;
```

## Edge cases

587 accounts ($27.6M ARR) have both channel mismatch AND DUNS duplication -- highest risk for revenue misreporting.

Direct accounts billed through partners are often mid-market companies going through distributors like Epicor and SoftwareONE. Indirect accounts billing themselves directly are mostly large enterprise customers like Discovery Communications, Baker Hughes, Open Text, and Corning.
