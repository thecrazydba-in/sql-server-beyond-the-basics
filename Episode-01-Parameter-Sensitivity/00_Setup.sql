/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 01 — Parameter Sensitivity | Step 1 of 5: Setup
   Requires: SQL Server 2019+ (2022 for the optional steps in 03) Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE master;
GO

/* ---------------------------------------------------------------
   1. Drop and recreate the lab database (safe to re-run).
   --------------------------------------------------------------- */
IF DB_ID(N'CrazyDBA_Lab01') IS NOT NULL
BEGIN
    ALTER DATABASE CrazyDBA_Lab01 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CrazyDBA_Lab01;
END;
GO

CREATE DATABASE CrazyDBA_Lab01;
GO

ALTER DATABASE CrazyDBA_Lab01 SET RECOVERY SIMPLE;
GO

/* ---------------------------------------------------------------
   2. Compatibility level, set explicitly.
      SQL Server 2022 and later: 160 (baseline of this series).
      SQL Server 2019: 150.
   --------------------------------------------------------------- */
IF CAST(SERVERPROPERTY('ProductMajorVersion') AS int) >= 16
    EXEC (N'ALTER DATABASE CrazyDBA_Lab01 SET COMPATIBILITY_LEVEL = 160;');
ELSE
    EXEC (N'ALTER DATABASE CrazyDBA_Lab01 SET COMPATIBILITY_LEVEL = 150;');
GO

/* ---------------------------------------------------------------
   3. Query Store, set explicitly (used by the optional steps in 03).
   --------------------------------------------------------------- */
ALTER DATABASE CrazyDBA_Lab01
SET QUERY_STORE = ON (OPERATION_MODE = READ_WRITE, QUERY_CAPTURE_MODE = ALL);
GO

USE CrazyDBA_Lab01;
GO

/* ---------------------------------------------------------------
   4. SQL Server 2022+: turn OFF Parameter Sensitive Plan (PSP)
      optimization for now, so the classic problem reproduces exactly
      as in the video. 03_Fix_and_Verify.sql turns it back ON.
      This is a database scoped setting: nothing changes at server level.
   --------------------------------------------------------------- */
IF CAST(SERVERPROPERTY('ProductMajorVersion') AS int) >= 16
    EXEC (N'ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = OFF;');
GO

/* ---------------------------------------------------------------
   5. Table and deterministic data.
      500,200 rows: every 2,501st row is 'SmallTown' (exactly 200 rows),
      all other rows are 'MetroCity' (exactly 500,000 rows).
   --------------------------------------------------------------- */
CREATE TABLE dbo.Orders
(
    OrderID   int           NOT NULL,
    City      nvarchar(50)  NOT NULL,
    OrderDate date          NOT NULL,
    Total     decimal(10,2) NOT NULL,
    CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (OrderID)
);
GO

WITH Numbers AS
(
    SELECT TOP (500200)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_columns AS a
    CROSS JOIN sys.all_columns AS b
)
INSERT INTO dbo.Orders WITH (TABLOCK) (OrderID, City, OrderDate, Total)
SELECT CAST(n AS int),
       CASE WHEN n % 2501 = 0 THEN N'SmallTown' ELSE N'MetroCity' END,
       DATEADD(DAY, CAST(n % 730 AS int), CAST('20240101' AS date)),
       CAST(10 + (n % 990) AS decimal(10,2))
FROM Numbers;
GO

/* ---------------------------------------------------------------
   6. Nonclustered index on City (OrderDate and Total are NOT included,
      so a seek on this index needs a Key Lookup), then full-scan stats.
   --------------------------------------------------------------- */
CREATE NONCLUSTERED INDEX IX_Orders_City ON dbo.Orders (City);
GO

UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO

/* ---------------------------------------------------------------
   7. The stored procedure from the video.
   --------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.GetOrdersByCity
    @City nvarchar(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT OrderID, OrderDate, Total
    FROM dbo.Orders
    WHERE City = @City;
END;
GO

/* ---------------------------------------------------------------
   8. Verification. Must match "Expected results" in README.md.
   --------------------------------------------------------------- */
-- EXPECTED: SmallTown = 200, MetroCity = 500000
SELECT City, COUNT(*) AS OrderCount
FROM dbo.Orders
GROUP BY City
ORDER BY OrderCount;

-- EXPECTED: histogram of IX_Orders_City has two steps:
--           MetroCity equal_rows = 500000, SmallTown equal_rows = 200
SELECT h.range_high_key, h.equal_rows
FROM sys.stats AS s
CROSS APPLY sys.dm_db_stats_histogram(s.object_id, s.stats_id) AS h
WHERE s.object_id = OBJECT_ID(N'dbo.Orders')
  AND s.name = N'IX_Orders_City';

-- EXPECTED: 160 on SQL Server 2022+, 150 on SQL Server 2019
SELECT name, compatibility_level
FROM sys.databases
WHERE name = N'CrazyDBA_Lab01';
GO
