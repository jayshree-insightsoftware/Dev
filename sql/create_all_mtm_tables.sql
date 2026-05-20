-- ============================================================
-- MTM — Create All Scenario Tables
-- Target schema: consumer_beta.telemetry_overview
-- Run this script in Snowflake to (re)create all 16 tables.
-- Tables are prefixed MTM_ so they are easy to identify.
-- ============================================================

-- ── STAGE: ONBOARDING ────────────────────────────────────────

-- S1 — CSM Assignment & Sales Handoff
CREATE OR REPLACE TABLE consumer_beta.telemetry_overview.MTM_S1_CSM_ASSIGNMENT_HANDOFF AS
SELECT
  a.NAME                          AS account_name,
  a.ID                            AS sfdc_account_id,
  a.TYPE                          AS account_type,
  a.ACTIVE_PRODUCT_LINES_C        AS product_lines,
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
ORDER BY days_since_signature DESC;

-- S2 — License Key Assigned, Never Used
CREATE OR REPLACE TABLE consumer_beta.telemetry_overview.MTM_S2_LICENSE_KEY_NEVER_USED AS
SELECT
  c.CUSTOMERNAME                  AS account_name,
  c.SALESFORCEID                  AS sfdc_account_id,
  a.TYPE                          AS account_type,
  a.ACTIVE_PRODUCT_LINES_C        AS product_lines,
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
ORDER BY days_since_assigned DESC;

-- S3 — Double-Homepage Confusion (ISW → RC)
CREATE OR REPLACE TABLE consumer_beta.telemetry_overview.MTM_S3_DOUBLE_HOMEPAGE_CONFUSION AS
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
ORDER BY total_login_days DESC;

-- S4 — First Report Upload Stall
CREATE OR REPLACE TABLE consumer_beta.telemetry_overview.MTM_S4_FIRST_REPORT_UPLOAD_STALL AS
SELECT
  d.CUSTOMERID                    AS licensing_customer_id,
  c.CUSTOMERNAME                  AS account_name,
  c.SALESFORCEID                  AS sfdc_account_id,
  a.TYPE                          AS account_type,
  a.ACTIVE_PRODUCT_LINES_C        AS product_lines,
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
LEFT JOIN inbound_raw.salesforce.account a
  ON a.ID = c.SALESFORCEID
WHERE c._FIVETRAN_DELETED = FALSE
GROUP BY d.CUSTOMERID, c.CUSTOMERNAME, c.SALESFORCEID, a.TYPE, a.ACTIVE_PRODUCT_LINES_C
HAVING days_since_first_use > 3
  AND reached_upload_page = 0
ORDER BY days_since_first_use DESC;

-- ── STAGE: ADOPTION ──────────────────────────────────────────

-- S5 — Feature Discovery Gap (30-day mark)
CREATE OR REPLACE TABLE consumer_beta.telemetry_overview.MTM_S5_FEATURE_DISCOVERY_GAP AS
SELECT
  d.CUSTOMERID                    AS licensing_customer_id,
  c.CUSTOMERNAME                  AS account_name,
  c.SALESFORCEID                  AS sfdc_account_id,
  a.TYPE                          AS account_type,
  a.ACTIVE_PRODUCT_LINES_C        AS product_lines,
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
GROUP BY d.CUSTOMERID, c.CUSTOMERNAME, c.SALESFORCEID, a.TYPE, a.ACTIVE_PRODUCT_LINES_C, a.CUSTOMER_SUCCESS_ASSOCIATE_C
HAVING active_days >= 30
  AND used_lineos = 0
  AND used_view_all = 0
  AND used_schedule = 0
ORDER BY active_days DESC;

-- S6 — Schedule Creation Drop-Off
CREATE OR REPLACE TABLE consumer_beta.telemetry_overview.MTM_S6_SCHEDULE_CREATION_DROPOFF AS
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
ORDER BY schedule_page_visits DESC;

-- S7 — Intelligence Layer Never Entered
CREATE OR REPLACE TABLE consumer_beta.telemetry_overview.MTM_S7_IL_NEVER_ENTERED AS
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
ORDER BY days_in_rc DESC;

-- S8 — Rule Creation Funnel Failure
CREATE OR REPLACE TABLE consumer_beta.telemetry_overview.MTM_S8_RULE_CREATION_FUNNEL AS
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
ORDER BY total_il_sessions DESC;

-- S9 — First Rule Fired — Value Realized (proxy)
CREATE OR REPLACE TABLE consumer_beta.telemetry_overview.MTM_S9_FIRST_RULE_FIRED AS
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
ORDER BY days_since_first_rule DESC;

-- ── STAGE: RETENTION ─────────────────────────────────────────

-- S10 — License Seat Utilization Drop
CREATE OR REPLACE TABLE consumer_beta.telemetry_overview.MTM_S10_SEAT_UTILIZATION_DROP AS
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
  a.TYPE                          AS account_type,
  a.ACTIVE_PRODUCT_LINES_C        AS product_lines,
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
ORDER BY u.active_users_prev_30d DESC;

-- S11 — Dormant Licensed Seats — Renewal Risk
CREATE OR REPLACE TABLE consumer_beta.telemetry_overview.MTM_S11_DORMANT_LICENSED_SEATS AS
SELECT
  c.CUSTOMERNAME                  AS account_name,
  c.SALESFORCEID                  AS sfdc_account_id,
  a.TYPE                          AS account_type,
  a.ACTIVE_PRODUCT_LINES_C        AS product_lines,
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
GROUP BY c.CUSTOMERNAME, c.SALESFORCEID, a.TYPE, a.ACTIVE_PRODUCT_LINES_C,
         a.NEXT_RENEWAL_DATE_C, a.OPEN_RENEWABLE_AMOUNT_C, a.CUSTOMER_SUCCESS_ASSOCIATE_C
HAVING dormancy_pct > 30
ORDER BY days_to_renewal ASC, dormancy_pct DESC;

-- S12 — Login-Without-IL Health Check
CREATE OR REPLACE TABLE consumer_beta.telemetry_overview.MTM_S12_LOGIN_WITHOUT_IL AS
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
ORDER BY login_days_14d DESC;

-- S13 — Intelligence Layer Engagement Drop
CREATE OR REPLACE TABLE consumer_beta.telemetry_overview.MTM_S13_IL_ENGAGEMENT_DROP AS
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
ORDER BY days_since_any_il_event DESC;

-- S14 — Pre-Renewal Health Scorecard (120-day window)
CREATE OR REPLACE TABLE consumer_beta.telemetry_overview.MTM_S14_PRE_RENEWAL_SCORECARD AS
SELECT
  a.NAME                          AS account_name,
  a.ID                            AS sfdc_account_id,
  a.TYPE                          AS account_type,
  a.ACTIVE_PRODUCT_LINES_C        AS product_lines,
  a.NEXT_RENEWAL_DATE_C           AS renewal_date,
  DATEDIFF('day', CURRENT_DATE, a.NEXT_RENEWAL_DATE_C) AS days_to_renewal,
  a.OPEN_RENEWABLE_AMOUNT_C       AS arr,
  a.CUSTOMER_HEALTH_GRADE_C       AS health_grade,
  a.TOTANGO_TOTANGO_ACCOUNT_HEALTH_C AS totango_health,
  a.AT_RISK_C                     AS at_risk_flag,
  a.OPEN_SUPPORT_CASES_C          AS open_cases,
  a.CUSTOMER_SUCCESS_ASSOCIATE_C  AS csm_id,
  COUNT(DISTINCT l.DATE)          AS login_days_90d,
  COUNT(DISTINCT il.SESSION_ID)   AS il_sessions_all_time,
  COUNT(DISTINCT d.ASSIGNEDUSER)  AS active_licensed_users_30d,
  COUNT(DISTINCT CASE
      WHEN clk.LASTVALIDATEDDATE IS NULL
        OR clk.LASTVALIDATEDDATE < DATEADD('day', -30, CURRENT_DATE)
      THEN clk.ASSIGNEDUSER END)  AS dormant_seats,
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
  a.NAME, a.ID, a.TYPE, a.ACTIVE_PRODUCT_LINES_C, a.NEXT_RENEWAL_DATE_C,
  a.OPEN_RENEWABLE_AMOUNT_C, a.CUSTOMER_HEALTH_GRADE_C,
  a.TOTANGO_TOTANGO_ACCOUNT_HEALTH_C, a.AT_RISK_C,
  a.OPEN_SUPPORT_CASES_C, a.CUSTOMER_SUCCESS_ASSOCIATE_C
ORDER BY days_to_renewal ASC, risk_tier ASC;

-- ── STAGE: OFFBOARDING ───────────────────────────────────────

-- S15 — Lapsed Maintenance — Still Using Product
CREATE OR REPLACE TABLE consumer_beta.telemetry_overview.MTM_S15_LAPSED_MAINTENANCE AS
SELECT
  c.CUSTOMERID                    AS licensing_customer_id,
  c.CUSTOMERNAME                  AS account_name,
  c.SALESFORCEID                  AS sfdc_account_id,
  a.TYPE                          AS account_type,
  a.ACTIVE_PRODUCT_LINES_C        AS product_lines,
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
  c.CUSTOMERID, c.CUSTOMERNAME, c.SALESFORCEID, a.TYPE, a.ACTIVE_PRODUCT_LINES_C,
  c.ONMAINTENANCE, a.CONTRACT_STATUS_C, a.CANCELLATION_DATE_C, a.NEXT_RENEWAL_DATE_C
ORDER BY users_still_active DESC;

-- S16 — Cancellation — IL Adoption Audit
CREATE OR REPLACE TABLE consumer_beta.telemetry_overview.MTM_S16_CANCELLATION_IL_AUDIT AS
SELECT
  o.ID                            AS opportunity_id,
  a.NAME                          AS account_name,
  a.ID                            AS sfdc_account_id,
  a.TYPE                          AS account_type,
  a.ACTIVE_PRODUCT_LINES_C        AS product_lines,
  o.CLOSE_DATE                    AS closed_lost_date,
  o.WIN_LOSS_REASON_C             AS loss_reason,
  o.WIN_LOSS_SUB_REASON_C         AS loss_sub_reason,
  MAX(CASE WHEN il.TRACKED_EVENT_NAME IS NOT NULL
      THEN 1 ELSE 0 END)          AS ever_used_intelligence_layer,
  MAX(CASE WHEN il.TRACKED_EVENT_NAME = 'INTEL | Button to Save Rule Clicked'
      THEN 1 ELSE 0 END)          AS ever_saved_rule,
  MAX(CASE WHEN rc.TRACKED_EVENT_NAME = 'RC | User on Reports Upload Page'
      THEN 1 ELSE 0 END)          AS ever_uploaded_report,
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
GROUP BY o.ID, a.NAME, a.ID, a.TYPE, a.ACTIVE_PRODUCT_LINES_C,
         o.CLOSE_DATE, o.WIN_LOSS_REASON_C, o.WIN_LOSS_SUB_REASON_C
ORDER BY o.CLOSE_DATE DESC;

-- ── MASTER ACCOUNT TABLE ─────────────────────────────────────
-- Run AFTER all S1–S16 tables above are created.
-- See sql/MTM_MASTER_ACCOUNT_TABLE.sql for full script.

CREATE OR REPLACE TABLE consumer_beta.telemetry_overview.MTM_MASTER_ACCOUNT AS

WITH telemetry_id_bridge AS (
  SELECT
    a.ID                              AS sfdc_account_id,
    CONCAT('platform:', lc.WEBID)    AS telemetry_account_id
  FROM inbound_raw.salesforce.account a
  JOIN dev_telemetry.awssql_spslicensing_dbo.customer lc
    ON lc.SALESFORCEID = a.ID
  WHERE lc._FIVETRAN_DELETED = FALSE
    AND a._FIVETRAN_DELETED = FALSE
),
s3_accounts  AS (SELECT DISTINCT b.sfdc_account_id FROM consumer_beta.telemetry_overview.MTM_S3_DOUBLE_HOMEPAGE_CONFUSION  s JOIN telemetry_id_bridge b ON b.telemetry_account_id = s.telemetry_account_id),
s6_accounts  AS (SELECT DISTINCT b.sfdc_account_id FROM consumer_beta.telemetry_overview.MTM_S6_SCHEDULE_CREATION_DROPOFF  s JOIN telemetry_id_bridge b ON b.telemetry_account_id = s.telemetry_account_id),
s7_accounts  AS (SELECT DISTINCT b.sfdc_account_id FROM consumer_beta.telemetry_overview.MTM_S7_IL_NEVER_ENTERED           s JOIN telemetry_id_bridge b ON b.telemetry_account_id = s.telemetry_account_id),
s8_accounts  AS (SELECT DISTINCT b.sfdc_account_id FROM consumer_beta.telemetry_overview.MTM_S8_RULE_CREATION_FUNNEL       s JOIN telemetry_id_bridge b ON b.telemetry_account_id = s.telemetry_account_id),
s9_accounts  AS (SELECT DISTINCT b.sfdc_account_id FROM consumer_beta.telemetry_overview.MTM_S9_FIRST_RULE_FIRED           s JOIN telemetry_id_bridge b ON b.telemetry_account_id = s.telemetry_account_id),
s12_accounts AS (SELECT DISTINCT b.sfdc_account_id FROM consumer_beta.telemetry_overview.MTM_S12_LOGIN_WITHOUT_IL          s JOIN telemetry_id_bridge b ON b.telemetry_account_id = s.telemetry_account_id),
s13_accounts AS (SELECT DISTINCT b.sfdc_account_id FROM consumer_beta.telemetry_overview.MTM_S13_IL_ENGAGEMENT_DROP        s JOIN telemetry_id_bridge b ON b.telemetry_account_id = s.telemetry_account_id)

SELECT
  a.NAME                                AS account_name,
  a.ID                                  AS sfdc_account_id,
  a.TYPE                                AS account_type,
  a.CHANNEL_TYPE__C                      AS channel,
  a.ACTIVE_PRODUCT_LINES_C              AS product_lines,
  a.CUSTOMER_SUCCESS_ASSOCIATE_C        AS csm_id,
  u.NAME                                AS csm_name,
  u.EMAIL                               AS csm_email,
  c.STATUS                              AS contract_status,
  c.CUSTOMER_SIGNED_DATE                AS contract_signed_date,
  a.NEXT_RENEWAL_DATE_C                 AS next_renewal_date,
  DATEDIFF('day', CURRENT_DATE, a.NEXT_RENEWAL_DATE_C) AS days_to_renewal,
  a.OPEN_RENEWABLE_AMOUNT_C             AS arr,
  a.AT_RISK_C                           AS at_risk_flag,
  a.CUSTOMER_HEALTH_GRADE_C             AS health_grade,
  a.TOTANGO_TOTANGO_ACCOUNT_HEALTH_C    AS totango_health,
  a.OPEN_SUPPORT_CASES_C                AS open_support_cases,
  lc.CUSTOMERID                         AS licensing_customer_id,
  lc.WEBID                              AS platform_web_id,
  -- MTM scenario flags
  CASE WHEN s1.sfdc_account_id  IS NOT NULL THEN TRUE ELSE FALSE END AS in_s1_csm_not_assigned,
  CASE WHEN s2.sfdc_account_id  IS NOT NULL THEN TRUE ELSE FALSE END AS in_s2_license_never_used,
  CASE WHEN s3.sfdc_account_id  IS NOT NULL THEN TRUE ELSE FALSE END AS in_s3_homepage_confusion,
  CASE WHEN s4.sfdc_account_id  IS NOT NULL THEN TRUE ELSE FALSE END AS in_s4_report_upload_stall,
  CASE WHEN s5.sfdc_account_id  IS NOT NULL THEN TRUE ELSE FALSE END AS in_s5_feature_gap,
  CASE WHEN s6.sfdc_account_id  IS NOT NULL THEN TRUE ELSE FALSE END AS in_s6_schedule_dropoff,
  CASE WHEN s7.sfdc_account_id  IS NOT NULL THEN TRUE ELSE FALSE END AS in_s7_il_never_entered,
  CASE WHEN s8.sfdc_account_id  IS NOT NULL THEN TRUE ELSE FALSE END AS in_s8_rule_funnel_failure,
  CASE WHEN s9.sfdc_account_id  IS NOT NULL THEN TRUE ELSE FALSE END AS in_s9_first_rule_fired,
  CASE WHEN s10.sfdc_account_id IS NOT NULL THEN TRUE ELSE FALSE END AS in_s10_seat_util_drop,
  CASE WHEN s11.sfdc_account_id IS NOT NULL THEN TRUE ELSE FALSE END AS in_s11_dormant_seats,
  CASE WHEN s12.sfdc_account_id IS NOT NULL THEN TRUE ELSE FALSE END AS in_s12_login_no_il,
  CASE WHEN s13.sfdc_account_id IS NOT NULL THEN TRUE ELSE FALSE END AS in_s13_il_engagement_drop,
  CASE WHEN s14.sfdc_account_id IS NOT NULL THEN TRUE ELSE FALSE END AS in_s14_pre_renewal,
  CASE WHEN s15.sfdc_account_id IS NOT NULL THEN TRUE ELSE FALSE END AS in_s15_lapsed_maintenance,
  CASE WHEN s16.sfdc_account_id IS NOT NULL THEN TRUE ELSE FALSE END AS in_s16_cancellation_audit,
  (
    CASE WHEN s1.sfdc_account_id  IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN s2.sfdc_account_id  IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN s3.sfdc_account_id  IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN s4.sfdc_account_id  IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN s5.sfdc_account_id  IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN s6.sfdc_account_id  IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN s7.sfdc_account_id  IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN s8.sfdc_account_id  IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN s9.sfdc_account_id  IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN s10.sfdc_account_id IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN s11.sfdc_account_id IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN s12.sfdc_account_id IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN s13.sfdc_account_id IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN s14.sfdc_account_id IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN s15.sfdc_account_id IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN s16.sfdc_account_id IS NOT NULL THEN 1 ELSE 0 END
  )                                     AS active_scenario_count
FROM inbound_raw.salesforce.account a
LEFT JOIN inbound_raw.salesforce.user u
  ON u.ID = a.CUSTOMER_SUCCESS_ASSOCIATE_C AND u._FIVETRAN_DELETED = FALSE
LEFT JOIN (
  SELECT ACCOUNT_ID, STATUS, CUSTOMER_SIGNED_DATE,
         ROW_NUMBER() OVER (PARTITION BY ACCOUNT_ID ORDER BY CUSTOMER_SIGNED_DATE DESC) AS rn
  FROM inbound_raw.salesforce.contract
  WHERE STATUS = 'Activated' AND _FIVETRAN_DELETED = FALSE
) c ON c.ACCOUNT_ID = a.ID AND c.rn = 1
LEFT JOIN dev_telemetry.awssql_spslicensing_dbo.customer lc
  ON lc.SALESFORCEID = a.ID AND lc._FIVETRAN_DELETED = FALSE
LEFT JOIN (SELECT DISTINCT sfdc_account_id FROM consumer_beta.telemetry_overview.MTM_S1_CSM_ASSIGNMENT_HANDOFF)  s1  ON s1.sfdc_account_id  = a.ID
LEFT JOIN (SELECT DISTINCT sfdc_account_id FROM consumer_beta.telemetry_overview.MTM_S2_LICENSE_KEY_NEVER_USED)  s2  ON s2.sfdc_account_id  = a.ID
LEFT JOIN (SELECT DISTINCT sfdc_account_id FROM consumer_beta.telemetry_overview.MTM_S4_FIRST_REPORT_UPLOAD_STALL) s4 ON s4.sfdc_account_id = a.ID
LEFT JOIN (SELECT DISTINCT sfdc_account_id FROM consumer_beta.telemetry_overview.MTM_S5_FEATURE_DISCOVERY_GAP)   s5  ON s5.sfdc_account_id  = a.ID
LEFT JOIN (SELECT DISTINCT sfdc_account_id FROM consumer_beta.telemetry_overview.MTM_S10_SEAT_UTILIZATION_DROP)  s10 ON s10.sfdc_account_id = a.ID
LEFT JOIN (SELECT DISTINCT sfdc_account_id FROM consumer_beta.telemetry_overview.MTM_S11_DORMANT_LICENSED_SEATS) s11 ON s11.sfdc_account_id = a.ID
LEFT JOIN (SELECT DISTINCT sfdc_account_id FROM consumer_beta.telemetry_overview.MTM_S14_PRE_RENEWAL_SCORECARD)  s14 ON s14.sfdc_account_id = a.ID
LEFT JOIN (SELECT DISTINCT sfdc_account_id FROM consumer_beta.telemetry_overview.MTM_S15_LAPSED_MAINTENANCE)     s15 ON s15.sfdc_account_id = a.ID
LEFT JOIN (SELECT DISTINCT sfdc_account_id FROM consumer_beta.telemetry_overview.MTM_S16_CANCELLATION_IL_AUDIT)  s16 ON s16.sfdc_account_id = a.ID
LEFT JOIN s3_accounts  s3  ON s3.sfdc_account_id  = a.ID
LEFT JOIN s6_accounts  s6  ON s6.sfdc_account_id  = a.ID
LEFT JOIN s7_accounts  s7  ON s7.sfdc_account_id  = a.ID
LEFT JOIN s8_accounts  s8  ON s8.sfdc_account_id  = a.ID
LEFT JOIN s9_accounts  s9  ON s9.sfdc_account_id  = a.ID
LEFT JOIN s12_accounts s12 ON s12.sfdc_account_id = a.ID
LEFT JOIN s13_accounts s13 ON s13.sfdc_account_id = a.ID
WHERE a.ACTIVE_PRODUCT_LINES_C ILIKE '%Angles Professional%'
  AND a._FIVETRAN_DELETED = FALSE
ORDER BY active_scenario_count DESC, a.NAME;

-- ============================================================
-- Verify row counts after creation
-- ============================================================
SELECT 'S1'      AS scenario, COUNT(*) AS rows FROM consumer_beta.telemetry_overview.MTM_S1_CSM_ASSIGNMENT_HANDOFF   UNION ALL
SELECT 'S2',      COUNT(*) FROM consumer_beta.telemetry_overview.MTM_S2_LICENSE_KEY_NEVER_USED     UNION ALL
SELECT 'S3',      COUNT(*) FROM consumer_beta.telemetry_overview.MTM_S3_DOUBLE_HOMEPAGE_CONFUSION  UNION ALL
SELECT 'S4',      COUNT(*) FROM consumer_beta.telemetry_overview.MTM_S4_FIRST_REPORT_UPLOAD_STALL  UNION ALL
SELECT 'S5',      COUNT(*) FROM consumer_beta.telemetry_overview.MTM_S5_FEATURE_DISCOVERY_GAP      UNION ALL
SELECT 'S6',      COUNT(*) FROM consumer_beta.telemetry_overview.MTM_S6_SCHEDULE_CREATION_DROPOFF  UNION ALL
SELECT 'S7',      COUNT(*) FROM consumer_beta.telemetry_overview.MTM_S7_IL_NEVER_ENTERED           UNION ALL
SELECT 'S8',      COUNT(*) FROM consumer_beta.telemetry_overview.MTM_S8_RULE_CREATION_FUNNEL       UNION ALL
SELECT 'S9',      COUNT(*) FROM consumer_beta.telemetry_overview.MTM_S9_FIRST_RULE_FIRED           UNION ALL
SELECT 'S10',     COUNT(*) FROM consumer_beta.telemetry_overview.MTM_S10_SEAT_UTILIZATION_DROP     UNION ALL
SELECT 'S11',     COUNT(*) FROM consumer_beta.telemetry_overview.MTM_S11_DORMANT_LICENSED_SEATS    UNION ALL
SELECT 'S12',     COUNT(*) FROM consumer_beta.telemetry_overview.MTM_S12_LOGIN_WITHOUT_IL          UNION ALL
SELECT 'S13',     COUNT(*) FROM consumer_beta.telemetry_overview.MTM_S13_IL_ENGAGEMENT_DROP        UNION ALL
SELECT 'S14',     COUNT(*) FROM consumer_beta.telemetry_overview.MTM_S14_PRE_RENEWAL_SCORECARD     UNION ALL
SELECT 'S15',     COUNT(*) FROM consumer_beta.telemetry_overview.MTM_S15_LAPSED_MAINTENANCE        UNION ALL
SELECT 'S16',     COUNT(*) FROM consumer_beta.telemetry_overview.MTM_S16_CANCELLATION_IL_AUDIT     UNION ALL
SELECT 'MASTER',  COUNT(*) FROM consumer_beta.telemetry_overview.MTM_MASTER_ACCOUNT
ORDER BY scenario;
