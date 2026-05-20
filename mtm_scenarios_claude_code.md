# Moments That Matter — Scenario Script Spec
# Paste this into Claude Code to generate automation scripts

## Context

**Product:** Reporting Intelligence (Angles Professional / Report Center / Intelligence Layer)
**Goal:** Build triggered alert scripts for each MTM scenario below
**Output per scenario:** A Python script that queries Snowflake and outputs a list of accounts matching the trigger condition, ready to push to Totango or email to CSMs

---

## Database connections

```
Snowflake account:   [your_account].snowflakecomputing.com
Databases:
  - dev_telemetry           (product telemetry + licensing)
  - inbound_raw             (Salesforce CRM)

Schemas:
  - dev_telemetry.product_telemetry          (WalkMe events and logins)
  - dev_telemetry.awssql_spslicensing_dbo    (license keys and daily usage)
  - inbound_raw.salesforce                   (accounts, opportunities, contracts, tasks)

Key join paths:
  - Licensing → SFDC:    awssql_spslicensing_dbo.customer.SALESFORCEID = salesforce.account.ID
  - Licensing → Telemetry: awssql_spslicensing_dbo.customer.WEBID → product_telemetry ACCOUNT_ID as 'platform:{WEBID}'
  - SFDC → Telemetry:    salesforce.account.PLATFORM_LEGACY_ID_C → product_telemetry ACCOUNT_ID as 'platform:{PLATFORM_LEGACY_ID_C}'
  Note: join coverage on WEBID and PLATFORM_LEGACY_ID_C is partial — add a coverage check to each script
```

---

## Implementation instructions for Claude Code

For each scenario below, generate:
1. A standalone Python script using `snowflake-connector-python`
2. Connection config loaded from environment variables (`SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD`, `SNOWFLAKE_WAREHOUSE`, `SNOWFLAKE_ROLE`)
3. Query output as a pandas DataFrame printed to console and saved as CSV to `./output/S{N}_{scenario_name}.csv`
4. A summary line printed at the end: `"[S{N}] {X} accounts matched trigger"`
5. Error handling and a dry-run flag (`--dry-run`) that prints the SQL without executing

---

## STAGE: ONBOARDING

---


### S1 — CSM Assignment & Sales Handoff

**Priority:** High
**MTM trigger:** Contract signed more than 1 day ago and no CSM assigned to the account
**Stakeholders:** CSM Lead, AE, RevOps

**Sources:**
- `inbound_raw.salesforce.account` — `CUSTOMER_SUCCESS_ASSOCIATE_C`, `ACTIVE_PRODUCT_LINES_C`, `NAME`
- `inbound_raw.salesforce.contract` — `CUSTOMER_SIGNED_DATE`, `STATUS`, `ACCOUNT_ID`
- `inbound_raw.salesforce.onboarding_c` — `STAGE_C`, `STATUS_C`, `ACCOUNT_C`

**SQL:**
```sql
SELECT
  a.NAME                          AS account_name,
  a.ID                            AS sfdc_account_id,
  c.CUSTOMER_SIGNED_DATE          AS contract_signed_date,
  DATEDIFF('day', c.CUSTOMER_SIGNED_DATE, CURRENT_DATE) AS days_since_signature,
  a.CUSTOMER_SUCCESS_ASSOCIATE_C  AS csm_assigned,
  o.STAGE_C                       AS onboarding_stage,
  o.STATUS_C                      AS onboarding_status
FROM inbound_raw.salesforce.account a
JOIN inbound_raw.salesforce.contract c
  ON c.ACCOUNT_ID = a.ID
LEFT JOIN inbound_raw.salesforce.onboarding_c o
  ON o.ACCOUNT_C = a.ID
WHERE c.STATUS = 'Activated'
  AND (a.CUSTOMER_SUCCESS_ASSOCIATE_C IS NULL OR a.CUSTOMER_SUCCESS_ASSOCIATE_C = '')
  AND DATEDIFF('day', c.CUSTOMER_SIGNED_DATE, CURRENT_DATE) > 1
  AND a.ACTIVE_PRODUCT_LINES_C ILIKE '%Angles Professional%'
  AND a._FIVETRAN_DELETED = FALSE
  AND c._FIVETRAN_DELETED = FALSE
ORDER BY days_since_signature DESC
```

**Output columns:** account_name, sfdc_account_id, contract_signed_date, days_since_signature, csm_assigned, onboarding_stage, onboarding_status

---

### S2 — License Key Assigned, Never Used

**Priority:** High
**MTM trigger:** License key assigned and registered, but LASTVALIDATEDDATE is NULL (product never launched) after 48+ hours
**Stakeholders:** CSM, IT/Provisioning

**Sources:**
- `dev_telemetry.awssql_spslicensing_dbo.customerlicensekeys` — `DATEASSIGNED`, `LASTVALIDATEDDATE`, `REGISTERED`, `ASSIGNEDUSER`, `CUSTOMEREMAIL`, `CUSTOMERID`
- `dev_telemetry.awssql_spslicensing_dbo.customer` — `CUSTOMERNAME`, `SALESFORCEID`
- `inbound_raw.salesforce.account` — `CUSTOMER_SUCCESS_ASSOCIATE_C`

**SQL:**
```sql
SELECT
  c.CUSTOMERNAME                  AS account_name,
  c.SALESFORCEID                  AS sfdc_account_id,
  clk.ASSIGNEDUSER                AS assigned_user,
  clk.CUSTOMEREMAIL               AS user_email,
  clk.DATEASSIGNED                AS key_assigned_date,
  DATEDIFF('day', clk.DATEASSIGNED, CURRENT_DATE) AS days_since_assigned,
  a.CUSTOMER_SUCCESS_ASSOCIATE_C  AS csm_id
FROM dev_telemetry.awssql_spslicensing_dbo.customerlicensekeys clk
JOIN dev_telemetry.awssql_spslicensing_dbo.customer c
  ON c.CUSTOMERID = clk.CUSTOMERID
LEFT JOIN inbound_raw.salesforce.account a
  ON a.ID = c.SALESFORCEID
WHERE clk.REGISTERED = TRUE
  AND clk.LASTVALIDATEDDATE IS NULL
  AND clk.DEACTIVATED IS NULL
  AND DATEDIFF('day', clk.DATEASSIGNED, CURRENT_DATE) > 2
  AND clk._FIVETRAN_DELETED = FALSE
  AND c._FIVETRAN_DELETED = FALSE
ORDER BY days_since_assigned DESC
```

**Output columns:** account_name, sfdc_account_id, assigned_user, user_email, key_assigned_date, days_since_assigned, csm_id

---

### S3 — Double-Homepage Confusion (ISW → RC)

**Priority:** High
**MTM trigger:** Account has logins recorded and license validated, but never reached the Report Center homepage
**Stakeholders:** CSM, Product UX, Onboarding

**Sources:**
- `dev_telemetry.product_telemetry.WM_WHOLOGGEDINYESTERDAY_ANGLESPROF` — `ACCOUNT_ID`, `DATE`
- `dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLEPROF_REPORTCENTER` — `ACCOUNT_ID`, `TRACKED_EVENT_NAME`
- `dev_telemetry.awssql_spslicensing_dbo.dailylicenseusage` — `LASTVALIDATEDDATE` (confirms product launched)

**SQL:**
```sql
SELECT
  l.ACCOUNT_ID                    AS telemetry_account_id,
  MAX(l.DATE)                     AS last_login_date,
  COUNT(DISTINCT l.DATE)          AS total_login_days,
  MAX(CASE WHEN r.TRACKED_EVENT_NAME = 'RC | User On Home Page'
      THEN 1 ELSE 0 END)          AS ever_reached_rc
FROM dev_telemetry.product_telemetry.WM_WHOLOGGEDINYESTERDAY_ANGLESPROF l
LEFT JOIN dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLEPROF_REPORTCENTER r
  ON r.ACCOUNT_ID = l.ACCOUNT_ID
GROUP BY l.ACCOUNT_ID
HAVING ever_reached_rc = 0
ORDER BY total_login_days DESC
```

**Output columns:** telemetry_account_id, last_login_date, total_login_days, ever_reached_rc

---

### S4 — First Report Upload Stall

**Priority:** High
**MTM trigger:** More than 3 days since first license validation, no report upload page reached in telemetry
**Stakeholders:** CSM, Product, Onboarding

**Sources:**
- `dev_telemetry.awssql_spslicensing_dbo.dailylicenseusage` — `CUSTOMERID`, `LASTVALIDATEDDATE`
- `dev_telemetry.awssql_spslicensing_dbo.customer` — `CUSTOMERNAME`, `WEBID`
- `dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLEPROF_REPORTCENTER` — `ACCOUNT_ID`, `TRACKED_EVENT_NAME`

**SQL:**
```sql
SELECT
  d.CUSTOMERID                    AS licensing_customer_id,
  c.CUSTOMERNAME                  AS account_name,
  c.SALESFORCEID                  AS sfdc_account_id,
  MIN(d.LASTVALIDATEDDATE)        AS first_product_use,
  MAX(d.LASTVALIDATEDDATE)        AS last_product_use,
  DATEDIFF('day', MIN(d.LASTVALIDATEDDATE), CURRENT_DATE) AS days_since_first_use,
  MAX(CASE WHEN r.TRACKED_EVENT_NAME = 'RC | Upload Report Clicked'
      THEN 1 ELSE 0 END)          AS clicked_upload,
  MAX(CASE WHEN r.TRACKED_EVENT_NAME = 'RC | User on Reports Upload Page'
      THEN 1 ELSE 0 END)          AS reached_upload_page
FROM dev_telemetry.awssql_spslicensing_dbo.dailylicenseusage d
JOIN dev_telemetry.awssql_spslicensing_dbo.customer c
  ON c.CUSTOMERID = d.CUSTOMERID
LEFT JOIN dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLEPROF_REPORTCENTER r
  ON r.ACCOUNT_ID = CONCAT('platform:', c.WEBID)
WHERE c._FIVETRAN_DELETED = FALSE
GROUP BY d.CUSTOMERID, c.CUSTOMERNAME, c.SALESFORCEID
HAVING days_since_first_use > 3
  AND reached_upload_page = 0
ORDER BY days_since_first_use DESC
```

**Output columns:** licensing_customer_id, account_name, sfdc_account_id, first_product_use, last_product_use, days_since_first_use, clicked_upload, reached_upload_page

---

## STAGE: ADOPTION

---

### S5 — Feature Discovery Gap (30-day mark)

**Priority:** Medium
**MTM trigger:** 30+ active license validation days but no secondary RC feature events (Lineos, Schedule, View All)
**Stakeholders:** CSM, Product Marketing

**Sources:**
- `dev_telemetry.awssql_spslicensing_dbo.dailylicenseusage` — `CUSTOMERID`, `LASTVALIDATEDDATE`
- `dev_telemetry.awssql_spslicensing_dbo.customer` — `CUSTOMERNAME`, `WEBID`, `SALESFORCEID`
- `dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLEPROF_REPORTCENTER` — `ACCOUNT_ID`, `TRACKED_EVENT_NAME`
- `inbound_raw.salesforce.account` — `CUSTOMER_SUCCESS_ASSOCIATE_C`

**SQL:**
```sql
SELECT
  d.CUSTOMERID                    AS licensing_customer_id,
  c.CUSTOMERNAME                  AS account_name,
  c.SALESFORCEID                  AS sfdc_account_id,
  COUNT(DISTINCT DATE_TRUNC('day', d.LASTVALIDATEDDATE)) AS active_days,
  DATEDIFF('day', MIN(d.LASTVALIDATEDDATE), MAX(d.LASTVALIDATEDDATE)) AS active_span_days,
  MAX(CASE WHEN r.TRACKED_EVENT_NAME = 'RC | Lineos Clicked'
      THEN 1 ELSE 0 END)          AS used_lineos,
  MAX(CASE WHEN r.TRACKED_EVENT_NAME = 'RC | View all Clicked (Reports)'
      THEN 1 ELSE 0 END)          AS used_view_all,
  MAX(CASE WHEN r.TRACKED_EVENT_NAME = 'RC | User on Create Schedules Page'
      THEN 1 ELSE 0 END)          AS used_schedule,
  a.CUSTOMER_SUCCESS_ASSOCIATE_C  AS csm_id
FROM dev_telemetry.awssql_spslicensing_dbo.dailylicenseusage d
JOIN dev_telemetry.awssql_spslicensing_dbo.customer c
  ON c.CUSTOMERID = d.CUSTOMERID
LEFT JOIN dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLEPROF_REPORTCENTER r
  ON r.ACCOUNT_ID = CONCAT('platform:', c.WEBID)
LEFT JOIN inbound_raw.salesforce.account a
  ON a.ID = c.SALESFORCEID
WHERE c._FIVETRAN_DELETED = FALSE
GROUP BY d.CUSTOMERID, c.CUSTOMERNAME, c.SALESFORCEID, a.CUSTOMER_SUCCESS_ASSOCIATE_C
HAVING active_days >= 30
  AND used_lineos = 0
  AND used_view_all = 0
  AND used_schedule = 0
ORDER BY active_days DESC
```

**Output columns:** licensing_customer_id, account_name, sfdc_account_id, active_days, active_span_days, used_lineos, used_view_all, used_schedule, csm_id

---

### S6 — Schedule Creation Drop-Off

**Priority:** High
**MTM trigger:** Account visited the schedule creation page but did not complete a schedule within 5 days (92% abandonment rate confirmed)
**Stakeholders:** CSM, Product UX

**Sources:**
- `dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLEPROF_REPORTCENTER` — `ACCOUNT_ID`, `TRACKED_EVENT_NAME`, `EVENT_TIME`

**Note:** No save-draft event exists — mid-flow abandonment is invisible. This query detects page entry without completion only.

**SQL:**
```sql
SELECT
  ACCOUNT_ID                      AS telemetry_account_id,
  MIN(CASE WHEN TRACKED_EVENT_NAME = 'RC | User on Create Schedules Page'
      THEN TRY_TO_DATE(EVENT_TIME) END) AS first_schedule_page_visit,
  MAX(CASE WHEN TRACKED_EVENT_NAME = 'RC | User on Create Schedules Page'
      THEN TRY_TO_DATE(EVENT_TIME) END) AS last_schedule_page_visit,
  COUNT(CASE WHEN TRACKED_EVENT_NAME = 'RC | User on Create Schedules Page'
      THEN 1 END)                 AS schedule_page_visits,
  MAX(CASE WHEN TRACKED_EVENT_NAME = 'RC | Create Report Schedule Clicked'
      THEN 1 ELSE 0 END)          AS completed_schedule,
  DATEDIFF('day',
    MIN(CASE WHEN TRACKED_EVENT_NAME = 'RC | User on Create Schedules Page'
        THEN TRY_TO_DATE(EVENT_TIME) END),
    CURRENT_DATE)                 AS days_since_first_visit
FROM dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLEPROF_REPORTCENTER
GROUP BY ACCOUNT_ID
HAVING first_schedule_page_visit IS NOT NULL
  AND completed_schedule = 0
  AND days_since_first_visit > 5
ORDER BY schedule_page_visits DESC
```

**Output columns:** telemetry_account_id, first_schedule_page_visit, last_schedule_page_visit, schedule_page_visits, completed_schedule, days_since_first_visit

---

### S7 — Intelligence Layer Never Entered

**Priority:** High
**MTM trigger:** Account active in Report Center for 7+ days with active license validations but zero Intelligence Layer events ever recorded (90% of RC accounts match this)
**Stakeholders:** CSM, CS Leadership, Product

**Sources:**
- `dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLEPROF_REPORTCENTER` — `ACCOUNT_ID`, `EVENT_TIME`
- `dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLESPROF_INTELLAYER` — `ACCOUNT_ID`
- `dev_telemetry.awssql_spslicensing_dbo.dailylicenseusage` — active validation corroboration
- `inbound_raw.salesforce.account` — `NAME`, `CUSTOMER_SUCCESS_ASSOCIATE_C`, `NEXT_RENEWAL_DATE_C`

**SQL:**
```sql
SELECT
  rc.ACCOUNT_ID                   AS telemetry_account_id,
  MIN(TRY_TO_DATE(rc.EVENT_TIME)) AS first_rc_event,
  MAX(TRY_TO_DATE(rc.EVENT_TIME)) AS last_rc_event,
  COUNT(DISTINCT rc.TRACKED_EVENT_NAME) AS distinct_rc_events,
  DATEDIFF('day', MIN(TRY_TO_DATE(rc.EVENT_TIME)), CURRENT_DATE) AS days_in_rc,
  COUNT(il.TRACKED_EVENT_NAME)    AS total_il_events
FROM dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLEPROF_REPORTCENTER rc
LEFT JOIN dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLESPROF_INTELLAYER il
  ON il.ACCOUNT_ID = rc.ACCOUNT_ID
GROUP BY rc.ACCOUNT_ID
HAVING days_in_rc >= 7
  AND total_il_events = 0
ORDER BY days_in_rc DESC
```

**Output columns:** telemetry_account_id, first_rc_event, last_rc_event, distinct_rc_events, days_in_rc, total_il_events

---

### S8 — Rule Creation Funnel Failure

**Priority:** High
**MTM trigger:** Account visited Intelligence Layer homepage but never saved a rule — includes accounts who only viewed Results tab (curious but blocked)
**Stakeholders:** CSM, Product

**Note:** Subscriber-not-found error during rule creation is not instrumented — this is the most likely cause of abandonment at the subscriber step.

**SQL:**
```sql
SELECT
  ACCOUNT_ID                      AS telemetry_account_id,
  MAX(CASE WHEN TRACKED_EVENT_NAME = 'INTEL | User on Intelligence Layer Home Page'
      THEN 1 ELSE 0 END)          AS visited_il_home,
  MAX(CASE WHEN TRACKED_EVENT_NAME = 'INTEL | Intelligence Layer Button Clicked'
      THEN 1 ELSE 0 END)          AS clicked_il_button,
  MAX(CASE WHEN TRACKED_EVENT_NAME = 'INTEL | Click Create Rule Button'
      THEN 1 ELSE 0 END)          AS started_rule,
  MAX(CASE WHEN TRACKED_EVENT_NAME = 'INTEL | Subscribers Added to Rule'
      THEN 1 ELSE 0 END)          AS added_subscriber,
  MAX(CASE WHEN TRACKED_EVENT_NAME = 'INTEL | Button to Save Rule Clicked'
      THEN 1 ELSE 0 END)          AS saved_rule,
  MAX(CASE WHEN TRACKED_EVENT_NAME = 'INTEL | Click Results tab Button'
      THEN 1 ELSE 0 END)          AS viewed_results_only,
  COUNT(DISTINCT SESSION_ID)      AS total_il_sessions
FROM dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLESPROF_INTELLAYER
GROUP BY ACCOUNT_ID
HAVING visited_il_home = 1
  AND saved_rule = 0
ORDER BY total_il_sessions DESC
```

**Output columns:** telemetry_account_id, visited_il_home, clicked_il_button, started_rule, added_subscriber, saved_rule, viewed_results_only, total_il_sessions

---

### S9 — ⭐ First Rule Fired — Value Realized (proxy)

**Priority:** High
**MTM trigger:** Rule saved but no Intelligence Layer Results tab view in 7+ days — proxy for rule-fire notification not engaged
**Stakeholders:** CSM, CS Leadership, Product

**Note (CRITICAL GAP):** Rule-fire notification events are not currently instrumented in any telemetry table. Results tab view is the closest available proxy. Add a comment to the script flagging this gap and requesting instrumentation.

**SQL:**
```sql
SELECT
  ACCOUNT_ID                      AS telemetry_account_id,
  MIN(CASE WHEN TRACKED_EVENT_NAME = 'INTEL | Button to Save Rule Clicked'
      THEN TRY_TO_DATE(EVENT_TIME) END) AS first_rule_saved_date,
  MAX(CASE WHEN TRACKED_EVENT_NAME = 'INTEL | Button to Save Rule Clicked'
      THEN TRY_TO_DATE(EVENT_TIME) END) AS last_rule_saved_date,
  COUNT(CASE WHEN TRACKED_EVENT_NAME = 'INTEL | Button to Save Rule Clicked'
      THEN 1 END)                 AS total_rules_saved,
  MAX(CASE WHEN TRACKED_EVENT_NAME = 'INTEL | Click Results tab Button'
      THEN TRY_TO_DATE(EVENT_TIME) END) AS last_results_view,
  DATEDIFF('day',
    MIN(CASE WHEN TRACKED_EVENT_NAME = 'INTEL | Button to Save Rule Clicked'
        THEN TRY_TO_DATE(EVENT_TIME) END),
    CURRENT_DATE)                 AS days_since_first_rule
FROM dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLESPROF_INTELLAYER
GROUP BY ACCOUNT_ID
HAVING first_rule_saved_date IS NOT NULL
  AND last_results_view IS NULL
  AND days_since_first_rule > 7
ORDER BY days_since_first_rule DESC
```

**Output columns:** telemetry_account_id, first_rule_saved_date, last_rule_saved_date, total_rules_saved, last_results_view, days_since_first_rule

---

## STAGE: RETENTION

---

### S10 — License Seat Utilization Drop

**Priority:** High
**MTM trigger:** Active user count in current 30-day window is less than 50% of prior 30-day window for accounts with 5+ seats — silent abandonment before renewal
**Stakeholders:** CSM, CS Leadership, RevOps

**Sources:**
- `dev_telemetry.awssql_spslicensing_dbo.dailylicenseusage` — `CUSTOMERID`, `ASSIGNEDUSER`, `LASTVALIDATEDDATE`
- `dev_telemetry.awssql_spslicensing_dbo.customer` — `CUSTOMERNAME`, `SALESFORCEID`
- `inbound_raw.salesforce.account` — `NEXT_RENEWAL_DATE_C`, `CUSTOMER_SUCCESS_ASSOCIATE_C`, `OPEN_RENEWABLE_AMOUNT_C`

**Note:** DAILYLICENSEUSAGE is current to 2026-03-19. Parameterise the reference date (`REF_DATE`) so the script accepts it as a CLI argument defaulting to the max date in the table.

**SQL:**
```sql
WITH ref AS (
  SELECT MAX(LASTVALIDATEDDATE)::DATE AS ref_date
  FROM dev_telemetry.awssql_spslicensing_dbo.dailylicenseusage
),
usage AS (
  SELECT
    d.CUSTOMERID,
    COUNT(DISTINCT CASE
        WHEN d.LASTVALIDATEDDATE >= DATEADD('day', -30, r.ref_date)
        THEN d.ASSIGNEDUSER END)  AS active_users_curr_30d,
    COUNT(DISTINCT CASE
        WHEN d.LASTVALIDATEDDATE BETWEEN DATEADD('day', -60, r.ref_date)
          AND DATEADD('day', -30, r.ref_date)
        THEN d.ASSIGNEDUSER END)  AS active_users_prev_30d
  FROM dev_telemetry.awssql_spslicensing_dbo.dailylicenseusage d
  CROSS JOIN ref r
  WHERE d.LASTVALIDATEDDATE >= DATEADD('day', -60, r.ref_date)
  GROUP BY d.CUSTOMERID
)
SELECT
  u.CUSTOMERID                    AS licensing_customer_id,
  c.CUSTOMERNAME                  AS account_name,
  c.SALESFORCEID                  AS sfdc_account_id,
  u.active_users_prev_30d,
  u.active_users_curr_30d,
  ROUND(u.active_users_curr_30d * 100.0
    / NULLIF(u.active_users_prev_30d, 0), 1) AS utilization_retention_pct,
  a.NEXT_RENEWAL_DATE_C           AS next_renewal_date,
  a.OPEN_RENEWABLE_AMOUNT_C       AS arr_at_risk,
  a.CUSTOMER_SUCCESS_ASSOCIATE_C  AS csm_id
FROM usage u
JOIN dev_telemetry.awssql_spslicensing_dbo.customer c
  ON c.CUSTOMERID = u.CUSTOMERID
LEFT JOIN inbound_raw.salesforce.account a
  ON a.ID = c.SALESFORCEID
WHERE u.active_users_prev_30d >= 5
  AND (u.active_users_curr_30d * 1.0 / NULLIF(u.active_users_prev_30d, 0)) < 0.5
  AND c._FIVETRAN_DELETED = FALSE
ORDER BY u.active_users_prev_30d DESC
```

**Output columns:** licensing_customer_id, account_name, sfdc_account_id, active_users_prev_30d, active_users_curr_30d, utilization_retention_pct, next_renewal_date, arr_at_risk, csm_id

---

### S11 — Dormant Licensed Seats — Renewal Risk

**Priority:** High
**MTM trigger:** More than 30% of registered, active seats have not validated in 30+ days for accounts renewing in the next 120 days
**Stakeholders:** CSM, RevOps, AE

**Sources:**
- `dev_telemetry.awssql_spslicensing_dbo.customerlicensekeys` — `CUSTOMERID`, `ASSIGNEDUSER`, `LASTVALIDATEDDATE`, `REGISTERED`, `DEACTIVATED`
- `dev_telemetry.awssql_spslicensing_dbo.customer` — `CUSTOMERNAME`, `SALESFORCEID`
- `inbound_raw.salesforce.account` — `NEXT_RENEWAL_DATE_C`, `OPEN_RENEWABLE_AMOUNT_C`, `CUSTOMER_SUCCESS_ASSOCIATE_C`

**SQL:**
```sql
SELECT
  c.CUSTOMERNAME                  AS account_name,
  c.SALESFORCEID                  AS sfdc_account_id,
  a.NEXT_RENEWAL_DATE_C           AS next_renewal_date,
  DATEDIFF('day', CURRENT_DATE, a.NEXT_RENEWAL_DATE_C) AS days_to_renewal,
  a.OPEN_RENEWABLE_AMOUNT_C       AS arr_at_risk,
  COUNT(DISTINCT clk.ASSIGNEDUSER) AS total_registered_seats,
  COUNT(DISTINCT CASE
      WHEN clk.LASTVALIDATEDDATE IS NULL
        OR clk.LASTVALIDATEDDATE < DATEADD('day', -30, CURRENT_DATE)
      THEN clk.ASSIGNEDUSER END)  AS dormant_seats,
  ROUND(
    COUNT(DISTINCT CASE
        WHEN clk.LASTVALIDATEDDATE IS NULL
          OR clk.LASTVALIDATEDDATE < DATEADD('day', -30, CURRENT_DATE)
        THEN clk.ASSIGNEDUSER END) * 100.0
    / NULLIF(COUNT(DISTINCT clk.ASSIGNEDUSER), 0), 1) AS dormancy_pct,
  a.CUSTOMER_SUCCESS_ASSOCIATE_C  AS csm_id
FROM dev_telemetry.awssql_spslicensing_dbo.customer c
JOIN dev_telemetry.awssql_spslicensing_dbo.customerlicensekeys clk
  ON clk.CUSTOMERID = c.CUSTOMERID
JOIN inbound_raw.salesforce.account a
  ON a.ID = c.SALESFORCEID
WHERE clk.REGISTERED = TRUE
  AND clk.DEACTIVATED IS NULL
  AND a.NEXT_RENEWAL_DATE_C BETWEEN CURRENT_DATE AND DATEADD('day', 120, CURRENT_DATE)
  AND clk._FIVETRAN_DELETED = FALSE
  AND c._FIVETRAN_DELETED = FALSE
  AND a._FIVETRAN_DELETED = FALSE
GROUP BY c.CUSTOMERNAME, c.SALESFORCEID, a.NEXT_RENEWAL_DATE_C, a.OPEN_RENEWABLE_AMOUNT_C, a.CUSTOMER_SUCCESS_ASSOCIATE_C
HAVING dormancy_pct > 30
ORDER BY days_to_renewal ASC, dormancy_pct DESC
```

**Output columns:** account_name, sfdc_account_id, next_renewal_date, days_to_renewal, arr_at_risk, total_registered_seats, dormant_seats, dormancy_pct, csm_id

---

### S12 — Login-Without-IL Health Check

**Priority:** Medium
**MTM trigger:** Active logins in past 14 days but zero Intelligence Layer events in the same window — customer using RC as a basic viewer only
**Stakeholders:** CSM, CS Leadership, Totango

**Sources:**
- `dev_telemetry.product_telemetry.WM_WHOLOGGEDINYESTERDAY_ANGLESPROF` — `ACCOUNT_ID`, `DATE`
- `dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLESPROF_INTELLAYER` — `ACCOUNT_ID`, `TRACKED_EVENT_NAME`, `EVENT_TIME`
- `inbound_raw.salesforce.account` — `TOTANGO_TOTANGO_ACCOUNT_HEALTH_C`, `CUSTOMER_SUCCESS_ASSOCIATE_C`

**SQL:**
```sql
SELECT
  l.ACCOUNT_ID                    AS telemetry_account_id,
  COUNT(DISTINCT l.DATE)          AS login_days_14d,
  COUNT(il.TRACKED_EVENT_NAME)    AS il_events_14d,
  CASE
    WHEN COUNT(il.TRACKED_EVENT_NAME) = 0 THEN 'login-only risk'
    WHEN COUNT(il.TRACKED_EVENT_NAME) < 3 THEN 'low IL engagement'
    ELSE 'healthy'
  END                             AS health_signal,
  MAX(l.DATE)                     AS last_login_date
FROM dev_telemetry.product_telemetry.WM_WHOLOGGEDINYESTERDAY_ANGLESPROF l
LEFT JOIN dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLESPROF_INTELLAYER il
  ON il.ACCOUNT_ID = l.ACCOUNT_ID
  AND TRY_TO_DATE(il.EVENT_TIME) >= DATEADD('day', -14, CURRENT_DATE)
WHERE l.DATE >= DATEADD('day', -14, CURRENT_DATE)
GROUP BY l.ACCOUNT_ID
HAVING login_days_14d > 0
  AND il_events_14d = 0
ORDER BY login_days_14d DESC
```

**Output columns:** telemetry_account_id, login_days_14d, il_events_14d, health_signal, last_login_date

---

### S13 — ⭐ Intelligence Layer Engagement Drop

**Priority:** High
**MTM trigger:** No new rules created in 60+ days OR IL results page not viewed in 14+ days — silent disengagement from RI's core feature
**Stakeholders:** CSM, CS Leadership, Product

**SQL:**
```sql
SELECT
  ACCOUNT_ID                      AS telemetry_account_id,
  MAX(CASE WHEN TRACKED_EVENT_NAME = 'INTEL | Button to Save Rule Clicked'
      THEN TRY_TO_DATE(EVENT_TIME) END) AS last_rule_save,
  MAX(CASE WHEN TRACKED_EVENT_NAME = 'INTEL | Click Results tab Button'
      THEN TRY_TO_DATE(EVENT_TIME) END) AS last_results_view,
  MAX(CASE WHEN TRACKED_EVENT_NAME = 'INTEL | Edit Rule Button'
      THEN TRY_TO_DATE(EVENT_TIME) END) AS last_rule_edit,
  COUNT(DISTINCT CASE WHEN TRACKED_EVENT_NAME = 'INTEL | Button to Save Rule Clicked'
      THEN SESSION_ID END)        AS total_rules_saved,
  COUNT(DISTINCT CASE WHEN TRACKED_EVENT_NAME = 'INTEL | Delete Rule Button'
      THEN SESSION_ID END)        AS rules_deleted,
  DATEDIFF('day', MAX(TRY_TO_DATE(EVENT_TIME)), CURRENT_DATE) AS days_since_any_il_event
FROM dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLESPROF_INTELLAYER
GROUP BY ACCOUNT_ID
HAVING (last_rule_save IS NOT NULL
    AND DATEDIFF('day', last_rule_save, CURRENT_DATE) > 60)
  OR (last_results_view IS NULL AND days_since_any_il_event > 14)
ORDER BY days_since_any_il_event DESC
```

**Output columns:** telemetry_account_id, last_rule_save, last_results_view, last_rule_edit, total_rules_saved, rules_deleted, days_since_any_il_event

---

### S14 — Pre-Renewal Health Scorecard (120-day window)

**Priority:** High
**MTM trigger:** Renewal date within 120 days — generate a 5-signal health scorecard combining SFDC health, login activity, IL engagement, seat utilization, and open cases
**Stakeholders:** CSM, CS Leadership, RevOps, AE

**Sources:**
- `inbound_raw.salesforce.account` — `NEXT_RENEWAL_DATE_C`, `CUSTOMER_HEALTH_GRADE_C`, `TOTANGO_TOTANGO_ACCOUNT_HEALTH_C`, `OPEN_SUPPORT_CASES_C`, `AT_RISK_C`, `OPEN_RENEWABLE_AMOUNT_C`
- `dev_telemetry.product_telemetry.WM_WHOLOGGEDINYESTERDAY_ANGLESPROF` — login days (90d)
- `dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLESPROF_INTELLAYER` — IL session count
- `dev_telemetry.awssql_spslicensing_dbo.dailylicenseusage` — active licensed users (30d)
- `dev_telemetry.awssql_spslicensing_dbo.customerlicensekeys` — dormant seat count

**SQL:**
```sql
SELECT
  a.NAME                          AS account_name,
  a.ID                            AS sfdc_account_id,
  a.NEXT_RENEWAL_DATE_C           AS renewal_date,
  DATEDIFF('day', CURRENT_DATE, a.NEXT_RENEWAL_DATE_C) AS days_to_renewal,
  a.OPEN_RENEWABLE_AMOUNT_C       AS arr,
  a.CUSTOMER_HEALTH_GRADE_C       AS health_grade,
  a.TOTANGO_TOTANGO_ACCOUNT_HEALTH_C AS totango_health,
  a.AT_RISK_C                     AS at_risk_flag,
  a.OPEN_SUPPORT_CASES_C          AS open_cases,
  a.CUSTOMER_SUCCESS_ASSOCIATE_C  AS csm_id,
  -- Signal 1: login activity
  COUNT(DISTINCT l.DATE)          AS login_days_90d,
  -- Signal 2: IL engagement
  COUNT(DISTINCT il.SESSION_ID)   AS il_sessions_all_time,
  -- Signal 3: active licensed users
  COUNT(DISTINCT d.ASSIGNEDUSER)  AS active_licensed_users_30d,
  -- Signal 4: dormant seats
  COUNT(DISTINCT CASE
      WHEN clk.LASTVALIDATEDDATE IS NULL
        OR clk.LASTVALIDATEDDATE < DATEADD('day', -30, CURRENT_DATE)
      THEN clk.ASSIGNEDUSER END)  AS dormant_seats,
  -- Signal 5: composite risk
  CASE
    WHEN a.TOTANGO_TOTANGO_ACCOUNT_HEALTH_C = 'Poor' THEN 'RED'
    WHEN a.TOTANGO_TOTANGO_ACCOUNT_HEALTH_C = 'Average'
      OR a.OPEN_SUPPORT_CASES_C > 5 THEN 'AMBER'
    ELSE 'GREEN'
  END                             AS risk_tier
FROM inbound_raw.salesforce.account a
LEFT JOIN dev_telemetry.product_telemetry.WM_WHOLOGGEDINYESTERDAY_ANGLESPROF l
  ON l.ACCOUNT_ID = CONCAT('platform:', a.PLATFORM_LEGACY_ID_C)
  AND l.DATE >= DATEADD('day', -90, CURRENT_DATE)
LEFT JOIN dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLESPROF_INTELLAYER il
  ON il.ACCOUNT_ID = CONCAT('platform:', a.PLATFORM_LEGACY_ID_C)
LEFT JOIN dev_telemetry.awssql_spslicensing_dbo.customer c
  ON c.SALESFORCEID = a.ID
LEFT JOIN dev_telemetry.awssql_spslicensing_dbo.dailylicenseusage d
  ON d.CUSTOMERID = c.CUSTOMERID
  AND d.LASTVALIDATEDDATE >= DATEADD('day', -30, CURRENT_DATE)
LEFT JOIN dev_telemetry.awssql_spslicensing_dbo.customerlicensekeys clk
  ON clk.CUSTOMERID = c.CUSTOMERID
  AND clk.REGISTERED = TRUE
  AND clk.DEACTIVATED IS NULL
WHERE a.ACTIVE_PRODUCT_LINES_C ILIKE '%Angles Professional%'
  AND a.NEXT_RENEWAL_DATE_C BETWEEN CURRENT_DATE AND DATEADD('day', 120, CURRENT_DATE)
  AND a._FIVETRAN_DELETED = FALSE
GROUP BY
  a.NAME, a.ID, a.NEXT_RENEWAL_DATE_C, a.OPEN_RENEWABLE_AMOUNT_C,
  a.CUSTOMER_HEALTH_GRADE_C, a.TOTANGO_TOTANGO_ACCOUNT_HEALTH_C,
  a.AT_RISK_C, a.OPEN_SUPPORT_CASES_C, a.CUSTOMER_SUCCESS_ASSOCIATE_C
ORDER BY days_to_renewal ASC, risk_tier ASC
```

**Output columns:** account_name, sfdc_account_id, renewal_date, days_to_renewal, arr, health_grade, totango_health, at_risk_flag, open_cases, csm_id, login_days_90d, il_sessions_all_time, active_licensed_users_30d, dormant_seats, risk_tier

---

## STAGE: OFFBOARDING

---

### S15 — Lapsed Maintenance — Still Using Product

**Priority:** High
**MTM trigger:** Customer has ONMAINTENANCE = FALSE in licensing but product license is still being validated daily — using product without active support coverage
**Stakeholders:** CSM, RevOps, AE, Legal/Compliance

**Sources:**
- `dev_telemetry.awssql_spslicensing_dbo.customer` — `ONMAINTENANCE`, `SALESFORCEID`, `CUSTOMERNAME`
- `dev_telemetry.awssql_spslicensing_dbo.dailylicenseusage` — `LASTVALIDATEDDATE`, `ASSIGNEDUSER`
- `inbound_raw.salesforce.account` — `CANCELLATION_DATE_C`, `CONTRACT_STATUS_C`, `NEXT_RENEWAL_DATE_C`

**SQL:**
```sql
SELECT
  c.CUSTOMERID                    AS licensing_customer_id,
  c.CUSTOMERNAME                  AS account_name,
  c.SALESFORCEID                  AS sfdc_account_id,
  c.ONMAINTENANCE                 AS on_maintenance,
  MAX(d.LASTVALIDATEDDATE)        AS last_license_validation,
  DATEDIFF('day', MAX(d.LASTVALIDATEDDATE), CURRENT_DATE) AS days_since_last_use,
  COUNT(DISTINCT d.ASSIGNEDUSER)  AS users_still_active,
  a.CONTRACT_STATUS_C             AS sfdc_contract_status,
  a.CANCELLATION_DATE_C           AS cancellation_date,
  a.NEXT_RENEWAL_DATE_C           AS next_renewal_date
FROM dev_telemetry.awssql_spslicensing_dbo.customer c
JOIN dev_telemetry.awssql_spslicensing_dbo.dailylicenseusage d
  ON d.CUSTOMERID = c.CUSTOMERID
LEFT JOIN inbound_raw.salesforce.account a
  ON a.ID = c.SALESFORCEID
WHERE c.ONMAINTENANCE = FALSE
  AND d.LASTVALIDATEDDATE >= DATEADD('day', -30, CURRENT_DATE)
  AND c._FIVETRAN_DELETED = FALSE
GROUP BY
  c.CUSTOMERID, c.CUSTOMERNAME, c.SALESFORCEID, c.ONMAINTENANCE,
  a.CONTRACT_STATUS_C, a.CANCELLATION_DATE_C, a.NEXT_RENEWAL_DATE_C
ORDER BY users_still_active DESC
```

**Output columns:** licensing_customer_id, account_name, sfdc_account_id, on_maintenance, last_license_validation, days_since_last_use, users_still_active, sfdc_contract_status, cancellation_date, next_renewal_date

---

### S16 — Cancellation — IL Adoption Audit

**Priority:** High
**MTM trigger:** Opportunity marked Closed Lost in SFDC — capture IL adoption status, RC upload status, and license usage at time of churn for product signal
**Stakeholders:** CSM, Product, CS Leadership, RevOps

**Sources:**
- `inbound_raw.salesforce.opportunity` — `STAGE_NAME`, `WIN_LOSS_REASON_C`, `WIN_LOSS_SUB_REASON_C`, `CLOSE_DATE`, `PRODUCT_LINE_C`
- `inbound_raw.salesforce.account` — `NAME`, `PLATFORM_LEGACY_ID_C`
- `dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLESPROF_INTELLAYER` — IL adoption flag
- `dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLEPROF_REPORTCENTER` — RC upload flag
- `dev_telemetry.awssql_spslicensing_dbo.dailylicenseusage` — peak usage before churn
- `dev_telemetry.awssql_spslicensing_dbo.customer` — `SALESFORCEID` join

**SQL:**
```sql
SELECT
  o.ID                            AS opportunity_id,
  a.NAME                          AS account_name,
  a.ID                            AS sfdc_account_id,
  o.CLOSE_DATE                    AS closed_lost_date,
  o.WIN_LOSS_REASON_C             AS loss_reason,
  o.WIN_LOSS_SUB_REASON_C         AS loss_sub_reason,
  -- IL adoption at time of churn
  MAX(CASE WHEN il.TRACKED_EVENT_NAME IS NOT NULL
      THEN 1 ELSE 0 END)          AS ever_used_intelligence_layer,
  MAX(CASE WHEN il.TRACKED_EVENT_NAME = 'INTEL | Button to Save Rule Clicked'
      THEN 1 ELSE 0 END)          AS ever_saved_rule,
  -- RC upload adoption
  MAX(CASE WHEN rc.TRACKED_EVENT_NAME = 'RC | User on Reports Upload Page'
      THEN 1 ELSE 0 END)          AS ever_uploaded_report,
  -- License usage at churn
  MAX(d.LASTVALIDATEDDATE)        AS last_license_use_date,
  COUNT(DISTINCT d.ASSIGNEDUSER)  AS users_at_churn
FROM inbound_raw.salesforce.opportunity o
JOIN inbound_raw.salesforce.account a
  ON a.ID = o.ACCOUNT_ID
LEFT JOIN dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLESPROF_INTELLAYER il
  ON il.ACCOUNT_ID = CONCAT('platform:', a.PLATFORM_LEGACY_ID_C)
LEFT JOIN dev_telemetry.product_telemetry.WM_TRACKEDEVENTS_ANGLEPROF_REPORTCENTER rc
  ON rc.ACCOUNT_ID = CONCAT('platform:', a.PLATFORM_LEGACY_ID_C)
LEFT JOIN dev_telemetry.awssql_spslicensing_dbo.customer c
  ON c.SALESFORCEID = a.ID
LEFT JOIN dev_telemetry.awssql_spslicensing_dbo.dailylicenseusage d
  ON d.CUSTOMERID = c.CUSTOMERID
WHERE o.PRODUCT_LINE_C = 'Angles Professional'
  AND o.STAGE_NAME = 'Closed Lost'
  AND o._FIVETRAN_DELETED = FALSE
  AND a._FIVETRAN_DELETED = FALSE
GROUP BY o.ID, a.NAME, a.ID, o.CLOSE_DATE, o.WIN_LOSS_REASON_C, o.WIN_LOSS_SUB_REASON_C
ORDER BY o.CLOSE_DATE DESC
```

**Output columns:** opportunity_id, account_name, sfdc_account_id, closed_lost_date, loss_reason, loss_sub_reason, ever_used_intelligence_layer, ever_saved_rule, ever_uploaded_report, last_license_use_date, users_at_churn

---

## Known telemetry gaps — add as TODO comments in each relevant script

1. **S9 — Rule-fire notification event not instrumented.** No telemetry exists for when a rule fires or when a notification is opened/clicked. Results tab view is the best available proxy. Request: add `INTEL | Rule Fired` and `INTEL | Notification Opened` events.
2. **S6 — No save-draft event.** Mid-flow schedule or rule abandonment is invisible unless the user completes or leaves the page entirely. Request: add `RC | Schedule Draft Abandoned` event.
3. **S8 — Subscriber-not-found error not captured.** When a user tries to add a subscriber not in the system, there is no error event. Request: add `INTEL | Subscriber Not Found` event.
4. **S2/S3/S4/S14 — Partial join key coverage.** `CUSTOMER.WEBID` → `platform:{WEBID}` and `ACCOUNT.PLATFORM_LEGACY_ID_C` → `platform:{ID}` joins are incomplete. Add a coverage check function to each script that reports: `{X} of {N} accounts matched via join key ({pct}% coverage)`.

---

## Suggested script structure for Claude Code

```python
# Template — replicate for each scenario

import os
import argparse
import snowflake.connector
import pandas as pd
from datetime import datetime

SCENARIO_ID = "S1"
SCENARIO_NAME = "csm_assignment_handoff"

SQL = """
-- paste scenario SQL here
"""

def run(dry_run=False):
    if dry_run:
        print(f"[{SCENARIO_ID}] DRY RUN — SQL:\n{SQL}")
        return

    conn = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
        role=os.environ.get("SNOWFLAKE_ROLE", "SYSADMIN"),
    )
    df = pd.read_sql(SQL, conn)
    conn.close()

    os.makedirs("output", exist_ok=True)
    out_path = f"output/{SCENARIO_ID}_{SCENARIO_NAME}_{datetime.today().strftime('%Y%m%d')}.csv"
    df.to_csv(out_path, index=False)
    print(f"[{SCENARIO_ID}] {len(df)} accounts matched trigger → {out_path}")
    return df

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    run(dry_run=args.dry_run)
```
