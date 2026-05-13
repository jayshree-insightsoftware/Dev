-- Validation query for: (mart_name)
--
-- Runs after every mart refresh. Produces a known-good number for a known-good
-- period. If this number changes unexpectedly, something upstream (raw or
-- staging) has shifted and needs investigation.
--
-- Reference: (where the expected value comes from -- PBI report, finance team,
-- historical confirmed value, etc.)
-- Expected: (the number this query should return)
-- Last confirmed: (date you last verified the expected value)

SELECT
    (aggregation) AS validation_value
FROM (mart_name)
WHERE (period_filter)
;

-- Example invariants (uncomment and adapt):
-- ASSERT validation_value BETWEEN (lower) AND (upper)
-- ASSERT validation_value = (exact_expected) (only use when value is fully deterministic)
