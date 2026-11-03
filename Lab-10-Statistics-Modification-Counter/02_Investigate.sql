/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 10 — Statistics: Checking the Modification Counter | Step 3 of 5: Investigate
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* Video: Slides 3–6. Run 01_Reproduce.sql first. */

USE CrazyDBA_Lab10;
GO

/* Evidence 1 (Slide 4) — the modification counter.
   Look at: rows and modification_counter, not just last_updated. */
SELECT s.name, sp.rows, sp.modification_counter
FROM sys.stats AS s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp
WHERE s.object_id = OBJECT_ID(N'dbo.Orders')
ORDER BY s.stats_id;
/* Expected:
   PK_Orders            1000000  30000
   IX_Orders_OrderDate  1000000  30000 */
GO

/* Slide 3 — how close are we to the auto-update threshold? */
SELECT s.name,
       sp.rows,
       sp.modification_counter,
       CAST(100.0 * sp.modification_counter / sp.rows AS decimal(5,2)) AS pct_changed,          -- Expected: 3.00
       CONVERT(int, CEILING(SQRT(1000.0 * sp.rows)))                   AS dynamic_threshold,    -- Expected: 31623
       CONVERT(bigint, 500 + 0.20 * sp.rows)                           AS classic_threshold     -- Expected: 200500 (compat < 130)
FROM sys.stats AS s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp
WHERE s.object_id = OBJECT_ID(N'dbo.Orders')
ORDER BY s.stats_id;
/* On compat 130+ the effective threshold is the smaller value: 31,623.
   Auto-update happens only when the threshold is crossed AND a query that
   uses these statistics compiles (or recompiles). */
GO

/* Evidence 2 (Slide 5) — the last histogram step. */
SELECT TOP (1) h.range_high_key, h.equal_rows
FROM sys.stats AS s
CROSS APPLY sys.dm_db_stats_histogram(s.object_id, s.stats_id) AS h
WHERE s.name = N'IX_Orders_OrderDate'
ORDER BY h.step_number DESC;
/* Expected: range_high_key 2025-12-31, equal_rows 2739.
   All 30,000 rows from 2026-01-01 to 2026-01-30 are beyond the last step. */
GO

/* Same information, classic way: */
DBCC SHOW_STATISTICS (N'dbo.Orders', IX_Orders_OrderDate) WITH STAT_HEADER, HISTOGRAM;
/* STAT_HEADER: Rows = 1000000. HISTOGRAM: last RANGE_HI_KEY = 2025-12-31. */
GO

/* Slide 6 — what the optimizer sees. Press Ctrl + M (Include Actual
   Execution Plan), run both queries, hover over the Index Seek and compare
   "Estimated Number of Rows" with "Actual Number of Rows". */

-- A) Inside the histogram: December 1–30, 2025. Actual: 82170. Estimate: close.
SELECT COUNT(*) AS dec_2025_orders
FROM dbo.Orders
WHERE OrderDate >= '20251201' AND OrderDate < '20251231'
OPTION (RECOMPILE);

-- B) Beyond the histogram: January 2026. Actual: 30000.
--    No histogram step covers these dates, so the estimate is an
--    extrapolation. Its exact value depends on the cardinality estimator
--    version, which is why it is not shown on the slide.
SELECT COUNT(*) AS jan_2026_orders
FROM dbo.Orders
WHERE OrderDate >= '20260101'
OPTION (RECOMPILE);
GO
