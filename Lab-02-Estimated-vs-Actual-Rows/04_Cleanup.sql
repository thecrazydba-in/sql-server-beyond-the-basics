/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 02 — Estimated vs Actual Rows | Step 5 of 5: Cleanup
   Requires: SQL Server 2019+ (2022 recommended) Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

/* Drops the lab database. This lab changed NO server-level settings;
   the scoped configuration (BATCH_MODE_ON_ROWSTORE) and the Query Store
   setting were inside CrazyDBA_Lab02 and disappear with it. */

SET NOCOUNT ON;
USE master;
GO

IF DB_ID(N'CrazyDBA_Lab02') IS NOT NULL
BEGIN
    ALTER DATABASE CrazyDBA_Lab02 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CrazyDBA_Lab02;
END;
GO

/* EXPECTED: LabDatabaseRemoved = 1 */
SELECT LabDatabaseRemoved = CASE WHEN DB_ID(N'CrazyDBA_Lab02') IS NULL THEN 1 ELSE 0 END;
GO
