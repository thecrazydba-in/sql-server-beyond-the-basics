/* The CrazyDBA — SQL Server: Beyond the Basics
   Lab 01 — Parameter Sensitivity | Step 5 of 5: Cleanup
   Requires: SQL Server 2019+ (2022 for the optional steps in 03) Developer Edition, SSMS
   Run on a test instance only.
   https://github.com/thecrazydba-in/sql-server-beyond-the-basics */

SET NOCOUNT ON;
USE master;
GO

/* This lab changed NO server-level settings. All settings it touched
   (compatibility level, Query Store, PSP, plan cache) belong to the lab
   database, so dropping the database removes everything. */

IF DB_ID(N'CrazyDBA_Lab01') IS NOT NULL
BEGIN
    ALTER DATABASE CrazyDBA_Lab01 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CrazyDBA_Lab01;
END;
GO

-- EXPECTED: no rows
SELECT name FROM sys.databases WHERE name = N'CrazyDBA_Lab01';
GO
