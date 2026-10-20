/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 04 — Tail-Log Backup | Step 2 of 5: Reproduce (create the tail)
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* ---------------------------------------------------------------
   Slides 1–2: work continues after the last log backup.
   These 100 rows (OrderID 1,501–1,600, Phase = 'Tail') exist only in
   the live transaction log. No backup contains them yet: they are
   the TAIL OF THE LOG.

   How to run: press F5 (Execute). Run 00_Setup.sql first.
--------------------------------------------------------------- */
SET NOCOUNT ON;
USE CrazyDBA_Lab04;
GO

/* Step 2.1 — 100 new orders after the last log backup.                */
WITH n AS
(
    SELECT TOP (100) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_columns AS a
    CROSS JOIN sys.all_columns AS b
)
INSERT dbo.Orders (OrderID, CustomerName, Amount, Phase)
SELECT 1500 + n,
       N'Customer ' + CAST(1500 + n AS nvarchar(10)),
       CAST(10 + ((1500 + n) % 90) AS decimal(10,2)),
       'Tail'
FROM n;
GO

/* Step 2.2 — Check the live database.
   EXPECTED: Full = 1000, Log1 = 500, Tail = 100, TotalRows = 1600.
   Only 1,500 of these 1,600 rows are inside a backup.                   */
SELECT Phase, COUNT(*) AS OrderRows
FROM dbo.Orders
GROUP BY Phase
ORDER BY MIN(OrderID);

SELECT COUNT(*) AS TotalRows
FROM dbo.Orders;
GO

/* Leave the session in master (restores need exclusive access). */
USE master;
GO
