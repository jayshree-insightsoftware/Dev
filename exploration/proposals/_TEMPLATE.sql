-- Mart proposal: (mart_name)
-- See _TEMPLATE.md for the rationale and design notes.
--
-- Grain: (one row per ...)
-- Refresh: (cadence)
-- Dependencies: (raw and staging tables this reads from)

CREATE OR REPLACE TABLE (mart_name) AS
WITH (cte_name) AS (
    -- (description of this CTE's purpose)
    SELECT
        (column),
        (column)
    FROM (source_table)
    WHERE (filter)
)
SELECT
    (column) AS (output_column),
    (column) AS (output_column)
FROM (cte_name)
;

-- Optional: assertions to run after load to catch obvious issues.
-- These complement the formal validation queries in warehouse/marts/validations/.

-- ASSERT row count > 0
-- ASSERT no null primary keys
-- ASSERT (specific business invariant)
