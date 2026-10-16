/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 03 — Implicit Conversion | Step 2 of 5: Reproduce
   Requires: SQL Server 2019+ (or 2022) Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE CrazyDBA_Lab03;
GO

/* 1. Start clean: clear cached plans for THIS database only (not the whole server). */
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

/* 2. The problem (video Slides 1–3).
      The application sends the account number as nvarchar(20),
      which is what ADO.NET does by default for a .NET string.
      The column is varchar(20).

      In SSMS: press Ctrl + M (Include Actual Execution Plan), then run this batch.

      EXPECTED result: 1 row, CustomerID = 12345.
      EXPECTED plan (right to left):
        Index Scan (NonClustered) [Customers].[IX_Customers_AccountNumber]  →  SELECT
        SELECT shows a yellow warning triangle.
      Hover the triangle: "Type conversion in expression (CONVERT_IMPLICIT(...)) may affect "SeekPlan" in query plan choice". */
EXEC sp_executesql
  N'SELECT c.CustomerID FROM dbo.Customers AS c
    WHERE c.AccountNumber = @Acct',
  N'@Acct nvarchar(20)',
  @Acct = N'AW00012345';
GO
