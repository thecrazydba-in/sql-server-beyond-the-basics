/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 10 — Statistics: Checking the Modification Counter | Step 1 of 5: Setup
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* Creates CrazyDBA_Lab10 with one table, dbo.Orders:
   - 1,000,000 rows, OrderDate 2025-01-01 to 2025-12-31 (deterministic)
   - PK_Orders (clustered) and IX_Orders_OrderDate (nonclustered)
   Both indexes are created AFTER the data load, so their statistics are
   built from all 1,000,000 rows and start with modification_counter = 0.
   Re-runnable: drops and recreates the lab database. */

USE master;
GO

IF DB_ID(N'CrazyDBA_Lab10') IS NOT NULL
BEGIN
    ALTER DATABASE CrazyDBA_Lab10 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CrazyDBA_Lab10;
END;
GO

CREATE DATABASE CrazyDBA_Lab10;
GO

ALTER DATABASE CrazyDBA_Lab10 SET RECOVERY SIMPLE;
ALTER DATABASE CrazyDBA_Lab10 SET COMPATIBILITY_LEVEL = 150;   -- 130+ = dynamic threshold; 150 runs on 2019 and 2022
ALTER DATABASE CrazyDBA_Lab10 SET AUTO_CREATE_STATISTICS ON;
ALTER DATABASE CrazyDBA_Lab10 SET AUTO_UPDATE_STATISTICS ON;
ALTER DATABASE CrazyDBA_Lab10 SET AUTO_UPDATE_STATISTICS_ASYNC OFF;
GO

USE CrazyDBA_Lab10;
GO

CREATE TABLE dbo.Orders
(
    OrderID    int           NOT NULL,
    OrderDate  date          NOT NULL,
    CustomerID int           NOT NULL,
    Amount     decimal(10,2) NOT NULL
);
GO

/* 1,000,000 rows. Day = (n - 1) % 365, so every day of 2025 is used.
   Days 1–265 get 2,740 rows, days 266–365 get 2,739 rows. */
WITH Numbers AS
(
    SELECT TOP (1000000)
           CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS int) AS n
    FROM sys.all_columns AS a
    CROSS JOIN sys.all_columns AS b
)
INSERT INTO dbo.Orders WITH (TABLOCK) (OrderID, OrderDate, CustomerID, Amount)
SELECT n,
       DATEADD(DAY, (n - 1) % 365, CONVERT(date, '20250101')),
       ((n - 1) % 5000) + 1,
       CONVERT(decimal(10,2), ((n * 37) % 50000) / 100.0 + 1)
FROM Numbers;
GO

ALTER TABLE dbo.Orders ADD CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (OrderID);
CREATE NONCLUSTERED INDEX IX_Orders_OrderDate ON dbo.Orders (OrderDate);
GO

/* Verification */
SELECT COUNT(*)       AS total_rows,   -- Expected: 1000000
       MIN(OrderDate) AS first_date,   -- Expected: 2025-01-01
       MAX(OrderDate) AS last_date     -- Expected: 2025-12-31
FROM dbo.Orders;

SELECT s.name, sp.rows, sp.rows_sampled, sp.modification_counter, sp.last_updated
FROM sys.stats AS s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp
WHERE s.object_id = OBJECT_ID(N'dbo.Orders')
ORDER BY s.stats_id;
/* Expected:
   PK_Orders            rows 1000000  rows_sampled 1000000  modification_counter 0
   IX_Orders_OrderDate  rows 1000000  rows_sampled 1000000  modification_counter 0 */
GO
