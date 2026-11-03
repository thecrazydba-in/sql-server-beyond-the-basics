/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 10 — Statistics: Checking the Modification Counter | Step 4 of 5: Fix and Verify
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* Video: Slide 7. Update only the statistic that is behind. */

USE CrazyDBA_Lab10;
GO

/* Fix — one targeted statistic. FULLSCAN keeps the lab results exact
   (sampled vs FULLSCAN is Episode 11). */
UPDATE STATISTICS dbo.Orders IX_Orders_OrderDate WITH FULLSCAN;
GO

/* Verify 1 — counter reset, row count current. */
SELECT s.name, sp.rows, sp.modification_counter, sp.last_updated
FROM sys.stats AS s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp
WHERE s.object_id = OBJECT_ID(N'dbo.Orders')
ORDER BY s.stats_id;
/* Expected:
   PK_Orders            rows 1000000  modification_counter 30000  (not touched: targeted update)
   IX_Orders_OrderDate  rows 1030000  modification_counter 0      last_updated = now */
GO

/* Verify 2 — the histogram now covers the new dates. */
SELECT TOP (1) h.range_high_key, h.equal_rows
FROM sys.stats AS s
CROSS APPLY sys.dm_db_stats_histogram(s.object_id, s.stats_id) AS h
WHERE s.name = N'IX_Orders_OrderDate'
ORDER BY h.step_number DESC;
/* Expected: range_high_key 2026-01-30, equal_rows 1000 */
GO

/* Verify 3 — Ctrl + M, run, hover over the Index Seek.
   Actual: 30000. The estimate now comes from histogram steps and should be
   close to 30000. */
SELECT COUNT(*) AS jan_2026_orders
FROM dbo.Orders
WHERE OrderDate >= '20260101'
OPTION (RECOMPILE);
GO

/* Broader options (know what they do before you use them):
   - UPDATE STATISTICS dbo.Orders;   -- every statistic on the table
   - EXEC sp_updatestats;            -- every statistic in the database with
                                     -- at least one modification, default sampling
   Both do more work than this single targeted update. */
