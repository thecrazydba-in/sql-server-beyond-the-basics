/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 03 — Implicit Conversion | Step 1 of 5: Setup
   Requires: SQL Server 2019+ (or 2022) Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE master;
GO

/* 1. Drop the lab database if it exists (re-runnable). */
IF DB_ID(N'CrazyDBA_Lab03') IS NOT NULL
BEGIN
    ALTER DATABASE CrazyDBA_Lab03 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CrazyDBA_Lab03;
END;
GO

/* 2. Create the lab database. */
CREATE DATABASE CrazyDBA_Lab03;
GO
ALTER DATABASE CrazyDBA_Lab03 SET RECOVERY SIMPLE;
GO

/* 3. Set the compatibility level explicitly:
      160 on SQL Server 2022, 150 on SQL Server 2019. */
DECLARE @MajorVersion int = CAST(SERVERPROPERTY('ProductMajorVersion') AS int);
IF @MajorVersion >= 16
    EXEC (N'ALTER DATABASE CrazyDBA_Lab03 SET COMPATIBILITY_LEVEL = 160;');
ELSE IF @MajorVersion = 15
    EXEC (N'ALTER DATABASE CrazyDBA_Lab03 SET COMPATIBILITY_LEVEL = 150;');
ELSE
    RAISERROR(N'This lab requires SQL Server 2019 or later.', 16, 1);
GO

USE CrazyDBA_Lab03;
GO

/* 4. Create the table.
      AccountNumber is varchar(20) with a SQL collation ON PURPOSE:
      with a SQL collation, comparing it to an nvarchar value blocks the index seek.
      CustomerName is a filler column that makes the clustered index wider,
      so the optimizer uses the narrow nonclustered index. */
CREATE TABLE dbo.Customers
(
    CustomerID    int          NOT NULL,
    AccountNumber varchar(20)  COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
    CustomerName  char(100)    NOT NULL,
    CONSTRAINT PK_Customers PRIMARY KEY CLUSTERED (CustomerID)
);
GO

/* 5. Load exactly 100,000 deterministic rows.
      CustomerID 1..100000, AccountNumber AW00000001..AW00100000.
      CustomerID 12345 has AccountNumber 'AW00012345'. */
INSERT dbo.Customers (CustomerID, AccountNumber, CustomerName)
SELECT  n.n,
        'AW' + RIGHT('00000000' + CAST(n.n AS varchar(8)), 8),
        'Customer ' + CAST(n.n AS varchar(8))
FROM
(
    SELECT TOP (100000)
           CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS int) AS n
    FROM sys.all_columns AS a
    CROSS JOIN sys.all_columns AS b
) AS n;
GO

/* 6. Index on the column we filter on. */
CREATE NONCLUSTERED INDEX IX_Customers_AccountNumber
    ON dbo.Customers (AccountNumber);
GO

UPDATE STATISTICS dbo.Customers WITH FULLSCAN;
GO

/* 7. Verification.
      EXPECTED: TotalRows = 100000, MatchingRows = 1
      EXPECTED: AccountNumber | varchar | 20 | SQL_Latin1_General_CP1_CI_AS */
SELECT  COUNT(*) AS TotalRows,
        SUM(CASE WHEN AccountNumber = 'AW00012345' THEN 1 ELSE 0 END) AS MatchingRows
FROM dbo.Customers;

SELECT  c.name AS ColumnName,
        TYPE_NAME(c.user_type_id) AS DataType,
        c.max_length AS MaxLength,
        c.collation_name AS CollationName
FROM sys.columns AS c
WHERE c.object_id = OBJECT_ID(N'dbo.Customers')
  AND c.name = N'AccountNumber';
GO
