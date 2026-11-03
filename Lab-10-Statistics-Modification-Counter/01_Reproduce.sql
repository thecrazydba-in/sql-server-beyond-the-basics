/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 10 — Statistics: Checking the Modification Counter | Step 2 of 5: Reproduce
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* Video: Slides 1–3.
   Insert 30,000 new orders, run a query that needs the OrderDate statistics,
   and confirm SQL Server did NOT refresh them. */

USE CrazyDBA_Lab10;
GO

/* Step 1 — 30,000 new orders for 2026-01-01 to 2026-01-30 (1,000 per day). */
WITH Numbers AS
(
    SELECT TOP (30000)
           CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS int) AS n
    FROM sys.all_columns AS a
    CROSS JOIN sys.all_columns AS b
)
INSERT INTO dbo.Orders (OrderID, OrderDate, CustomerID, Amount)
SELECT 1000000 + n,
       DATEADD(DAY, (n - 1) / 1000, CONVERT(date, '20260101')),
       ((n - 1) % 5000) + 1,
       CONVERT(decimal(10,2), ((n * 37) % 50000) / 100.0 + 1)
FROM Numbers;
GO

/* Step 2 — A query that needs the OrderDate statistics.
   OPTION (RECOMPILE) forces a fresh compile, the moment SQL Server checks
   whether the statistics are out of date. */
SELECT COUNT(*) AS jan_2026_orders      -- Expected: 30000
FROM dbo.Orders
WHERE OrderDate >= '20260101'
OPTION (RECOMPILE);
GO

/* Step 3 — The statistics were counted, not refreshed. */
SELECT s.name, sp.rows, sp.modification_counter, sp.last_updated
FROM sys.stats AS s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp
WHERE s.object_id = OBJECT_ID(N'dbo.Orders')
ORDER BY s.stats_id;
/* Expected:
   PK_Orders            rows 1000000  modification_counter 30000
   IX_Orders_OrderDate  rows 1000000  modification_counter 30000
   last_updated is unchanged from 00_Setup.sql.

   Why no auto-update? On compatibility level 130+ the threshold is
   MIN(500 + 0.20 * n, SQRT(1000 * n)). For n = 1,000,000 that is about 31,623
   (and about 32,094 for the current 1,030,000 rows). 30,000 is below both. */
GO
