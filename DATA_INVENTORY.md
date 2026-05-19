# Data inventory

## Connection details

- Warehouse: Snowflake
- Account: xp97223-edw
- Database: INBOUND_RAW
- Schema: SALESFORCE
- Access method: Claude MCP (Snowflake connector)
- Authorized scope: All tables in INBOUND_RAW.SALESFORCE (1,654 tables)

## Tables profiled

### ACCOUNT

- Row count: 614,117 (392,097 active, 222,020 deleted)
- Grain: One row per Salesforce Account record
- Key fields: ID, NAME, TYPE, CHANNEL_C, BILLING_COUNTRY, BILLING_STATE, BILLING_CITY, PHONE, WEBSITE, INDUSTRY, ANNUAL_REVENUE, NUMBER_OF_EMPLOYEES, PARENT_ID, DUNSNUMBER_C, DNBCONNECT_D_B_CONNECT_COMPANY_PROFILE_C, OWNER_ID, IS_DELETED, RECORD_TYPE_ID
- Last profiled: 2026-05-18

Completeness (active accounts only, 392,097):

| Field | Null count | Null % |
|-------|-----------|--------|
| Phone | 77,895 | 20% |
| Billing state | 39,575 | 10% |
| Website | 25,933 | 7% |
| Number of employees | 25,931 | 7% |
| Annual revenue | 21,319 | 5% |
| Billing city | 13,244 | 3% |
| Industry | 8,492 | 2% |
| Billing country | 7,797 | 2% |

Parent ID is null for 76% of accounts which is normal -- most accounts are standalone, not subsidiaries.

Type distribution (active accounts):

| Type | Count |
|------|-------|
| Prospect | 329,462 |
| Customer | 30,457 |
| Former Customer | 20,231 |
| Former Partner | 4,866 |
| Customer (Expired Entitlements) | 4,711 |
| Partner | 2,206 |
| Distributor | 160 |

Channel distribution (active accounts):

| Channel | Count | % |
|---------|-------|---|
| Direct | 347,394 | 88.6% |
| Indirect | 44,705 | 11.4% |

### CONTRACT

- Row count: 265,207 (263,134 active, 2,073 deleted)
- Grain: One row per Salesforce Contract record
- Key fields: ID, ACCOUNT_ID, BILL_TO_ACCOUNT_C, BILL_TO_C, PARTNER_ACCOUNT_C, CONTRACT_STATUS_C, STATUS, START_DATE, END_DATE, NET_ARR_C, CONTRACT_ARR_C, ACCOUNT_TYPE_C
- Last profiled: 2026-05-18

Note: Use CONTRACT_STATUS_C (custom field with values Active/Expired/Cancelled/Inactive) for contract status. The standard STATUS field stays "Activated" and does not update when contracts expire.

Contract status distribution:

| CONTRACT_STATUS_C | Count |
|-------------------|-------|
| Expired | 210,537 |
| Active | 35,712 |
| Cancelled | 14,658 |
| Inactive | 2,260 |

### DNBCONNECT_D_B_CONNECT_COMPANY_PROFILE_C

- Grain: One row per D&B company profile linked to an Account
- Key fields: ID, DNBCONNECT_DUNSNUMBER_C, DU_DUNS_C (Domestic Ultimate), GU_DUNS_C (Global Ultimate), HQ_DUNS_C (Headquarters), PARENT_DUNS_C, DU_PRIM_NAME_C, GU_PRIM_NAME_C, HQ_PRIM_NAME_C, PARENT_PRIM_NAME_C, HIERARCHY_LEVEL_C, IS_STANDALONE_C
- Join: Account.DNBCONNECT_D_B_CONNECT_COMPANY_PROFILE_C = D&B_Profile.ID
- Last profiled: 2026-05-18

## Tables not yet profiled

The following high-value tables are queued for Phase 1 profiling:

- CONTACT (3.4M rows)
- OPPORTUNITY (581K rows)
- OPPORTUNITY_LINE_ITEM (2.2M rows)
- LEAD (1.8M rows)
- CASE (3.8M rows)
- TASK (28.6M rows)
- CAMPAIGN (25K rows)
- PRODUCT_2 (12K rows)

## Access issues

- BUYERGROUPMEMBER: Object exists in Salesforce (confirmed via Object Manager) but cannot be queried from Workbench or Developer Console due to insufficient privileges. Not replicated to Snowflake. Mike Hooker has access and can provide data as needed.
