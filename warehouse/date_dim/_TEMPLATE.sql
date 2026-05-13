-- Date dimension table
--
-- The single source of truth for date-related logic. Built once, joined often.
-- Replaces the JavaScript date arithmetic that causes timezone bugs in the app.
--
-- The app should JOIN against date_dim for all period logic rather than
-- computing dates in JS or in ad-hoc SQL.
--
-- Grain: one row per calendar day

CREATE OR REPLACE TABLE date_dim AS
WITH date_range AS (
    -- Adjust the range based on project needs. Default: 5 years back to 3 years forward.
    SELECT DATEADD(day, seq4(), DATE '2020-01-01') AS date_day
    FROM TABLE(GENERATOR(rowcount => 365 * 10))
)
SELECT
    date_day,
    YEAR(date_day)                                              AS calendar_year,
    QUARTER(date_day)                                           AS calendar_quarter,
    MONTH(date_day)                                             AS calendar_month,
    DAY(date_day)                                               AS calendar_day_of_month,
    DAYOFWEEK(date_day)                                         AS day_of_week,
    DAYOFYEAR(date_day)                                         AS day_of_year,

    -- Month boundaries -- the most useful columns for monthly snapshot queries
    DATE_TRUNC('month', date_day)                               AS month_start,
    LAST_DAY(date_day)                                          AS month_end,

    -- Quarter boundaries
    DATE_TRUNC('quarter', date_day)                             AS quarter_start,
    LAST_DAY(date_day, 'quarter')                               AS quarter_end,

    -- Year boundaries
    DATE_TRUNC('year', date_day)                                AS year_start,
    LAST_DAY(date_day, 'year')                                  AS year_end,

    -- Prior period lookups for year-over-year comparisons
    DATEADD(year, -1, date_day)                                 AS prior_year_same_day,
    LAST_DAY(DATEADD(year, -1, date_day))                       AS prior_year_month_end,

    -- Fiscal calendar (adjust if your fiscal year is offset from calendar year)
    -- The defaults below assume fiscal year = calendar year.
    YEAR(date_day)                                              AS fiscal_year,
    QUARTER(date_day)                                           AS fiscal_quarter,
    MONTH(date_day)                                             AS fiscal_month,

    -- Flags
    CASE WHEN DAYOFWEEK(date_day) IN (1, 7) THEN TRUE ELSE FALSE END AS is_weekend,
    CASE WHEN date_day = LAST_DAY(date_day) THEN TRUE ELSE FALSE END AS is_month_end,
    CASE WHEN date_day = LAST_DAY(date_day, 'quarter') THEN TRUE ELSE FALSE END AS is_quarter_end,
    CASE WHEN date_day = LAST_DAY(date_day, 'year') THEN TRUE ELSE FALSE END AS is_year_end

FROM date_range
ORDER BY date_day
;

-- Add custom holiday flags, business day counts, or other project-specific
-- date attributes here.
