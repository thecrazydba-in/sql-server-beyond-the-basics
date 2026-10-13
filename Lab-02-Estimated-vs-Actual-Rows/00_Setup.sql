/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 02 — Estimated vs Actual Rows | Step 1 of 5: Setup
   Requires: SQL Server 2019+ (2022 recommended) Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* What this script does:
   - Drops and recreates the lab database CrazyDBA_Lab02 (safe to re-run).
   - Creates dbo.Customers (200,000 rows) and dbo.Orders (1,250,000 rows).
   - Orders.Status has 1,250 distinct values:
       N'Shipped'            -> 1,245,620 rows
       N'Hold-0001'..N'Hold-1249' -> 4,380 rows in total
     So the AVERAGE rows per status is 1,250,000 / 1,250 = 1,000.
     That average is the estimate you will see in the video.
   Runtime: usually under a minute. */

SET NOCOUNT ON;
USE master;
GO

/* Step 1 — Version check (SQL Server 2019 = 15, SQL Server 2022 = 16). */
IF CAST(SERVERPROPERTY('ProductMajorVersion') AS int) < 15
    THROW 50000, N'Lab 02 requires SQL Server 2019 or later.', 1;
GO

/* Step 2 — Drop the lab database if it exists. */
IF DB_ID(N'CrazyDBA_Lab02') IS NOT NULL
BEGIN
    ALTER DATABASE CrazyDBA_Lab02 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CrazyDBA_Lab02;
END;
GO

/* Step 3 — Create the database and set its options explicitly.
   - Compatibility level 160 on SQL Server 2022, 150 on SQL Server 2019.
   - Query Store OFF: this lab does not use it, and it keeps the plan
     stable between runs (no feedback features adjusting the plan). */
CREATE DATABASE CrazyDBA_Lab02;
GO

ALTER DATABASE CrazyDBA_Lab02 SET RECOVERY SIMPLE;

DECLARE @compat int =
    CASE WHEN CAST(SERVERPROPERTY('ProductMajorVersion') AS int) >= 16
         THEN 160 ELSE 150 END;
DECLARE @sql nvarchar(200) =
    N'ALTER DATABASE CrazyDBA_Lab02 SET COMPATIBILITY_LEVEL = '
    + CAST(@compat AS nvarchar(3)) + N';';
EXEC sys.sp_executesql @sql;

ALTER DATABASE CrazyDBA_Lab02 SET QUERY_STORE = OFF;
GO

USE CrazyDBA_Lab02;
GO

/* Step 4 — Keep the plan in row mode.
   Batch mode on rowstore (compat 150+) can turn this join into an
   Adaptive Join. Switching it off for THIS database only keeps your
   plan identical to the video. Database-scoped; no server change. */
ALTER DATABASE SCOPED CONFIGURATION SET BATCH_MODE_ON_ROWSTORE = OFF;
GO

/* Step 5 — Tables. */
CREATE TABLE dbo.Customers
(
    CustomerID   int           NOT NULL,
    CustomerName nvarchar(100) NOT NULL,
    Filler       char(400)     NOT NULL
        CONSTRAINT DF_Customers_Filler DEFAULT ('x'),
    CONSTRAINT PK_Customers PRIMARY KEY CLUSTERED (CustomerID)
);

CREATE TABLE dbo.Orders
(
    OrderID    int          NOT NULL,
    CustomerID int          NOT NULL,
    Status     nvarchar(20) NOT NULL,
    CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (OrderID)
);
GO

/* Step 6 — Deterministic data (no RAND/NEWID). */
WITH Numbers AS
(
    SELECT TOP (200000)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_columns AS a
    CROSS JOIN sys.all_columns AS b
)
INSERT dbo.Customers WITH (TABLOCK) (CustomerID, CustomerName)
SELECT CAST(n AS int),
       N'Customer ' + CAST(n AS nvarchar(10))
FROM Numbers;
GO

WITH Numbers AS
(
    SELECT TOP (1250000)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_columns AS a
    CROSS JOIN sys.all_columns AS b
)
INSERT dbo.Orders WITH (TABLOCK) (OrderID, CustomerID, Status)
SELECT CAST(n AS int),
       CAST(((n - 1) % 200000) + 1 AS int),
       CASE WHEN n <= 1245620
            THEN N'Shipped'
            ELSE N'Hold-' + RIGHT(N'0000'
                 + CAST(((n - 1245621) % 1249) + 1 AS nvarchar(4)), 4)
       END
FROM Numbers;
GO

/* Step 7 — Index and full-scan statistics. */
CREATE NONCLUSTERED INDEX IX_Orders_Status
    ON dbo.Orders (Status) INCLUDE (CustomerID);
GO

UPDATE STATISTICS dbo.Orders IX_Orders_Status WITH FULLSCAN;
UPDATE STATISTICS dbo.Customers PK_Customers WITH FULLSCAN;
GO

/* Step 8 — Verification.
   EXPECTED (must match README "Expected results"):
   TotalOrders = 1250000 | ShippedOrders = 1245620 | DistinctStatuses = 1250
   AvgRowsPerStatus = 1000 | TotalCustomers = 200000
   CompatibilityLevel = 160 (150 on SQL Server 2019) */
SELECT
    TotalOrders        = (SELECT COUNT(*) FROM dbo.Orders),
    ShippedOrders      = (SELECT COUNT(*) FROM dbo.Orders WHERE Status = N'Shipped'),
    DistinctStatuses   = (SELECT COUNT(DISTINCT Status) FROM dbo.Orders),
    AvgRowsPerStatus   = (SELECT COUNT(*) / COUNT(DISTINCT Status) FROM dbo.Orders),
    TotalCustomers     = (SELECT COUNT(*) FROM dbo.Customers),
    CompatibilityLevel = (SELECT compatibility_level FROM sys.databases
                          WHERE name = N'CrazyDBA_Lab02');
GO
