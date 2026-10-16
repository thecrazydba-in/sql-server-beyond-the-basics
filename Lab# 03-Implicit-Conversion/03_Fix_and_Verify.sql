/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 03 — Implicit Conversion | Step 4 of 5: Fix and Verify
   Requires: SQL Server 2019+ (or 2022) Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE CrazyDBA_Lab03;
GO

/* OPTION A — RECOMMENDED: match the parameter type to the column (video Slide 6).
   In application code this means setting the parameter type explicitly,
   e.g. SqlDbType.VarChar with Size = 20, instead of letting a string default to NVarChar.

   Ctrl + M on, run.
   EXPECTED: 1 row, CustomerID = 12345.
   EXPECTED plan: Index Seek (NonClustered) [Customers].[IX_Customers_AccountNumber] → SELECT,
                  NO warning triangle on SELECT.
   F4 on the Index Seek: Number of Rows Read = 1 */
EXEC sp_executesql
  N'SELECT c.CustomerID FROM dbo.Customers AS c
    WHERE c.AccountNumber = @Acct',
  N'@Acct varchar(20)',
  @Acct = 'AW00012345';
GO

/* OPTION B — if you cannot change the caller's type: convert the PARAMETER, not the column.
   Caution: characters that do not exist in the column's code page become '?'.
   Only use it when the values are known to fit varchar.

   Ctrl + M on, run.
   EXPECTED: 1 row, Index Seek (NonClustered) on IX_Customers_AccountNumber.
   F4 on the Index Seek: Number of Rows Read = 1 */
EXEC sp_executesql
  N'SELECT c.CustomerID FROM dbo.Customers AS c
    WHERE c.AccountNumber = CAST(@Acct AS varchar(20))',
  N'@Acct nvarchar(20)',
  @Acct = N'AW00012345';
GO

/* ANTI-PATTERN — wrapping the COLUMN in CAST (video Slide 7, red bar).
   This only makes the conversion explicit. The column is still converted on every row.

   Ctrl + M on, run.
   EXPECTED: 1 row, but still Index Scan (NonClustered) on IX_Customers_AccountNumber.
   F4 on the Index Scan: Number of Rows Read = 100000 */
EXEC sp_executesql
  N'SELECT c.CustomerID FROM dbo.Customers AS c
    WHERE CAST(c.AccountNumber AS nvarchar(20)) = @Acct',
  N'@Acct nvarchar(20)',
  @Acct = N'AW00012345';
GO

/* NOT RUN HERE — changing the column type to nvarchar(20).
   This also removes the mismatch, but it is a schema change: it doubles the bytes per character,
   needs the index rebuilt, and can create NEW mismatches for callers that send varchar.
   Plan and test it like any other schema change. */
