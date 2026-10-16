/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 03 — Implicit Conversion | Step 5 of 5: Cleanup
   Requires: SQL Server 2019+ (or 2022) Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE master;
GO

/* Drop the lab database. This lab changes no server settings, so nothing else needs restoring.
   EXPECTED: the final SELECT returns DatabaseStillExists = 0 */
IF DB_ID(N'CrazyDBA_Lab03') IS NOT NULL
BEGIN
    ALTER DATABASE CrazyDBA_Lab03 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CrazyDBA_Lab03;
END;
GO

SELECT CASE WHEN DB_ID(N'CrazyDBA_Lab03') IS NULL THEN 0 ELSE 1 END AS DatabaseStillExists;
GO
