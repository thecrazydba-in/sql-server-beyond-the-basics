/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 02 — Estimated vs Actual Rows | Step 3 of 5: Investigate
   Requires: SQL Server 2019+ (2022 recommended) Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* Matches video Slides 3–6. Property names below are as shown in
   SSMS 18.5 and later. Older SSMS shows "Actual Number of Rows" and
   "Estimated Number of Rows" instead. */

SET NOCOUNT ON;
USE CrazyDBA_Lab02;
GO

/* Step 1 — Ctrl + M, then run (same query as 01_Reproduce.sql).
   EXPECTED on the Index Seek: 1245620 of 1000 (124562%) */
DECLARE @Status nvarchar(20) = N'Shipped';
DECLARE @OrderID int, @CustomerName nvarchar(100);

SELECT @OrderID      = o.OrderID,
       @CustomerName = c.CustomerName
FROM dbo.Orders AS o
JOIN dbo.Customers AS c
    ON c.CustomerID = o.CustomerID
WHERE o.Status = @Status
OPTION (MAXDOP 1);
GO

/* Step 2 — Confirm in Properties (Slide 4).
   Click the Index Seek on [Orders].[IX_Orders_Status], press F4.
   EXPECTED:
     Actual Number of Rows for All Executions    1245620
     Estimated Number of Rows Per Execution      1000
     Estimated Number of Rows for All Executions 1000
     Number of Executions                        1
   It ran once, so compare directly: a real gap. */

/* Step 3 — The per-execution trap (no slide; read-along).
   Click the Clustered Index Seek on [Customers].[PK_Customers], press F4.
   EXPECTED:
     Number of Executions                        1245620
     Actual Number of Rows for All Executions    1245620
     Estimated Number of Rows Per Execution      1
   Per execution: 1245620 / 1245620 = 1 actual vs 1 estimated -> CORRECT.
   This operator ran many times; its estimate per execution is fine.
   Always check Number of Executions before calling something a mismatch. */

/* Step 4 — Find the origin (Slide 5).
   Read right to left. The Index Seek is the FIRST operator with a big
   gap -> origin. The Nested Loops join only inherits the wrong number.
   Do not tune the join; ask why the Index Seek estimate is wrong. */

/* Step 5 — Bonus: WHY is the estimate exactly 1,000?
   The value of a local variable is unknown when the batch compiles, so
   the optimizer uses the average from the density vector:
     rows x All density = 1,250,000 x (1 / 1,250) = 1,000
   EXPECTED below:
   - STAT_HEADER: Rows = 1250000, Rows Sampled = 1250000
   - DENSITY_VECTOR, first row (Columns = Status): All density = 0.0008
   - HISTOGRAM: a step with RANGE_HI_KEY = Shipped and EQ_ROWS = 1245620
     (the optimizer only uses this when it can see the value). */
DBCC SHOW_STATISTICS (N'dbo.Orders', IX_Orders_Status)
    WITH STAT_HEADER, DENSITY_VECTOR;

DBCC SHOW_STATISTICS (N'dbo.Orders', IX_Orders_Status)
    WITH HISTOGRAM;
GO

/* EXPECTED: TotalRows = 1250000 | DistinctStatuses = 1250 | AvgRowsPerStatus = 1000 */
SELECT TotalRows        = COUNT(*),
       DistinctStatuses = COUNT(DISTINCT Status),
       AvgRowsPerStatus = COUNT(*) / COUNT(DISTINCT Status)
FROM dbo.Orders;
GO
