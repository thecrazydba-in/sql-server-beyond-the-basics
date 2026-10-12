/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 01 — Parameter Sensitivity | Step 2 of 5: Reproduce
   Requires: SQL Server 2019+ (2022 for the optional steps in 03) Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE CrazyDBA_Lab01;
GO

/* BEFORE YOU RUN: press Ctrl + M (Include Actual Execution Plan).
   Optional: Query > Query Options > Results > Grid >
   "Discard results after execution", so SSMS does not spend time
   drawing 500,000 rows in the grid. The actual plan is still captured. */

/* ---------------------------------------------------------------
   Step 1 (video Slide 2): clear cached plans for THIS database only.
   Never use a server-wide cache clear for this.
   --------------------------------------------------------------- */
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

/* ---------------------------------------------------------------
   Step 2 (video Slide 2): first call compiles the plan for 'SmallTown'.
   EXPECTED in the actual plan: SELECT <- Nested Loops (Inner Join)
     outer input (top):   Index Seek (NonClustered) [Orders].[IX_Orders_City]
                          200 of 200 (100%)
     inner input (below): Key Lookup (Clustered) [Orders].[PK_Orders]
   --------------------------------------------------------------- */
EXEC dbo.GetOrdersByCity @City = N'SmallTown';
GO

/* ---------------------------------------------------------------
   Step 3 (video Slides 3 and 4): second call reuses that cached plan.
   EXPECTED in the actual plan: the SAME plan shape.
     Index Seek (NonClustered) [Orders].[IX_Orders_City]
     500000 of 200 (250000%)
     Key Lookup (Clustered): runs once per row (500,000 executions).
   This call is noticeably slower than Step 2.
   --------------------------------------------------------------- */
EXEC dbo.GetOrdersByCity @City = N'MetroCity';
GO
