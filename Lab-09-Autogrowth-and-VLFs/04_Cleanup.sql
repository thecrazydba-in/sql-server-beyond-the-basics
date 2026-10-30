/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 09 — Autogrowth Settings and VLF Count | Step 5 of 5: Cleanup
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE master;
GO

/* ------------------------------------------------------------------
   STEP 5.1  Drop the lab database (data and log files are deleted).
   This lab changed no server settings, so nothing else to restore.
   EXPECTED: database_still_exists = 0
------------------------------------------------------------------- */
IF DB_ID(N'CrazyDBA_Lab09') IS NOT NULL
BEGIN
    ALTER DATABASE CrazyDBA_Lab09 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CrazyDBA_Lab09;
END;
GO

SELECT CASE WHEN DB_ID(N'CrazyDBA_Lab09') IS NULL THEN 0 ELSE 1 END AS database_still_exists;
GO
