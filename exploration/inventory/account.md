# Account table inventory

Profiled: 2026-05-18
Source: INBOUND_RAW.SALESFORCE.ACCOUNT
Active rows: 392,097

## Summary

The Account table is the central entity for customer data. It contains 614,117 total rows with a 36.2% deletion rate. Active accounts split 88.6% Direct and 11.4% Indirect by channel. DUNS coverage is strong at 95.4% via D&B Connect integration.

## Key observations

The table has significant data quality issues across four dimensions: duplicates (13,014 exact name groups), DUNS inconsistencies (9,736 duplicate groups), channel misclassification ($75.5M ARR impact when compared against Contract Bill To), and field standardization gaps (272 country variations, 539 industry values).

The CONTRACT_STATUS_C custom field on the Contract table is the correct field for determining active vs expired contracts. The standard STATUS field stays "Activated" permanently and should not be used for filtering.

Phone is the most incomplete field at 20% null for active accounts. Billing country and industry have low null rates but high variation in how values are entered.

## Fields examined

ID, NAME, TYPE, CHANNEL_C, BILLING_COUNTRY, BILLING_STATE, BILLING_CITY, PHONE, WEBSITE, INDUSTRY, ANNUAL_REVENUE, NUMBER_OF_EMPLOYEES, PARENT_ID, DUNSNUMBER_C, DNBCONNECT_D_B_CONNECT_COMPANY_PROFILE_C, DNBCONNECT_MATCHED_DUNS_C, PARTNER_ACCOUNT_C, DISTRIBUTOR_ACCOUNT_C, IS_PARTNER, PARTNER_TYPE_C, CHANNEL_TYPE_C, OWNER_ID, IS_DELETED, RECORD_TYPE_ID, ACCOUNT_NUMBER

## Related tables

- CONTRACT: joined via CONTRACT.ACCOUNT_ID = ACCOUNT.ID and CONTRACT.BILL_TO_ACCOUNT_C = ACCOUNT.ID
- DNBCONNECT_D_B_CONNECT_COMPANY_PROFILE_C: joined via ACCOUNT.DNBCONNECT_D_B_CONNECT_COMPANY_PROFILE_C = D&B.ID
