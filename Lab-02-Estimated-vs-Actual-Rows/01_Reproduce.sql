/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 02 — Estimated vs Actual Rows | Step 2 of 5: Reproduce
   Requires: SQL Server 2019+ (2022 recommended) Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* Matches video Slides 1–3: the plan expected 1,000 rows and got 1,245,620. */

SET NOCOUNT ON;
USE CrazyDBA_Lab02;
GO

/* Step 1 — Clear cached plans for THIS database only (not the server). */
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

/* Step 2 — In SSMS press Ctrl + M (Include Actual Execution Plan), then run
   this batch.
   Notes:
   - The values are assigned to variables so SSMS does not have to display
     1.2 million rows. The plan shape is the same.
   - OPTION (MAXDOP 1) keeps the plan serial, so it looks the same on any
     machine as in the video.
   EXPECTED in the "Execution plan" tab (read right to left):
   - Index Seek (NonClustered) [Orders].[IX_Orders_Status]
       label under it: 1245620 of 1000 (124562%)
   - Clustered Index Seek (Clustered) [Customers].[PK_Customers] below it
   - Nested Loops (Inner Join) -> SELECT
   EXPECTED in the "Results" tab: RowsProcessed = 1245620 */
DECLARE @Status nvarchar(20) = N'Shipped';
DECLARE @OrderID int, @CustomerName nvarchar(100);

SELECT @OrderID      = o.OrderID,
       @CustomerName = c.CustomerName
FROM dbo.Orders AS o
JOIN dbo.Customers AS c
    ON c.CustomerID = o.CustomerID
WHERE o.Status = @Status
OPTION (MAXDOP 1);

SELECT @@ROWCOUNT AS RowsProcessed;
GO
