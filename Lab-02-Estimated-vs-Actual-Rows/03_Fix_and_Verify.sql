/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 02 — Estimated vs Actual Rows | Step 4 of 5: Fix and Verify
   Requires: SQL Server 2019+ (2022 recommended) Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* Slide 7: find the origin, then the cause. In this lab the cause is a
   local variable whose value the optimizer cannot see at compile time.
   Test ONE targeted option at a time and verify it with the actual plan. */

SET NOCOUNT ON;
USE CrazyDBA_Lab02;
GO

/* Option A — OPTION (RECOMPILE)
   Compiles this statement with the CURRENT value of @Status, so the
   optimizer reads the histogram step for N'Shipped'.
   Trade-off: the statement compiles on every execution (CPU cost).
   Ctrl + M, then run.
   EXPECTED:
   - On the Orders access operator: 1245620 of 1245620 (100%)
   - The plan usually changes: a Hash Match join instead of Nested Loops,
     so Customers is read once instead of 1,245,620 seeks.
   - RowsProcessed = 1245620 */
DECLARE @Status nvarchar(20) = N'Shipped';
DECLARE @OrderID int, @CustomerName nvarchar(100);

SELECT @OrderID      = o.OrderID,
       @CustomerName = c.CustomerName
FROM dbo.Orders AS o
JOIN dbo.Customers AS c
    ON c.CustomerID = o.CustomerID
WHERE o.Status = @Status
OPTION (RECOMPILE, MAXDOP 1);

SELECT @@ROWCOUNT AS RowsProcessed;
GO

/* Option B — OPTIMIZE FOR a known value
   Use only if N'Shipped' really is the typical value: every other value
   will now get a plan built for 1,245,620 rows.
   Ctrl + M, then run.
   EXPECTED: same estimate as Option A: 1245620 of 1245620 (100%) */
DECLARE @Status nvarchar(20) = N'Shipped';
DECLARE @OrderID int, @CustomerName nvarchar(100);

SELECT @OrderID      = o.OrderID,
       @CustomerName = c.CustomerName
FROM dbo.Orders AS o
JOIN dbo.Customers AS c
    ON c.CustomerID = o.CustomerID
WHERE o.Status = @Status
OPTION (OPTIMIZE FOR (@Status = N'Shipped'), MAXDOP 1);

SELECT @@ROWCOUNT AS RowsProcessed;
GO

/* Verify — Compare with 01_Reproduce.sql.
   Before: 1245620 of 1000 (124562%), Nested Loops, 1,245,620 inner seeks.
   After:  estimate matches actual (100%), and the join is chosen for the
           real row count. If the estimate is right, the plan choice is
           made with the right information. */
