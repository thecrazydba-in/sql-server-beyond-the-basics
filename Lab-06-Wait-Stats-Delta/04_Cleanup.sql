/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 06 — Wait Statistics: Take a Delta | Step 5 of 5: Cleanup
   Requires: SQL Server 2019+ Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* This lab changed NO server settings and did NOT clear sys.dm_os_wait_stats.
   The only thing to remove is the lab database.
   Before you run this: if Window 1 was cancelled mid-way, run
       IF @@TRANCOUNT > 0 ROLLBACK;
   in that window (ROLLBACK IMMEDIATE below would also end it). Press F5. */

SET NOCOUNT ON;
USE master;
GO

/* ---------------------------------------------------------------
   STEP 5.1 — Drop CrazyDBA_Lab06 (closes any open lab connections).
   --------------------------------------------------------------- */
IF DB_ID(N'CrazyDBA_Lab06') IS NOT NULL
BEGIN
    ALTER DATABASE CrazyDBA_Lab06 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CrazyDBA_Lab06;
END;
GO

/* ---------------------------------------------------------------
   STEP 5.2 — Verify.
   EXPECTED: lab_database_exists = 0
   Note: the LCK_M_S wait you created stays in the cumulative
   sys.dm_os_wait_stats totals until the next restart. That is normal
   and harmless; this lab never clears the server-wide counters.
   --------------------------------------------------------------- */
SELECT CASE WHEN DB_ID(N'CrazyDBA_Lab06') IS NULL THEN 0 ELSE 1 END AS lab_database_exists;
GO
