# DUNS duplicate analysis

Status: validated
Profiled: 2026-05-18
Tables: ACCOUNT, DNBCONNECT_D_B_CONNECT_COMPANY_PROFILE_C

## Business question

How many accounts share the same DUNS number, and what patterns explain the duplication?

## Finding

9,736 Account DUNS groups contain 20,727 accounts sharing the same entity-level DUNS. Three distinct patterns explain the majority of these duplicates.

Pattern 1 -- test and internal accounts: insightsoftware's own DUNS (061720173) is shared across 33 accounts including smoke tests, demo accounts, and unrelated BofA ESPP companies.

Pattern 2 -- wrong DUNS assigned: Bank of America's DUNS (055169452) is stamped on 27 accounts that are clearly different companies (BioCryst Pharmaceuticals, Emerson Electric, Republic Services). These are ESPP accounts that incorrectly inherited BofA's DUNS.

Pattern 3 -- legitimate divisions: HSBC (18 accounts) and Epicor (14 accounts) are real divisions of the same entity sharing one DUNS because D&B only assigned one number.

Additionally, 2,598 accounts have a DUNS on the Account record that does not match the linked D&B Profile DUNS. Possible causes include traded-up DUNS numbers, stale D&B profiles, or incorrect D&B matches.

GU and DU DUNS duplicates (41,150 and 43,585 groups respectively) are mostly expected -- they reflect corporate hierarchy, not duplication.

## DUNS coverage (active accounts)

| DUNS field | Populated | Coverage |
|-----------|-----------|----------|
| Account DUNS | 374,214 | 95.4% |
| D&B Profile DUNS | 374,231 | 95.4% |
| DU DUNS | 237,921 | 60.7% |
| GU DUNS | 237,921 | 60.7% |
| Parent DUNS | 114,964 | 29.3% |
| HQ DUNS | 17,498 | 4.5% |

## SQL

```sql
-- Account DUNS duplicates
SELECT DUNSNUMBER_C, COUNT(*) as cnt
FROM INBOUND_RAW.SALESFORCE.ACCOUNT
WHERE IS_DELETED = FALSE AND DUNSNUMBER_C IS NOT NULL
GROUP BY DUNSNUMBER_C
HAVING COUNT(*) > 1
ORDER BY cnt DESC;

-- DUNS mismatch: Account vs D&B Profile
SELECT COUNT(CASE WHEN a.DUNSNUMBER_C = d.DNBCONNECT_DUNSNUMBER_C THEN 1 END) as matching,
       COUNT(CASE WHEN a.DUNSNUMBER_C != d.DNBCONNECT_DUNSNUMBER_C THEN 1 END) as mismatched
FROM INBOUND_RAW.SALESFORCE.ACCOUNT a
JOIN INBOUND_RAW.SALESFORCE.DNBCONNECT_D_B_CONNECT_COMPANY_PROFILE_C d
  ON a.DNBCONNECT_D_B_CONNECT_COMPANY_PROFILE_C = d.ID
WHERE a.IS_DELETED = FALSE AND a.DUNSNUMBER_C IS NOT NULL AND d.DNBCONNECT_DUNSNUMBER_C IS NOT NULL;
```

## Validation reference

Snowflake is the trusted source. Numbers match between Account DUNS and D&B Profile DUNS for 371,616 of 374,214 accounts (99.3%).
